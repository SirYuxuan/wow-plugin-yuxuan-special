local addonName, NS = ...
local Core = NS.Core

local ItemLevelPlanner = {}
NS.Modules.InterfaceEnhance.ItemLevelPlanner = ItemLevelPlanner

--[[
装等预估面板定位是“配装试算器”：
1. 列出当前穿戴的所有核心装备槽位。
2. 每一行显示图标、槽位名、当前装等、目标装等。
3. 直接点击并编辑目标装等，顶部实时汇总整体平均装等变化。

默认会出现在角色面板左侧，但支持拖动挪开并记住位置。
这样既保留“贴着角色面板看”的便利，也不会被固定布局束缚。
]]

local SLOT_ORDER = {
    "HEAD", "NECK", "SHOULDER", "CHEST",
    "WAIST", "LEGS", "FEET", "WRIST",
    "HANDS", "FINGER1", "FINGER2", "TRINKET1",
    "TRINKET2", "BACK", "MAINHAND", "OFFHAND",
}

local SLOT_INFO = {
    HEAD = { slotId = 1, name = "头部" },
    NECK = { slotId = 2, name = "项链" },
    SHOULDER = { slotId = 3, name = "肩部" },
    CHEST = { slotId = 5, name = "胸部" },
    WAIST = { slotId = 6, name = "腰部" },
    LEGS = { slotId = 7, name = "腿部" },
    FEET = { slotId = 8, name = "脚部" },
    WRIST = { slotId = 9, name = "手腕" },
    HANDS = { slotId = 10, name = "手部" },
    FINGER1 = { slotId = 11, name = "戒指 1" },
    FINGER2 = { slotId = 12, name = "戒指 2" },
    TRINKET1 = { slotId = 13, name = "饰品 1" },
    TRINKET2 = { slotId = 14, name = "饰品 2" },
    BACK = { slotId = 15, name = "披风" },
    MAINHAND = { slotId = 16, name = "主手" },
    OFFHAND = { slotId = 17, name = "副手" },
}

local EQUIP_LOC_TO_SLOT_KEYS = {
    INVTYPE_HEAD = { "HEAD" },
    INVTYPE_NECK = { "NECK" },
    INVTYPE_SHOULDER = { "SHOULDER" },
    INVTYPE_CHEST = { "CHEST" },
    INVTYPE_ROBE = { "CHEST" },
    INVTYPE_WAIST = { "WAIST" },
    INVTYPE_LEGS = { "LEGS" },
    INVTYPE_FEET = { "FEET" },
    INVTYPE_WRIST = { "WRIST" },
    INVTYPE_HAND = { "HANDS" },
    INVTYPE_FINGER = { "FINGER1", "FINGER2" },
    INVTYPE_TRINKET = { "TRINKET1", "TRINKET2" },
    INVTYPE_CLOAK = { "BACK" },
    INVTYPE_WEAPONMAINHAND = { "MAINHAND" },
    INVTYPE_WEAPONOFFHAND = { "OFFHAND" },
    INVTYPE_HOLDABLE = { "OFFHAND" },
    INVTYPE_SHIELD = { "OFFHAND" },
    INVTYPE_WEAPON = { "MAINHAND", "OFFHAND" },
    INVTYPE_2HWEAPON = { "MAINHAND" },
    INVTYPE_RANGED = { "MAINHAND" },
    INVTYPE_RANGEDRIGHT = { "MAINHAND" },
}

local TWO_HANDED_EQUIP_LOCS = {
    INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local PANEL_WIDTH = 432
local PANEL_GAP = 12
local HEADER_HEIGHT = 98
local ROW_HEIGHT = 24
local ROW_SPACING = 4
local PANEL_PADDING = 16
local DEFAULT_CHARACTER_BUTTON_OFFSET_X = 58
local DEFAULT_CHARACTER_BUTTON_OFFSET_Y = -34
local UPGRADE_TRACK_COLORS = {
    explorer = { r = 0.70, g = 0.78, b = 0.86 },
    adventurer = { r = 0.20, g = 1.00, b = 0.50 },
    veteran = { r = 0.35, g = 1.00, b = 0.72 },
    champion = { r = 0.35, g = 0.72, b = 1.00 },
    hero = { r = 0.82, g = 0.45, b = 1.00 },
    myth = { r = 1.00, g = 0.50, b = 0.20 },
}
local UPGRADE_TRACK_ALIASES = {
    { key = "myth", names = { "神话", "史诗", "Myth" } },
    { key = "hero", names = { "英雄", "Hero" } },
    { key = "champion", names = { "勇士", "Champion" } },
    { key = "veteran", names = { "老兵", "Veteran" } },
    { key = "adventurer", names = { "冒险者", "Adventurer" } },
    { key = "explorer", names = { "探索者", "Explorer" } },
}

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "itemLevelPlanner")
end

