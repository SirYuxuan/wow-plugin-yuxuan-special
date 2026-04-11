local addonName, NS = ...
local Core = NS.Core

local HuntAssist = {}
NS.Modules.InterfaceEnhance.HuntAssist = HuntAssist

local C_Map = rawget(_G, "C_Map")
local C_QuestLog = rawget(_G, "C_QuestLog")
local C_SuperTrack = rawget(_G, "C_SuperTrack")
local C_TaskQuest = rawget(_G, "C_TaskQuest")
local C_VignetteInfo = rawget(_G, "C_VignetteInfo")
local CreateFrame = rawget(_G, "CreateFrame")
local Enum = rawget(_G, "Enum")
local GetTime = rawget(_G, "GetTime")
local Minimap = rawget(_G, "Minimap")
local STANDARD_TEXT_FONT = rawget(_G, "STANDARD_TEXT_FONT")
local UIParent = rawget(_G, "UIParent")

local AUTO_TRACK_THROTTLE = 2
local MONITOR_HEIGHT = 24
local MONITORED_VIGNETTES = {
    7667,
    7443,
}
local VIGNETTE_DATA = {
    [7667] = {
        atlas = "Vehicle-Trap-Gold",
        label = "夹子",
    },
    [7443] = {
        atlas = "poi-prey",
        label = "猎物",
    },
}

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "huntAssist")
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function ApplyConfiguredFont(fontString, size)
    if not fontString then
        return
    end

    local optionsPrivate = GetOptionsPrivate()
    local config = GetConfig()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, "OUTLINE", config and config.fontPreset or "CHAT")
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
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

local function QuestHasMapIcon(questID, mapID)
    if not (questID and mapID and C_QuestLog and C_QuestLog.GetNextWaypointForMap) then
        return false
    end

    local x, y = C_QuestLog.GetNextWaypointForMap(questID, mapID)
    if x and y then
        return true
    end

    if not C_QuestLog.GetQuestsOnMap then
        return false
    end

    local quests = C_QuestLog.GetQuestsOnMap(mapID)
    if not quests then
        return false
    end

    for _, info in ipairs(quests) do
        if info and info.questID == questID then
            return true
        end
    end

    return false
end

local function GetAnchorFrame(anchorName)
    if anchorName == "Minimap" and Minimap then
        return Minimap
    end

    return UIParent
end

function HuntAssist:EnsureEventFrame()
    if self.eventFrame then
        return self.eventFrame
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            HuntAssist:RefreshMonitor()
            HuntAssist:TryAutoTrack()
        elseif event == "VIGNETTE_MINIMAP_UPDATED" then
            HuntAssist:RefreshMonitor()
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            HuntAssist:RefreshMonitor()
            HuntAssist:TryAutoTrack()
        elseif event == "QUEST_LOG_UPDATE" then
            HuntAssist:TryAutoTrack()
        end
    end)

    self.eventFrame = frame
    return frame
end

function HuntAssist:CreateMonitorFrame()
    if self.monitorFrame then
        return self.monitorFrame
    end

    local config = GetConfig() or {}
    local point = config.point or {}
    local relativeFrame = GetAnchorFrame(point.relativeTo)
    local frame = CreateFrame("Frame", addonName .. "HuntAssistMonitorFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(0, 0, 0, 0.38)

    frame.border = CreateSimpleOutline(frame, "BORDER", 1)
    SetSimpleOutlineColor(frame.border, 0, 0.6, 1, 0.45)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetPoint("LEFT", frame, "LEFT", 8, 0)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    frame.text:SetText("狩猎辅助")

    frame:SetPoint(
        point.point or "TOP",
        relativeFrame,
        point.relativePoint or "BOTTOM",
        point.x or 0,
        point.y or -8
    )

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end

        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        HuntAssist:SavePosition()
        HuntAssist:RefreshMonitor()
    end)

    frame:SetSize(120, MONITOR_HEIGHT)
    self.monitorFrame = frame
    return frame
end

