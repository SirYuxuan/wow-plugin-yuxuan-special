local addonName, NS = ...
local Core = NS.Core

local ItemLevelPlanner = {}
NS.Modules.InterfaceEnhance.ItemLevelPlanner = ItemLevelPlanner

--[[
装等预估模块负责做三件事：
1. 读取当前已装备平均装等。
2. 选择一个装备槽位并输入目标装等。
3. 计算替换后整体平均装等的变化。

这里优先保证“结果稳定、使用顺手”：
1. 独立预估窗口负责手动模拟。
2. 角色面板按钮负责快速打开。
3. 物品提示里追加一行预估结果，方便平时直接看。
]]

local SLOT_ORDER = {
    "HEAD",
    "NECK",
    "SHOULDER",
    "CHEST",
    "WAIST",
    "LEGS",
    "FEET",
    "WRIST",
    "HANDS",
    "FINGER1",
    "FINGER2",
    "TRINKET1",
    "TRINKET2",
    "BACK",
    "MAINHAND",
    "OFFHAND",
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

local DEFAULT_FRAME_WIDTH = 320
local DEFAULT_FRAME_HEIGHT = 220
local QUICK_STEPS = { 3, 6, 9 }
local TOOLTIP_LINE_COLOR = { 0.35, 1.00, 0.72 }

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "itemLevelPlanner")
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

local function FormatNumber(value, decimals)
    return string.format("%." .. tostring(decimals or 1) .. "f", tonumber(value) or 0)
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
        return 0, nil, nil
    end

    local itemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(link)
    elseif GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(link)
    end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfoInstant(link)
    return tonumber(itemLevel) or 0, link, equipLoc
end

local function GetWeaponState()
    local mainLevel, mainLink, mainEquipLoc = GetSlotItemInfo(16)
    local offLevel, offLink = GetSlotItemInfo(17)
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
        hasOffHand = offLink ~= nil,
        mainWeight = mainWeight,
        offWeight = offWeight,
    }
end

local function GetCurrentWeightedTotal()
    local total = 0
    for _, slotKey in ipairs(SLOT_ORDER) do
        local slotInfo = SLOT_INFO[slotKey]
        if slotInfo.slotId ~= 16 and slotInfo.slotId ~= 17 then
            local itemLevel = GetSlotItemInfo(slotInfo.slotId)
            total = total + itemLevel
        end
    end

    local weaponState = GetWeaponState()
    total = total + weaponState.mainLevel * weaponState.mainWeight
    total = total + weaponState.offLevel * weaponState.offWeight

    return total, weaponState
end

local function GetCurrentSlotContribution(slotKey, weaponState)
    local slotInfo = SLOT_INFO[slotKey]
    if not slotInfo then
        return 0, 0
    end

    if slotInfo.slotId == 16 then
        return weaponState.mainLevel, weaponState.mainLevel * weaponState.mainWeight
    end

    if slotInfo.slotId == 17 then
        return weaponState.offLevel, weaponState.offLevel * weaponState.offWeight
    end

    local itemLevel = GetSlotItemInfo(slotInfo.slotId)
    return itemLevel, itemLevel
end

local function GetSlotIndex(slotKey)
    for index, key in ipairs(SLOT_ORDER) do
        if key == slotKey then
            return index
        end
    end
    return 1
end

local function GetSlotKeyByIndex(index)
    local count = #SLOT_ORDER
    if count == 0 then
        return "HEAD"
    end

    while index < 1 do
        index = index + count
    end

    while index > count do
        index = index - count
    end

    return SLOT_ORDER[index]
end

