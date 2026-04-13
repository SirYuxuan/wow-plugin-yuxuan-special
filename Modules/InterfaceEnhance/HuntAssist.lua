local addonName, NS = ...
local Core = NS.Core

local HuntAssist = {}
NS.Modules.InterfaceEnhance.HuntAssist = HuntAssist

local C_Map = rawget(_G, "C_Map")
local C_QuestLog = rawget(_G, "C_QuestLog")
local C_SuperTrack = rawget(_G, "C_SuperTrack")
local C_TaskQuest = rawget(_G, "C_TaskQuest")
local C_UIWidgetManager = rawget(_G, "C_UIWidgetManager")
local C_VignetteInfo = rawget(_G, "C_VignetteInfo")
local CreateFrame = rawget(_G, "CreateFrame")
local Enum = rawget(_G, "Enum")
local GameTooltip = rawget(_G, "GameTooltip")
local GetTime = rawget(_G, "GetTime")
local Minimap = rawget(_G, "Minimap")
local OpenQuestMap = rawget(_G, "OpenQuestMap")
local QuestMapFrame_OpenToQuestDetails = rawget(_G, "QuestMapFrame_OpenToQuestDetails")
local STANDARD_TEXT_FONT = rawget(_G, "STANDARD_TEXT_FONT")
local ToggleWorldMap = rawget(_G, "ToggleWorldMap")
local UIParent = rawget(_G, "UIParent")
local UiMapPoint = rawget(_G, "UiMapPoint")

local floor = math.floor
local max = math.max
local min = math.min

local AUTO_TRACK_THROTTLE = 2
local MONITOR_HEIGHT = 24
local BAR_FILL_INSET = 3
local BAR_POLL_INTERVAL = 0.35
local PREY_PROGRESS_FINAL = 3
local MAX_PREY_STAGE = 4
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

local BAR_STAGE_PERCENTS = {
    [1] = 25,
    [2] = 50,
    [3] = 75,
    [4] = 100,
}

local function Clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

local function Round(value)
    return floor((tonumber(value) or 0) + 0.5)
end

local function EnsurePoint(point, defaults)
    point = point or {}
    if point.point == nil then
        point.point = defaults.point
    end
    if point.relativeTo == nil then
        point.relativeTo = defaults.relativeTo
    end
    if point.relativePoint == nil then
        point.relativePoint = defaults.relativePoint
    end
    if point.x == nil then
        point.x = defaults.x
    end
    if point.y == nil then
        point.y = defaults.y
    end
    return point
end

local function GetConfig()
    local config = Core:GetConfig("interfaceEnhance", "huntAssist")

    config.minimap = config.minimap or {}
    if config.minimap.enabled == nil then
        config.minimap.enabled = true
    end
    if config.minimap.hideWhenEmpty == nil then
        config.minimap.hideWhenEmpty = true
    end
    if config.minimap.showBackground == nil then
        config.minimap.showBackground = true
    end
    if config.minimap.showBorder == nil then
        config.minimap.showBorder = true
    end
    if config.minimap.monitorTrap == nil then
        config.minimap.monitorTrap = true
    end
    if config.minimap.monitorPrey == nil then
        config.minimap.monitorPrey = true
    end

    config.autoTrack = config.autoTrack or {}
    if config.autoTrack.enabled == nil then
        config.autoTrack.enabled = true
    end
    if config.autoTrack.worldQuest == nil then
        config.autoTrack.worldQuest = true
    end
    if config.autoTrack.stageQuest == nil then
        config.autoTrack.stageQuest = true
    end
    if config.autoTrack.chatNotify == nil then
        config.autoTrack.chatNotify = true
    end

    config.bar = config.bar or {}
    if config.bar.enabled == nil then
        config.bar.enabled = false
    end
    if config.bar.locked == nil then
        config.bar.locked = true
    end
    if config.bar.onlyShowInPreyZone == nil then
        config.bar.onlyShowInPreyZone = false
    end
    if config.bar.hideDefaultPreyIcon == nil then
        config.bar.hideDefaultPreyIcon = false
    end
    if config.bar.width == nil then
        config.bar.width = 160
    end
    if config.bar.height == nil then
        config.bar.height = 29
    end
    if config.bar.fontSize == nil then
        config.bar.fontSize = 12
    end

    if config.locked == nil then
        config.locked = true
    end
    if config.fontPreset == nil then
        config.fontPreset = "CHAT"
    end
    if config.fontSize == nil then
        config.fontSize = 12
    end

    config.point = EnsurePoint(config.point, {
        point = "TOP",
        relativeTo = "Minimap",
        relativePoint = "BOTTOM",
        x = 0,
        y = -8,
    })
    config.bar.point = EnsurePoint(config.bar.point, {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 472,
    })

    return config
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

local function IsValidQuestID(questID)
    return type(questID) == "number" and questID > 0
end

local function GetQuestTitle(questID)
    if not (C_QuestLog and C_QuestLog.GetTitleForQuestID) then
        return nil
    end

    local titleInfo = C_QuestLog.GetTitleForQuestID(questID)
    if type(titleInfo) == "table" then
        return titleInfo.title
    end

    return titleInfo
