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

local globalTooltipHooked = false
local tooltipVisibilityHooked = false
local tooltipNPCAliveHooked = false
local tooltipHealthBarHooked = false

local RAID_PROGRESS_ENTRIES = {
    {
        key = "nerubar",
        label = "灏奸瞾宸村皵鐜嬪",
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

local function BuildDateText(month, day, year)
    month = tonumber(month)
    day = tonumber(day)
    year = tonumber(year)
    if not (month and day and year) then
        return nil
    end

    return string.format("%04d-%02d-%02d", year, month, day)
end

local function GetAchievementStatus(achievementID, useComparison)
    if type(achievementID) ~= "number" then
        return false, nil
    end

    local getter = useComparison and GetComparisonAchievementInfo or GetAchievementInfo
    if type(getter) ~= "function" then
        return false, nil
    end

    local _, _, _, completed, month, day, year = getter(achievementID)
    if completed then
        return true, BuildDateText(month, day, year)
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

    local _, unit = tooltip:GetUnit()
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) then
        return
    end

    local guid = UnitGUID(unit)
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
