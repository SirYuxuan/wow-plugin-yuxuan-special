local addonName, NS = ...
local Core = NS.Core

local BagItemOverlay = {}
NS.Modules.InterfaceEnhance.BagItemOverlay = BagItemOverlay

local BAG_SCAN_DELAY = 0.05
local BINDING_CACHE_TTL = 1
local BINDING_CACHE_MAX_SIZE = 512
local EQUIP_SLOT_FALLBACK = {
    INVTYPE_HEAD = "Head",
    INVTYPE_NECK = "Neck",
    INVTYPE_SHOULDER = "Shoulder",
    INVTYPE_CHEST = "Chest",
    INVTYPE_ROBE = "Chest",
    INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs",
    INVTYPE_FEET = "Feet",
    INVTYPE_WRIST = "Wrist",
    INVTYPE_HAND = "Hands",
    INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Back",
    INVTYPE_WEAPON = "Weapon",
    INVTYPE_SHIELD = "Off Hand",
    INVTYPE_2HWEAPON = "Two-Hand",
    INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand",
    INVTYPE_HOLDABLE = "Off Hand",
    INVTYPE_RANGED = "Ranged",
    INVTYPE_RANGEDRIGHT = "Ranged",
}
local EQUIPMENT_CLASS_IDS = {
    [LE_ITEM_CLASS_WEAPON or 2] = true,
    [LE_ITEM_CLASS_ARMOR or 4] = true,
}
local NON_EQUIPMENT_INVENTORY_TYPES = {
    INVTYPE_NON_EQUIP = true,
    INVTYPE_BAG = true,
    INVTYPE_QUIVER = true,
}

local scannerName = addonName .. "BagItemOverlayScanner"
local bindingStatusCache = {}
local bindingStatusCacheSize = 0

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "bagItemOverlay")
end

local function AsFrame(value)
    if type(value) ~= "table" then
        return nil
    end
    if type(value.GetObjectType) == "function" then
        return value
    end
    if type(value.region) == "table" and type(value.region.GetObjectType) == "function" then
        return value.region
    end
    return nil
end

local function ClampNumber(value, minValue, maxValue)
    local number = tonumber(value) or minValue
    if maxValue then
        number = math.min(maxValue, number)
    end
    return math.max(minValue, number)
end

local function GetLineConfigValue(config, lineKey, suffix, fallback)
    local value = config[lineKey .. suffix]
    if value == nil then
        value = fallback
    end
    return value
end

local function ApplyConfiguredFont(fontString, size, outline, fontPreset)
    if not fontString then
        return
    end

    local config = GetConfig()
    local optionsPrivate = NS.Options and NS.Options.Private
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or (config.fontSize or 11), outline or "OUTLINE", fontPreset or config.fontPreset or "CHAT")
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or (config.fontSize or 11), outline or "OUTLINE")
end

local function GetContainerItemLink(bagID, slotID)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagID, slotID)
    end
    if _G.GetContainerItemLink then
        return _G.GetContainerItemLink(bagID, slotID)
    end
end

local function GetItemLevel(itemLink)
    if not itemLink then
        return nil
    end

    local itemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    elseif GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(itemLink)
    end
    return tonumber(itemLevel)
end

local function GetItemQualityColorRGBA(itemLink)
    local quality
    if C_Item and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(itemLink)
    end
    if not quality and GetItemInfo then
        quality = select(3, GetItemInfo(itemLink))
    end

    if quality and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        return r or 1, g or 1, b or 1, 1
    end

    return 1, 1, 1, 1
end

local function ApplyTextColor(fontString, itemLink, lineKey)
    if not fontString then
        return
    end

    local config = GetConfig()
    local colorMode = GetLineConfigValue(config, lineKey or "", "ColorMode", config.colorMode or "FIXED")
    if colorMode == "ITEM_LEVEL" then
        fontString:SetTextColor(GetItemQualityColorRGBA(itemLink))
        return
    end

    local color = GetLineConfigValue(config, lineKey or "", "FixedColor", config.fixedColor or {}) or {}
    fontString:SetTextColor(color.r or 1, color.g or 0.82, color.b or 0.20, color.a or 1)
end