function ItemLevelPlanner:ComputeProjection(slotKey, targetItemLevel)
    local config = GetConfig()
    local normalizedTarget = ClampNumber(targetItemLevel or config.targetItemLevel or 0, 0, 9999)
    local currentAverage = GetCurrentAverageItemLevel()
    local _, weaponState = GetCurrentWeightedTotal()
    local currentSlotLevel, currentContribution = GetCurrentSlotContribution(slotKey, weaponState)

    local newContribution = normalizedTarget
    if slotKey == "MAINHAND" then
        newContribution = normalizedTarget * weaponState.mainWeight
    elseif slotKey == "OFFHAND" then
        newContribution = normalizedTarget * weaponState.offWeight
    end

    local delta = (newContribution - currentContribution) / 16
    local projectedAverage = currentAverage + delta

    local result = {
        slotKey = slotKey,
        slotName = (SLOT_INFO[slotKey] and SLOT_INFO[slotKey].name) or slotKey,
        currentAverage = currentAverage,
        projectedAverage = projectedAverage,
        delta = delta,
        currentSlotLevel = currentSlotLevel,
        targetItemLevel = normalizedTarget,
        slotContributionWeight = (slotKey == "MAINHAND" and weaponState.mainWeight)
            or (slotKey == "OFFHAND" and weaponState.offWeight)
            or 1,
    }

    if slotKey == "OFFHAND" and weaponState.offWeight == 0 then
        result.note = "当前副手不参与平均装等计算。"
    elseif slotKey == "MAINHAND" and weaponState.mainWeight == 2 then
        result.note = "当前主手按双手武器处理，会按两个武器槽位计算。"
    end

    return result
end

function ItemLevelPlanner:ComputeWeaponPreview(targetItemLevel, equipLoc)
    local currentAverage = GetCurrentAverageItemLevel()
    local _, weaponState = GetCurrentWeightedTotal()
    local currentCombined = weaponState.mainLevel * weaponState.mainWeight + weaponState.offLevel * weaponState.offWeight
    local newCombined
    local slotText
    local note

    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" then
        newCombined = targetItemLevel * 2
        slotText = weaponState.offWeight > 0 and "主手/副手" or "主手"
    elseif equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_SHIELD" then
        if weaponState.mainWeight == 2 and weaponState.offWeight == 0 then
            return nil
        end
        newCombined = weaponState.mainLevel * weaponState.mainWeight + targetItemLevel
        slotText = "副手"
    elseif equipLoc == "INVTYPE_WEAPON" then
        local bestResult

        local mainCombined
        if weaponState.mainWeight == 2 and weaponState.offWeight == 0 then
            mainCombined = targetItemLevel
        else
            mainCombined = targetItemLevel + weaponState.offLevel * weaponState.offWeight
        end

        local mainDelta = (mainCombined - currentCombined) / 16
        bestResult = {
            slotName = "主手",
            projectedAverage = currentAverage + mainDelta,
            delta = mainDelta,
            currentAverage = currentAverage,
            currentSlotLevel = weaponState.mainLevel,
            targetItemLevel = targetItemLevel,
        }

        if weaponState.mainWeight ~= 2 and weaponState.offWeight > 0 then
            local offCombined = weaponState.mainLevel + targetItemLevel
            local offDelta = (offCombined - currentCombined) / 16
            if offDelta > bestResult.delta then
                bestResult = {
                    slotName = "副手",
                    projectedAverage = currentAverage + offDelta,
                    delta = offDelta,
                    currentAverage = currentAverage,
                    currentSlotLevel = weaponState.offLevel,
                    targetItemLevel = targetItemLevel,
                }
            end
        end

        if weaponState.mainWeight == 2 and weaponState.offWeight == 0 then
            bestResult.note = "当前主手为双手武器，单手武器按仅替换主手预估。"
        end

        return bestResult
    else
        newCombined = targetItemLevel * weaponState.mainWeight
        slotText = "主手"
    end

    local delta = (newCombined - currentCombined) / 16
    if equipLoc == "INVTYPE_2HWEAPON" and weaponState.offWeight > 0 then
        note = "双手武器预估会同时替换主手和副手贡献。"
    end

    return {
        slotName = slotText,
        currentAverage = currentAverage,
        projectedAverage = currentAverage + delta,
        delta = delta,
        currentSlotLevel = weaponState.mainLevel,
        targetItemLevel = targetItemLevel,
        note = note,
    }
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

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfoInstant(itemLink)
    if not equipLoc then
        return nil
    end

    if equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_RANGED"
        or equipLoc == "INVTYPE_RANGEDRIGHT"
        or equipLoc == "INVTYPE_WEAPON"
        or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_HOLDABLE"
        or equipLoc == "INVTYPE_SHIELD" then
        return self:ComputeWeaponPreview(itemLevel, equipLoc)
    end

    local slotKeys = EQUIP_LOC_TO_SLOT_KEYS[equipLoc]
    if type(slotKeys) ~= "table" then
        return nil
    end

    local bestResult
    for _, slotKey in ipairs(slotKeys) do
        local result = self:ComputeProjection(slotKey, itemLevel)
        if not bestResult or result.delta > bestResult.delta then
            bestResult = result
        end
    end

    return bestResult
