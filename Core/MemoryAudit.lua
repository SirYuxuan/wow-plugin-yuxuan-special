local _, NS = ...

local Core = NS.Core

local Audit = NS.MemoryAudit or {}
NS.MemoryAudit = Audit

local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local tostring = tostring
local unpack = unpack or table.unpack

local DEFAULT_SAMPLE_INTERVAL = 1
local MAX_SAMPLE_COUNT = 600
local MAX_REPORT_ROWS = 5
local MAX_DEBUG_LINES = 800

local function SafeDebugProfileStop()
    if type(debugprofilestop) == "function" then
        return debugprofilestop()
    end
    return 0
end

-- Reusable results table to avoid creating a new table per wrapped call.
local _packResults = {}
local function PackResults(...)
    local n = select("#", ...)
    _packResults.n = n
    for i = 1, n do
        _packResults[i] = select(i, ...)
    end
    -- Clear stale trailing slots from a previous call with more results.
    for i = n + 1, (_packResults._prevN or 0) do
        _packResults[i] = nil
    end
    _packResults._prevN = n
    return _packResults
end

local function Print(message)
    if Core and Core.Print then
        Core:Print(message)
    end
end

local function FormatMemoryKB(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then
        return string_format("%.2f MB", kb / 1024)
    end
    return string_format("%.0f KB", kb)
end

local function FormatNumber(value)
    return string_format("%.2f", tonumber(value) or 0)
end

local function GetTimeSeconds()
    if type(GetTimePreciseSec) == "function" then
        return GetTimePreciseSec()
    end
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

local function GetNumAddOnsCompat()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return C_AddOns.GetNumAddOns()
    end
    return GetNumAddOns and GetNumAddOns() or 0
end

local function GetAddOnInfoCompat(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local info = C_AddOns.GetAddOnInfo(index)
        if type(info) == "table" then
            return info.name or info.Name, info.title or info.Title
        end
        return info
    end

    if GetAddOnInfo then
        local name, title = GetAddOnInfo(index)
        return name, title
    end
end

local function GetAddOnIndexByName(addonName)
    for index = 1, GetNumAddOnsCompat() do
        local name = GetAddOnInfoCompat(index)
        if name == addonName then
            return index
        end
    end
end

local function BuildRankedRows(rows)
    local ranked = {}
    for _, row in ipairs(rows or {}) do
        if (row.calls or 0) > 0 then
            ranked[#ranked + 1] = row
        end
    end

    table_sort(ranked, function(left, right)
        local leftGrowth = tonumber(left.positiveLuaDeltaKB) or 0
        local rightGrowth = tonumber(right.positiveLuaDeltaKB) or 0
        if leftGrowth ~= rightGrowth then
            return leftGrowth > rightGrowth
        end

        local leftMs = tonumber(left.totalMs) or 0
        local rightMs = tonumber(right.totalMs) or 0
        if leftMs ~= rightMs then
            return leftMs > rightMs
        end

        local leftCalls = tonumber(left.calls) or 0
        local rightCalls = tonumber(right.calls) or 0
        if leftCalls ~= rightCalls then
            return leftCalls > rightCalls
        end

        return tostring(left.key or left.module or "") < tostring(right.key or right.module or "")
    end)

    return ranked
end

local function CreateDebugBackdrop(frame, backgroundAlpha)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.06, 0.08, backgroundAlpha or 0.96)
    frame:SetBackdropBorderColor(0.33, 0.38, 0.46, 1)
end

local function CreateDebugButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 84, height or 24)
    CreateDebugBackdrop(button, 1)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(label or "")
    text:SetTextColor(0.92, 0.94, 0.98, 1)
    button.text = text

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.16, 0.20, 0.27, 1)
        self:SetBackdropBorderColor(0.55, 0.68, 0.88, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.08, 0.10, 0.14, 1)
        self:SetBackdropBorderColor(0.33, 0.38, 0.46, 1)
    end)

    return button
end

function Audit:EnsureDebugBuffer()
    self.debugLines = self.debugLines or {}
end

