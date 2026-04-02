local _, NS = ...
local Core = NS.Core

local SpecTalentBar = {}
NS.Modules.InterfaceEnhance.SpecTalentBar = SpecTalentBar

local PADDING_X = 10
local PADDING_Y = 8
local ICON_SIZE = 16
local TALENT_NAME_MAX_CHARS = 10
local FLASH_INTERVAL = 0.5

local DURABILITY_SLOTS = {
    [1] = "头部",
    [3] = "肩部",
    [5] = "胸部",
    [6] = "腰部",
    [7] = "腿部",
    [8] = "脚部",
    [9] = "手腕",
    [10] = "手部",
    [16] = "主手",
    [17] = "副手",
}

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "specTalentBar")
end

local function ApplyFont(fontString, size, outline, preset)
    if not fontString then
        return
    end

    local optionsPrivate = NS.Options and NS.Options.Private
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, outline or "OUTLINE", preset or GetConfig().fontPreset)
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, outline or "OUTLINE")
end

local function Clamp(value, minValue, maxValue)
    local number = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, number))
end

local function Round(value)
    local number = tonumber(value) or 0
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function RGBToHex(color)
    local r = math.floor(Clamp((color and color.r) or 1, 0, 1) * 255 + 0.5)
    local g = math.floor(Clamp((color and color.g) or 1, 0, 1) * 255 + 0.5)
    local b = math.floor(Clamp((color and color.b) or 1, 0, 1) * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
end

local function Utf8Truncate(text, maxChars)
    if type(text) ~= "string" or text == "" or not maxChars or maxChars < 1 then
        return text or ""
    end

    local count = 0
    local lastByte = 0
    for startPos, codepoint in text:gmatch("()([%z\1-\127\194-\244][\128-\191]*)") do
        count = count + 1
        lastByte = startPos + #codepoint - 1
        if count >= maxChars then
            if lastByte < #text then
                return text:sub(1, lastByte) .. "..."
            end
            return text
        end
    end

    return text
end

local function GetCenterOffset(frame)
    local scale = frame:GetScale()
    if not scale or scale == 0 then
        return 0, 0
    end

    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then
        return 0, 0
    end

    left, right, top, bottom = left * scale, right * scale, top * scale, bottom * scale
    local parentWidth, parentHeight = UIParent:GetSize()
    return ((left + right) * 0.5 - parentWidth * 0.5) / scale, ((bottom + top) * 0.5 - parentHeight * 0.5) / scale
end

local function SetButtonBackground(button, alpha)
    if button and button.bg then
        button.bg:SetColorTexture(0, 0, 0, alpha or 0)
    end
end

function SpecTalentBar:GetSpecializationEntries()
    local entries = {}
    local currentIndex = GetSpecialization and GetSpecialization()
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0

    for specIndex = 1, numSpecs do
        local specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
        entries[#entries + 1] = {
            index = specIndex,
            id = specID,
            name = specName or ("专精" .. tostring(specIndex)),
            icon = specIcon,
            active = specIndex == currentIndex,
        }
    end

    return entries
end

function SpecTalentBar:GetCurrentSpecializationName()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then
        return "未激活专精", nil
    end

    local _, specName, _, specIcon = GetSpecializationInfo(specIndex)
    return specName or "未激活专精", specIcon
end

function SpecTalentBar:GetTalentLoadoutState()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then
        return { activeConfigID = nil, selectedConfigID = nil, displayConfigID = nil }
    end

    local specID = GetSpecializationInfo(specIndex)
    local activeConfigID
    local selectedConfigID
    local savedConfigIDs = {}

    if specID and C_ClassTalents and type(C_ClassTalents.GetConfigIDsBySpecID) == "function" then
        for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
            savedConfigIDs[configID] = true
        end
    end

    if C_ClassTalents and type(C_ClassTalents.GetActiveConfigID) == "function" then
        activeConfigID = C_ClassTalents.GetActiveConfigID()
        if activeConfigID and not savedConfigIDs[activeConfigID] then
            activeConfigID = nil
        end
    end

    if specID and C_ClassTalents and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" then
        selectedConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if selectedConfigID and not savedConfigIDs[selectedConfigID] then
            selectedConfigID = nil
        end
    end

    local displayConfigID = selectedConfigID or activeConfigID
    if not displayConfigID then
        for configID in pairs(savedConfigIDs) do
            displayConfigID = configID
            break
        end
    end

    return {
        activeConfigID = activeConfigID,
        selectedConfigID = selectedConfigID,
        displayConfigID = displayConfigID,
    }
end

function SpecTalentBar:GetTalentLoadouts()
    local entries = {}
    local specIndex = GetSpecialization and GetSpecialization()
    if not (specIndex and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID) then
        return entries
    end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then
        return entries
    end

    local state = self:GetTalentLoadoutState()
    for _, configID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
        local name = "方案" .. tostring(configID)
        if C_Traits and C_Traits.GetConfigInfo then
            local info = C_Traits.GetConfigInfo(configID)
            if info and info.name and info.name ~= "" then
                name = info.name
            end
        end

        entries[#entries + 1] = {
            id = configID,
            name = name,
            active = configID == state.displayConfigID,
        }
    end

    return entries
end

function SpecTalentBar:GetCurrentTalentLoadoutName()
    local state = self:GetTalentLoadoutState()

    local function GetConfigName(configID)
        if not (configID and C_Traits and C_Traits.GetConfigInfo) then
            return nil
        end
        local info = C_Traits.GetConfigInfo(configID)
        return info and info.name or nil
    end

    return GetConfigName(state.displayConfigID)
        or GetConfigName(state.activeConfigID)
        or GetConfigName(state.selectedConfigID)
        or ((self:GetTalentLoadouts()[1] and self:GetTalentLoadouts()[1].name) or "未命名天赋")
end

function SpecTalentBar:EnsureTalentUILoaded()
    if PlayerSpellsFrame then
        return true
    end

    if PlayerSpellsFrame_LoadUI then
        PlayerSpellsFrame_LoadUI()
    elseif C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ClassTalentUI")
    end

    return PlayerSpellsFrame ~= nil
end

function SpecTalentBar:ApplyTalentLoadout(configID)
    if not configID then
        return false
    end

    self:EnsureTalentUILoaded()

    if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame and PlayerSpellsFrame.TalentsFrame.LoadConfigByPredicate then
        PlayerSpellsFrame.TalentsFrame:LoadConfigByPredicate(function(_, candidateID)
            return candidateID == configID
        end)
        return true
    end

    if C_ClassTalents and type(C_ClassTalents.LoadConfig) == "function" then
        local result = C_ClassTalents.LoadConfig(configID, true)
        local errorResult = Enum and Enum.LoadConfigResult and Enum.LoadConfigResult.Error or nil
        return result ~= errorResult
    end

    return false
end

function SpecTalentBar:SwitchSpecialization(specIndex)
    if InCombatLockdown and InCombatLockdown() then
        Core:Print("战斗中无法切换专精")
        return
    end

    local setSpec = (C_SpecializationInfo and C_SpecializationInfo.SetSpecialization) or SetSpecialization
    if not (setSpec and specIndex) then
        return
    end

    if GetSpecialization and GetSpecialization() == specIndex then
        return
    end

    setSpec(specIndex)
end

function SpecTalentBar:SwitchTalentLoadout(configID)
    if InCombatLockdown and InCombatLockdown() then
        Core:Print("战斗中无法切换天赋方案")
        return
    end

    if not configID then
        return
    end

    self:ApplyTalentLoadout(configID)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() ~= configID then
                SpecTalentBar:ApplyTalentLoadout(configID)
            end
        end)
    end