end

function ItemLevelPlanner:UpdateFrameText()
    if not self.frame then
        return
    end

    local config = GetConfig()
    config.selectedSlot = SLOT_INFO[config.selectedSlot] and config.selectedSlot or "HEAD"
    config.targetItemLevel = ClampNumber(config.targetItemLevel or 665, 0, 9999)

    local decimals = ClampNumber(config.decimalPlaces or 1, 0, 2)
    local result = self:ComputeProjection(config.selectedSlot, config.targetItemLevel)
    local slotName = (SLOT_INFO[config.selectedSlot] and SLOT_INFO[config.selectedSlot].name) or "未知槽位"

    self.frame.slotLabel:SetText(slotName)
    self.frame.currentAverageValue:SetText(FormatNumber(result.currentAverage, decimals))
    self.frame.projectedAverageValue:SetText(FormatNumber(result.projectedAverage, decimals))
    self.frame.currentSlotValue:SetText(string.format("%s 当前：%d", slotName, result.currentSlotLevel))
    self.frame.targetEditBox:SetText(tostring(math.floor(result.targetItemLevel + 0.5)))
    self.frame.resultLine:SetText(string.format("%s %d -> %d", slotName, result.currentSlotLevel, result.targetItemLevel))

    local deltaPrefix = result.delta >= 0 and "+" or ""
    self.frame.deltaValue:SetText(deltaPrefix .. FormatNumber(result.delta, decimals))
    if result.delta >= 0 then
        self.frame.deltaValue:SetTextColor(0.25, 1.00, 0.50, 1)
    else
        self.frame.deltaValue:SetTextColor(1.00, 0.35, 0.35, 1)
    end

    if result.note and result.note ~= "" then
        self.frame.noteText:SetText(result.note)
        self.frame.noteText:Show()
    else
        self.frame.noteText:SetText("")
        self.frame.noteText:Hide()
    end
end

function ItemLevelPlanner:SaveFramePosition()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    local config = GetConfig()
    config.point.point = point or "CENTER"
    config.point.relativePoint = relativePoint or "CENTER"
    config.point.x = math.floor((x or 0) + 0.5)
    config.point.y = math.floor((y or 0) + 0.5)
end