local function EnsurePanelPoint()
    local config = GetConfig()
    if config.point then
        return config.point
    end

    local x, y = -340, 0
    if CharacterFrame and CharacterFrame:IsShown() then
        local left = CharacterFrame:GetLeft()
        local top = CharacterFrame:GetTop()
        if left and top then
            x = left - (PANEL_WIDTH * 0.5) - PANEL_GAP
            y = top - 240
        end
    end

    config.point = {
        point = "TOPRIGHT",
        relativePoint = "BOTTOMLEFT",
        x = math.floor(x + 0.5),
        y = math.floor(y + 0.5),
    }
    return config.point
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function ApplyConfiguredFont(target, size, outline)
    if not target then
        return
    end

    local config = GetConfig()
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(target, size or (config.fontSize or 13), outline or "", config.fontPreset or "CHAT")
        return
    end

    target:SetFont(STANDARD_TEXT_FONT, size or (config.fontSize or 13), outline or "")
end

local function ClampNumber(value, minValue, maxValue)
    local number = tonumber(value) or minValue
    if maxValue then
        number = math.min(maxValue, number)
    end
    return math.max(minValue, number)
end

local function GetCharacterButtonOffsets()
    local config = GetConfig()
    return ClampNumber(config.characterButtonOffsetX or DEFAULT_CHARACTER_BUTTON_OFFSET_X, -1000, 1000),
        ClampNumber(config.characterButtonOffsetY or DEFAULT_CHARACTER_BUTTON_OFFSET_Y, -1000, 1000)
end

local function FormatNumber(value, decimals)
    return string.format("%." .. tostring(decimals or 1) .. "f", tonumber(value) or 0)
end

local function TruncateText(text, maxChars)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    local limit = tonumber(maxChars) or 0
    if limit <= 0 or #text <= limit then
        return text
    end

    return text:sub(1, limit) .. "..."
end

local function GetCurrentAverageItemLevel()
    if type(GetAverageItemLevel) == "function" then
        local overall, equipped = GetAverageItemLevel()
        local value = tonumber(equipped) or tonumber(overall)
        if value and value > 0 then
            return value
        end
    end
    return 0
end