end

function SpecTalentBar:GetDurabilityEntries()
    local entries = {}
    local totalCurrent, totalMax = 0, 0

    for slotID, slotName in pairs(DURABILITY_SLOTS) do
        local current, maximum = GetInventoryItemDurability(slotID)
        if current and maximum and maximum > 0 then
            totalCurrent = totalCurrent + current
            totalMax = totalMax + maximum

            local percent = (current / maximum) * 100
            local itemLink = GetInventoryItemLink("player", slotID)
            local itemName = slotName
            local itemIcon
            if itemLink then
                local foundName, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemLink)
                itemName = foundName or itemName
                itemIcon = texture
            end
            itemIcon = itemIcon or GetInventoryItemTexture("player", slotID)

            entries[#entries + 1] = {
                itemName = itemName,
                icon = itemIcon,
                percent = percent,
            }
        end
    end

    table.sort(entries, function(a, b)
        return a.percent < b.percent
    end)

    local overall = 100
    if totalMax > 0 then
        overall = math.floor((totalCurrent / totalMax) * 100 + 0.5)
    end
    return overall, entries
end

function SpecTalentBar:OpenCharacterFrame()
    if ToggleCharacter then
        ToggleCharacter("PaperDollFrame")
    end
end

local function GetMenuFrame()
    if SpecTalentBar.menuFrame then
        return SpecTalentBar.menuFrame
    end

    local frame = CreateFrame("Frame", "YuXuanSpecialSpecTalentMenu", UIParent, "UIDropDownMenuTemplate")
    SpecTalentBar.menuFrame = frame
    return frame