end

local function GetCurrentActivePreyQuest()
    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        return C_QuestLog.GetActivePreyQuest()
    end

    return nil
end

local function GetPreyZoneInfo(questID)
    if not IsValidQuestID(questID) then
        return nil, nil
    end

    if not (C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_Map and C_Map.GetMapInfo) then
        return nil, nil
    end

    local mapID = C_TaskQuest.GetQuestZoneID(questID)
    if not mapID then
        return nil, nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    return mapInfo and mapInfo.name or nil, mapID
end

local function IsPreyQuestOnCurrentMap(questID)
    if not (IsValidQuestID(questID) and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo) then
        return nil
    end

    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIndex then
        return nil
    end

    local info = C_QuestLog.GetInfo(logIndex)
    if type(info) ~= "table" or info.isOnMap == nil then
        return nil
    end

    return info.isOnMap == true
end

local function GetStageFromProgressState(progressState)
    if progressState == nil or progressState == 0 then
        return 1
    elseif progressState == 1 then
        return 2
    elseif progressState == 2 then
        return 3
    elseif progressState == PREY_PROGRESS_FINAL then
        return 4
    end

    return 1
end

local function GetStageFallbackPercent(stage)
    return BAR_STAGE_PERCENTS[stage] or 0
end

local function NormalizePercentCandidate(value)
    if type(value) ~= "number" then
        return nil
    end

    if value >= 0 and value <= 1 then
        return Clamp(value * 100, 0, 100)
    end

    return Clamp(value, 0, 100)
end

