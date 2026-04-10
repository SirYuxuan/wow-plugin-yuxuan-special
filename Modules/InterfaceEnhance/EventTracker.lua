local _, NS = ...
local Core = NS.Core
local ETD = NS.EventTrackerData
local LibStub = _G.LibStub
local LibSharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

local EventTracker = {}
NS.Modules.InterfaceEnhance.EventTracker = EventTracker

--------------------------------------------------------------------------------
-- 事件追踪器 - 主模块
-- 挂载在世界地图下方，追踪至暗之夜/剧团演出/周常等事件状态
--------------------------------------------------------------------------------

local floor, format, pairs, ipairs = floor, format, pairs, ipairs
local CreateFrame = CreateFrame
local GetServerTime = GetServerTime
local C_Timer = C_Timer

local TRACKER_WIDTH = 220
local TRACKER_HEIGHT = 28
local BACKDROP_SPACING = 6
local H_SPACING = 8
local V_SPACING = 4

--------------------------------------------------------------------------------
-- 配置读取
--------------------------------------------------------------------------------
-- Apply event-key defaults once to avoid iterating the event list on every ETcfg() call.
local _etcfgDefaultsApplied = false

local function ETcfg()
    local cfg = Core:GetConfig("interfaceEnhance", "eventTracker")
    if cfg.enabled == nil then cfg.enabled = true end
    if cfg.fontSize == nil then cfg.fontSize = 12 end
    if cfg.fontOutline == nil then cfg.fontOutline = true end
    if cfg.trackerWidth == nil then cfg.trackerWidth = TRACKER_WIDTH end
    if cfg.trackerHeight == nil then cfg.trackerHeight = TRACKER_HEIGHT end
    if cfg.backdropAlpha == nil then cfg.backdropAlpha = 0.6 end
    if cfg.alertEnabled == nil then cfg.alertEnabled = true end
    if cfg.alertSecond == nil then cfg.alertSecond = 60 end
    -- 各事件的开关默认值（只遍历一次）
    if not _etcfgDefaultsApplied then
        for _, eventKey in ipairs(ETD.EventList) do
            local data = ETD.EventData[eventKey]
            if data and data.dbKey then
                if cfg[data.dbKey] == nil then cfg[data.dbKey] = true end
            end
        end
        _etcfgDefaultsApplied = true
    end
    return cfg
end

local function GetEventTrackerAnchorFrame()
    return WorldMapFrame
end

--------------------------------------------------------------------------------
-- 追踪器对象池
--------------------------------------------------------------------------------
local trackerPool = {}

-- 设置字体
local function SetTrackerFont(fontString, size)
    if not fontString then return end
    local cfg = ETcfg()
    local outline = cfg.fontOutline and "OUTLINE" or ""
    local optionsPrivate = NS.Options and NS.Options.Private
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or cfg.fontSize, outline, cfg.fontPreset)
    else
        fontString:SetFont(STANDARD_TEXT_FONT, size or cfg.fontSize, outline)
    end
end

local function PrintEventTrackerAlert(message)
    if not message or message == "" then return end
    if Core and Core.Print then
        Core:Print(message)
    else
        print(message)
    end
end