end

function SpecTalentBar:ShowMenu(anchor, title, entries, onClick)
    if not (anchor and UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and ToggleDropDownMenu) then
        return
    end

    self._menuTitle = title
    self._menuEntries = entries
    self._menuHandler = onClick

    local menu = GetMenuFrame()
    UIDropDownMenu_Initialize(menu, function(_, level)
        if level ~= 1 then
            return
        end

        local header = UIDropDownMenu_CreateInfo()
        header.isTitle = true
        header.notCheckable = true
        header.text = SpecTalentBar._menuTitle or ""
        UIDropDownMenu_AddButton(header, level)

        for _, entry in ipairs(SpecTalentBar._menuEntries or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.name or ""
            info.checked = entry.active == true
            info.notCheckable = false
            info.icon = entry.icon
            info.func = function()
                if SpecTalentBar._menuHandler then
                    SpecTalentBar._menuHandler(entry)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")

    ToggleDropDownMenu(1, nil, menu, anchor, 0, 2)
end

function SpecTalentBar:SavePosition()
    if not self.frame then
        return
    end

    local offsetX, offsetY = GetCenterOffset(self.frame)
    local point = GetConfig().point
    point.point = "CENTER"
    point.relativePoint = "CENTER"
    point.x = Round(offsetX)
    point.y = Round(offsetY)
end

function SpecTalentBar:UpdateLayout()
    local frame = self.frame
    if not frame then
        return
    end

    local config = GetConfig()
    local spacing = Clamp(config.spacing or 18, 1, 300)
    local textColor = config.textColor or { r = 1, g = 1, b = 1, a = 1 }
    local labelHex = RGBToHex(textColor)

    ApplyFont(frame.specButton.text, config.fontSize or 13, "OUTLINE", config.fontPreset)
    ApplyFont(frame.durabilityButton.text, config.fontSize or 13, "OUTLINE", config.fontPreset)

    local specName, specIcon = self:GetCurrentSpecializationName()
    local talentName = Utf8Truncate(self:GetCurrentTalentLoadoutName(), TALENT_NAME_MAX_CHARS)
    frame.specButton.text:SetText(string.format("%s / %s", specName, talentName))
    frame.specButton.text:SetTextColor(textColor.r or 1, textColor.g or 1, textColor.b or 1, 1)

    if specIcon then
        frame.specButton.icon:SetTexture(specIcon)
        frame.specButton.icon:Show()
        frame.specButton.text:ClearAllPoints()
        frame.specButton.text:SetPoint("LEFT", frame.specButton.icon, "RIGHT", 4, 0)
    else
        frame.specButton.icon:Hide()
        frame.specButton.text:ClearAllPoints()
        frame.specButton.text:SetPoint("LEFT", frame.specButton, "LEFT", PADDING_X, 0)
    end

    local durabilityPercent = select(1, self:GetDurabilityEntries())
    local percentColorCode = durabilityPercent > 60 and "|cFF33FF33" or (durabilityPercent > 30 and "|cFFFFDD33" or "|cFFFF3333")
    frame.durabilityButton.text:SetText(string.format("|cFF%s耐久度：|r%s%d%%|r", labelHex, percentColorCode, durabilityPercent))
    frame.durabilityButton.text:SetTextColor(1, 1, 1, 1)

    if durabilityPercent < 60 then
        frame.durabilityButton.text:SetAlpha(frame._flashVisible and 1 or 0.3)
    else
        frame.durabilityButton.text:SetAlpha(1)
        frame._flashVisible = true
        frame._flashElapsed = 0
    end

    local height = math.max(26, math.ceil(frame.specButton.text:GetStringHeight() + PADDING_Y * 2))
    local iconOffset = specIcon and (ICON_SIZE + 4) or 0
    local specWidth = math.max(120, math.ceil(frame.specButton.text:GetStringWidth() + iconOffset + PADDING_X * 2))
    local durabilityWidth = math.max(100, math.ceil(frame.durabilityButton.text:GetStringWidth() + PADDING_X * 2))

    frame.specButton:SetSize(specWidth, height)
    frame.durabilityButton:SetSize(durabilityWidth, height)

    frame.specButton:ClearAllPoints()
    frame.durabilityButton:ClearAllPoints()
    if config.orientation == "VERTICAL" then
        frame.specButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame.durabilityButton:SetPoint("TOPLEFT", frame.specButton, "BOTTOMLEFT", 0, -spacing)
        frame:SetSize(math.max(specWidth, durabilityWidth), height * 2 + spacing)
    else
        frame.specButton:SetPoint("LEFT", frame, "LEFT", 0, 0)
        frame.durabilityButton:SetPoint("LEFT", frame.specButton, "RIGHT", spacing, 0)
        frame:SetSize(specWidth + durabilityWidth + spacing, height)
    end

    frame:SetMovable(config.locked ~= true)
    if config.locked then
        frame.bg:SetColorTexture(0, 0, 0, 0)
        SetButtonBackground(frame.specButton, 0)
        SetButtonBackground(frame.durabilityButton, 0)
    else
        frame.bg:SetColorTexture(0, 0.6, 1, 0.12)
        SetButtonBackground(frame.specButton, 0.28)
        SetButtonBackground(frame.durabilityButton, 0.28)
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        config.point and config.point.point or "CENTER",
        UIParent,
        config.point and config.point.relativePoint or "CENTER",
        Round(config.point and config.point.x or 0),
        Round(config.point and config.point.y or -150)
    )
end

function SpecTalentBar:UpdateVisibility()
    if not self.frame then
        return
    end

    if GetConfig().enabled then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function SpecTalentBar:RefreshFromSettings()
    if not self.frame then
        self:CreateFrame()
    end
    self:UpdateLayout()
    self:UpdateVisibility()
end

function SpecTalentBar:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "YuXuanSpecialSpecTalentBar", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame._flashVisible = true
    frame._flashElapsed = 0

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)

    local function CreateButton(parent, withIcon)
        local button = CreateFrame("Button", nil, parent)
        button:RegisterForClicks("AnyUp")
        button:RegisterForDrag("LeftButton")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints(button)

        if withIcon then
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetSize(ICON_SIZE, ICON_SIZE)
            button.icon:SetPoint("LEFT", button, "LEFT", 4, 0)
        end

        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if withIcon then
            button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
        else
            button.text:SetPoint("CENTER")
        end

        button:SetScript("OnDragStart", function()
            if GetConfig().locked then
                return
            end
            parent:StartMoving()
        end)
        button:SetScript("OnDragStop", function()
            if GetConfig().locked then
                return
            end
            parent:StopMovingOrSizing()
            SpecTalentBar:SavePosition()
        end)

        return button
    end

    frame.specButton = CreateButton(frame, true)
    frame.durabilityButton = CreateButton(frame, false)

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        SpecTalentBar:SavePosition()
    end)

    frame.specButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("专精 / 天赋", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        for _, entry in ipairs(SpecTalentBar:GetSpecializationEntries()) do
            local prefix = entry.active and "|cFF33FF99●|r " or "● "
            local iconText = entry.icon and ("|T" .. entry.icon .. ":16:16:0:0|t ") or ""
            GameTooltip:AddLine(iconText .. prefix .. entry.name, entry.active and 0.2 or 1, 1, entry.active and 0.6 or 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("天赋方案", 1, 0.82, 0)
        local loadouts = SpecTalentBar:GetTalentLoadouts()
        if #loadouts == 0 then
            GameTooltip:AddLine("未读取到方案列表", 0.7, 0.7, 0.7)
        else
            for _, entry in ipairs(loadouts) do
                local prefix = entry.active and "|cFF33FF99●|r " or "● "
                GameTooltip:AddLine(prefix .. entry.name, entry.active and 0.2 or 1, 1, entry.active and 0.6 or 1)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("左键：切换专精", 0.75, 1, 0.75)
        GameTooltip:AddLine("右键：切换天赋方案", 0.75, 1, 0.75)
        GameTooltip:Show()
    end)
    frame.specButton:SetScript("OnLeave", GameTooltip_Hide)
    frame.specButton:SetScript("OnClick", function(button, mouseButton)
        GameTooltip:Hide()
        if mouseButton == "RightButton" then
            local entries = SpecTalentBar:GetTalentLoadouts()
            if #entries == 0 then
                entries = { { name = "当前专精没有可用方案", active = true } }
            end
            SpecTalentBar:ShowMenu(button, "切换天赋方案", entries, function(entry)
                if entry.id then
                    SpecTalentBar:SwitchTalentLoadout(entry.id)
                end
            end)
        else
            SpecTalentBar:ShowMenu(button, "切换专精", SpecTalentBar:GetSpecializationEntries(), function(entry)
                SpecTalentBar:SwitchSpecialization(entry.index)
            end)
        end
    end)

    frame.durabilityButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        local overall, entries = SpecTalentBar:GetDurabilityEntries()
        GameTooltip:AddLine("耐久度", 1, 0.82, 0)
        GameTooltip:AddLine(string.format("当前平均耐久：%d%%", overall), 1, 1, 1)
        GameTooltip:AddLine(" ")
        if #entries == 0 then
            GameTooltip:AddLine("无耐久装备", 0.7, 0.7, 0.7)
        else
            for _, entry in ipairs(entries) do
                local pct = math.floor(entry.percent + 0.5)
                local iconText = entry.icon and ("|T" .. entry.icon .. ":16:16:0:0|t ") or ""
                local r, g, b = 0.6, 1, 0.6
                if pct < 30 then
                    r, g, b = 1, 0.2, 0.2
                elseif pct < 50 then
                    r, g, b = 1, 0.85, 0.2
                elseif pct < 100 then
                    r, g, b = 1, 0.85, 0.4
                end
                GameTooltip:AddLine(string.format("%s%s %d%%", iconText, entry.itemName, pct), r, g, b)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("点击打开角色面板", 0.75, 1, 0.75)
        GameTooltip:Show()
    end)
    frame.durabilityButton:SetScript("OnLeave", GameTooltip_Hide)
    frame.durabilityButton:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            SpecTalentBar:OpenCharacterFrame()
        end
    end)

    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        local durabilityPercent = select(1, SpecTalentBar:GetDurabilityEntries())
        if durabilityPercent >= 60 then
            selfFrame._flashVisible = true
            selfFrame._flashElapsed = 0
            return
        end

        selfFrame._flashElapsed = (selfFrame._flashElapsed or 0) + elapsed
        if selfFrame._flashElapsed >= FLASH_INTERVAL then
            selfFrame._flashElapsed = selfFrame._flashElapsed - FLASH_INTERVAL
            selfFrame._flashVisible = not selfFrame._flashVisible
            SpecTalentBar:UpdateLayout()
        end
    end)

    self.frame = frame
end

function SpecTalentBar:OnPlayerLogin()
    self:CreateFrame()
    self.eventFrame = self.eventFrame or CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_SPECIALIZATION_CHANGED"
            or event == "ACTIVE_TALENT_GROUP_CHANGED"
            or event == "TRAIT_CONFIG_UPDATED"
            or event == "TRAIT_CONFIG_LIST_UPDATED"
            or event == "PLAYER_EQUIPMENT_CHANGED"
            or event == "UPDATE_INVENTORY_DURABILITY"
            or event == "PLAYER_ENTERING_WORLD"
        then
            SpecTalentBar:UpdateLayout()
            SpecTalentBar:UpdateVisibility()
        end
    end)
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
    self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

    self:RefreshFromSettings()
end