function ItemLevelPlanner:ApplyFrameStyle()
    if not self.frame then
        return
    end

    local config = GetConfig()
    local frame = self.frame
    local size = ClampNumber(config.fontSize or 13, 10, 22)

    ApplyConfiguredFont(frame.titleText, size + 2, "OUTLINE")
    ApplyConfiguredFont(frame.currentAverageLabel, size - 1, "")
    ApplyConfiguredFont(frame.currentAverageValue, size + 6, "OUTLINE")
    ApplyConfiguredFont(frame.projectedAverageLabel, size - 1, "")
    ApplyConfiguredFont(frame.projectedAverageValue, size + 6, "OUTLINE")
    ApplyConfiguredFont(frame.slotLabel, size + 1, "OUTLINE")
    ApplyConfiguredFont(frame.currentSlotValue, size, "")
    ApplyConfiguredFont(frame.targetLabel, size, "")
    ApplyConfiguredFont(frame.resultLine, size, "")
    ApplyConfiguredFont(frame.deltaLabel, size, "")
    ApplyConfiguredFont(frame.deltaValue, size + 2, "OUTLINE")
    ApplyConfiguredFont(frame.noteText, size - 1, "")
    ApplyConfiguredFont(frame.closeButton.text, size + 1, "OUTLINE")
    ApplyConfiguredFont(frame.previousSlotButton.text, size + 2, "OUTLINE")
    ApplyConfiguredFont(frame.nextSlotButton.text, size + 2, "OUTLINE")
    ApplyConfiguredFont(frame.targetEditBox.label, size - 1, "")

    for _, quickButton in ipairs(frame.quickButtons or {}) do
        ApplyConfiguredFont(quickButton.text, size - 1, "OUTLINE")
    end

    frame.bg:SetColorTexture(0.04, 0.06, 0.09, 0.92)
    frame.border:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.65)
    frame:SetMovable(not config.locked)

    if self.characterButton then
        ApplyConfiguredFont(self.characterButton.text, size - 2, "OUTLINE")
    end
end

function ItemLevelPlanner:RefreshFrameVisibility()
    if self.frame then
        self.frame:SetShown(GetConfig().enabled and GetConfig().windowShown and true or false)
    end

    if self.characterButton then
        self.characterButton:SetShown(GetConfig().enabled and GetConfig().showCharacterButton ~= false)
    end
end

function ItemLevelPlanner:ToggleFrame(forceShown)
    local config = GetConfig()
    if not config.enabled then
        config.windowShown = false
        self:RefreshFrameVisibility()
        return
    end

    if forceShown == nil then
        config.windowShown = not config.windowShown
    else
        config.windowShown = forceShown and true or false
    end

    if config.windowShown and not self.frame then
        self:CreateFrame()
    end

    self:RefreshFromSettings()
end

function ItemLevelPlanner:ShiftSelectedSlot(delta)
    local config = GetConfig()
    config.selectedSlot = GetSlotKeyByIndex(GetSlotIndex(config.selectedSlot or "HEAD") + delta)
    self:RefreshFromSettings()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function ItemLevelPlanner:SetTargetItemLevel(value)
    local config = GetConfig()
    config.targetItemLevel = ClampNumber(value or config.targetItemLevel or 0, 0, 9999)
    self:RefreshFromSettings()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function ItemLevelPlanner:ApplyQuickStep(step)
    local config = GetConfig()
    local result = self:ComputeProjection(config.selectedSlot or "HEAD", config.targetItemLevel or 0)
    self:SetTargetItemLevel((result.currentSlotLevel or 0) + (tonumber(step) or 0))
end

function ItemLevelPlanner:CreateCharacterButton()
    if self.characterButton or not CharacterFrame then
        return
    end

    local button = CreateFrame("Button", addonName .. "ItemLevelPlannerButton", CharacterFrame, "BackdropTemplate")
    button:SetSize(62, 22)
    button:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -38, -34)
    button:RegisterForClicks("AnyUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.05, 0.08, 0.12, 0.86)
    button:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.65)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText("装等预估")

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:AddLine("装等预估", 1, 0.82, 0.18)
        GameTooltip:AddLine("左键打开或关闭预估窗口。", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function()
        ItemLevelPlanner:ToggleFrame()
    end)

    self.characterButton = button
    self:ApplyFrameStyle()
    self:RefreshFrameVisibility()
end

function ItemLevelPlanner:EnsureCharacterButtonHook()
    if self.characterButtonHooked then
        return
    end

    self.characterButtonHooked = true

    if CharacterFrame and CharacterFrame.HookScript then
        CharacterFrame:HookScript("OnShow", function()
            ItemLevelPlanner:CreateCharacterButton()
            ItemLevelPlanner:RefreshFrameVisibility()
        end)
        CharacterFrame:HookScript("OnHide", function()
            if ItemLevelPlanner.characterButton then
                ItemLevelPlanner.characterButton:Hide()
            end
        end)
    end

    self:CreateCharacterButton()