local function IsEquippableItem(itemLink)
    if not itemLink or not GetItemInfoInstant then
        return false
    end

    local _, _, _, equipLoc, _, classID = GetItemInfoInstant(itemLink)
    if (type(equipLoc) ~= "string" or equipLoc == "") and GetItemInfo then
        equipLoc = select(9, GetItemInfo(itemLink))
    end
    if type(equipLoc) ~= "string" or equipLoc == "" or NON_EQUIPMENT_INVENTORY_TYPES[equipLoc] then
        return false
    end

    return classID == nil or EQUIPMENT_CLASS_IDS[classID] == true
end

local function GetEquipSlotText(itemLink)
    if not itemLink then
        return nil
    end

    local _, _, _, equipLoc = GetItemInfoInstant and GetItemInfoInstant(itemLink)
    if (type(equipLoc) ~= "string" or equipLoc == "") and GetItemInfo then
        equipLoc = select(9, GetItemInfo(itemLink))
    end

    if type(equipLoc) ~= "string" or equipLoc == "" or NON_EQUIPMENT_INVENTORY_TYPES[equipLoc] then
        return nil
    end

    return _G[equipLoc] or EQUIP_SLOT_FALLBACK[equipLoc] or equipLoc:gsub("^INVTYPE_", "")
end