local function GetSlotItemInfo(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then
        return 0, nil, nil, nil
    end

    local itemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(link)
    elseif GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(link)
    end

    local _, _, _, equipLoc, icon = GetItemInfoInstant(link)
    return tonumber(itemLevel) or 0, link, equipLoc, icon
end

local upgradeScannerName = addonName .. "ItemLevelPlannerUpgradeScanner"

local function GetUpgradeScannerTooltip()
    if ItemLevelPlanner.upgradeScannerTooltip then
        return ItemLevelPlanner.upgradeScannerTooltip
    end

    local tooltip = CreateFrame("GameTooltip", upgradeScannerName, UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    ItemLevelPlanner.upgradeScannerTooltip = tooltip
    return tooltip
end

local function GetUpgradeTrackGain(currentRank, maxRank)
    local gain = 0
    for nextRank = currentRank + 1, maxRank do
        if nextRank == 2 or nextRank == maxRank then
            gain = gain + 4
        else
            gain = gain + 3
        end
    end
    return gain
end

local function DetectUpgradeTrackName(text)
    if type(text) ~= "string" then
        return nil, nil
    end

    for _, track in ipairs(UPGRADE_TRACK_ALIASES) do
        for _, name in ipairs(track.names) do
            if text:find(name, 1, true) then
                return name, track.key
            end
        end
    end

    local name = text:match("^%s*([^%d/]+)%s+%d+%s*/%s*%d+")
    if type(name) == "string" then
        name = name:gsub(".*[:：]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and #name <= 18 then
            return name, nil
        end
    end
end

local function GetItemUpgradeTrackInfo(itemLink)
    if not itemLink then
        return nil
    end

    local currentLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        currentLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    elseif GetDetailedItemLevelInfo then
        currentLevel = GetDetailedItemLevelInfo(itemLink)
    end
    currentLevel = tonumber(currentLevel)
    if not currentLevel or currentLevel <= 0 then
        return nil
    end

    local tooltip = GetUpgradeScannerTooltip()
    tooltip:ClearLines()
    local ok = pcall(tooltip.SetHyperlink, tooltip, itemLink)
    if not ok then
        return nil
    end

    for index = 2, tooltip:NumLines() do
        local left = _G[upgradeScannerName .. "TextLeft" .. tostring(index)]
        local text = left and left:GetText()
        if type(text) == "string" then
            local currentRank, maxRank = text:match("(%d+)%s*/%s*(%d+)")
            currentRank = tonumber(currentRank)
            maxRank = tonumber(maxRank)
            if currentRank and maxRank and maxRank >= currentRank then
                local trackName, trackKey = DetectUpgradeTrackName(text)
                local color = UPGRADE_TRACK_COLORS[trackKey or ""]
                return {
                    name = trackName,
                    key = trackKey,
                    color = color,
                    currentRank = currentRank,
                    maxRank = maxRank,
                    maxItemLevel = currentLevel + GetUpgradeTrackGain(currentRank, maxRank),
                }
            end
        end
    end

    return nil
end

local function GetItemMaxUpgradeLevel(itemLink)
    local track = GetItemUpgradeTrackInfo(itemLink)
    return track and track.maxItemLevel or nil
end

function ItemLevelPlanner.GetItemUpgradeTrackInfo(itemLink)
    return GetItemUpgradeTrackInfo(itemLink)
end

local function GetWeaponState()
    local mainLevel, mainLink, mainEquipLoc, mainIcon = GetSlotItemInfo(16)
    local offLevel, offLink, offEquipLoc, offIcon = GetSlotItemInfo(17)
    local mainWeight, offWeight = 1, 1

    if mainLink and not offLink and TWO_HANDED_EQUIP_LOCS[mainEquipLoc] then
        mainWeight = 2
        offWeight = 0
    elseif not offLink then
        offWeight = 0
    end

    return {
        mainLevel = mainLevel,
        offLevel = offLevel,
        mainEquipLoc = mainEquipLoc,
        offEquipLoc = offEquipLoc,
        mainIcon = mainIcon,
        offIcon = offIcon,
        mainWeight = mainWeight,
        offWeight = offWeight,
    }
end

local function BuildCurrentSnapshot()
    local snapshot = {}
    local total = 0
    local weaponState = GetWeaponState()

    for _, slotKey in ipairs(SLOT_ORDER) do
        local slotInfo = SLOT_INFO[slotKey]
        local itemLevel, link, _, icon = GetSlotItemInfo(slotInfo.slotId)
        local weight = 1
        local contribution = itemLevel

        if slotKey == "MAINHAND" then
            itemLevel = weaponState.mainLevel
            icon = weaponState.mainIcon
            weight = weaponState.mainWeight
            contribution = itemLevel * weight
        elseif slotKey == "OFFHAND" then
            itemLevel = weaponState.offLevel
            icon = weaponState.offIcon
            weight = weaponState.offWeight
            contribution = itemLevel * weight
        end

        snapshot[slotKey] = {
            slotKey = slotKey,
            slotName = slotInfo.name,
            itemName = link and (GetItemInfo(link) or "读取中...") or "未装备",
            itemLevel = itemLevel,
            link = link,
            icon = icon,
            weight = weight,
            contribution = contribution,
        }

        total = total + contribution
    end

    return snapshot, total, weaponState
end

local function GetProjectedSummary(snapshot, total)
    local config = GetConfig()
    config.customTargets = config.customTargets or {}

    local projectedTotal = total
    for slotKey, info in pairs(snapshot) do
        local target = tonumber(config.customTargets[slotKey])
        if target and target > 0 then
            projectedTotal = projectedTotal - info.contribution + target * (info.weight or 1)
        end
    end

    local currentAverage = GetCurrentAverageItemLevel()
    local delta = (projectedTotal - total) / 16
    return {
        currentAverage = currentAverage,
        projectedAverage = currentAverage + delta,
        delta = delta,
    }
end

function ItemLevelPlanner:RefreshEquipmentSnapshot()
    local snapshot, total = BuildCurrentSnapshot()
    self.snapshot = snapshot
    self.currentTotal = total
end

function ItemLevelPlanner:ComputeItemPreview(itemLink)
    if not itemLink then
        return nil
    end

    local itemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    elseif GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(itemLink)
    end

    itemLevel = tonumber(itemLevel)
    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    local _, _, _, equipLoc = GetItemInfoInstant(itemLink)
    local slotKeys = EQUIP_LOC_TO_SLOT_KEYS[equipLoc]
    if type(slotKeys) ~= "table" then
        return nil
    end

    local snapshot, _, weaponState = BuildCurrentSnapshot()
    local bestResult

    for _, slotKey in ipairs(slotKeys) do
        local info = snapshot[slotKey]
        if info then
            local weight = info.weight or 1
            if slotKey ~= "OFFHAND" or weaponState.offWeight > 0 then
                local delta = (itemLevel * weight - info.contribution) / 16
                local result = {
                    slotName = info.slotName,
                    currentSlotLevel = info.itemLevel or 0,
                    targetItemLevel = itemLevel,
                    projectedAverage = GetCurrentAverageItemLevel() + delta,
                    delta = delta,
                }
                if not bestResult or result.delta > bestResult.delta then
                    bestResult = result
                end
            end
        end
    end

    return bestResult
end

function ItemLevelPlanner:RefreshSummary()
    if not self.frame then
        return
    end

    if not self.snapshot or not self.currentTotal then
        self:RefreshEquipmentSnapshot()
    end

    local summary = GetProjectedSummary(self.snapshot, self.currentTotal)
    local decimals = ClampNumber(GetConfig().decimalPlaces or 1, 0, 2)

    self.frame.currentValue:SetText(FormatNumber(summary.currentAverage, decimals))
    self.frame.projectedValue:SetText(FormatNumber(summary.projectedAverage, decimals))

    local prefix = summary.delta >= 0 and "+" or ""
    self.frame.deltaValue:SetText(prefix .. FormatNumber(summary.delta, decimals))
    if summary.delta >= 0 then
        self.frame.deltaValue:SetTextColor(0.25, 1.00, 0.50, 1)
    else
        self.frame.deltaValue:SetTextColor(1.00, 0.35, 0.35, 1)
    end
end

function ItemLevelPlanner:RefreshRows()
    if not self.frame then
        return
    end

    if not self.snapshot then
        self:RefreshEquipmentSnapshot()
    end

    local config = GetConfig()
    config.customTargets = config.customTargets or {}
    local snapshot = self.snapshot or {}
    local fontSize = ClampNumber(config.fontSize or 13, 10, 18)

    for index, slotKey in ipairs(SLOT_ORDER) do
        local row = self.frame.rows[index]
        local info = snapshot[slotKey]
        local target = tonumber(config.customTargets[slotKey])

        ApplyConfiguredFont(row.slotText, fontSize, "")
        ApplyConfiguredFont(row.trackText, fontSize - 2, "OUTLINE")
        ApplyConfiguredFont(row.currentText, fontSize, "")
        ApplyConfiguredFont(row.editBox, fontSize, "OUTLINE")
        if row.maxButton and row.maxButton.text then
            ApplyConfiguredFont(row.maxButton.text, fontSize - 2, "OUTLINE")
        end

        row.slotKey = slotKey
        row.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.slotText:SetText(string.format("%s -> %s", (info and info.slotName) or slotKey, TruncateText((info and info.itemName) or "未装备", 24)))
        row.currentText:SetText(string.format("%d", info and (info.itemLevel or 0) or 0))

        local track = info and GetItemUpgradeTrackInfo(info.link)
        if track and track.name then
            row.trackText:SetText(string.format("%s %d/%d", track.name, track.currentRank or 0, track.maxRank or 0))
            if track.color then
                row.trackText:SetTextColor(track.color.r, track.color.g, track.color.b, 1)
            else
                row.trackText:SetTextColor(1.00, 0.82, 0.20, 1)
            end
        else
            row.trackText:SetText("")
        end

        if target and target > 0 then
            row.editBox:SetText(tostring(math.floor(target + 0.5)))
            row.editBox:SetTextColor(0.35, 1.00, 0.72)
            row.clearButton:Show()
        else
            row.editBox:SetText(info and tostring(info.itemLevel or 0) or "0")
            row.editBox:SetTextColor(1, 1, 1)
            row.clearButton:Hide()
        end

        if row.maxButton then
            local maxLevel = info and GetItemMaxUpgradeLevel(info.link)
            local canUpgrade = maxLevel and info and (info.itemLevel or 0) < maxLevel
            row.maxButton:SetEnabled(canUpgrade and true or false)
            if canUpgrade then
                row.maxButton.text:SetTextColor(1.00, 0.82, 0.20, 1)
            else
                row.maxButton.text:SetTextColor(0.38, 0.40, 0.45, 1)
            end
        end
    end
end

function ItemLevelPlanner:RefreshPanel(rebuildSnapshot)
    if not self.frame then
        return
    end

    if rebuildSnapshot ~= false then
        self:RefreshEquipmentSnapshot()
    end

    local config = GetConfig()
    local fontSize = ClampNumber(config.fontSize or 13, 10, 18)

    ApplyConfiguredFont(self.frame.titleText, fontSize + 3, "OUTLINE")
    ApplyConfiguredFont(self.frame.currentLabel, fontSize - 1, "")
    ApplyConfiguredFont(self.frame.currentValue, fontSize + 7, "OUTLINE")
    ApplyConfiguredFont(self.frame.projectedLabel, fontSize - 1, "")
    ApplyConfiguredFont(self.frame.projectedValue, fontSize + 7, "OUTLINE")
    ApplyConfiguredFont(self.frame.deltaLabel, fontSize - 1, "")
    ApplyConfiguredFont(self.frame.deltaValue, fontSize + 2, "OUTLINE")
    ApplyConfiguredFont(self.frame.clearButton.text, fontSize - 1, "OUTLINE")
    ApplyConfiguredFont(self.frame.hintText, fontSize - 2, "")
    ApplyConfiguredFont(self.frame.columnCurrent, fontSize - 2, "")
    ApplyConfiguredFont(self.frame.columnTarget, fontSize - 2, "")

    self.frame:Raise()

    self:RefreshSummary()
    self:RefreshRows()
end

function ItemLevelPlanner:SavePosition()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    local config = GetConfig()
    config.point = config.point or {}
    config.point.point = point or "CENTER"
    config.point.relativePoint = relativePoint or "CENTER"
    config.point.x = math.floor((x or 0) + 0.5)
    config.point.y = math.floor((y or 0) + 0.5)
end

function ItemLevelPlanner:SetOverride(slotKey, value)
    local config = GetConfig()
    config.customTargets = config.customTargets or {}

    local number = tonumber(value)
    local currentLevel = self.snapshot and self.snapshot[slotKey] and self.snapshot[slotKey].itemLevel or 0
    if not number or number <= 0 or number == currentLevel then
        config.customTargets[slotKey] = nil
    else
        config.customTargets[slotKey] = ClampNumber(number, 1, 9999)
    end

    self:RefreshSummary()
    self:RefreshRows()
    if self.frame then
        self.frame:Raise()
    end
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function ItemLevelPlanner:SetOverrideToMax(slotKey)
    if not self.snapshot then
        self:RefreshEquipmentSnapshot()
    end

    local info = self.snapshot and self.snapshot[slotKey]
    local target = info and GetItemMaxUpgradeLevel(info.link)
    if target then
        self:SetOverride(slotKey, target)
    end
end

function ItemLevelPlanner:ClearAllOverrides()
    GetConfig().customTargets = {}
    self:RefreshSummary()
    self:RefreshRows()
    if self.frame then
        self.frame:Raise()
    end
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function ItemLevelPlanner:CreatePanel()
    if self.frame or not CharacterFrame then
        return
    end

    local frame = CreateFrame("Frame", addonName .. "ItemLevelPlannerFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(PANEL_WIDTH)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel((CharacterFrame:GetFrameLevel() or 1) + 18)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.04, 0.06, 0.09, 0.96)
    frame:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.60)
    local point = EnsurePanelPoint()
    frame:SetPoint(point.point or "CENTER", UIParent, point.relativePoint or "CENTER", point.x or 0, point.y or 0)

    frame:SetScript("OnDragStart", function(selfFrame)
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        ItemLevelPlanner:SavePosition()
    end)

    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    frame.titleText:SetText("装等预估")

    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetSize(22, 22)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    frame.closeButton:SetScript("OnClick", function()
        ItemLevelPlanner:TogglePanel(false)
    end)

    frame.clearButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.clearButton:SetSize(56, 20)
    frame.clearButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -4, 0)
    frame.clearButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame.clearButton:SetBackdropColor(0.10, 0.14, 0.20, 1)
    frame.clearButton:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.50)
    frame.clearButton.text = frame.clearButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.clearButton.text:SetPoint("CENTER")
    frame.clearButton.text:SetText("清空")
    frame.clearButton:SetScript("OnClick", function()
        ItemLevelPlanner:ClearAllOverrides()
    end)

    frame.summaryPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.summaryPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -36)
    frame.summaryPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -36)
    frame.summaryPanel:SetHeight(HEADER_HEIGHT)
    frame.summaryPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame.summaryPanel:SetBackdropColor(0.08, 0.11, 0.16, 0.98)
    frame.summaryPanel:SetBackdropBorderColor(0.10, 0.20, 0.32, 1)

    frame.currentLabel = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.currentLabel:SetPoint("TOPLEFT", frame.summaryPanel, "TOPLEFT", 16, -14)
    frame.currentLabel:SetText("当前平均装等")

    frame.currentValue = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.currentValue:SetPoint("TOPLEFT", frame.currentLabel, "BOTTOMLEFT", 0, -2)
    frame.currentValue:SetTextColor(1.00, 0.82, 0.20, 1)

    frame.projectedLabel = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.projectedLabel:SetPoint("TOPLEFT", frame.summaryPanel, "TOPLEFT", 162, -14)
    frame.projectedLabel:SetText("预估平均装等")

    frame.projectedValue = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.projectedValue:SetPoint("TOPLEFT", frame.projectedLabel, "BOTTOMLEFT", 0, -2)
    frame.projectedValue:SetTextColor(0.35, 1.00, 0.72, 1)

    frame.deltaLabel = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.deltaLabel:SetPoint("BOTTOMLEFT", frame.summaryPanel, "BOTTOMLEFT", 16, 14)
    frame.deltaLabel:SetText("整体变化")

    frame.deltaValue = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.deltaValue:SetPoint("LEFT", frame.deltaLabel, "RIGHT", 14, 0)

    frame.hintText = frame.summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.hintText:SetPoint("BOTTOMRIGHT", frame.summaryPanel, "BOTTOMRIGHT", -12, 14)
    frame.hintText:SetText("点右侧数字直接改")
    frame.hintText:SetTextColor(0.70, 0.78, 0.86, 1)

    frame.columnCurrent = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.columnCurrent:SetPoint("TOPRIGHT", frame.summaryPanel, "BOTTOMRIGHT", -112, -12)
    frame.columnCurrent:SetText("当前")
    frame.columnCurrent:SetTextColor(0.70, 0.78, 0.86, 1)

    frame.columnTarget = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.columnTarget:SetPoint("LEFT", frame.columnCurrent, "RIGHT", 56, 0)
    frame.columnTarget:SetText("预估")
    frame.columnTarget:SetTextColor(0.70, 0.78, 0.86, 1)

    frame.rows = {}
    for index, slotKey in ipairs(SLOT_ORDER) do
        local row = CreateFrame("Button", nil, frame, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame.summaryPanel, "BOTTOMLEFT", 0, -26 - (index - 1) * (ROW_HEIGHT + ROW_SPACING))
        row:SetPoint("TOPRIGHT", frame.summaryPanel, "BOTTOMRIGHT", 0, -26 - (index - 1) * (ROW_HEIGHT + ROW_SPACING))
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        row:SetBackdropColor(index % 2 == 0 and 0.065 or 0.08, 0.09, 0.13, 0.98)
        row:SetBackdropBorderColor(0.09, 0.16, 0.24, 1)

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints(row)
        row.highlight:SetColorTexture(0.13, 0.22, 0.34, 0.28)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

        row.slotText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.slotText:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.slotText:SetPoint("RIGHT", row, "RIGHT", -214, 0)
        row.slotText:SetJustifyH("LEFT")

        row.trackText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.trackText:SetWidth(58)
        row.trackText:SetPoint("RIGHT", row, "RIGHT", -150, 0)
        row.trackText:SetJustifyH("RIGHT")

        row.currentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.currentText:SetPoint("RIGHT", row, "RIGHT", -112, 0)
        row.currentText:SetTextColor(0.82, 0.86, 0.92, 1)

        row.editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.editBox:SetSize(60, 18)
        row.editBox:SetPoint("RIGHT", row, "RIGHT", -42, 0)
        row.editBox:SetAutoFocus(false)
        row.editBox:SetNumeric(true)
        row.editBox:SetMaxLetters(4)
        row.editBox:SetJustifyH("CENTER")
        row.editBox:SetScript("OnEnterPressed", function(selfEditBox)
            ItemLevelPlanner:SetOverride(row.slotKey, selfEditBox:GetText())
            selfEditBox:ClearFocus()
        end)
        row.editBox:SetScript("OnEditFocusLost", function(selfEditBox)
            ItemLevelPlanner:SetOverride(row.slotKey, selfEditBox:GetText())
        end)

        row.clearButton = CreateFrame("Button", nil, row)
        row.clearButton:SetSize(14, 14)
        row.clearButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.clearButton.text = row.clearButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.clearButton.text:SetPoint("CENTER")
        row.clearButton.text:SetText("×")
        row.clearButton:SetScript("OnClick", function()
            ItemLevelPlanner:SetOverride(row.slotKey, nil)
        end)

        row.maxButton = CreateFrame("Button", nil, row, "BackdropTemplate")
        row.maxButton:SetSize(16, 16)
        row.maxButton:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        row.maxButton:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        row.maxButton:SetBackdropColor(0.10, 0.14, 0.20, 1)
        row.maxButton:SetBackdropBorderColor(0.95, 0.76, 0.18, 0.60)
        row.maxButton.text = row.maxButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.maxButton.text:SetPoint("CENTER")
        row.maxButton.text:SetText("M")
        row.maxButton:SetScript("OnEnter", function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Max", 1, 0.82, 0.18)
            GameTooltip:AddLine("Set this slot to the maximum item level of its current upgrade track.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row.maxButton:SetScript("OnLeave", GameTooltip_Hide)
        row.maxButton:SetScript("OnClick", function()
            ItemLevelPlanner:SetOverrideToMax(row.slotKey)
        end)

        row:SetScript("OnClick", function()
            row.editBox:SetFocus()
            row.editBox:HighlightText()
        end)

        local function ShowRowItemTooltip(selfRow)
            local slotKeyForTooltip = selfRow.slotKey or row.slotKey
            local slotInfo = SLOT_INFO[slotKeyForTooltip]
            if not slotInfo or not GetInventoryItemLink("player", slotInfo.slotId) then
                return
            end
            GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
            GameTooltip:SetInventoryItem("player", slotInfo.slotId)
            GameTooltip:Show()
        end
        row:SetScript("OnEnter", ShowRowItemTooltip)
        row:SetScript("OnLeave", GameTooltip_Hide)

        frame.rows[index] = row
    end

    local requiredHeight = PANEL_PADDING + HEADER_HEIGHT + 34 + (#SLOT_ORDER * ROW_HEIGHT) + ((#SLOT_ORDER - 1) * ROW_SPACING) + 24
    frame:SetHeight(requiredHeight)

    self.frame = frame
end

function ItemLevelPlanner:RefreshVisibility()
    if self.characterButton then
        self.characterButton:SetShown(GetConfig().enabled and GetConfig().showCharacterButton ~= false)
    end

    if not self.frame then
        return
    end

    local shouldShow = GetConfig().enabled
        and GetConfig().windowShown
        and CharacterFrame
        and CharacterFrame:IsShown()

    self.frame:SetShown(shouldShow and true or false)
    if shouldShow then
        self.frame:Raise()
    end
end

function ItemLevelPlanner:TogglePanel(forceShown)
    local config = GetConfig()
    if not config.enabled then
        config.windowShown = false
        self:RefreshVisibility()
        return
    end

    if forceShown == nil then
        config.windowShown = not config.windowShown
    else
        config.windowShown = forceShown and true or false
    end

    if config.windowShown then
        self:CreatePanel()
        self:RefreshPanel()
        if not (CharacterFrame and CharacterFrame:IsShown()) and Core and Core.Print then
            Core:Print("装等预估已准备好，打开角色面板后会自动显示。")
        end
    end

    self:RefreshVisibility()
end

function ItemLevelPlanner:CreateCharacterButton()
    if self.characterButton or not CharacterFrame then
        return
    end

    local button = CreateFrame("Button", addonName .. "ItemLevelPlannerButton", CharacterFrame, "BackdropTemplate")
    button:SetSize(58, 20)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel((CharacterFrame:GetFrameLevel() or 1) + 15)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.05, 0.08, 0.12, 0.88)
    button:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.55)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetText("预估")

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:AddLine("装等预估", 1, 0.82, 0.18)
        GameTooltip:AddLine("打开角色面板左侧的装等试算面板。", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function()
        ItemLevelPlanner:TogglePanel()
    end)

    self.characterButton = button
    self:ApplyCharacterButtonPosition()
end

function ItemLevelPlanner:ApplyCharacterButtonPosition()
    if not (self.characterButton and CharacterFrame) then
        return
    end

    local offsetX, offsetY = GetCharacterButtonOffsets()
    self.characterButton:ClearAllPoints()
    self.characterButton:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", offsetX, offsetY)
end

function ItemLevelPlanner:EnsureCharacterHooks()
    if self.characterHooked or not CharacterFrame then
        return
    end

    self.characterHooked = true
    self:CreateCharacterButton()

    CharacterFrame:HookScript("OnShow", function()
        ItemLevelPlanner:CreatePanel()
        ItemLevelPlanner:RefreshPanel()
        ItemLevelPlanner:RefreshVisibility()
    end)

    CharacterFrame:HookScript("OnHide", function()
        ItemLevelPlanner:RefreshVisibility()
    end)
end

function ItemLevelPlanner:AppendTooltipPreview(tooltip)
    local config = GetConfig()
    if not (config.enabled and config.showTooltipPreview) then
        return
    end

    if not tooltip or not tooltip.GetItem then
        return
    end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then
        return
    end

    local result = self:ComputeItemPreview(itemLink)
    if not result then
        return
    end

    local decimals = ClampNumber(config.decimalPlaces or 1, 0, 2)
    local deltaPrefix = result.delta >= 0 and "+" or ""

    tooltip:AddLine(" ")
    tooltip:AddLine("装等预估", 0.35, 1.00, 0.72)
    tooltip:AddLine(
        string.format(
            "替换%s %d -> %d，整体 %s (%s%s)",
            result.slotName or "该槽位",
            result.currentSlotLevel or 0,
            result.targetItemLevel or 0,
            FormatNumber(result.projectedAverage or 0, decimals),
            deltaPrefix,
            FormatNumber(result.delta or 0, decimals)
        ),
        0.90,
        0.96,
        1.00
    )
    tooltip:Show()
end

function ItemLevelPlanner:ApplyTooltipHook()
    if self.tooltipHooked then
        return
    end

    self.tooltipHooked = true

    local tooltipDataProcessor = _G.TooltipDataProcessor
    if tooltipDataProcessor and Enum and Enum.TooltipDataType and tooltipDataProcessor.AddTooltipPostCall then
        tooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            ItemLevelPlanner:AppendTooltipPreview(tooltip)
        end)
        return
    end

    if GameTooltip and GameTooltip.HookScript and GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            ItemLevelPlanner:AppendTooltipPreview(tooltip)
        end)
    end