function Audit:GetDebugText()
    self:EnsureDebugBuffer()
    return table_concat(self.debugLines, "\n")
end

function Audit:UpdateDebugWindowStatus()
    local frame = self.debugWindow
    if not frame or not frame.statusText then
        return
    end

    local lineCount = #(self.debugLines or {})
    local modeText = self.sampling and "|cFF33FF99采样中|r" or "|cFFFFD24A未采样|r"
    frame.statusText:SetText(string_format("%s  |cFF8FA4BD日志 %d 行|r", modeText, lineCount))
end

function Audit:RefreshDebugWindow(scrollToBottom)
    local frame = self.debugWindow
    if not frame then
        return
    end

    local text = self:GetDebugText()
    if frame.editBox:GetText() ~= text then
        frame.editBox:SetText(text)
    end

    local width = math_max(1, math_floor((frame.scrollFrame:GetWidth() or 0) - 12))
    local textHeight = 0
    if frame.editBox.GetTextHeight then
        textHeight = frame.editBox:GetTextHeight() or 0
    elseif frame.editBox.GetHeight then
        textHeight = frame.editBox:GetHeight() or 0
    end

    frame.editBox:SetWidth(width)
    frame.editBox:SetHeight(math_max(frame.scrollFrame:GetHeight() or 1, textHeight + 20))
    frame.scrollFrame:UpdateScrollChildRect()

    if frame.scrollBar and frame.scrollBar.UpdateScrollBar then
        frame.scrollBar:UpdateScrollBar()
    end

    self:UpdateDebugWindowStatus()

    if scrollToBottom ~= false then
        C_Timer.After(0, function()
            if Audit.debugWindow == frame and frame.scrollFrame then
                frame.scrollFrame:SetVerticalScroll(frame.scrollFrame:GetVerticalScrollRange() or 0)
                if frame.scrollBar and frame.scrollBar.UpdateScrollBar then
                    frame.scrollBar:UpdateScrollBar()
                end
            end
        end)
    end
end

function Audit:AppendDebugLine(message)
    self:EnsureDebugBuffer()

    local timePrefix = date and date("%H:%M:%S") or ""
    local line = tostring(message or "")
    if timePrefix ~= "" then
        line = "[" .. timePrefix .. "] " .. line
    end

    table_insert(self.debugLines, line)
    while #self.debugLines > MAX_DEBUG_LINES do
        table_remove(self.debugLines, 1)
    end

    self:RefreshDebugWindow(true)
end

function Audit:EmitLine(message, alsoChat)
    self:AppendDebugLine(message)
    if alsoChat then
        Print(message)
    end
end

function Audit:EmitLines(lines, alsoChat)
    for _, line in ipairs(lines or {}) do
        self:EmitLine(line, alsoChat)
    end
end

function Audit:CopyDebugOutput()
    self:ShowDebugWindow()
    if self.debugWindow and self.debugWindow.editBox then
        if self.debugWindow.editBox:GetText() == "" then
            self.debugWindow.editBox:SetText("暂无调试输出")
        end
        self.debugWindow.editBox:SetFocus()
        self.debugWindow.editBox:HighlightText()
    end
end

function Audit:ClearDebugOutput()
    self.debugLines = {}
    self:RefreshDebugWindow(false)
    self:UpdateDebugWindowStatus()
    Print("调试输出已清空")
end

function Audit:HideDebugWindow()
    if self.debugWindow then
        self.debugWindow:Hide()
    end
end

