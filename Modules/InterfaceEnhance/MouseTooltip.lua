local _, NS = ...
local Core = NS.Core

-- Tooltip enhancements copied from YuXuanToolbox and adapted to this addon.
local MouseTooltip = {}
NS.Modules.InterfaceEnhance.MouseTooltip = MouseTooltip

local TOOLTIP_FRAME_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "EmbeddedItemTooltip",
    "FriendsTooltip",
}

local NPC_TIME_FORMAT = "%H:%M, %d.%m"
local RAID_PROGRESS_REQUEST_COOLDOWN = 15
local RAID_PROGRESS_CACHE_TTL = 600
local bitlib = bit or bit32
local band = bitlib and bitlib.band
local rshift = bitlib and bitlib.rshift
local ClearAchievementComparisonUnit = rawget(_G, "ClearAchievementComparisonUnit")
local EJ_GetInstanceInfo = rawget(_G, "EJ_GetInstanceInfo")
local GetAchievementInfo = rawget(_G, "GetAchievementInfo")
local GetComparisonStatistic = rawget(_G, "GetComparisonStatistic")
local GetStatistic = rawget(_G, "GetStatistic")
local SetAchievementComparisonUnit = rawget(_G, "SetAchievementComparisonUnit")

local L_NORMAL = "\230\153\174\233\128\154"
local L_HEROIC = "\232\139\177\233\155\132"
local L_MYTHIC = "\229\143\178\232\175\151"
local L_LFR = "\233\154\143\230\156\186"
local L_NO_DATA = "\230\154\130\230\151\160\230\149\176\230\141\174"
local L_RAID_RECORD_TITLE = "\229\155\162\230\156\172\229\142\134\229\143\178\230\156\128\233\171\152\231\186\170\229\189\149"
local L_RAID_RECORD_FAILED = "\230\154\130\230\151\182\230\151\160\230\179\149\232\175\187\229\143\150\232\175\165\231\142\169\229\174\182\231\154\132\229\142\134\229\143\178\229\155\162\230\156\172\231\186\170\229\189\149\227\128\130"
local L_RAID_RECORD_LOADING = "\230\173\163\229\156\168\232\175\187\229\143\150\232\175\165\231\142\169\229\174\182\231\154\132\229\142\134\229\143\178\229\155\162\230\156\172\231\186\170\229\189\149\46\46\46"

local globalTooltipHooked = false
local tooltipVisibilityHooked = false
local tooltipNPCAliveHooked = false
local tooltipHealthBarHooked = false

local RAID_PROGRESS_RAIDS = {
    {
        key = "voidspire",
        ejID = 1308,
        fallbackLabel = "The Voidspire",
        bosses = {
            { 61276, 61277, 61278, 61279 },
            { 61280, 61281, 61282, 61283 },
            { 61284, 61285, 61286, 61287 },
            { 61288, 61289, 61290, 61291 },
            { 61292, 61293, 61294, 61295 },
            { 61296, 61297, 61298, 61299 },
        },
    },
    {
        key = "dreamrift",
        ejID = 1314,
        fallbackLabel = "The Dreamrift",
        bosses = {
            { 61474, 61475, 61476, 61477 },
        },
    },
    {
        key = "queldanas",
        ejID = 1307,
        fallbackLabel = "March on Quel'Danas",
        bosses = {
            { 61300, 61301, 61302, 61303 },
            { 61304, 61305, 61306, 61307 },
        },
    },
}

local npcTimeFormatter = CreateFromMixins and SecondsFormatterMixin and CreateFromMixins(SecondsFormatterMixin) or nil
if npcTimeFormatter and npcTimeFormatter.Init and SecondsFormatter and SecondsFormatter.Abbreviation then
    npcTimeFormatter:Init(1, SecondsFormatter.Abbreviation.Truncate)
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "mouseTooltip")
end