end

function ItemLevelPlanner:RefreshFromSettings()
    local config = GetConfig()
    config.customTargets = config.customTargets or {}
    local point = EnsurePanelPoint()

    self:EnsureCharacterHooks()
    if config.windowShown then
        self:CreatePanel()
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point.point or "CENTER", UIParent, point.relativePoint or "CENTER", point.x or 0, point.y or 0)
        self:RefreshPanel()
    end

    if self.characterButton then
        ApplyConfiguredFont(self.characterButton.text, ClampNumber(config.fontSize or 13, 10, 18) - 1, "OUTLINE")
        self:ApplyCharacterButtonPosition()
    end

    self:RefreshVisibility()
end

function ItemLevelPlanner:HandleEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonLoaded = ...
        if addonLoaded == "Blizzard_CharacterUI" or addonLoaded == "Blizzard_UIPanels" then
            self:EnsureCharacterHooks()
            self:RefreshFromSettings()
        end
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" and ... ~= "player" then
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "UNIT_INVENTORY_CHANGED"
        or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE"
        or event == "PLAYER_ENTERING_WORLD" then
        if self.frame and self.frame:IsShown() then
            self:RefreshPanel()
        end
    end
end

function ItemLevelPlanner:OnPlayerLogin()
    self.eventFrame = self.eventFrame or CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        ItemLevelPlanner:HandleEvent(event, ...)
    end)

    self:ApplyTooltipHook()
    self:RefreshFromSettings()
end