function Audit:ShowDebugWindow()
    if not self.debugWindow then
        local frame = CreateFrame("Frame", "YuXuanSpecialDebugWindow", UIParent, "BackdropTemplate")
        frame:SetSize(820, 560)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(500)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        CreateDebugBackdrop(frame, 0.97)
        frame:Hide()

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetText("雨轩工具箱 调试窗口")
        title:SetTextColor(0.96, 0.84, 0.32, 1)
        frame.title = title

        local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        statusText:SetTextColor(0.62, 0.70, 0.80, 1)
        frame.statusText = statusText

        local closeButton = CreateDebugButton(frame, "关闭", 70, 24)
        closeButton:SetPoint("TOPRIGHT", -14, -12)
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        local buttonBar = CreateFrame("Frame", nil, frame)
        buttonBar:SetPoint("TOPLEFT", 16, -58)
        buttonBar:SetPoint("TOPRIGHT", -16, -58)
        buttonBar:SetHeight(28)

        local startButton = CreateDebugButton(buttonBar, "开始", 72, 24)
        startButton:SetPoint("LEFT", 0, 0)
        startButton:SetScript("OnClick", function()
            Audit:StartSampling()
        end)

        local stopButton = CreateDebugButton(buttonBar, "停止", 72, 24)
        stopButton:SetPoint("LEFT", startButton, "RIGHT", 8, 0)
        stopButton:SetScript("OnClick", function()
            Audit:StopSampling()
        end)

        local reportButton = CreateDebugButton(buttonBar, "报告", 72, 24)
        reportButton:SetPoint("LEFT", stopButton, "RIGHT", 8, 0)
        reportButton:SetScript("OnClick", function()
            Audit:Report()
        end)

        local modulesButton = CreateDebugButton(buttonBar, "模块", 72, 24)
        modulesButton:SetPoint("LEFT", reportButton, "RIGHT", 8, 0)
        modulesButton:SetScript("OnClick", function()
            Audit:ReportModules()
        end)

        local clearButton = CreateDebugButton(buttonBar, "清空", 72, 24)
        clearButton:SetPoint("RIGHT", 0, 0)
        clearButton:SetScript("OnClick", function()
            Audit:ClearDebugOutput()
        end)

        local scrollArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        scrollArea:SetPoint("TOPLEFT", 16, -96)
        scrollArea:SetPoint("BOTTOMRIGHT", -16, 16)
        CreateDebugBackdrop(scrollArea, 0.92)
        frame.scrollArea = scrollArea

        local scrollFrame = CreateFrame("ScrollFrame", nil, scrollArea)
        scrollFrame:SetPoint("TOPLEFT", 10, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", -10, 10)
        scrollFrame:EnableMouseWheel(true)
        frame.scrollFrame = scrollFrame

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(1)
        editBox:SetHeight(1)
        editBox:SetTextInsets(0, 0, 0, 0)
        editBox:SetTextColor(0.90, 0.93, 0.98, 1)
        editBox:SetJustifyH("LEFT")
        editBox:SetJustifyV("TOP")
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            frame:Hide()
        end)
        editBox:SetScript("OnTextChanged", function()
            Audit:RefreshDebugWindow(false)
        end)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            if range <= 0 then
                return
            end

            local step = math_max(30, (self:GetHeight() or 0) * 0.25)
            local value = (self:GetVerticalScroll() or 0) - delta * step
            if value < 0 then
                value = 0
            elseif value > range then
                value = range
            end
            self:SetVerticalScroll(value)
            if frame.scrollBar and frame.scrollBar.UpdateScrollBar then
                frame.scrollBar:UpdateScrollBar()
            end
        end)

        local ui = NS.Options and NS.Options.Private and NS.Options.Private.UI
        if ui and ui.AttachCustomScrollBar then
            frame.scrollBar = ui.AttachCustomScrollBar(scrollFrame, scrollArea, scrollArea)
        end

        frame:SetScript("OnShow", function()
            Audit:RefreshDebugWindow(true)
        end)

        self.debugWindow = frame
    end

    self.debugWindow:Show()
    self:RefreshDebugWindow(true)
end

function Audit:GetAddonMemoryKB()
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end

    self.addonIndex = self.addonIndex or GetAddOnIndexByName(NS.ADDON_NAME)
    if self.addonIndex and GetAddOnMemoryUsage then
        return GetAddOnMemoryUsage(self.addonIndex) or 0
    end

    return 0
end

function Audit:Reset()
    local keepSampling = self.sampling == true

    self.samples = {}
    self.metrics = {}
    self.metricOrder = {}
    self._metricByModule = nil
    self.startedAt = nil
    self.lastSampleAt = nil

    if keepSampling then
        self:CaptureSample()
    end
end