local function AreTooltipsBlocked(config)
    if not (config and config.enabled) then
        return false
    end

    if config.disableAllTooltips then
        return true
    end

    return config.disableInCombat and InCombatLockdown and InCombatLockdown()
end

local function GetTooltipUnit(tooltip)
    if not (tooltip and type(tooltip.GetUnit) == "function") then
        return nil
    end

    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if ok then
        return unit
    end
end

local function SafeUnitExists(unit)
    if not unit then
        return false
    end

    local ok, result = pcall(UnitExists, unit)
    return ok and result or false
end

local function SafeUnitGUID(unit)
    if not unit then
        return nil
    end

    local ok, guid = pcall(UnitGUID, unit)
    if ok then
        return guid
    end
end

local function SafeUnitIsDead(unit)
    if not unit then
        return false
    end

    local ok, result = pcall(UnitIsDead, unit)
    return ok and result or false
end

local function SafeUnitIsPlayer(unit)
    if not unit then
        return false
    end

    local ok, result = pcall(UnitIsPlayer, unit)
    return ok and result or false
end

local function SafeUnitIsUnit(unit, otherUnit)
    if not (unit and otherUnit) then
        return false
    end

    local ok, result = pcall(UnitIsUnit, unit, otherUnit)
    return ok and result or false
end

local function SafeUnitName(unit)
    if not unit then
        return nil, nil
    end

    local ok, name, realm = pcall(UnitName, unit)
    if ok then
        return name, realm
    end
end

local function AddColoredDoubleLine(tooltip, leftText, rightText, leftColor, rightColor, wrap)
    leftColor = leftColor or NORMAL_FONT_COLOR
    rightColor = rightColor or HIGHLIGHT_FONT_COLOR

    if wrap == nil then
        wrap = true
    end

    tooltip:AddDoubleLine(
        leftText,
        rightText,
        leftColor.r or 1,
        leftColor.g or 1,
        leftColor.b or 1,
        rightColor.r or 1,
        rightColor.g or 1,
        rightColor.b or 1,
        wrap
    )
end

local function EnsureDefaults()
    local config = GetConfig()
    if not config then
        return
    end

    local defaults = NS.DEFAULTS.interfaceEnhance.mouseTooltip or {}
    for key, value in pairs(defaults) do
        if config[key] == nil then
            config[key] = value
        end
    end
end

local function DecodeNPCSpawnInfo(guid)
    if type(guid) ~= "string" or not band or not rshift then
        return nil
    end

    local unitType, _, serverID, _, layerUID, unitID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end

    local rawTime = tonumber(strsub(guid, -6), 16)
    local indexValue = tonumber(strsub(guid, -10, -6), 16)
    if not rawTime or not indexValue then
        return nil
    end

    local serverTime = GetServerTime()
    local spawnTime = (serverTime - (serverTime % 2 ^ 23)) + band(rawTime, 0x7fffff)
    if spawnTime > serverTime then
        spawnTime = spawnTime - ((2 ^ 23) - 1)
    end

    local spawnIndex = rshift(band(indexValue, 0xffff8), 3)

    return {
        serverID = serverID,
        layerUID = layerUID,
        unitID = unitID,
        spawnIndex = spawnIndex,
        spawnTime = spawnTime,
        serverTime = serverTime,
        aliveSeconds = math.max(0, serverTime - spawnTime),
    }
end