local function GetScannerTooltip()
    if BagItemOverlay.scannerTooltip then
        return BagItemOverlay.scannerTooltip
    end

    local tooltip = CreateFrame("GameTooltip", scannerName, UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    BagItemOverlay.scannerTooltip = tooltip
    return tooltip
end

local function GetBindingStatusText(itemLink)
    if not itemLink then
        return nil
    end

    local tooltip = GetScannerTooltip()
    tooltip:ClearLines()
    local ok = pcall(tooltip.SetHyperlink, tooltip, itemLink)
    if not ok then
        return nil
    end

    local hasWarbound
    for index = 2, tooltip:NumLines() do
        local left = _G[scannerName .. "TextLeft" .. tostring(index)]
        local text = left and left:GetText()
        if type(text) == "string" then
            local lowerText = text:lower()
            local hasWarbandText = text:find("战团", 1, true)
                or lowerText:find("warbound", 1, true)
                or lowerText:find("warband", 1, true)
            if hasWarbandText and (text:find("装备", 1, true) or lowerText:find("until equipped", 1, true)) then
                return "装战绑"
            end
            if text:find("装备后绑定", 1, true)
                or lowerText:find("binds when equipped", 1, true) then
                return "装绑"
            end
            if hasWarbandText then
                hasWarbound = true
            end
        end
    end

    return hasWarbound and "战团" or nil
end

local function GetShortBindingStatusText(itemLink)
    if not itemLink then
        return nil
    end

    local tooltip = GetScannerTooltip()
    tooltip:ClearLines()
    local ok = pcall(tooltip.SetHyperlink, tooltip, itemLink)
    if not ok then
        return nil
    end

    local hasWarbound
    for index = 2, tooltip:NumLines() do
        local left = _G[scannerName .. "TextLeft" .. tostring(index)]
        local text = left and left:GetText()
        if type(text) == "string" then
            local lowerText = text:lower()
            local hasWarbandText = lowerText:find("warbound", 1, true)
                or lowerText:find("warband", 1, true)
                or text:find("战团", 1, true)
            if hasWarbandText and (lowerText:find("until equipped", 1, true) or text:find("装备", 1, true)) then
                return "战绑"
            end
            if lowerText:find("binds when equipped", 1, true) or text:find("装备后绑定", 1, true) then
                return "装绑"
            end
            if hasWarbandText then
                hasWarbound = true
            end
        end
    end

    return hasWarbound and "战团" or nil
end

local function GetCachedBindingStatusText(itemLink)
    if not itemLink then
        return nil
    end

    local now = GetTime and GetTime() or 0
    local cached = bindingStatusCache[itemLink]
    if cached and (now - cached.time) < BINDING_CACHE_TTL then
        return cached.value
    end

    local value = GetShortBindingStatusText(itemLink)
    if cached == nil then
        bindingStatusCacheSize = bindingStatusCacheSize + 1
        if bindingStatusCacheSize > BINDING_CACHE_MAX_SIZE then
            bindingStatusCache = {}
            bindingStatusCacheSize = 1
        end
    end

    bindingStatusCache[itemLink] = {
        time = now,
        value = value,
    }
    return value
end

local function EnsureButtonOverlay(button)
    if not button or type(button.CreateFontString) ~= "function" then
        return nil
    end

    if button._yxsBagOverlay then
        return button._yxsBagOverlay
    end

    local overlay = {}
    overlay.topText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if overlay.topText.SetDrawLayer then
        overlay.topText:SetDrawLayer("OVERLAY", 7)
    end
    overlay.topText:SetPoint("TOP", button, "TOP", 0, -1)
    overlay.topText:SetJustifyH("CENTER")

    overlay.middleText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if overlay.middleText.SetDrawLayer then
        overlay.middleText:SetDrawLayer("OVERLAY", 7)
    end
    overlay.middleText:SetPoint("CENTER", button, "CENTER", 0, 0)
    overlay.middleText:SetJustifyH("CENTER")
    overlay.middleText:SetJustifyV("MIDDLE")

    overlay.bottomText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if overlay.bottomText.SetDrawLayer then
        overlay.bottomText:SetDrawLayer("OVERLAY", 7)
    end
    overlay.bottomText:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
    overlay.bottomText:SetJustifyH("CENTER")

    overlay.Show = function(self)
        self.topText:Show()
        self.middleText:Show()
        self.bottomText:Show()
    end
    overlay.Hide = function(self)
        self.topText:Hide()
        self.middleText:Hide()
        self.bottomText:Hide()
    end
    overlay.SetShown = function(self, shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end

    button._yxsBagOverlay = overlay
    return overlay
end

local function PositionButtonOverlay(button, overlay)
    if not button or not overlay then
        return
    end

    local anchor = button.icon or button.Icon or button
    local config = GetConfig()
    overlay.topText:ClearAllPoints()
    overlay.topText:SetPoint(
        "TOP",
        anchor,
        "TOP",
        ClampNumber(config.topOffsetX or 0, -60, 60),
        ClampNumber(config.topOffsetY or -1, -60, 60)
    )
    overlay.middleText:ClearAllPoints()
    overlay.middleText:SetPoint(
        "CENTER",
        anchor,
        "CENTER",
        ClampNumber(config.middleOffsetX or 0, -60, 60),
        ClampNumber(config.middleOffsetY or 0, -60, 60)
    )
    overlay.bottomText:ClearAllPoints()
    overlay.bottomText:SetPoint(
        "BOTTOM",
        anchor,
        "BOTTOM",
        ClampNumber(config.bottomOffsetX or 0, -60, 60),
        ClampNumber(config.bottomOffsetY or 1, -60, 60)
    )
end

local function HideButtonOverlay(button)
    if not button then
        return
    end

    local overlay = button._yxsBagOverlay
    if not overlay then
        return
    end

    if overlay.topText then
        overlay.topText:SetText("")
    end
    if overlay.middleText then
        overlay.middleText:SetText("")
    end
    if overlay.bottomText then
        overlay.bottomText:SetText("")
    end
    overlay:Hide()
end

local function UpdateButtonWithItemLink(button, itemLink)
    if not button then
        return
    end

    local overlay = EnsureButtonOverlay(button)
    if not overlay then
        return
    end
    PositionButtonOverlay(button, overlay)

    local config = GetConfig()
    if not config.enabled or not itemLink then
        overlay.topText:SetText("")
        overlay.middleText:SetText("")
        overlay.bottomText:SetText("")
        overlay:Hide()
        return
    end

    local topFontSize = ClampNumber(GetLineConfigValue(config, "top", "FontSize", config.fontSize or 11), 8, 18)
    local middleFontSize = ClampNumber(GetLineConfigValue(config, "middle", "FontSize", config.fontSize or 11), 8, 18)
    local bottomFontSize = ClampNumber(GetLineConfigValue(config, "bottom", "FontSize", config.fontSize or 11), 8, 18)
    ApplyConfiguredFont(overlay.topText, topFontSize, "OUTLINE", GetLineConfigValue(config, "top", "FontPreset", config.fontPreset or "CHAT"))
    ApplyConfiguredFont(overlay.middleText, middleFontSize, "OUTLINE", GetLineConfigValue(config, "middle", "FontPreset", config.fontPreset or "CHAT"))
    ApplyConfiguredFont(overlay.bottomText, bottomFontSize, "OUTLINE", GetLineConfigValue(config, "bottom", "FontPreset", config.fontPreset or "CHAT"))
    ApplyTextColor(overlay.topText, itemLink, "top")
    ApplyTextColor(overlay.middleText, itemLink, "middle")
    ApplyTextColor(overlay.bottomText, itemLink, "bottom")

    local isEquipment = IsEquippableItem(itemLink)
    local itemLevel = isEquipment and GetItemLevel(itemLink) or nil
    local showBinding = config.showBinding
    if showBinding == nil then
        showBinding = config.showWarbound
    end
    if showBinding == nil then
        showBinding = true
    end

    overlay.topText:SetText(config.showItemLevel ~= false and isEquipment and itemLevel and tostring(itemLevel) or "")
    overlay.middleText:SetText(showBinding and GetCachedBindingStatusText(itemLink) or "")
    overlay.bottomText:SetText(config.showEquipSlot and GetEquipSlotText(itemLink) or "")
    overlay:SetShown(overlay.topText:GetText() ~= "" or overlay.middleText:GetText() ~= "" or overlay.bottomText:GetText() ~= "")
end

local function GetButtonBagAndSlot(button)
    button = AsFrame(button)
    if not button then
        return nil, nil
    end

    if button.GetItemLocation then
        local ok, itemLocation = pcall(button.GetItemLocation, button)
        if ok and itemLocation and itemLocation.GetBagAndSlot then
            local locationOk, bagID, slotID = pcall(itemLocation.GetBagAndSlot, itemLocation)
            if locationOk and bagID and slotID then
                return tonumber(bagID), tonumber(slotID)
            end
        end
    end

    local parent = button.GetParent and button:GetParent()
    local bagID = button.GetBagID and button:GetBagID()
    if not bagID and parent and parent.GetBagID then
        bagID = parent:GetBagID()
    end
    if not bagID and parent and parent.GetID then
        bagID = parent:GetID()
    end

    local slotID = button.GetID and button:GetID()

    if type(button.GetBagID) ~= "function" and button.BagID ~= nil then
        bagID = button.BagID
    end
    if button.bagID ~= nil then
        bagID = button.bagID
    end
    if button.slotID ~= nil then
        slotID = button.slotID
    end

    bagID = tonumber(bagID)
    slotID = tonumber(slotID)
    if not bagID or not slotID or slotID <= 0 then
        return nil, nil
    end
    return bagID, slotID
end

local function UpdateButton(button)
    if not button then
        return
    end

    local config = GetConfig()
    if not config.enabled then
        HideButtonOverlay(button)
        return
    end

    local bagID, slotID = GetButtonBagAndSlot(button)
    local itemLink = bagID and slotID and GetContainerItemLink(bagID, slotID)
    UpdateButtonWithItemLink(button, itemLink)
end

local function GetBaganatorItemLink(button)
    button = AsFrame(button)
    local details = button and button.BGR
    if not details then
        return nil
    end

    if details.itemLink then
        return details.itemLink
    end

    local itemLocation = details.itemLocation
    if itemLocation and itemLocation.bagID and itemLocation.slotIndex then
        return GetContainerItemLink(itemLocation.bagID, itemLocation.slotIndex)
    end
end

local function VisitContainerButtons(root, visited)
    local frame = AsFrame(root)
    if not frame or visited[frame] then
        return
    end
    visited[frame] = true

    if frame.BGR ~= nil then
        BagItemOverlay:UpdateBaganatorButton(frame)
    else
        local bagID, slotID = GetButtonBagAndSlot(frame)
        if bagID and slotID then
            UpdateButton(frame)
        end
    end

    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            VisitContainerButtons(child, visited)
        end
    end
end

function BagItemOverlay:UpdateBaganatorButton(button)
    button = AsFrame(button)
    if not button then
        return
    end

    local itemLink = GetBaganatorItemLink(button)
    UpdateButtonWithItemLink(button, itemLink)

    if button and not button._yxsBagOverlayRefreshPending then
        button._yxsBagOverlayRefreshPending = true
        self._baganatorDirtyButtons = self._baganatorDirtyButtons or {}
        self._baganatorDirtyButtons[button] = true
        if not self._baganatorDirtyPending then
            self._baganatorDirtyPending = true
            C_Timer.After(0, function()
                self._baganatorDirtyPending = false
                local dirtyButtons = self._baganatorDirtyButtons
                if not dirtyButtons then
                    return
                end
                for dirtyButton in pairs(dirtyButtons) do
                    dirtyButton._yxsBagOverlayRefreshPending = nil
                    if dirtyButton.IsShown and dirtyButton:IsShown() then
                        UpdateButtonWithItemLink(dirtyButton, GetBaganatorItemLink(dirtyButton))
                    end
                end
                for dirtyButton in pairs(dirtyButtons) do
                    dirtyButtons[dirtyButton] = nil
                end
            end)
        end
    end
end

function BagItemOverlay:RequestBaganatorRefresh()
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        if Baganator.Constants and Baganator.Constants.RefreshReason then
            Baganator.API.RequestItemButtonsRefresh({ Baganator.Constants.RefreshReason.ItemWidgets })
        else
            Baganator.API.RequestItemButtonsRefresh()
        end
    end
end

function BagItemOverlay:TryHookBaganator()
    if self.baganatorHooksApplied then
        return
    end

    local mixinNames = {
        "BaganatorRetailCachedItemButtonMixin",
        "BaganatorRetailLiveContainerItemButtonMixin",
        "BaganatorClassicLiveContainerItemButtonMixin",
        "BaganatorClassicLiveGuildItemButtonMixin",
    }

    local hooked = false
    for _, mixinName in ipairs(mixinNames) do
        local mixin = _G[mixinName]
        if mixin and type(mixin.SetItemDetails) == "function" then
            hooksecurefunc(mixin, "SetItemDetails", function(button)
                BagItemOverlay:UpdateBaganatorButton(button)
            end)
            hooked = true
        end
    end

    if hooked then
        self.baganatorHooksApplied = true
        self:RequestBaganatorRefresh()
    end
end

function BagItemOverlay:RefreshAll()
    if self.refreshQueued then
        return
    end

    self.refreshQueued = true
    C_Timer.After(BAG_SCAN_DELAY, function()
        self.refreshQueued = false
        local visited = {}

        if _G.ContainerFrameCombinedBags then
            VisitContainerButtons(_G.ContainerFrameCombinedBags, visited)
        end

        for index = 1, 13 do
            local frame = _G["ContainerFrame" .. tostring(index)]
            if frame then
                VisitContainerButtons(frame, visited)
            end
        end

        if Baganator and Baganator.API and Baganator.API.Skins and Baganator.API.Skins.GetAllFrames then
            for _, entry in pairs(Baganator.API.Skins.GetAllFrames()) do
                if entry.regionType == "ItemButton" then
                    VisitContainerButtons(entry.region, visited)
                end
            end
        end

        self:RequestBaganatorRefresh()
    end)
end

function BagItemOverlay:RefreshFromSettings()
    self:RequestBaganatorRefresh()
    self:RefreshAll()
end

function BagItemOverlay:OnPlayerLogin()
    if self.eventFrame then
        self:RefreshFromSettings()
        return
    end

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("BAG_UPDATE")
    self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    self.eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.eventFrame:SetScript("OnEvent", function(_, event, addonLoaded)
        if event == "ADDON_LOADED" then
            if addonLoaded == "Baganator" then
                BagItemOverlay:TryHookBaganator()
            elseif addonLoaded ~= "Blizzard_ContainerUI" then
                return
            end
        end
        BagItemOverlay:RefreshAll()
    end)

    self:TryHookBaganator()

    if not self.containerHooksApplied then
        self.containerHooksApplied = true
        if _G.ContainerFrame_Update then
            hooksecurefunc("ContainerFrame_Update", function()
                BagItemOverlay:RefreshAll()
            end)
        end
        if _G.ContainerFrame_UpdateAll then
            hooksecurefunc("ContainerFrame_UpdateAll", function()
                BagItemOverlay:RefreshAll()
            end)
        end
        if _G.ToggleAllBags then
            hooksecurefunc("ToggleAllBags", function()
                BagItemOverlay:RefreshAll()
            end)
        end
        if _G.OpenAllBags then
            hooksecurefunc("OpenAllBags", function()
                BagItemOverlay:RefreshAll()
            end)
        end
    end

    self:RefreshFromSettings()
end