local function ExtractProgressPercentFromInfoScan(info)
    if type(info) ~= "table" then
        return nil
    end

    for key, value in pairs(info) do
        if type(value) == "number" then
            local keyText = string.lower(tostring(key))
            if string.find(keyText, "percent", 1, true) then
                local pct = NormalizePercentCandidate(value)
                if pct ~= nil then
                    return pct
                end
            end
        end
    end

    local currentValues = {}
    local maxValues = {}
    for key, value in pairs(info) do
        if type(value) == "number" and value >= 0 then
            local keyText = string.lower(tostring(key))
            if string.find(keyText, "current", 1, true)
                or string.find(keyText, "value", 1, true)
                or string.find(keyText, "progress", 1, true)
                or string.find(keyText, "fulfilled", 1, true)
                or string.find(keyText, "completed", 1, true)
            then
                currentValues[#currentValues + 1] = value
            end

            if string.find(keyText, "max", 1, true)
                or string.find(keyText, "total", 1, true)
                or string.find(keyText, "required", 1, true)
            then
                maxValues[#maxValues + 1] = value
            end
        end
    end

    for _, current in ipairs(currentValues) do
        for _, maxValue in ipairs(maxValues) do
            if maxValue > 0 and current <= maxValue then
                return Clamp((current / maxValue) * 100, 0, 100)
            end
        end
    end

    return nil
end

local function ExtractProgressPercent(info, tooltipText)
    if type(info) == "table" then
        local directFields = {
            "progressPercentage",
            "progressPercent",
            "fillPercentage",
            "percentage",
            "percent",
            "progress",
            "progressValue",
        }

        for _, fieldName in ipairs(directFields) do
            local pct = NormalizePercentCandidate(info[fieldName])
            if pct ~= nil then
                return pct
            end
        end
    end

    local scannedPct = ExtractProgressPercentFromInfoScan(info)
    if scannedPct ~= nil then
        return scannedPct
    end

    if type(tooltipText) == "string" then
        local pctText = tooltipText:match("(%d+)%s*%%")
        local pctValue = tonumber(pctText)
        if pctValue then
            return Clamp(pctValue, 0, 100)
        end
    end

    return nil
end

local function ExtractQuestObjectivePercent(questID)
    if not IsValidQuestID(questID) then
        return nil
    end

    local questBarPct = nil
    if rawget(_G, "GetQuestProgressBarPercent") then
        local okQuestBarPct, rawQuestBarPct = pcall(function()
            return tonumber(_G.GetQuestProgressBarPercent(questID))
        end)
        if okQuestBarPct and rawQuestBarPct ~= nil then
            questBarPct = Clamp(rawQuestBarPct, 0, 100)
        end
    end

    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return questBarPct
    end

    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if type(objectives) ~= "table" or #objectives == 0 then
        return questBarPct
    end

    local totalFulfilled = 0
    local totalRequired = 0
    local anyNumericObjective = false

    for _, objective in ipairs(objectives) do
        if type(objective) == "table" then
            local fulfilled = tonumber(objective.numFulfilled or objective.fulfilled)
            local required = tonumber(objective.numRequired or objective.required)

            if fulfilled and required and required > 0 then
                anyNumericObjective = true
                totalFulfilled = totalFulfilled + max(0, fulfilled)
                totalRequired = totalRequired + max(0, required)
            elseif type(objective.text) == "string" then
                local curText, maxText = objective.text:match("(%d+)%s*/%s*(%d+)")
                local curValue = tonumber(curText)
                local maxValue = tonumber(maxText)
                if curValue and maxValue and maxValue > 0 then
                    anyNumericObjective = true
                    totalFulfilled = totalFulfilled + max(0, curValue)
                    totalRequired = totalRequired + max(0, maxValue)
                else
                    local pctText = objective.text:match("(%d+)%s*%%")
                    local pctValue = tonumber(pctText)
                    if pctValue then
                        return Clamp(pctValue, 0, 100)
                    end
                end
            end
        end
    end

    local objectivePct = nil
    if anyNumericObjective and totalRequired > 0 then
        objectivePct = Clamp((totalFulfilled / totalRequired) * 100, 0, 100)
    end

    if objectivePct ~= nil and questBarPct ~= nil then
        return max(objectivePct, questBarPct)
    end

    return objectivePct or questBarPct
end

local function GetWidgetTypePreyHuntProgress()
    if Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.PreyHuntProgress then
        return Enum.UIWidgetVisualizationType.PreyHuntProgress
    end

    return 29
end

local function GetShownStateShown()
    if Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown then
        return Enum.WidgetShownState.Shown
    end

    return 1
end

local function ExtractWidgetQuestID(info)
    if type(info) ~= "table" then
        return nil
    end

    local possibleFields = {
        "questID",
        "questId",
        "associatedQuestID",
        "associatedQuestId",
    }

    for _, fieldName in ipairs(possibleFields) do
        local value = info[fieldName]
        if type(value) == "number" and value > 0 then
            return value
        end
    end

    return nil
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

local function TryGetWidgetFrameByID(container, widgetID)
    if type(container) ~= "table" and type(container) ~= "userdata" then
        return nil
    end

    if container.GetWidgetFrame then
        local ok, frameRef = pcall(container.GetWidgetFrame, container, widgetID)
        if ok and frameRef then
            return frameRef
        end
    end

    local possibleFrameTables = {
        container.widgetFrames,
        container.WidgetFrames,
        container.activeWidgets,
        container.ActiveWidgets,
    }

    for _, frameTable in ipairs(possibleFrameTables) do
        if type(frameTable) == "table" and frameTable[widgetID] then
            return frameTable[widgetID]
        end
    end

    return nil
end

local function ApplyWidgetFrameSuppression(frameRef, suppress)
    if not frameRef then
        return
    end

    local visited = {}

    local function shouldHardSuppress(target)
        if not target then
            return false
        end

        local objectType = target.GetObjectType and target:GetObjectType() or nil
        if objectType == "ModelScene" or objectType == "PlayerModel" or objectType == "Model" then
            return true
        end

        local name = target.GetName and target:GetName() or ""
        local lowered = string.lower(tostring(name or ""))
        return string.find(lowered, "modelscene", 1, true) ~= nil
            or string.find(lowered, "scriptedanimation", 1, true) ~= nil
            or string.find(lowered, "anim", 1, true) ~= nil
            or string.find(lowered, "glow", 1, true) ~= nil
    end

    local function applyHardVisibilitySuppression(target)
        if not target or not target.Hide or not shouldHardSuppress(target) then
            return
        end

        if suppress then
            if target.__YuXuanWasShown == nil and target.IsShown then
                target.__YuXuanWasShown = target:IsShown() and true or false
            end
            pcall(target.Hide, target)
            return
        end

        if target.__YuXuanWasShown then
            target.__YuXuanWasShown = nil
            if target.Show then
                pcall(target.Show, target)
            end
        elseif target.__YuXuanWasShown ~= nil then
            target.__YuXuanWasShown = nil
        end
    end

    local function applyToFrameTree(node, depth)
        if not node or visited[node] or depth > 8 then
            return
        end

        visited[node] = true
        applyHardVisibilitySuppression(node)

        if node.SetAlpha then
            if suppress then
                if node.__YuXuanOriginalAlpha == nil and node.GetAlpha then
                    node.__YuXuanOriginalAlpha = node:GetAlpha()
                end
                node:SetAlpha(0)
            elseif node.__YuXuanOriginalAlpha ~= nil then
                node:SetAlpha(node.__YuXuanOriginalAlpha)
            end
        end

        if node.GetRegions then
            local regions = { node:GetRegions() }
            for _, region in ipairs(regions) do
                applyHardVisibilitySuppression(region)
                if region and region.SetAlpha then
                    if suppress then
                        if region.__YuXuanOriginalAlpha == nil and region.GetAlpha then
                            region.__YuXuanOriginalAlpha = region:GetAlpha()
                        end
                        region:SetAlpha(0)
                    elseif region.__YuXuanOriginalAlpha ~= nil then
                        region:SetAlpha(region.__YuXuanOriginalAlpha)
                    end
                end
            end
        end

        if node.GetChildren then
            local children = { node:GetChildren() }
            for _, child in ipairs(children) do
                applyToFrameTree(child, depth + 1)
            end
        end
    end

    applyToFrameTree(frameRef, 0)

    if frameRef.EnableMouse then
        frameRef:EnableMouse(not suppress)
    end
end

function HuntAssist:GetBarState()
    if self.barState then
        return self.barState
    end

    self.barState = {
        activeQuestID = nil,
        progressState = nil,
        progressPercent = nil,
        preyZoneName = nil,
        preyZoneMapID = nil,
        inPreyZone = nil,
        stage = 1,
        tooltipText = nil,
        playerMapID = nil,
        playerMapHierarchy = nil,
        lastWidgetSeenAt = 0,
        candidateWidgetSetIDs = {},
    }

    return self.barState
end

function HuntAssist:ClearBarState()
    local state = self:GetBarState()
    state.activeQuestID = nil
    state.progressState = nil
    state.progressPercent = nil
    state.preyZoneName = nil
    state.preyZoneMapID = nil
    state.inPreyZone = nil
    state.stage = 1
    state.tooltipText = nil
    state.playerMapID = nil
    state.playerMapHierarchy = nil
    state.lastWidgetSeenAt = 0
end

function HuntAssist:ResetBarStateForQuest(questID)
    local state = self:GetBarState()
    if state.activeQuestID == questID then
        return
    end

    state.activeQuestID = questID
    state.progressState = nil
    state.progressPercent = nil
    state.preyZoneName, state.preyZoneMapID = GetPreyZoneInfo(questID)
    state.inPreyZone = nil
    state.stage = 1
    state.tooltipText = nil
    state.playerMapID = nil
    state.playerMapHierarchy = nil
    state.lastWidgetSeenAt = 0
end

function HuntAssist:GetCandidateWidgetSetIDs()
    local state = self:GetBarState()
    local ids = state.candidateWidgetSetIDs
    for index = #ids, 1, -1 do
        ids[index] = nil
    end

    if C_UIWidgetManager and C_UIWidgetManager.GetTopCenterWidgetSetID then
        ids[#ids + 1] = C_UIWidgetManager.GetTopCenterWidgetSetID()
    end
    if C_UIWidgetManager and C_UIWidgetManager.GetObjectiveTrackerWidgetSetID then
        ids[#ids + 1] = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()
    end
    if C_UIWidgetManager and C_UIWidgetManager.GetBelowMinimapWidgetSetID then
        ids[#ids + 1] = C_UIWidgetManager.GetBelowMinimapWidgetSetID()
    end
    if C_UIWidgetManager and C_UIWidgetManager.GetPowerBarWidgetSetID then
        ids[#ids + 1] = C_UIWidgetManager.GetPowerBarWidgetSetID()
    end

    return ids
end

function HuntAssist:RefreshBarZoneState(questID, force)
    local state = self:GetBarState()
    if not IsValidQuestID(questID) then
        state.inPreyZone = nil
        return nil
    end

    if state.preyZoneMapID and C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local playerMapID = C_Map.GetBestMapForUnit("player")
        if playerMapID and (force or state.playerMapID ~= playerMapID or type(state.playerMapHierarchy) ~= "table") then
            local hierarchy = {}
            local currentMapID = playerMapID
            local guard = 0
            while currentMapID and guard < 20 do
                hierarchy[currentMapID] = true
                local mapInfo = C_Map.GetMapInfo(currentMapID)
                if not mapInfo or not mapInfo.parentMapID then
                    break
                end
                currentMapID = mapInfo.parentMapID
                guard = guard + 1
            end

            state.playerMapID = playerMapID
            state.playerMapHierarchy = hierarchy
        end

        if playerMapID and type(state.playerMapHierarchy) == "table" then
            state.inPreyZone = state.playerMapHierarchy[state.preyZoneMapID] == true
            return state.inPreyZone
        end
    end

    state.inPreyZone = IsPreyQuestOnCurrentMap(questID)
    return state.inPreyZone
end

function HuntAssist:FindPreyWidgetProgressState(activeQuestID)
    if not (C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo) then
        return nil, nil, nil
    end

    local preyWidgetType = GetWidgetTypePreyHuntProgress()
    local shownStateShown = GetShownStateShown()
    local fallbackState, fallbackTooltip, fallbackPct = nil, nil, nil

    for _, setID in ipairs(self:GetCandidateWidgetSetIDs()) do
        local okWidgets, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, C_UIWidgetManager, setID)
        if not okWidgets or type(widgets) ~= "table" then
            okWidgets, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
        end

        if type(widgets) == "table" then
            for _, widget in ipairs(widgets) do
                local okType, widgetType = pcall(function() return widget and widget.widgetType end)
                local okID, rawWidgetID = pcall(function() return widget and widget.widgetID end)
                local numericWidgetID = okID and tonumber(rawWidgetID) or nil
                if okType and widgetType == preyWidgetType and numericWidgetID then
                    local okInfo, info = pcall(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo, numericWidgetID)
                    if okInfo and info and info.shownState == shownStateShown then
                        local pct = ExtractProgressPercent(info, info.tooltip)
                        if IsValidQuestID(activeQuestID) then
                            local widgetQuestID = ExtractWidgetQuestID(info)
                            if widgetQuestID == activeQuestID then
                                return info.progressState, info.tooltip, pct
                            end

                            if widgetQuestID == nil and fallbackState == nil then
                                fallbackState, fallbackTooltip, fallbackPct = info.progressState, info.tooltip, pct
                            end
                        else
                            return info.progressState, info.tooltip, pct
                        end
                    end
                end
            end
        end
    end

    return fallbackState, fallbackTooltip, fallbackPct
end

function HuntAssist:IsRestrictedInstanceForPreyBar()
    local inInstance = false
    local instanceType = nil

    if rawget(_G, "IsInInstance") then
        local ok, inInst, instType = pcall(_G.IsInInstance)
        if ok then
            inInstance = inInst == true
            instanceType = instType
        end
    end

    if inInstance then
        return instanceType == "party"
            or instanceType == "raid"
            or instanceType == "scenario"
            or instanceType == "delve"
    end

    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local playerMapID = C_Map.GetBestMapForUnit("player")
        if playerMapID then
            local mapInfo = C_Map.GetMapInfo(playerMapID)
            if mapInfo and tonumber(mapInfo.mapType) == 4 then
                return true
            end
        end
    end

    return false
end

function HuntAssist:TryGetPreyQuestWaypoint(questID)
    local state = self:GetBarState()
    if not IsValidQuestID(questID) then
        return nil, nil, nil
    end

    if C_QuestLog and C_QuestLog.GetNextWaypoint then
        local waypoint = C_QuestLog.GetNextWaypoint(questID)
        if type(waypoint) == "table" then
            local waypointMapID = tonumber(waypoint.uiMapID or waypoint.mapID)
            local waypointX = tonumber((waypoint.position and waypoint.position.x) or waypoint.x)
            local waypointY = tonumber((waypoint.position and waypoint.position.y) or waypoint.y)
            if waypointMapID and waypointX and waypointY then
                return waypointMapID, waypointX, waypointY
            end
        end
    end

    local mapCandidates = {}
    local seenMapIDs = {}
    local function addMapCandidate(mapID)
        mapID = tonumber(mapID)
        if mapID and mapID > 0 and not seenMapIDs[mapID] then
            seenMapIDs[mapID] = true
            mapCandidates[#mapCandidates + 1] = mapID
        end
    end

    addMapCandidate(state.preyZoneMapID)
    if C_Map and C_Map.GetBestMapForUnit then
        addMapCandidate(C_Map.GetBestMapForUnit("player"))
    end

    if C_TaskQuest and C_TaskQuest.GetQuestLocation then
        for _, mapID in ipairs(mapCandidates) do
            local x, y = C_TaskQuest.GetQuestLocation(questID, mapID)
            if x and y then
                return mapID, x, y
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        for _, mapID in ipairs(mapCandidates) do
            local questsOnMap = C_QuestLog.GetQuestsOnMap(mapID)
            if type(questsOnMap) == "table" then
                for _, questInfo in ipairs(questsOnMap) do
                    if questInfo and questInfo.questID == questID and questInfo.x and questInfo.y then
                        return mapID, questInfo.x, questInfo.y
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

function HuntAssist:TryOpenPreyQuestOnMap()
    local state = self:GetBarState()
    if not IsValidQuestID(state.activeQuestID) then
        return false
    end

    local questID = state.activeQuestID
    local superTrackedQuest = false
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        local ok = pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        superTrackedQuest = ok == true
    end

    if OpenQuestMap then
        pcall(OpenQuestMap)
    elseif ToggleWorldMap then
        ToggleWorldMap()
    elseif _G.WorldMapFrame and _G.WorldMapFrame.Show then
        _G.WorldMapFrame:Show()
    end

    if QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, questID)
    end

    if not superTrackedQuest then
        local mapID, x, y = self:TryGetPreyQuestWaypoint(questID)
        if mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
            local waypointPoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
            if waypointPoint then
                C_Map.SetUserWaypoint(waypointPoint)
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                end
            end
        end
    end

    return true
end

function HuntAssist:RestoreSuppressedPreyFrames()
    if type(self.suppressedPreyFrames) ~= "table" then
        return
    end

    for frameRef in pairs(self.suppressedPreyFrames) do
        pcall(ApplyWidgetFrameSuppression, frameRef, false)
        self.suppressedPreyFrames[frameRef] = nil
    end
end

function HuntAssist:ApplyDefaultPreyIconVisibility()
    local config = GetConfig()
    local state = self:GetBarState()
    if not (config.enabled and config.bar and config.bar.enabled and config.bar.hideDefaultPreyIcon and IsValidQuestID(state.activeQuestID)) then
        self:RestoreSuppressedPreyFrames()
        return
    end

    if not (C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID and C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo) then
        return
    end

    local preyWidgetType = GetWidgetTypePreyHuntProgress()
    local shownStateShown = GetShownStateShown()
    local registry = self.suppressedPreyFrames or {}
    local seen = {}
    local containerGlobals = {
        "UIWidgetTopCenterContainerFrame",
        "UIWidgetObjectiveTrackerContainerFrame",
        "UIWidgetBelowMinimapContainerFrame",
        "UIWidgetPowerBarContainerFrame",
    }

    self.suppressedPreyFrames = registry

    for _, setID in ipairs(self:GetCandidateWidgetSetIDs()) do
        local okWidgets, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, C_UIWidgetManager, setID)
        if not okWidgets or type(widgets) ~= "table" then
            okWidgets, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
        end

        if type(widgets) == "table" then
            for _, widget in ipairs(widgets) do
                local okType, widgetType = pcall(function() return widget and widget.widgetType end)
                local okID, rawWidgetID = pcall(function() return widget and widget.widgetID end)
                local numericWidgetID = okID and tonumber(rawWidgetID) or nil
                if okType and widgetType == preyWidgetType and numericWidgetID then
                    local okInfo, info = pcall(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo, numericWidgetID)
                    if okInfo and info and info.shownState == shownStateShown then
                        local widgetQuestID = ExtractWidgetQuestID(info)
                        if widgetQuestID == nil or widgetQuestID == state.activeQuestID then
                            for _, globalName in ipairs(containerGlobals) do
                                local container = _G[globalName]
                                local widgetFrame = TryGetWidgetFrameByID(container, numericWidgetID)
                                if widgetFrame then
                                    ApplyWidgetFrameSuppression(widgetFrame, true)
                                    registry[widgetFrame] = true
                                    seen[widgetFrame] = true
                                end

                                local namedFrame = _G[globalName .. "Widget" .. tostring(numericWidgetID)]
                                if namedFrame then
                                    ApplyWidgetFrameSuppression(namedFrame, true)
                                    registry[namedFrame] = true
                                    seen[namedFrame] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for frameRef in pairs(registry) do
        if not seen[frameRef] then
            pcall(ApplyWidgetFrameSuppression, frameRef, false)
            registry[frameRef] = nil
        end
    end
end

function HuntAssist:ShouldPollBar()
    local config = GetConfig()
    return config.enabled and config.bar and config.bar.enabled
end

function HuntAssist:EnsureEventFrame()
    if self.eventFrame then
        return self.eventFrame
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            local barState = HuntAssist:GetBarState()
            barState.playerMapID = nil
            barState.playerMapHierarchy = nil
            HuntAssist:RefreshMonitor()
            HuntAssist:RefreshBarState(true)
            HuntAssist:TryAutoTrack()
        elseif event == "VIGNETTE_MINIMAP_UPDATED" then
            HuntAssist:RefreshMonitor()
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
            local barState = HuntAssist:GetBarState()
            barState.playerMapID = nil
            barState.playerMapHierarchy = nil
            if event == "ZONE_CHANGED_NEW_AREA" then
                HuntAssist:RefreshMonitor()
                HuntAssist:TryAutoTrack()
            end
            HuntAssist:RefreshBarState(true)
        elseif event == "QUEST_LOG_UPDATE" then
            HuntAssist:TryAutoTrack()
            HuntAssist:RefreshBarState(true)
        elseif event == "UPDATE_UI_WIDGET" or event == "UPDATE_ALL_UI_WIDGETS" or event == "QUEST_TURNED_IN" then
            HuntAssist:RefreshBarState(false)
        end
    end)
    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        if not HuntAssist:ShouldPollBar() then
            selfFrame._barElapsed = 0
            return
        end

        selfFrame._barElapsed = (selfFrame._barElapsed or 0) + elapsed
        if selfFrame._barElapsed >= BAR_POLL_INTERVAL then
            selfFrame._barElapsed = 0
            HuntAssist:RefreshBarState(false)
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

    if config.minimap and config.minimap.showBackground ~= false then
        frame.bg:SetColorTexture(0, 0, 0, 0.38)
    else
        frame.bg:SetColorTexture(0, 0, 0, 0)
    end

    if config.minimap and config.minimap.showBorder ~= false then
        SetSimpleOutlineColor(frame.border, 0, 0.6, 1, 0.45)
    else
        SetSimpleOutlineColor(frame.border, 0, 0, 0, 0)
    end
end

function HuntAssist:CreateBarFrame()
    if self.barFrame then
        return self.barFrame
    end

    local barConfig = GetConfig().bar
    local point = barConfig.point or {}
    local relativeFrame = GetAnchorFrame(point.relativeTo)
    local frame = CreateFrame("Frame", addonName .. "HuntAssistPreyBarFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetColorTexture(0, 0, 0, 0.55)

    frame.fill = frame:CreateTexture(nil, "ARTWORK")
    frame.fill:SetColorTexture(0.85, 0.23, 0.18, 0.95)

    frame.border = CreateSimpleOutline(frame, "BORDER", 1)

    frame.stageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.stageText:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    frame.stageText:SetJustifyH("CENTER")

    frame.percentText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.percentText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.percentText:SetJustifyH("CENTER")

    frame.tickMarks = {}
    for index = 1, 3 do
        local tick = frame:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(1, 1, 1, 0.28)
        frame.tickMarks[index] = tick
    end

    frame:SetPoint(
        point.point or "CENTER",
        relativeFrame,
        point.relativePoint or "CENTER",
        point.x or 0,
        point.y or 472
    )

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().bar.locked then
            return
        end

        selfFrame._dragging = true
        selfFrame._justDragged = false
        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        if not selfFrame._dragging then
            return
        end

        selfFrame._dragging = false
        selfFrame._justDragged = true
        selfFrame:StopMovingOrSizing()
        HuntAssist:SaveBarPosition()
        HuntAssist:RefreshBarDisplay()
    end)

    frame:SetScript("OnMouseUp", function(selfFrame, button)
        if button ~= "LeftButton" then
            return
        end

        if selfFrame._justDragged then
            selfFrame._justDragged = false
            return
        end

        local config = GetConfig()
        local state = HuntAssist:GetBarState()
        if config.enabled and config.bar.enabled and config.bar.hideDefaultPreyIcon and state.stage == MAX_PREY_STAGE then
            HuntAssist:TryOpenPreyQuestOnMap()
        end
    end)

    frame:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end

        local state = HuntAssist:GetBarState()
        local percent = state._displayPercent or 0
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("狩猎进度条", 1, 0.82, 0.20)

        if IsValidQuestID(state.activeQuestID) then
            local title = GetQuestTitle(state.activeQuestID)
            if title and title ~= "" then
                GameTooltip:AddLine(title, 1, 1, 1)
            end
            GameTooltip:AddLine(string.format("阶段：%d/%d", state.stage or 1, MAX_PREY_STAGE), 0.85, 0.85, 0.85)
            GameTooltip:AddLine(string.format("进度：%d%%", Round(percent)), 0.85, 0.85, 0.85)
            if state.preyZoneName then
                GameTooltip:AddLine("区域：" .. tostring(state.preyZoneName), 0.65, 0.82, 1.00)
            end
            if GetConfig().bar.hideDefaultPreyIcon and state.stage == MAX_PREY_STAGE then
                GameTooltip:AddLine("左键：打开地图并追踪当前猎物", 0.55, 0.92, 0.55)
            end
        else
            GameTooltip:AddLine("当前没有激活的狩猎任务", 0.85, 0.85, 0.85)
        end

        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    frame:SetSize(barConfig.width or 160, barConfig.height or 29)
    self.barFrame = frame
    return frame
end

function HuntAssist:SaveBarPosition()
    if not self.barFrame then
        return
    end

    local point, relativeTo, relativePoint, x, y = self.barFrame:GetPoint(1)
    local config = GetConfig()
    config.bar.point = config.bar.point or {}
    config.bar.point.point = point or "CENTER"
    config.bar.point.relativePoint = relativePoint or "CENTER"
    config.bar.point.relativeTo = relativeTo == Minimap and "Minimap" or "UIParent"
    config.bar.point.x = Round(x)
    config.bar.point.y = Round(y)
end

function HuntAssist:ApplyBarLayout()
    local frame = self:CreateBarFrame()
    local barConfig = GetConfig().bar
    local point = barConfig.point or {}
    local relativeFrame = GetAnchorFrame(point.relativeTo)
    local width = Clamp(barConfig.width or 160, 120, 320)
    local height = Clamp(barConfig.height or 29, 16, 48)
    local innerHeight = max(1, height - (BAR_FILL_INSET * 2))
    local tickPercents = { 25, 50, 75 }

    frame:ClearAllPoints()
    frame:SetPoint(
        point.point or "CENTER",
        relativeFrame,
        point.relativePoint or "CENTER",
        point.x or 0,
        point.y or 472
    )
    frame:SetSize(width, height)
    frame:SetMovable(not barConfig.locked)

    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", BAR_FILL_INSET, BAR_FILL_INSET)
    frame.bg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -BAR_FILL_INSET, -BAR_FILL_INSET)

    frame.fill:ClearAllPoints()
    frame.fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", BAR_FILL_INSET, BAR_FILL_INSET)
    frame.fill:SetHeight(innerHeight)

    ApplyConfiguredFont(frame.stageText, max(10, (barConfig.fontSize or 12) - 1))
    ApplyConfiguredFont(frame.percentText, barConfig.fontSize or 12)
    frame.stageText:SetTextColor(1, 0.82, 0.20, 1)
    frame.percentText:SetTextColor(1, 1, 1, 1)

    SetSimpleOutlineColor(frame.border, 0.82, 0.27, 0.21, 0.85)

    local innerWidth = max(0, width - (BAR_FILL_INSET * 2))
    for index, tick in ipairs(frame.tickMarks) do
        local pct = tickPercents[index]
        local x = BAR_FILL_INSET + Round(innerWidth * (pct / 100))
        tick:ClearAllPoints()
        tick:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", min(width - BAR_FILL_INSET - 1, x), BAR_FILL_INSET)
        tick:SetWidth(1)
        tick:SetHeight(innerHeight)
    end
end

function HuntAssist:RefreshBarDisplay()
    local config = GetConfig()
    local state = self:GetBarState()

    if not (config.enabled and config.bar and config.bar.enabled) then
        if self.barFrame then
            self.barFrame:Hide()
        end
        return
    end

    if not IsValidQuestID(state.activeQuestID) then
        if self.barFrame then
            self.barFrame:Hide()
        end
        return
    end

    if self:IsRestrictedInstanceForPreyBar() then
        if self.barFrame then
            self.barFrame:Hide()
        end
        return
    end

    if config.bar.onlyShowInPreyZone and state.inPreyZone == false then
        if self.barFrame then
            self.barFrame:Hide()
        end
        return
    end

    local frame = self:CreateBarFrame()
    self:ApplyBarLayout()

    local stage = GetStageFromProgressState(state.progressState)
    local displayPercent = 0
    if stage == MAX_PREY_STAGE then
        displayPercent = 100
    elseif state.inPreyZone == false then
        displayPercent = 0
    elseif type(state.progressPercent) == "number" then
        displayPercent = Clamp(state.progressPercent, 0, 100)
    else
        displayPercent = GetStageFallbackPercent(stage)
    end

    state.stage = stage
    state._displayPercent = displayPercent

    frame.stageText:SetText(string.format("狩猎进度 %d/%d", stage, MAX_PREY_STAGE))
    frame.percentText:SetText(string.format("%d%%", Round(displayPercent)))

    local fillWidth = Round(max(0, frame:GetWidth() - (BAR_FILL_INSET * 2)) * (displayPercent / 100))
    frame.fill:SetWidth(fillWidth)
    if displayPercent > 0 then
        frame.fill:Show()
    else
        frame.fill:Hide()
    end

    frame:Show()
end

function HuntAssist:RefreshBarState(forceZoneRefresh)
    local config = GetConfig()
    if not (config.enabled and config.bar and config.bar.enabled) then
        self:ClearBarState()
        self:RestoreSuppressedPreyFrames()
        self:RefreshBarDisplay()
        return
    end

    local state = self:GetBarState()
    local questID = GetCurrentActivePreyQuest()
    local now = GetTime and GetTime() or 0

    if not IsValidQuestID(questID) then
        self:ClearBarState()
        self:ApplyDefaultPreyIconVisibility()
        self:RefreshBarDisplay()
        return
    end

    self:ResetBarStateForQuest(questID)
    self:RefreshBarZoneState(questID, forceZoneRefresh == true)

    local newProgressState, tooltipText, newProgressPercent = nil, nil, nil
    if state.inPreyZone ~= false then
        newProgressState, tooltipText, newProgressPercent = self:FindPreyWidgetProgressState(questID)
    end

    if newProgressState ~= nil then
        state.progressState = newProgressState
        state.inPreyZone = true
        state.lastWidgetSeenAt = now
    elseif (now - (state.lastWidgetSeenAt or 0)) > 2 then
        state.progressState = nil
    end

    if newProgressPercent ~= nil then
        state.progressPercent = Clamp(newProgressPercent, 0, 100)
    else
        local objectivePercent = ExtractQuestObjectivePercent(questID)
        if objectivePercent ~= nil and (objectivePercent > 0 or state.progressState == PREY_PROGRESS_FINAL) then
            state.progressPercent = objectivePercent
        elseif state.progressState == PREY_PROGRESS_FINAL then
            state.progressPercent = 100
        elseif newProgressState ~= nil then
            state.progressPercent = nil
        elseif (now - (state.lastWidgetSeenAt or 0)) > 2 then
            state.progressPercent = nil
        end
    end

    state.tooltipText = tooltipText
    state.stage = GetStageFromProgressState(state.progressState)

    self:ApplyDefaultPreyIconVisibility()
    self:RefreshBarDisplay()
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

    if (config.minimap and config.minimap.enabled)
        or (config.autoTrack and config.autoTrack.enabled)
        or (config.bar and config.bar.enabled)
    then
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end

    if config.minimap and config.minimap.enabled then
        frame:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
    end

    if config.autoTrack and config.autoTrack.enabled and (config.autoTrack.worldQuest or config.autoTrack.stageQuest) then
        frame:RegisterEvent("QUEST_LOG_UPDATE")
    end

    if config.bar and config.bar.enabled then
        frame:RegisterEvent("QUEST_LOG_UPDATE")
        frame:RegisterEvent("QUEST_TURNED_IN")
        frame:RegisterEvent("UPDATE_UI_WIDGET")
        frame:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
        frame:RegisterEvent("ZONE_CHANGED")
        frame:RegisterEvent("ZONE_CHANGED_INDOORS")
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

    if config.enabled and config.bar and config.bar.enabled then
        self:CreateBarFrame()
        self:ApplyBarLayout()
        self:RefreshBarState(true)
    else
        self:ClearBarState()
        self:RestoreSuppressedPreyFrames()
        if self.barFrame then
            self.barFrame:Hide()
        end
    end

    if config.enabled and config.autoTrack and config.autoTrack.enabled then
        self:TryAutoTrack()
    end
end

function HuntAssist:OnPlayerLogin()
    self:RefreshFromSettings()
end