function Audit:EnsureMetric(moduleName, metricName)
    self.metrics = self.metrics or {}
    self.metricOrder = self.metricOrder or {}

    -- Two-level lookup: avoids tostring() .. "::" .. tostring() on every call
    local modKey = moduleName or "Core"
    local metKey = metricName or "unknown"
    self._metricByModule = self._metricByModule or {}
    local modTable = self._metricByModule[modKey]
    if modTable then
        local cached = modTable[metKey]
        if cached then return cached end
    else
        modTable = {}
        self._metricByModule[modKey] = modTable
    end

    local metricKey = tostring(modKey) .. "::" .. tostring(metKey)
    local metric = {
        key = metricKey,
        module = tostring(modKey),
        name = tostring(metKey),
        calls = 0,
        totalMs = 0,
        maxMs = 0,
        totalLuaDeltaKB = 0,
        positiveLuaDeltaKB = 0,
        maxLuaDeltaKB = 0,
    }

    self.metrics[metricKey] = metric
    modTable[metKey] = metric
    table_insert(self.metricOrder, metric)
    return metric
end

function Audit:RecordMetric(moduleName, metricName, elapsedMs, startLuaKB, endLuaKB)
    local metric = self:EnsureMetric(moduleName, metricName)
    local deltaLuaKB = (tonumber(endLuaKB) or 0) - (tonumber(startLuaKB) or 0)

    metric.calls = metric.calls + 1
    metric.totalMs = metric.totalMs + (tonumber(elapsedMs) or 0)
    metric.maxMs = math_max(metric.maxMs, tonumber(elapsedMs) or 0)
    metric.totalLuaDeltaKB = metric.totalLuaDeltaKB + deltaLuaKB
    if deltaLuaKB > 0 then
        metric.positiveLuaDeltaKB = metric.positiveLuaDeltaKB + deltaLuaKB
    end
    metric.maxLuaDeltaKB = math_max(metric.maxLuaDeltaKB, deltaLuaKB)
end

function Audit:CaptureSample()
    if not self.sampling then
        return nil
    end

    self.samples = self.samples or {}

    -- Reuse evicted sample table when ring buffer is full
    local sample
    if #self.samples >= MAX_SAMPLE_COUNT then
        sample = table_remove(self.samples, 1)
    else
        sample = {}
    end

    sample.time = GetTimeSeconds()
    sample.luaKB = collectgarbage("count")
    sample.addonKB = self:GetAddonMemoryKB()

    self.lastSampleAt = sample.time
    if not self.startedAt then
        self.startedAt = sample.time
    end

    table_insert(self.samples, sample)

    return sample
end

function Audit:StartSampling(intervalSeconds)
    if self.sampleTicker then
        self.sampleTicker:Cancel()
        self.sampleTicker = nil
    end

    self.sampling = false
    self:Reset()

    self.sampleInterval = math_max(0.2, tonumber(intervalSeconds) or DEFAULT_SAMPLE_INTERVAL)
    self.sampling = true
    self:CaptureSample()

    if C_Timer and C_Timer.NewTicker then
        if not self._stableSampleCallback then
            self._stableSampleCallback = function()
                Audit:CaptureSample()
            end
        end
        self.sampleTicker = C_Timer.NewTicker(self.sampleInterval, self._stableSampleCallback)
    end

    self:EmitLine("内存审计已启动，采样间隔 " .. FormatNumber(self.sampleInterval) .. " 秒", true)
end

function Audit:StopSampling()
    if self.sampleTicker then
        self.sampleTicker:Cancel()
        self.sampleTicker = nil
    end

    if self.sampling then
        self:CaptureSample()
    end
    self.sampling = false

    self:EmitLine("内存审计已停止", true)
end

function Audit:BeginScope(moduleName, metricName)
    if not self.sampling then
        return nil
    end

    return {
        module = moduleName,
        metric = metricName,
        startedMs = SafeDebugProfileStop(),
        startedLuaKB = collectgarbage("count"),
    }
end