local function FormatAliveTime(seconds)
    if npcTimeFormatter and npcTimeFormatter.Format then
        return npcTimeFormatter:Format(seconds, false)
    end

    seconds = math.max(0, math.floor(seconds or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainSeconds = seconds % 60

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    if minutes > 0 then
        return string.format("%dm %ds", minutes, remainSeconds)
    end
    return string.format("%ds", remainSeconds)
end

local function GetRaidLabel(raid)
    if type(EJ_GetInstanceInfo) == "function" and raid.ejID then
        local name = EJ_GetInstanceInfo(raid.ejID)
        if name and name ~= "" then
            return name
        end
    end

    return raid.fallbackLabel or raid.key
end

local function DetectStatisticDifficulty(statID, index)
    if type(GetAchievementInfo) == "function" and type(statID) == "number" then
        local _, statisticName = GetAchievementInfo(statID)
        if type(statisticName) == "string" then
            local lowerName = string.lower(statisticName)
            if string.find(lowerName, "mythic", 1, true) or string.find(statisticName, L_MYTHIC, 1, true) then
                return "mythic"
            end
            if string.find(lowerName, "heroic", 1, true) or string.find(statisticName, L_HEROIC, 1, true) then
                return "heroic"
            end
            if string.find(lowerName, "normal", 1, true) or string.find(statisticName, L_NORMAL, 1, true) then
                return "normal"
            end
            if string.find(lowerName, "raid finder", 1, true) or string.find(statisticName, L_LFR, 1, true) then
                return "lfr"
            end
        end
    end

    if index == 4 then
        return "mythic"
    end
    if index == 3 then
        return "heroic"
    end
    if index == 2 then
        return "normal"
    end
    if index == 1 then
        return "lfr"
    end
end

local function GetStatisticValue(statID, useComparison)
    if type(statID) ~= "number" then
        return 0
    end

    local getter = useComparison and GetComparisonStatistic or GetStatistic
    if type(getter) ~= "function" then
        return 0
    end

    local value = getter(statID)
    value = tonumber(value or 0)
    return value or 0
end

local function BuildRaidProgressSnapshot(useComparison)
    local snapshot = {}

    for _, raid in ipairs(RAID_PROGRESS_RAIDS) do
        local progress = {
            label = GetRaidLabel(raid),
            totalBosses = #raid.bosses,
            normalKilled = 0,
            heroicKilled = 0,
            mythicKilled = 0,
        }

        for _, bossStats in ipairs(raid.bosses) do
            local bossKilled = {
                normal = false,
                heroic = false,
                mythic = false,
            }

            for statIndex, statID in ipairs(bossStats) do
                local difficulty = DetectStatisticDifficulty(statID, statIndex)
                if difficulty and bossKilled[difficulty] ~= nil and GetStatisticValue(statID, useComparison) > 0 then
                    bossKilled[difficulty] = true
                end
            end

            if bossKilled.normal then
                progress.normalKilled = progress.normalKilled + 1
            end
            if bossKilled.heroic then
                progress.heroicKilled = progress.heroicKilled + 1
            end
            if bossKilled.mythic then
                progress.mythicKilled = progress.mythicKilled + 1
            end
        end

        snapshot[raid.key] = progress
    end

    return snapshot
end

local function BuildRaidProgressStatusText(progress)
    if not progress then
        return "|cFF888888" .. L_NO_DATA .. "|r"
    end

    local total = progress.totalBosses or 0
    return string.format(
        "|cFFFFFFFF%s|r %d/%d  |cFF66CCFF%s|r %d/%d  |cFFFF8040%s|r %d/%d",
        L_NORMAL,
        progress.normalKilled or 0,
        total,
        L_HEROIC,
        progress.heroicKilled or 0,
        total,
        L_MYTHIC,
        progress.mythicKilled or 0,
        total
    )
end

function MouseTooltip:RefreshRaidProgressTooltip(guid)
    local tooltip = _G.GameTooltip
    if not (tooltip and tooltip:IsShown() and guid and tooltip.YXSRaidProgressGUID == guid) then
        return
    end

    if tooltip.RefreshData then
        pcall(tooltip.RefreshData, tooltip)
        return
    end

    local unit = GetTooltipUnit(tooltip)
    if SafeUnitExists(unit) then
        pcall(tooltip.SetUnit, tooltip, unit)
    end
end

function MouseTooltip:RequestRaidProgressForUnit(unit, guid)
    if not (unit and guid and type(SetAchievementComparisonUnit) == "function") then
        return
    end

    local cacheEntry = self.raidProgressCache and self.raidProgressCache[guid]
    local now = GetTime and GetTime() or 0
    if cacheEntry and cacheEntry.state == "pending" and (now - (cacheEntry.requestedAt or 0)) < RAID_PROGRESS_REQUEST_COOLDOWN then
        return
    end

    self.raidProgressCache = self.raidProgressCache or {}
    self.raidProgressCache[guid] = {
        state = "pending",
        requestedAt = now,
    }

    self.pendingRaidProgressGUID = guid
    self.pendingRaidProgressRequestedAt = now

    if type(ClearAchievementComparisonUnit) == "function" then
        pcall(ClearAchievementComparisonUnit)
    end

    local ok = pcall(SetAchievementComparisonUnit, unit)
    if not ok then
        local name, realm = SafeUnitName(unit)
        local fullName = name
        if name and realm and realm ~= "" then
            fullName = name .. "-" .. realm
        end
        if fullName then
            ok = pcall(SetAchievementComparisonUnit, fullName)
        end
    end

    if not ok then
        self.raidProgressCache[guid].state = "failed"
        self.pendingRaidProgressGUID = nil
        self.pendingRaidProgressRequestedAt = nil
    end
end

function MouseTooltip:AppendRaidProgressToTooltip(tooltip)
    local config = GetConfig()
    if not (config and config.enabled and config.showPlayerRaidProgress) then
        return
    end

    if AreTooltipsBlocked(config) or not tooltip or type(tooltip.GetUnit) ~= "function" then
        return
    end

    local unit = GetTooltipUnit(tooltip)
    if not SafeUnitExists(unit) or not SafeUnitIsPlayer(unit) then
        return
    end

    local guid = SafeUnitGUID(unit)
    if not guid then
        return
    end

    tooltip.YXSRaidProgressGUID = guid

    local snapshot
    if SafeUnitIsUnit(unit, "player") then
        snapshot = BuildRaidProgressSnapshot(false)
    else
        if type(SetAchievementComparisonUnit) ~= "function" or type(GetComparisonStatistic) ~= "function" then
            return
        end

        self.raidProgressCache = self.raidProgressCache or {}
        local cacheEntry = self.raidProgressCache[guid]
        local now = GetTime and GetTime() or 0

        if cacheEntry and cacheEntry.state == "ready" and (now - (cacheEntry.updatedAt or 0)) <= RAID_PROGRESS_CACHE_TTL then
            snapshot = cacheEntry.snapshot
        elseif cacheEntry and cacheEntry.state == "failed" then
            tooltip:AddLine(" ")
            tooltip:AddLine(L_RAID_RECORD_TITLE, 1, 0.82, 0)
            tooltip:AddLine("|cFF888888" .. L_RAID_RECORD_FAILED .. "|r", 0.7, 0.7, 0.7)
            tooltip:Show()
            return
        else
            self:RequestRaidProgressForUnit(unit, guid)
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(L_RAID_RECORD_TITLE, 1, 0.82, 0)

    if not snapshot then
        tooltip:AddLine("|cFF888888" .. L_RAID_RECORD_LOADING .. "|r", 0.7, 0.7, 0.7)
        tooltip:Show()
        return
    end

    for _, raid in ipairs(RAID_PROGRESS_RAIDS) do
        local progress = snapshot[raid.key]
        AddColoredDoubleLine(tooltip, progress and progress.label or GetRaidLabel(raid), BuildRaidProgressStatusText(progress))
    end

    tooltip:Show()
end

function MouseTooltip:HandleInspectAchievementReady(guid)
    if not (guid and self.pendingRaidProgressGUID and guid == self.pendingRaidProgressGUID) then
        return
    end

    self.raidProgressCache = self.raidProgressCache or {}
    self.raidProgressCache[guid] = {
        state = "ready",
        updatedAt = GetTime and GetTime() or 0,
        snapshot = BuildRaidProgressSnapshot(true),
    }

    self.pendingRaidProgressGUID = nil
    self.pendingRaidProgressRequestedAt = nil

    if type(ClearAchievementComparisonUnit) == "function" then
        pcall(ClearAchievementComparisonUnit)
    end

    self:RefreshRaidProgressTooltip(guid)
end

function Core:SetTooltipAnchor(tooltip, owner, fallbackAnchor)
    if not tooltip then
        return
    end

    local config = GetConfig()
    if not (config and config.enabled) then
        tooltip:SetOwner(owner or UIParent, fallbackAnchor or "ANCHOR_RIGHT")
        return
    end

    if AreTooltipsBlocked(config) then
        tooltip:Hide()
        return
    end

    if config.tooltipFollowCursor then
        tooltip:SetOwner(owner or UIParent, "ANCHOR_CURSOR_RIGHT")
    else
        tooltip:SetOwner(owner or UIParent, fallbackAnchor or "ANCHOR_RIGHT")
    end
end

function MouseTooltip:AppendNPCAliveTimeToTooltip(tooltip)
    local config = GetConfig()
    if not (config and config.enabled and config.showNPCAliveTime) then
        return
    end

    if AreTooltipsBlocked(config) then
        return
    end

    if not tooltip or type(tooltip.GetUnit) ~= "function" then
        return
    end

    if config.npcTimeUseModifier and not IsModifierKeyDown() then
        return
    end

    local unit = GetTooltipUnit(tooltip)
    if not SafeUnitExists(unit) or SafeUnitIsPlayer(unit) or SafeUnitIsDead(unit) then
        return
    end

    local guid = SafeUnitGUID(unit)
    local info = DecodeNPCSpawnInfo(guid)
    if not info then
        return
    end

    if config.npcTimeShowCurrentTime then
        AddColoredDoubleLine(tooltip, "Current Time", date(NPC_TIME_FORMAT, info.serverTime))
    end

    AddColoredDoubleLine(
        tooltip,
        "NPC Alive Time",
        FormatAliveTime(info.aliveSeconds) .. " (" .. date(NPC_TIME_FORMAT, info.spawnTime) .. ")"
    )

    if config.npcTimeShowLayer and info.serverID and info.layerUID then
        AddColoredDoubleLine(tooltip, "Layer", tostring(info.serverID) .. "-" .. tostring(info.layerUID))
    end

    if config.npcTimeShowNPCID and info.unitID then
        AddColoredDoubleLine(tooltip, "NPC ID", tostring(info.unitID))
        if info.spawnIndex and info.spawnIndex > 0 then
            AddColoredDoubleLine(tooltip, "Index", tostring(info.spawnIndex))
        end
    end

    tooltip:Show()
end

function MouseTooltip:ApplyNPCTooltipHook()
    if tooltipNPCAliveHooked then
        return
    end

    tooltipNPCAliveHooked = true

    local function HookTooltipUnit(tooltip)
        MouseTooltip:AppendNPCAliveTimeToTooltip(tooltip)
        MouseTooltip:AppendRaidProgressToTooltip(tooltip)
    end

    local tooltipDataProcessor = _G["TooltipDataProcessor"]
    if tooltipDataProcessor and Enum and Enum.TooltipDataType and tooltipDataProcessor.AddTooltipPostCall then
        tooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, HookTooltipUnit)
        return
    end

    for _, frameName in ipairs(TOOLTIP_FRAME_NAMES) do
        local tooltip = _G[frameName]
        if tooltip and tooltip.HookScript and tooltip.HasScript and tooltip:HasScript("OnTooltipSetUnit") then
            tooltip:HookScript("OnTooltipSetUnit", HookTooltipUnit)
        end
    end
end

local function EnsureOpaqueTooltipBackground(frame)
    if not frame or frame.YXSOpaqueBackground then
        return
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    if frame.NineSlice and frame.NineSlice.Center then
        bg:SetAllPoints(frame.NineSlice.Center)
    else
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    end
    bg:SetColorTexture(0, 0, 0, 1)
    bg:Hide()
    frame.YXSOpaqueBackground = bg
end

function MouseTooltip:ApplyTooltipBackgroundOpacity()
    local config = GetConfig()
    local enabled = config and config.enabled and config.opaqueTooltipBackground

    for _, frameName in ipairs(TOOLTIP_FRAME_NAMES) do
        local tooltip = _G[frameName]
        if tooltip then
            EnsureOpaqueTooltipBackground(tooltip)
            if tooltip.YXSOpaqueBackground then
                tooltip.YXSOpaqueBackground:SetShown(enabled and true or false)
            end
        end
    end
end

function MouseTooltip:ApplyTooltipHealthBarVisibility()
    local statusBar = _G["GameTooltipStatusBar"]
    if not statusBar then
        return
    end

    if not tooltipHealthBarHooked and statusBar.HookScript then
        tooltipHealthBarHooked = true
        statusBar:HookScript("OnShow", function(bar)
            local config = GetConfig()
            if not (config and config.enabled and config.showTooltipHealthBar and not AreTooltipsBlocked(config)) then
                bar:Hide()
            end
        end)
    end

    local config = GetConfig()
    local showHealthBar = config and config.enabled and config.showTooltipHealthBar and not AreTooltipsBlocked(config)
    if showHealthBar then
        statusBar:Show()
    else
        statusBar:Hide()
    end
end

function MouseTooltip:ApplyGlobalTooltipHook()
    if globalTooltipHooked then
        return
    end

    globalTooltipHooked = true
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        local config = GetConfig()
        if not (config and config.enabled and config.tooltipFollowCursor) then
            return
        end

        if AreTooltipsBlocked(config) then
            return
        end

        tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR_RIGHT")
    end)