end

function ItemLevelPlanner:CreateFrame()
    if self.frame then
        return
    end

    local config = GetConfig()
    local frame = CreateFrame("Frame", addonName .. "ItemLevelPlannerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_FRAME_WIDTH, DEFAULT_FRAME_HEIGHT)
    frame:SetFrameStrata("HIGH")
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

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)

    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints(frame)
    frame.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    frame:SetPoint(
        config.point.point or "CENTER",
        UIParent,
        config.point.relativePoint or "CENTER",
        config.point.x or 320,
        config.point.y or 0
    )

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end
        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        ItemLevelPlanner:SaveFramePosition()
    end)

    frame.titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    frame.titleText:SetText("装等预估")

    frame.closeButton = CreateFrame("Button", nil, frame)
    frame.closeButton:SetSize(22, 22)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.closeButton.text = frame.closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.closeButton.text:SetPoint("CENTER")
    frame.closeButton.text:SetText("×")
    frame.closeButton:SetScript("OnClick", function()
        ItemLevelPlanner:ToggleFrame(false)
    end)

    frame.currentAverageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.currentAverageLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -42)
    frame.currentAverageLabel:SetText("当前平均装等")

    frame.currentAverageValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.currentAverageValue:SetPoint("TOPLEFT", frame.currentAverageLabel, "BOTTOMLEFT", 0, -4)
    frame.currentAverageValue:SetTextColor(1.00, 0.82, 0.20, 1)

    frame.projectedAverageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.projectedAverageLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 172, -42)
    frame.projectedAverageLabel:SetText("预估平均装等")

    frame.projectedAverageValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.projectedAverageValue:SetPoint("TOPLEFT", frame.projectedAverageLabel, "BOTTOMLEFT", 0, -4)
    frame.projectedAverageValue:SetTextColor(0.35, 1.00, 0.72, 1)

    frame.slotPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.slotPanel:SetSize(292, 40)
    frame.slotPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -94)
    frame.slotPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame.slotPanel:SetBackdropColor(0.08, 0.11, 0.16, 0.96)
    frame.slotPanel:SetBackdropBorderColor(0.10, 0.20, 0.32, 1)

    local function CreateArrowButton(parent, text)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(28, 28)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.10, 0.14, 0.20, 1)
        button:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.55)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("CENTER")
        button.text:SetText(text)
        return button
    end

    frame.previousSlotButton = CreateArrowButton(frame.slotPanel, "‹")
    frame.previousSlotButton:SetPoint("LEFT", frame.slotPanel, "LEFT", 6, 0)
    frame.previousSlotButton:SetScript("OnClick", function()
        ItemLevelPlanner:ShiftSelectedSlot(-1)
    end)

    frame.nextSlotButton = CreateArrowButton(frame.slotPanel, "›")
    frame.nextSlotButton:SetPoint("RIGHT", frame.slotPanel, "RIGHT", -6, 0)
    frame.nextSlotButton:SetScript("OnClick", function()
        ItemLevelPlanner:ShiftSelectedSlot(1)
    end)

    frame.slotLabel = frame.slotPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.slotLabel:SetPoint("CENTER", frame.slotPanel, "CENTER")

    frame.currentSlotValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.currentSlotValue:SetPoint("TOPLEFT", frame.slotPanel, "BOTTOMLEFT", 0, -8)
    frame.currentSlotValue:SetTextColor(0.82, 0.86, 0.92, 1)

    frame.targetLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.targetLabel:SetPoint("TOPLEFT", frame.currentSlotValue, "BOTTOMLEFT", 0, -14)
    frame.targetLabel:SetText("目标装等")

    frame.targetEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.targetEditBox:SetSize(72, 28)
    frame.targetEditBox:SetPoint("LEFT", frame.targetLabel, "RIGHT", 12, 0)
    frame.targetEditBox:SetAutoFocus(false)
    frame.targetEditBox:SetNumeric(true)
    frame.targetEditBox:SetMaxLetters(4)
    frame.targetEditBox:SetScript("OnEnterPressed", function(selfEditBox)
        ItemLevelPlanner:SetTargetItemLevel(tonumber(selfEditBox:GetText()) or 0)
        selfEditBox:ClearFocus()
    end)
    frame.targetEditBox:SetScript("OnEditFocusLost", function(selfEditBox)
        ItemLevelPlanner:SetTargetItemLevel(tonumber(selfEditBox:GetText()) or 0)
    end)
    frame.targetEditBox.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.targetEditBox.label:SetPoint("BOTTOMLEFT", frame.targetEditBox, "TOPLEFT", 0, 4)
    frame.targetEditBox.label:SetText("输入新装等")

    frame.quickButtons = {}
    for index, step in ipairs(QUICK_STEPS) do
        local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
        button:SetSize(44, 28)
        button:SetPoint("LEFT", frame.targetEditBox, "RIGHT", 10 + (index - 1) * 48, 0)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.10, 0.14, 0.20, 1)
        button:SetBackdropBorderColor(0.12, 0.62, 1.00, 0.55)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("CENTER")
        button.text:SetText("+" .. tostring(step))
        button:SetScript("OnClick", function()
            ItemLevelPlanner:ApplyQuickStep(step)
        end)
        frame.quickButtons[#frame.quickButtons + 1] = button
    end

    frame.resultLine = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.resultLine:SetPoint("TOPLEFT", frame.targetLabel, "BOTTOMLEFT", 0, -20)

    frame.deltaLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.deltaLabel:SetPoint("TOPLEFT", frame.resultLine, "BOTTOMLEFT", 0, -10)
    frame.deltaLabel:SetText("整体变化")

    frame.deltaValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.deltaValue:SetPoint("LEFT", frame.deltaLabel, "RIGHT", 12, 0)

    frame.noteText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.noteText:SetPoint("TOPLEFT", frame.deltaLabel, "BOTTOMLEFT", 0, -12)
    frame.noteText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    frame.noteText:SetJustifyH("LEFT")
    frame.noteText:SetJustifyV("TOP")
    frame.noteText:SetTextColor(0.72, 0.82, 0.92, 1)

    self.frame = frame
    self:ApplyFrameStyle()
    self:UpdateFrameText()
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
    tooltip:AddLine("装等预估", TOOLTIP_LINE_COLOR[1], TOOLTIP_LINE_COLOR[2], TOOLTIP_LINE_COLOR[3])
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

    if result.note and result.note ~= "" then
        tooltip:AddLine(result.note, 0.72, 0.82, 0.92)
    end

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
    config.selectedSlot = SLOT_INFO[config.selectedSlot] and config.selectedSlot or "HEAD"
    config.point = config.point or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 320,
        y = 0,
    }

    self:EnsureCharacterButtonHook()
    if config.windowShown and not self.frame then
        self:CreateFrame()
    end

    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(
            config.point.point or "CENTER",
            UIParent,
            config.point.relativePoint or "CENTER",
            config.point.x or 320,
            config.point.y or 0
        )
        self:ApplyFrameStyle()
        self:UpdateFrameText()
    end

    self:RefreshFrameVisibility()
end

function ItemLevelPlanner:HandleEvent(event, unit)
    if event == "ADDON_LOADED" then
        if unit == "Blizzard_CharacterUI" or unit == "Blizzard_UIPanels" then
            self:EnsureCharacterButtonHook()
            self:RefreshFrameVisibility()
        end
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "UNIT_INVENTORY_CHANGED"
        or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE"
        or event == "PLAYER_ENTERING_WORLD" then
        if self.frame and self.frame:IsShown() then
            self:UpdateFrameText()
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
    self:EnsureCharacterButtonHook()
    self:RefreshFromSettings()
end