function Audit:EndScope(scope)
    if not scope then
        return
    end

    self:RecordMetric(
        scope.module,
        scope.metric,
        SafeDebugProfileStop() - (scope.startedMs or 0),
        scope.startedLuaKB,
        collectgarbage("count")
    )
end

function Audit:WrapFunction(moduleName, targetTable, functionName, metricName)
    if type(targetTable) ~= "table" or type(targetTable[functionName]) ~= "function" then
        return false
    end

    self.wrappedFunctionKeys = self.wrappedFunctionKeys or {}

    local wrappedKey = tostring(targetTable) .. "::" .. tostring(functionName)
    if self.wrappedFunctionKeys[wrappedKey] then
        return true
    end

    local original = targetTable[functionName]
    local wrappedMetricName = metricName or functionName
    local wrapped = function(...)
        if not Audit.sampling then
            return original(...)
        end

        local startedMs = SafeDebugProfileStop()
        local startedLuaKB = collectgarbage("count")
        local results = PackResults(pcall(original, ...))
        local endedMs = SafeDebugProfileStop()
        local endedLuaKB = collectgarbage("count")

        Audit:RecordMetric(moduleName, wrappedMetricName, endedMs - startedMs, startedLuaKB, endedLuaKB)

        if not results[1] then
            error(results[2], 0)
        end

        return unpack(results, 2, results.n)
    end

    targetTable[functionName] = wrapped
    self.wrappedFunctionKeys[wrappedKey] = true
    return true
end

function Audit:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    self.samples = {}
    self.metrics = {}
    self._metricByModule = nil
    self.metricOrder = {}
    self.sampling = false
    self.sampleInterval = DEFAULT_SAMPLE_INTERVAL
    self.wrappedFunctionKeys = self.wrappedFunctionKeys or {}
    self:EnsureDebugBuffer()

    local modules = NS.Modules or {}
    local interfaceEnhance = modules.InterfaceEnhance or {}
    local combatAssist = modules.CombatAssist or {}
    local mapAssist = modules.MapAssist or {}

    self:WrapFunction("SpecTalentBar", interfaceEnhance.SpecTalentBar, "GetDurabilityEntries")
    self:WrapFunction("SpecTalentBar", interfaceEnhance.SpecTalentBar, "UpdateLayout")
    self:WrapFunction("AttributeDisplay", Core, "UpdateAttributeDisplay")
    self:WrapFunction("InterfaceBeautify", interfaceEnhance.InterfaceBeautify, "Refresh")
    self:WrapFunction("InterfaceBeautify", interfaceEnhance.InterfaceBeautify, "HookChatFrames")
    self:WrapFunction("PerformanceMonitor", Core, "RefreshPerformanceMonitor")
    self:WrapFunction("EventTracker", interfaceEnhance.EventTracker, "TickEventTrackers")
    self:WrapFunction("EventTracker", interfaceEnhance.EventTracker, "UpdateEventTrackers")
    self:WrapFunction("GameBar", Core, "UpdateGameBarLayout")
    self:WrapFunction("DistanceMonitor", interfaceEnhance.DistanceMonitor, "Refresh")
    self:WrapFunction("CursorTrail", interfaceEnhance.CursorTrail, "Refresh")
    self:WrapFunction("RaidMarkers", interfaceEnhance.RaidMarkers, "Refresh")
    self:WrapFunction("MouseTooltip", interfaceEnhance.MouseTooltip, "AppendRaidProgressToTooltip")
    self:WrapFunction("MouseTooltip", interfaceEnhance.MouseTooltip, "RefreshRaidProgressTooltip")
    self:WrapFunction("MouseTooltip", interfaceEnhance.MouseTooltip, "RequestRaidProgressForUnit")
    self:WrapFunction("TrinketMonitor", combatAssist.TrinketMonitor, "UpdateDisplay")
    self:WrapFunction("TrinketMonitor", combatAssist.TrinketMonitor, "UpdateButton")
    self:WrapFunction("MapIDDisplay", mapAssist.MapIDDisplay, "UpdateText")
end