end

function MouseTooltip:ApplyTooltipVisibilityHook()
    if tooltipVisibilityHooked then
        return
    end

    tooltipVisibilityHooked = true

    local function HideTooltipIfDisabled(self)
        local config = GetConfig()
        if AreTooltipsBlocked(config) then
            self:Hide()
        end
    end

    for _, frameName in ipairs(TOOLTIP_FRAME_NAMES) do
        local tooltip = _G[frameName]
        if tooltip and tooltip.HookScript then
            tooltip:HookScript("OnShow", HideTooltipIfDisabled)
        end
    end
end

function MouseTooltip:UpdateTooltipVisibility()
    self:ApplyTooltipVisibilityHook()

    local config = GetConfig()
    if not AreTooltipsBlocked(config) then
        return
    end

    for _, frameName in ipairs(TOOLTIP_FRAME_NAMES) do
        local tooltip = _G[frameName]
        if tooltip and tooltip.Hide then
            tooltip:Hide()
        end
    end
end

function MouseTooltip:ApplyAllSettings()
    EnsureDefaults()
    self:ApplyGlobalTooltipHook()
    self:ApplyTooltipVisibilityHook()
    self:ApplyNPCTooltipHook()
    self:ApplyTooltipBackgroundOpacity()
    self:ApplyTooltipHealthBarVisibility()
    self:UpdateTooltipVisibility()
end

function MouseTooltip:RefreshFromSettings()
    self:ApplyAllSettings()
end

function MouseTooltip:OnPlayerLogin()
    self.eventFrame = self.eventFrame or CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "INSPECT_ACHIEVEMENT_READY" then
            MouseTooltip:HandleInspectAchievementReady(...)
            return
        end

        MouseTooltip:UpdateTooltipVisibility()
        MouseTooltip:ApplyTooltipHealthBarVisibility()
    end)

    self:ApplyAllSettings()
end