function HuntAssist:SavePosition()
    if not self.monitorFrame then
        return
    end

    local point, relativeTo, relativePoint, x, y = self.monitorFrame:GetPoint(1)
    local config = GetConfig()
    config.point = config.point or {}
    config.point.point = point or "TOP"
    config.point.relativePoint = relativePoint or "BOTTOM"
    config.point.relativeTo = relativeTo == Minimap and "Minimap" or "UIParent"
    config.point.x = math.floor((x or 0) + 0.5)
    config.point.y = math.floor((y or 0) + 0.5)
end

function HuntAssist:ApplyMonitorLayout()
    local frame = self:CreateMonitorFrame()
    local config = GetConfig()
    local point = config.point or {}
    local relativeFrame = GetAnchorFrame(point.relativeTo)

    frame:ClearAllPoints()
    frame:SetPoint(
        point.point or "TOP",
        relativeFrame,
        point.relativePoint or "BOTTOM",
        point.x or 0,
        point.y or -8
    )
    frame:SetMovable(not config.locked)

    ApplyConfiguredFont(frame.text, config.fontSize or 12)

    local width = math.max(96, math.ceil((frame.text:GetStringWidth() or 0) + 20))
    frame:SetSize(width, MONITOR_HEIGHT)
end

function HuntAssist:GetVignetteCounts()
    local config = GetConfig()
    local counts = {}
    local total = 0

    if not (config and config.minimap and config.minimap.enabled and C_VignetteInfo and C_VignetteInfo.GetVignettes and C_VignetteInfo.GetVignetteInfo) then
        return counts, total
    end

    local ids = C_VignetteInfo.GetVignettes()
    if type(ids) ~= "table" then
        return counts, total
    end

    local enabledMap = {
        [7667] = config.minimap.monitorTrap ~= false,
        [7443] = config.minimap.monitorPrey ~= false,
    }
    local visited = {}

    for key, value in pairs(ids) do
        local vignetteInstanceID = value or key
        if vignetteInstanceID and not visited[vignetteInstanceID] then
            visited[vignetteInstanceID] = true
            local info = C_VignetteInfo.GetVignetteInfo(vignetteInstanceID)
            local vignetteID = info and info.vignetteID
            if vignetteID and enabledMap[vignetteID] then
                counts[vignetteID] = (counts[vignetteID] or 0) + 1
                total = total + 1
            end
        end
    end

    return counts, total
end

function HuntAssist:BuildMonitorText(counts)
    local parts = {}

    for _, vignetteID in ipairs(MONITORED_VIGNETTES) do
        local count = counts[vignetteID] or 0
        local data = VIGNETTE_DATA[vignetteID]
        if count > 0 and data then
            parts[#parts + 1] = string.format("|A:%s:14:14|a x %d", data.atlas, count)
        end
    end

    if #parts == 0 then
        return ""
    end

    return table.concat(parts, "  ")
end

function HuntAssist:RefreshMonitor()
    local config = GetConfig()
    if not config then
        return
    end

    local frame = self.monitorFrame
    if not (config.enabled and config.minimap and config.minimap.enabled) then
        if frame then
            frame:Hide()
        end
        return
    end

    frame = self:CreateMonitorFrame()
    local counts, total = self:GetVignetteCounts()
    local text = self:BuildMonitorText(counts)
    local shouldShowEmpty = not config.locked or config.minimap.hideWhenEmpty == false

    if text ~= "" then
        frame.text:SetText(text)
        frame.text:SetTextColor(1, 0.82, 0.20, 1)
        frame:Show()
    elseif shouldShowEmpty then
        frame.text:SetText("狩猎辅助")
        frame.text:SetTextColor(0.75, 0.82, 0.90, 1)
        frame:Show()
    else
        frame:Hide()
    end

    if total <= 0 and text == "" and config.minimap.hideWhenEmpty ~= false and config.locked then
        frame:Hide()
    end

    self:ApplyMonitorLayout()
end

function HuntAssist:PrintTrackMessage(questID)
    local config = GetConfig()
    if not (config and config.autoTrack and config.autoTrack.chatNotify) then
        return
    end

    local title = questID
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID) or questID
    end

    Core:Print(string.format("|cFFFFD200[狩猎辅助]|r 开始追踪：|cFF80B3FF%s|r", tostring(title)))
end

