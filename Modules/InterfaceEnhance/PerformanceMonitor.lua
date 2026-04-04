local addonName, NS = ...
local Core = NS.Core

local PerformanceMonitor = {}
NS.Modules.InterfaceEnhance.PerformanceMonitor = PerformanceMonitor

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "performanceMonitor")
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function CreateSimpleOutline(parent, layer, thickness)
    local border = {}
    local size = thickness or 1

    border.top = parent:CreateTexture(nil, layer or "BORDER")
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.top:SetHeight(size)

    border.bottom = parent:CreateTexture(nil, layer or "BORDER")
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.bottom:SetHeight(size)

    border.left = parent:CreateTexture(nil, layer or "BORDER")
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.left:SetWidth(size)

    border.right = parent:CreateTexture(nil, layer or "BORDER")
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.right:SetWidth(size)

    return border
end

local function SetSimpleOutlineColor(border, r, g, b, a)
    if type(border) ~= "table" then
        return
    end

    for _, edge in pairs(border) do
        edge:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
    end
end

local function GetFontPreset(config)
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.NormalizeFontPreset then
        return optionsPrivate.NormalizeFontPreset(config, "font")
    end

    return (config and config.fontPreset) or "CHAT"
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

local function IsAddOnLoadedCompat(indexOrName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(indexOrName)
    end
    return IsAddOnLoaded and IsAddOnLoaded(indexOrName) or false
end

local function FormatMemoryUsage(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then
        return string.format("%.2f MB", kb / 1024)
    end
    return string.format("%.0f KB", kb)
end

local function CollectAddOnMemoryRows()
    local total = 0
    local rows = {}

    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end

    for index = 1, GetNumAddOnsCompat() do
        local name, title = GetAddOnInfoCompat(index)
        if name and IsAddOnLoadedCompat(index) then
            local memory = GetAddOnMemoryUsage and GetAddOnMemoryUsage(index) or 0
            total = total + memory
            table.insert(rows, {
                name = title and title ~= "" and title or name,
                memory = memory,
            })
        end
    end

    table.sort(rows, function(left, right)
        if left.memory == right.memory then
            return left.name < right.name
        end
        return left.memory > right.memory
    end)

    return total, rows
end

local function GetMetricColorHex(value, metric)
    value = tonumber(value) or 0
    if metric == "fps" then
        if value >= 50 then
            return "ff33ff66"
        elseif value >= 30 then
            return "ffffcc33"
        end
        return "ffff5555"
    end

    if value <= 80 then
        return "ff33ff66"
    elseif value <= 150 then
        return "ffffcc33"
    end
    return "ffff5555"
end

local function BuildPerformanceText(fps, latency)
    return string.format(
        "FPS |c%s%d|r  MS |c%s%d|r",
        GetMetricColorHex(fps, "fps"),
        tonumber(fps) or 0,
        GetMetricColorHex(latency, "ms"),
        tonumber(latency) or 0
    )
end

local function ApplyPerformanceMonitorFont(frame)
    if not frame or not frame.text then
        return
    end

    local config = GetConfig()
    if not config then
        return
    end

    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(frame.text, config.fontSize or 14, "OUTLINE", GetFontPreset(config))
    elseif not frame.text:SetFont(STANDARD_TEXT_FONT, config.fontSize or 14, "OUTLINE") then
        frame.text:SetFont(STANDARD_TEXT_FONT, config.fontSize or 14, "OUTLINE")
    end

    if frame.measureText then
        local fontName, fontHeight, fontFlags = frame.text:GetFont()
        if fontName then
            frame.measureText:SetFont(fontName, fontHeight or (config.fontSize or 14), fontFlags or "OUTLINE")
        end
    end
end

local function GetPerformanceMonitorSize(frame)
    if not (frame and frame.measureText) then
        return 110, 20
    end

    -- Use a stable template width so bottom-anchored layouts do not jitter
    -- when FPS / latency digit counts fluctuate during updates.
    frame.measureText:SetText("FPS 0000  MS 0000")

    local width = math.max(110, math.ceil((frame.measureText:GetStringWidth() or 0) + 14))
    local textHeight = frame.measureText:GetStringHeight() or 0
    local height = math.max(16, math.ceil(textHeight + 4))
    return width, height
end

function Core:SavePerformanceMonitorPosition()
    if not self.performanceMonitorFrame then
        return
    end

    local point, _, relativePoint, x, y = self.performanceMonitorFrame:GetPoint(1)
    local position = GetConfig().point
    position.point = point or "CENTER"
    position.relativePoint = relativePoint or "CENTER"
    position.x = math.floor((x or 0) + 0.5)
    position.y = math.floor((y or 0) + 0.5)
end

function Core:UpdatePerformanceMonitorVisibility()
    if not self.performanceMonitorFrame then
        return
    end

    self.performanceMonitorFrame:SetShown(GetConfig().enabled)
end

function Core:UpdatePerformanceMonitorPosition()
    if not self.performanceMonitorFrame then
        return
    end

    local position = GetConfig().point or {}
    self.performanceMonitorFrame:ClearAllPoints()
    self.performanceMonitorFrame:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or "CENTER",
        position.x or 220,
        position.y or -20
    )
end

function Core:UpdatePerformanceMonitorLayout()
    if not self.performanceMonitorFrame then
        return
    end

    local config = GetConfig()
    local frame = self.performanceMonitorFrame

    frame:SetMovable(not config.locked)
    ApplyPerformanceMonitorFont(frame)
    frame.text:ClearAllPoints()
    frame.text:SetPoint("LEFT", frame, "LEFT", 6, 0)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

    local width, height = GetPerformanceMonitorSize(frame)
    frame:SetSize(width, height)

    if config.showBackground then
        local background = config.backgroundColor or { r = 0, g = 0, b = 0, a = 0.32 }
        frame.bg:SetColorTexture(background.r or 0, background.g or 0, background.b or 0, background.a or 0.32)
    else
        frame.bg:SetColorTexture(0, 0, 0, 0)
    end

    if config.showBorder then
        local border = config.borderColor or { r = 0, g = 0.6, b = 1, a = 0.45 }
        SetSimpleOutlineColor(frame.border, border.r or 0, border.g or 0.6, border.b or 1, border.a or 0.45)
    else
        SetSimpleOutlineColor(frame.border, 0, 0, 0, 0)
    end
end

function Core:RefreshPerformanceMonitor()
    if not self.performanceMonitorFrame then
        return
    end

    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, _, world = GetNetStats()
    local latency = tonumber(world) or 0

    ApplyPerformanceMonitorFont(self.performanceMonitorFrame)
    self.performanceMonitorFrame.text:SetTextColor(1, 1, 1, 1)
    self.performanceMonitorFrame.text:SetText(BuildPerformanceText(fps, latency))

    self:UpdatePerformanceMonitorVisibility()
end

function Core:RefreshPerformanceMonitorTooltip()
    if not self.performanceMonitorFrame then
        return
    end

    local totalMemory, rows = CollectAddOnMemoryRows()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, home, world = GetNetStats()

    GameTooltip:SetOwner(self.performanceMonitorFrame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("性能监控", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("FPS", tostring(fps), 1, 1, 1, 0.25, 1, 0.4)
    GameTooltip:AddDoubleLine("本地延迟", string.format("%d ms", tonumber(home) or 0), 1, 1, 1, 0.35, 0.8, 1)
    GameTooltip:AddDoubleLine("世界延迟", string.format("%d ms", tonumber(world) or 0), 1, 1, 1, 0.35, 0.8, 1)
    GameTooltip:AddDoubleLine("插件总内存", FormatMemoryUsage(totalMemory), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, entry in ipairs(rows) do
        GameTooltip:AddDoubleLine(entry.name, FormatMemoryUsage(entry.memory), 1, 1, 1, 0.75, 0.9, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Shift + 左键：立即回收内存", 1, 1, 1)
    GameTooltip:Show()
end

function Core:UpdatePerformanceMonitorTicker()
    if self.performanceMonitorTicker then
        self.performanceMonitorTicker:Cancel()
        self.performanceMonitorTicker = nil
    end

    local config = GetConfig()
    if not config.enabled then
        return
    end

    self.performanceMonitorTicker = C_Timer.NewTicker(math.max(0.2, tonumber(config.updateInterval) or 1), function()
        Core:RefreshPerformanceMonitor()
    end)
end

function Core:CreatePerformanceMonitorFrame()
    if self.performanceMonitorFrame then
        return
    end

    local config = GetConfig()
    local position = config.point or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 220,
        y = -20,
    }

    local frame = CreateFrame("Button", addonName .. "PerformanceMonitor", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetSize(110, 20)
    frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 220, position.y or -20)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.border = CreateSimpleOutline(frame, "BORDER", 1)

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")

    frame.measureText = frame:CreateFontString(nil, "OVERLAY")
    frame.measureText:Hide()

    frame:SetScript("OnEnter", function(selfFrame)
        Core:RefreshPerformanceMonitorTooltip()

        if selfFrame.tooltipTicker then
            selfFrame.tooltipTicker:Cancel()
        end

        selfFrame.tooltipTicker = C_Timer.NewTicker(math.max(0.2, tonumber(GetConfig().updateInterval) or 1), function()
            if GameTooltip:IsOwned(selfFrame) then
                Core:RefreshPerformanceMonitor()
                Core:RefreshPerformanceMonitorTooltip()
            end
        end)
    end)
    frame:SetScript("OnLeave", function(selfFrame)
        if selfFrame.tooltipTicker then
            selfFrame.tooltipTicker:Cancel()
            selfFrame.tooltipTicker = nil
        end
        GameTooltip:Hide()
    end)
    frame:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" and IsShiftKeyDown() then
            collectgarbage("collect")
            if UpdateAddOnMemoryUsage then
                UpdateAddOnMemoryUsage()
            end
            Core:RefreshPerformanceMonitor()
            if GameTooltip:IsOwned(frame) then
                Core:RefreshPerformanceMonitorTooltip()
            end
        end
    end)
    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        Core:SavePerformanceMonitorPosition()
    end)

    self.performanceMonitorFrame = frame
end

function Core:ApplyPerformanceMonitorSettings()
    if not self.performanceMonitorFrame then
        self:CreatePerformanceMonitorFrame()
    end

    self:UpdatePerformanceMonitorPosition()
    self:RefreshPerformanceMonitor()
    self:UpdatePerformanceMonitorLayout()
    self:UpdatePerformanceMonitorVisibility()
    self:UpdatePerformanceMonitorTicker()
end

function PerformanceMonitor:OnPlayerLogin()
    Core:ApplyPerformanceMonitorSettings()
end

function PerformanceMonitor:RefreshFromSettings()
    Core:ApplyPerformanceMonitorSettings()
end