--------------------------------------------------------------------------------
-- 周常类型追踪器
--------------------------------------------------------------------------------
local function CreateWeeklyTracker(parent, eventKey)
    local data = ETD.EventData[eventKey]
    if not data then return nil end

    local frame = CreateFrame("Frame", (NS.ADDON_NAME or "YuXuanSpecial") .. "ET_" .. eventKey, parent)
    frame:SetSize(TRACKER_WIDTH, TRACKER_HEIGHT)
    frame.eventKey = eventKey
    frame.data = data

    -- 图标
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(20, 20)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
    frame.icon:SetTexture(data.icon)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- 图标边框
    frame.iconBorder = frame:CreateTexture(nil, "OVERLAY")
    frame.iconBorder:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -1, 1)
    frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 1, -1)
    frame.iconBorder:SetColorTexture(0, 0, 0, 0.8)
    frame.iconBorder:SetDrawLayer("ARTWORK", -1)

    -- 名称文本
    frame.nameText = frame:CreateFontString(nil, "OVERLAY")
    frame.nameText:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
    SetTrackerFont(frame.nameText, ETcfg().fontSize)
    frame.nameText:SetText(data.label)
    frame.nameText:SetTextColor(ETD.Colors.label[1], ETD.Colors.label[2], ETD.Colors.label[3])

    -- 状态图标/文本
    frame.statusText = frame:CreateFontString(nil, "OVERLAY")
    frame.statusText:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    SetTrackerFont(frame.statusText, ETcfg().fontSize)

    -- 更新函数
    frame.UpdateStatus = function(self)
        local isCompleted = ETD.GetEventCompletionStatus(self.eventKey)
        self.icon:SetDesaturated(isCompleted)

        if isCompleted then
            self.statusText:SetText("已完成")
            self.statusText:SetTextColor(ETD.Colors.completed[1], ETD.Colors.completed[2], ETD.Colors.completed[3])
        else
            self.statusText:SetText("未完成")
            self.statusText:SetTextColor(ETD.Colors.notDone[1], ETD.Colors.notDone[2], ETD.Colors.notDone[3])
        end
    end

    -- Tooltip
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 8)
        GameTooltip:SetText("|T" .. data.icon .. ":16:16:0:0|t " .. data.eventName, 1, 1, 1)
        GameTooltip:AddLine(" ")

        if data.location then
            GameTooltip:AddDoubleLine("地点", data.location, 0.7, 0.7, 0.7, 1, 1, 1)
        end

        -- 周常奖励状态
        if data.hasWeeklyReward then
            local isCompleted = ETD.GetEventCompletionStatus(eventKey)
            if isCompleted then
                GameTooltip:AddDoubleLine("周常奖励", "|cFF33FF33已完成|r", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddDoubleLine("周常奖励", "|cFFFF5555未完成|r", 0.7, 0.7, 0.7)
            end
        end

        -- 任务组进度
        if data.questGroups then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("任务进度：", 1, 0.82, 0)
            for _, group in ipairs(data.questGroups) do
                local groupCompleted = ETD.IsQuestGroupCompleted(group.quests)
                local statusStr = groupCompleted and "|cFF33FF33已完成|r" or "|cFFFF5555未完成|r"
                local nameStr = group.name
                if group.location then
                    nameStr = nameStr .. " |cFF55CCFF(" .. group.location .. ")|r"
                end
                GameTooltip:AddDoubleLine(nameStr, statusStr, 1, 1, 1)
            end
        end

        -- 专业周常
        if data.useProfessionQuests then
            local profProgress = ETD.GetProfessionWeeklyProgress()
            if #profProgress > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("专业进度：", 1, 0.82, 0)
                for _, prof in ipairs(profProgress) do
                    local statusStr = prof.isCompleted and "|cFF33FF33已完成|r" or "|cFFFF5555未完成|r"
                    GameTooltip:AddDoubleLine("|T" .. prof.iconID .. ":14:14:0:0|t " .. prof.name, statusStr, 1, 1, 1)
                end
            else
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFFAAAAAA未检测到对应专业|r", 0.7, 0.7, 0.7)
            end
        end

        -- 简单任务列表
        if data.questIDs and not data.questGroups then
            GameTooltip:AddLine(" ")
            local anyCompleted = ETD.IsAnyQuestCompleted(data.questIDs)
            if anyCompleted then
                GameTooltip:AddDoubleLine("本周任务", "|cFF33FF33已完成|r", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddDoubleLine("本周任务", "|cFFFF5555未完成|r", 0.7, 0.7, 0.7)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFCCCCCC点击打开世界地图|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 点击打开地图
    frame:SetScript("OnMouseDown", function()
        if data.mapID and WorldMapFrame and WorldMapFrame.SetMapID then
            if not WorldMapFrame:IsShown() then
                ToggleWorldMap()
            end
            WorldMapFrame:SetMapID(data.mapID)
        end
    end)

    return frame
end

--------------------------------------------------------------------------------
-- 循环计时类型追踪器
--------------------------------------------------------------------------------
local function CreateLoopTimerTracker(parent, eventKey)
    local data = ETD.EventData[eventKey]
    if not data then return nil end

    local frame = CreateFrame("Frame", (NS.ADDON_NAME or "YuXuanSpecial") .. "ET_" .. eventKey, parent)
    frame:SetSize(TRACKER_WIDTH, TRACKER_HEIGHT)
    frame.eventKey = eventKey
    frame.data = data
    frame.alertFired = {}

    -- 图标
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(20, 20)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
    frame.icon:SetTexture(data.icon)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- 图标边框
    frame.iconBorder = frame:CreateTexture(nil, "OVERLAY")
    frame.iconBorder:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -1, 1)
    frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 1, -1)
    frame.iconBorder:SetColorTexture(0, 0, 0, 0.8)
    frame.iconBorder:SetDrawLayer("ARTWORK", -1)

    -- 进度条背景
    frame.barBg = frame:CreateTexture(nil, "BACKGROUND")
    frame.barBg:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 4, -2)
    frame.barBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 4)
    frame.barBg:SetColorTexture(0.1, 0.1, 0.1, 0.7)

    -- 进度条
    frame.statusBar = CreateFrame("StatusBar", nil, frame)
    frame.statusBar:SetPoint("TOPLEFT", frame.barBg, "TOPLEFT", 1, -1)
    frame.statusBar:SetPoint("BOTTOMRIGHT", frame.barBg, "BOTTOMRIGHT", -1, 1)
    local media = NS.Media
    local barTexture = media and media.FetchStatusBar and media:FetchStatusBar("Yuxuan") or
        (LibSharedMedia and LibSharedMedia:Fetch("statusbar", "Yuxuan")) or
        "Interface\\TargetingFrame\\UI-StatusBar"
    frame.statusBar:SetStatusBarTexture(barTexture)

    -- 名称文本（在进度条上）
    frame.nameText = frame.statusBar:CreateFontString(nil, "OVERLAY")
    frame.nameText:SetPoint("LEFT", frame.statusBar, "LEFT", 4, 0)
    SetTrackerFont(frame.nameText, ETcfg().fontSize)
    frame.nameText:SetText(data.label)
    frame.nameText:SetTextColor(ETD.Colors.label[1], ETD.Colors.label[2], ETD.Colors.label[3])

    -- 倒计时文本
    frame.timerText = frame.statusBar:CreateFontString(nil, "OVERLAY")
    frame.timerText:SetPoint("RIGHT", frame.statusBar, "RIGHT", -4, 0)
    SetTrackerFont(frame.timerText, ETcfg().fontSize)

    -- 状态提示（进行中闪烁）
    frame.runningTip = frame.statusBar:CreateFontString(nil, "OVERLAY")
    frame.runningTip:SetPoint("CENTER", frame.statusBar, "BOTTOM", 0, 0)
    SetTrackerFont(frame.runningTip, math.max(9, (ETcfg().fontSize or 12) - 2))
    frame.runningTip:SetText(data.runningText or "进行中")
    frame.runningTip:Hide()

    -- 更新函数
    frame.UpdateStatus = function(self)
        local status = ETD.GetLoopTimerStatus(self.eventKey)
        if not status then return end

        local isCompleted = ETD.GetEventCompletionStatus(self.eventKey)
        self.icon:SetDesaturated(isCompleted)

        self.isRunning = status.isRunning
        self.timeLeft = status.timeLeft

        if status.isRunning then
            -- 事件进行中
            self.timerText:SetText(ETD.SecondToTimeGreen(status.timeLeft))
            self.statusBar:SetMinMaxValues(0, status.duration)
            self.statusBar:SetValue(status.timeInCycle)
            local c = self.data.barColor or ETD.Colors.running
            self.statusBar:SetStatusBarColor(c[1], c[2], c[3], 0.8)
            self.runningTip:Show()
        else
            -- 等待下一次
            self.timerText:SetText(ETD.SecondToTime(status.timeLeft))
            self.timerText:SetTextColor(0.8, 0.8, 0.8)
            self.statusBar:SetMinMaxValues(0, status.interval)
            self.statusBar:SetValue(status.timeLeft)
            local c = ETD.Colors.waiting
            self.statusBar:SetStatusBarColor(c[1], c[2], c[3], 0.5)
            self.runningTip:Hide()
        end

        -- 提前通知
        self:CheckAlert(status)
    end

    -- 提前通知检查
    frame.CheckAlert = function(self, status)
        local cfg = ETcfg()
        if not cfg.alertEnabled then return end
        if status.isRunning then return end

        local alertSec = cfg.alertSecond or 60
        local alertKey = floor((GetServerTime() - self.data.startTimestamp) / self.data.interval) + 1

        if self.alertFired[alertKey] then return end

        if status.timeLeft <= alertSec then
            self.alertFired[alertKey] = true
            local msg = format("%s 将在 %s 后开始！", self.data.eventName, ETD.SecondToTime(status.timeLeft))
            PrintEventTrackerAlert(msg)

            -- 可选：中央提示
            if Core.ShowInstanceDifficultyToast then
                Core:ShowInstanceDifficultyToast(self.data.eventName .. " 即将开始！")
            end
        end
    end

    -- Tooltip
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 8)
        GameTooltip:SetText("|T" .. data.icon .. ":16:16:0:0|t " .. data.eventName, 1, 1, 1)
        GameTooltip:AddLine(" ")

        if data.location then
            GameTooltip:AddDoubleLine("地点", data.location, 0.7, 0.7, 0.7, 1, 1, 1)
        end

        local status = ETD.GetLoopTimerStatus(eventKey)
        if status then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("间隔", ETD.SecondToTime(status.interval), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("持续", ETD.SecondToTime(status.duration), 0.7, 0.7, 0.7, 1, 1, 1)

            if status.nextEventTimestamp then
                GameTooltip:AddDoubleLine("下次开始", date("%m/%d %H:%M:%S", status.nextEventTimestamp), 0.7, 0.7, 0.7, 1, 1,
                    1)
            end

            GameTooltip:AddLine(" ")
            if status.isRunning then
                GameTooltip:AddDoubleLine("状态", "|cFF33FF33" .. (data.runningText or "进行中") .. "|r", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddDoubleLine("状态", "|cFF888888等待中|r", 0.7, 0.7, 0.7)
            end
        end

        -- 周常奖励状态
        if data.hasWeeklyReward then
            local isCompleted = ETD.GetEventCompletionStatus(eventKey)
            GameTooltip:AddLine(" ")
            if isCompleted then
                GameTooltip:AddDoubleLine("周常奖励", "|cFF33FF33已完成|r", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddDoubleLine("周常奖励", "|cFFFF5555未完成|r", 0.7, 0.7, 0.7)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFCCCCCC点击打开世界地图|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 点击打开地图
    frame:SetScript("OnMouseDown", function()
        if data.mapID and WorldMapFrame and WorldMapFrame.SetMapID then
            if not WorldMapFrame:IsShown() then
                ToggleWorldMap()
            end
            WorldMapFrame:SetMapID(data.mapID)
        end
    end)

    return frame
end

--------------------------------------------------------------------------------
-- 创建或获取追踪器
--------------------------------------------------------------------------------
local function AcquireTracker(parent, eventKey)
    if trackerPool[eventKey] then
        trackerPool[eventKey]:Show()
        return trackerPool[eventKey]
    end

    local data = ETD.EventData[eventKey]
    if not data then return nil end

    local tracker
    if data.type == "weekly" then
        tracker = CreateWeeklyTracker(parent, eventKey)
    elseif data.type == "loopTimer" then
        tracker = CreateLoopTimerTracker(parent, eventKey)
    end

    if tracker then
        trackerPool[eventKey] = tracker
    end

    return tracker
end

local function DisableTracker(eventKey)
    if trackerPool[eventKey] then
        trackerPool[eventKey]:Hide()
    end
end

--------------------------------------------------------------------------------
-- 主框架构建
--------------------------------------------------------------------------------
function EventTracker:CreateEventTrackerFrame()
    if self.frame then return end
    if not WorldMapFrame then return end

    local frame = CreateFrame("Frame", (NS.ADDON_NAME or "YuXuanSpecial") .. "EventTrackerFrame", WorldMapFrame,
    "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(3600)
    frame:SetHeight(30)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(0.32, 0.32, 0.36, 1)
    frame:SetBackdropColor(0.08, 0.08, 0.09, math.max(0, math.min(0.98, ETcfg().backdropAlpha or 0.6)))

    -- 标题（可选，左侧小标题）
    frame.titleText = frame:CreateFontString(nil, "OVERLAY")
    frame.titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", BACKDROP_SPACING, -BACKDROP_SPACING)
    SetTrackerFont(frame.titleText, (ETcfg().fontSize or 12) + 1)
    frame.titleText:SetText("|cFF33FF99事件追踪|r")
    frame.titleText:Hide() -- 默认隐藏标题，空间紧凑

    self.frame = frame
end

--------------------------------------------------------------------------------
-- 更新追踪器布局
--------------------------------------------------------------------------------
function EventTracker:UpdateEventTrackers()
    if not WorldMapFrame then return end
    self:CreateEventTrackerFrame()

    local frame = self.frame
    local cfg = ETcfg()

    if not cfg.enabled then
        frame:Hide()
        return
    end

    -- 定位在世界地图下方
    frame:ClearAllPoints()
    local anchorFrame = GetEventTrackerAnchorFrame()
    frame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -2)
    frame:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -2)

    -- 更新背景透明度
    frame:SetBackdropColor(0.08, 0.08, 0.09, math.max(0, math.min(0.98, cfg.backdropAlpha or 0.6)))

    local trackerW = cfg.trackerWidth or TRACKER_WIDTH
    local trackerH = cfg.trackerHeight or TRACKER_HEIGHT
    local maxWidth = math.max(200, math.floor(frame:GetWidth() or 600) - BACKDROP_SPACING * 2)

    local row, col = 1, 1
    local activeCount = 0

    for _, eventKey in ipairs(ETD.EventList) do
        local data = ETD.EventData[eventKey]
        if not data then
            -- skip
        elseif cfg[data.dbKey] then
            local tracker = AcquireTracker(frame, eventKey)
            if tracker then
                tracker:SetSize(trackerW, trackerH)
                tracker:ClearAllPoints()

                -- 自动换行
                local currentWidth = trackerW * col + H_SPACING * (col - 1)
                if currentWidth > maxWidth and col > 1 then
                    row = row + 1
                    col = 1
                end

                tracker:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    BACKDROP_SPACING + trackerW * (col - 1) + H_SPACING * (col - 1),
                    -BACKDROP_SPACING - trackerH * (row - 1) - V_SPACING * (row - 1)
                )

                col = col + 1
                activeCount = activeCount + 1

                -- 更新数据
                if tracker.UpdateStatus then
                    tracker:UpdateStatus()
                end
            end
        else
            DisableTracker(eventKey)
        end
    end

    -- 动态调整框架高度
    if activeCount > 0 then
        frame:SetHeight(
            BACKDROP_SPACING * 2 + trackerH * row + V_SPACING * (row - 1)
        )
        frame:Show()
    else
        frame:Hide()
    end
end

--------------------------------------------------------------------------------
-- 更新所有追踪器的数据（定时调用）
--------------------------------------------------------------------------------
function EventTracker:TickEventTrackers()
    if not self.frame or not self.frame:IsShown() then return end
    if not WorldMapFrame:IsShown() then return end

    for eventKey, tracker in pairs(trackerPool) do
        if tracker:IsShown() and tracker.UpdateStatus then
            tracker:UpdateStatus()
        end
    end
end

--------------------------------------------------------------------------------
-- 应用字体设置
--------------------------------------------------------------------------------
function EventTracker:ApplyEventTrackerFonts()
    local cfg = ETcfg()
    local size = cfg.fontSize or 12

    for _, tracker in pairs(trackerPool) do
        if tracker.nameText then
            SetTrackerFont(tracker.nameText, size)
        end
        if tracker.timerText then
            SetTrackerFont(tracker.timerText, size)
        end
        if tracker.statusText then
            SetTrackerFont(tracker.statusText, size)
        end
        if tracker.runningTip then
            SetTrackerFont(tracker.runningTip, math.max(9, size - 2))
        end
    end
end

--------------------------------------------------------------------------------
-- 设置初始化与应用
--------------------------------------------------------------------------------
function EventTracker:ApplyEventTrackerSettings()
    local cfg = ETcfg()

    self:CreateEventTrackerFrame()
    self:UpdateEventTrackers()

    -- 启动/更新定时器
    if cfg.enabled then
        if not self.eventTrackerTicker then
            self.eventTrackerTicker = C_Timer.NewTicker(0.5, function()
                if ETcfg().enabled then
                    EventTracker:TickEventTrackers()
                end
            end)
        end

        -- 监听世界地图的显示/隐藏
        if not self.eventTrackerMapHooked then
            -- Stable callback reused for all delayed update calls
            -- to avoid creating new closures on every map show/resize.
            if not self._stableUpdateCallback then
                self._stableUpdateCallback = function()
                    EventTracker:UpdateEventTrackers()
                end
            end

            if WorldMapFrame then
                WorldMapFrame:HookScript("OnShow", function()
                    C_Timer.After(0.1, self._stableUpdateCallback)
                end)
                -- 处理地图大小变化
                if EventRegistry then
                    pcall(function()
                        EventRegistry:RegisterCallback("WorldMapMinimized", function()
                            C_Timer.After(0.15, self._stableUpdateCallback)
                        end)
                        EventRegistry:RegisterCallback("WorldMapMaximized", function()
                            C_Timer.After(0.15, self._stableUpdateCallback)
                        end)
                    end)
                end
            end
            self.eventTrackerMapHooked = true
        end
    else
        if self.eventTrackerTicker then
            self.eventTrackerTicker:Cancel()
            self.eventTrackerTicker = nil
        end
        if self.frame then
            self.frame:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- 可见性控制
--------------------------------------------------------------------------------
function EventTracker:ToggleEventTracker(forceVisible)
    local cfg = ETcfg()
    if forceVisible == nil then
        cfg.enabled = not cfg.enabled
    else
        cfg.enabled = forceVisible and true or false
    end
    self:ApplyEventTrackerSettings()
end

function EventTracker:RefreshFromSettings()
    self:ApplyEventTrackerSettings()
end

function EventTracker:OnPlayerLogin()
    self:ApplyEventTrackerSettings()
end

function EventTracker:OnWorldMapLoaded()
    self:ApplyEventTrackerSettings()
end