function HuntAssist:TryAutoTrack()
    local config = GetConfig()
    if not (config and config.enabled and config.autoTrack and config.autoTrack.enabled) then
        return
    end

    if not C_QuestLog or not C_Map or not C_SuperTrack then
        return
    end

    if not config.autoTrack.worldQuest and not config.autoTrack.stageQuest then
        return
    end

    if not (C_QuestLog.GetActivePreyQuest and C_Map.GetBestMapForUnit and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.SetSuperTrackedQuestID) then
        return
    end

    local activePreyQuestID = C_QuestLog.GetActivePreyQuest()
    if not activePreyQuestID or activePreyQuestID == 0 then
        return
    end

    local now = GetTime and GetTime() or 0
    if self.lastAutoTrackTime and (now - self.lastAutoTrackTime) < AUTO_TRACK_THROTTLE then
        return
    end
    self.lastAutoTrackTime = now

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return
    end

    local superTrackedID = C_SuperTrack.GetSuperTrackedQuestID()
    local bestQuestID
    local bestDistSq = math.huge
    local preyWorldQuestType = Enum and Enum.QuestTagType and Enum.QuestTagType.Prey

    if config.autoTrack.worldQuest and preyWorldQuestType and C_TaskQuest and C_TaskQuest.GetQuestsOnMap and C_QuestLog.IsWorldQuest and C_QuestLog.GetQuestTagInfo then
        local tasks = C_TaskQuest.GetQuestsOnMap(mapID)
        if tasks then
            for _, info in ipairs(tasks) do
                if info and info.questID and C_QuestLog.IsWorldQuest(info.questID) then
                    local tagInfo = C_QuestLog.GetQuestTagInfo(info.questID)
                    if tagInfo and tagInfo.worldQuestType == preyWorldQuestType then
                        local distSq = C_QuestLog.GetDistanceSqToQuest and C_QuestLog.GetDistanceSqToQuest(info.questID)
                        if distSq and distSq < bestDistSq then
                            bestDistSq = distSq
                            bestQuestID = info.questID
                        end
                    end
                end
            end
        end
    end

    if bestQuestID then
        if C_QuestLog.AddWorldQuestWatch then
            local watchType = Enum and Enum.QuestWatchType and Enum.QuestWatchType.Automatic
            if watchType then
                C_QuestLog.AddWorldQuestWatch(bestQuestID, watchType)
            else
                C_QuestLog.AddWorldQuestWatch(bestQuestID)
            end
        end

        if superTrackedID ~= bestQuestID then
            C_SuperTrack.SetSuperTrackedQuestID(bestQuestID)
            self:PrintTrackMessage(bestQuestID)
        end
        return
    end

    if config.autoTrack.stageQuest
        and C_QuestLog.IsOnMap
        and C_QuestLog.IsOnMap(activePreyQuestID)
        and QuestHasMapIcon(activePreyQuestID, mapID) then
        if C_QuestLog.AddQuestWatch then
            C_QuestLog.AddQuestWatch(activePreyQuestID)
        end

        if superTrackedID ~= activePreyQuestID then
            C_SuperTrack.SetSuperTrackedQuestID(activePreyQuestID)
            self:PrintTrackMessage(activePreyQuestID)
        end
    end
end

function HuntAssist:UpdateEventRegistration()
    local frame = self:EnsureEventFrame()
    frame:UnregisterAllEvents()

    local config = GetConfig()
    if not (config and config.enabled) then
        return
    end

    if (config.minimap and config.minimap.enabled) or (config.autoTrack and config.autoTrack.enabled) then
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end

    if config.minimap and config.minimap.enabled then
        frame:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
    end

    if config.autoTrack and config.autoTrack.enabled and (config.autoTrack.worldQuest or config.autoTrack.stageQuest) then
        frame:RegisterEvent("QUEST_LOG_UPDATE")
    end
end

function HuntAssist:RefreshFromSettings()
    local config = GetConfig()
    if not config then
        return
    end

    if config.enabled and not self.monitorFrame then
        self:CreateMonitorFrame()
    end

    self:UpdateEventRegistration()
    self:RefreshMonitor()

    if config.enabled and config.autoTrack and config.autoTrack.enabled then
        self:TryAutoTrack()
    end
end

function HuntAssist:OnPlayerLogin()
    self:RefreshFromSettings()
end