function Audit:Report()
    if self.sampling then
        self:CaptureSample()
    end

    if not self.samples or #self.samples < 2 then
        self:EmitLine("内存审计样本不足，请先运行 /yxs mem start", true)
        return
    end

    local firstSample = self.samples[1]
    local lastSample = self.samples[#self.samples]
    local duration = math_max(0.001, (lastSample.time or 0) - (firstSample.time or 0))
    local luaDeltaKB = (lastSample.luaKB or 0) - (firstSample.luaKB or 0)
    local addonDeltaKB = (lastSample.addonKB or 0) - (firstSample.addonKB or 0)
    local luaRateKBPerMinute = luaDeltaKB / duration * 60
    local addonRateKBPerMinute = addonDeltaKB / duration * 60

    self:EmitLine("内存审计窗口 " .. FormatNumber(duration) .. " 秒", true)
    self:EmitLine(
        "Lua: "
        .. FormatMemoryKB(firstSample.luaKB) .. " -> " .. FormatMemoryKB(lastSample.luaKB)
        .. " (" .. (luaDeltaKB >= 0 and "+" or "") .. FormatMemoryKB(luaDeltaKB)
        .. ", " .. (luaRateKBPerMinute >= 0 and "+" or "") .. FormatMemoryKB(luaRateKBPerMinute) .. "/分钟)",
        true
    )
    self:EmitLine(
        "插件: "
        .. FormatMemoryKB(firstSample.addonKB) .. " -> " .. FormatMemoryKB(lastSample.addonKB)
        .. " (" .. (addonDeltaKB >= 0 and "+" or "") .. FormatMemoryKB(addonDeltaKB)
        .. ", " .. (addonRateKBPerMinute >= 0 and "+" or "") .. FormatMemoryKB(addonRateKBPerMinute) .. "/分钟)",
        true
    )

    local topMetrics = BuildRankedRows(self.metricOrder)
    if #topMetrics == 0 then
        self:EmitLine("当前没有记录到热点函数调用", true)
        return
    end

    local rowCount = math_min(MAX_REPORT_ROWS, #topMetrics)
    self:EmitLine("热点函数 Top " .. tostring(rowCount), true)
    for index = 1, rowCount do
        local metric = topMetrics[index]
        local avgMs = metric.calls > 0 and (metric.totalMs / metric.calls) or 0
        self:EmitLine(
            string_format(
                "%d. [%s] %s 调用 %d 次，总耗时 %s ms，均值 %s ms，正向 Lua 增量 %s",
                index,
                metric.module,
                metric.name,
                metric.calls,
                FormatNumber(metric.totalMs),
                FormatNumber(avgMs),
                FormatMemoryKB(metric.positiveLuaDeltaKB)
            ),
            true
        )
    end
end

function Audit:ReportModules()
    local grouped = {}
    for _, metric in ipairs(self.metricOrder or {}) do
        if metric.calls > 0 then
            local row = grouped[metric.module]
            if not row then
                row = {
                    module = metric.module,
                    calls = 0,
                    totalMs = 0,
                    positiveLuaDeltaKB = 0,
                }
                grouped[metric.module] = row
            end

            row.calls = row.calls + metric.calls
            row.totalMs = row.totalMs + metric.totalMs
            row.positiveLuaDeltaKB = row.positiveLuaDeltaKB + metric.positiveLuaDeltaKB
        end
    end

    local rows = {}
    for _, row in pairs(grouped) do
        rows[#rows + 1] = row
    end

    rows = BuildRankedRows(rows)
    if #rows == 0 then
        self:EmitLine("当前没有模块级热点数据", true)
        return
    end

    local rowCount = math_min(MAX_REPORT_ROWS, #rows)
    self:EmitLine("模块热点排行", true)
    for index = 1, rowCount do
        local row = rows[index]
        self:EmitLine(
            string_format(
                "%d. [%s] 调用 %d 次，总耗时 %s ms，正向 Lua 增量 %s",
                index,
                row.module,
                row.calls,
                FormatNumber(row.totalMs),
                FormatMemoryKB(row.positiveLuaDeltaKB)
            ),
            true
        )
    end
end

function Audit:IsSampling()
    return self.sampling == true
end
