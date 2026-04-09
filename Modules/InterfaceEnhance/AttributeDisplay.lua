local _, NS = ...
local Core = NS.Core

local AttributeDisplay = {}
NS.Modules.InterfaceEnhance.AttributeDisplay = AttributeDisplay

local LibSharedMedia = LibStub("LibSharedMedia-3.0")

local STAT_KEYS = { "ilvl", "primary", "crit", "haste", "mastery", "versa", "leech", "dodge", "parry", "block", "speed" }
local PROGRESS_KEYS = { "ilvl", "primary", "crit", "haste", "mastery", "versa", "speed" }
local PRIMARY_STAT_NAMES = {
    [1] = "力量",
    [2] = "敏捷",
    [4] = "智力",
}
local SECONDARY_STAT_NAMES = {
    crit = "暴击",
    haste = "急速",
    mastery = "精通",
    versa = "全能",
    leech = "吸血",
    dodge = "躲闪",
    parry = "招架",
    block = "格挡",
}
local DRAGON_RIDING_SPELL_IDS = {
    32235, 32239, 32240, 32242, 32289, 32290, 32292, 336036, 340068, 341776,
    342666, 342667, 344574, 346554, 349943, 353263, 353265, 353856, 353875,
    353883, 358319, 359317, 359367, 359380, 359407, 360954, 366790, 366962,
    367, 368896, 368899, 368901, 369536, 397406, 400976, 413827, 41514, 41515,
    41516, 417888, 418286, 420097, 424082, 425338, 427777, 431357, 431359,
    431360, 431992, 432558, 432562, 43927, 44153, 443660, 446017, 446022,
    446052, 447057, 447176, 447185, 447195, 447413, 448188, 448851, 448939,
    451487, 454682, 458335, 463133, 466012, 466013, 466016, 466133, 468205,
    471538, 472253, 472487, 48025, 54729, 59568, 59569, 59570, 59571, 59650,
    60025, 61229, 61996, 62048, 63796, 63956, 63963, 71342, 72286, 72807,
    74856, 75614, 75973, 88741, 88744, 88990, 97493, 97501, 97359, 113199,
    123992, 123993, 124408, 1245358, 1245359, 1245517, 1246781, 1241429,
    1250482, 1251255, 1251279, 1251281, 1251283, 1251284, 1251295, 1251297,
    1251298, 1251300, 1253130, 1255264, 129918, 130092, 130985, 132036,
    133023, 134359, 136163, 139442, 139448, 142478, 148476, 163024, 171847,
    196681, 215159, 233364, 235764, 239013, 242875, 242882, 243651, 253088,
    253106, 253107, 253108, 253109, 253639, 272770, 278966, 280729, 289083,
    289555, 290328, 290718, 299158, 299159, 302143, 308078, 312776, 317177,
    332252, 332256, 334352, 334482, 335150,
}

local lastX, lastY = 0, 0
local wasSwimming = false
local lastUpdateTime = 0
local attributeScratch = {
    displayList = {},
    sortable = {},
    usedKeys = {},
}
local ATTRIBUTE_FRAME_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBorder",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function WipeArray(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function WipeDictionary(dict)
    for key in pairs(dict) do
        dict[key] = nil
    end
end

local function AcquireScratchEntry(list, index)
    local entry = list[index]
    if not entry then
        entry = {}
        list[index] = entry
    end
    return entry
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "attributeDisplay")
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function GetFontPreset(config)
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.NormalizeFontPreset then
        return optionsPrivate.NormalizeFontPreset(config, "font")
    end

    return (config and config.fontPreset) or "CHAT"
end

local function ApplyConfiguredFont(target, size, outline, config)
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(target, size, outline, GetFontPreset(config))
        return
    end

    target:SetFont(STANDARD_TEXT_FONT, size or 12, outline or "")
end

local function FetchStatusBar(textureName)
    local media = NS.Media
    if media and media.FetchStatusBar then
        return media:FetchStatusBar(textureName)
    end

    return (LibSharedMedia and LibSharedMedia:Fetch("statusbar", textureName)) or
        "Interface\\TargetingFrame\\UI-StatusBar"
end

local function EnsurePosition()
    local config = GetConfig()
    config.pos = config.pos or {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }
    return config.pos
end

local function IsDragonRiding()
    for _, spellID in ipairs(DRAGON_RIDING_SPELL_IDS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            return true
        end
    end
    return false
end

local function GetDragonSpeed()
    local elapsed = GetTime() - lastUpdateTime
    lastUpdateTime = GetTime()

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        return 0
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return 0
    end

    local width, height = C_Map.GetMapWorldSize(mapID)
    local x = position.x * width
    local y = position.y * height
    local dx = x - lastX
    local dy = y - lastY
    lastX = x
    lastY = y

    if elapsed <= 0 then
        return 0
    end

    return math.sqrt(dx * dx + dy * dy) / elapsed
end

local function GetPlayerSpeed()
    local unit = "player"
    local currentSpeed, _, _, swimSpeed = GetUnitSpeed(unit)
    local speed = currentSpeed
    local swimming = IsSwimming(unit)

    if UnitInVehicle(unit) then
        speed = GetUnitSpeed("vehicle") / BASE_MOVEMENT_SPEED * 100
    elseif swimming then
        speed = swimSpeed
    elseif UnitOnTaxi(unit) then
        speed = currentSpeed
    elseif IsFlying(unit) then
        if IsDragonRiding() then
            speed = GetDragonSpeed()
        else
            speed = currentSpeed
        end
    end

    if IsFalling(unit) then
        if wasSwimming then
            speed = swimSpeed
        end
    else
        wasSwimming = swimming
    end

    return (speed / BASE_MOVEMENT_SPEED) * 100
end

local function GetPrimaryStatValue()
    local specIndex = GetSpecialization()
    local statID = 1
    if specIndex then
        local _, _, _, _, _, primaryStatID = GetSpecializationInfo(specIndex)
        statID = primaryStatID or 1
    end

    local statValue = UnitStat("player", statID) or 0
    local statName = PRIMARY_STAT_NAMES[statID] or "主属性"
    return statName, statValue
end

local function BuildSecondaryStatList(config, sortable)
    local count = 0

    local function AddStat(key, rating, percent)
        count = count + 1
        local entry = AcquireScratchEntry(sortable, count)
        entry.key = key
        entry.value = percent or 0
        entry.rating = rating or 0
        entry.color = config["color" .. key:sub(1, 1):upper() .. key:sub(2)]
        entry.name = SECONDARY_STAT_NAMES[key]
    end

    if config.showCrit then
        AddStat("crit", GetCombatRating(CR_CRIT_MELEE), GetCritChance("player") or 0)
    end
    if config.showHaste then
        AddStat("haste", GetCombatRating(CR_HASTE_MELEE), UnitSpellHaste("player") or 0)
    end
    if config.showMastery then
        AddStat("mastery", GetCombatRating(CR_MASTERY), GetMasteryEffect("player") or 0)
    end
    if config.showVersa then
        AddStat("versa", GetCombatRating(CR_VERSATILITY_DAMAGE_DONE),
            GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
    end
    if config.showLeech then
        AddStat("leech", GetCombatRating(CR_LIFESTEAL), GetLifesteal() or 0)
    end
    if config.showDodge then
        AddStat("dodge", GetCombatRating(CR_DODGE), GetDodgeChance() or 0)
    end
    if config.showParry then
        AddStat("parry", GetCombatRating(CR_PARRY), GetParryChance() or 0)
    end
    if config.showBlock then
        AddStat("block", GetCombatRating(CR_BLOCK), GetBlockChance() or 0)
    end

    for index = count + 1, #sortable do
        sortable[index] = nil
    end

    table.sort(sortable, function(left, right)
        return left.value > right.value
    end)

    return count
end

function Core:CreateAttributeFrame()
    if self.attributeFrame then
        return
    end

    self.attributeLines = self.attributeLines or {}
    self.attributeProgressBars = self.attributeProgressBars or {}

    local frame = CreateFrame("Frame", "YuXuanAttributeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(200, 250)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(selfFrame)
        if not GetConfig().locked then
            selfFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = selfFrame:GetPoint(1)
        local position = EnsurePosition()
        position.point = point
        position.relativeTo = relativeTo and relativeTo:GetName() or "UIParent"
        position.relativePoint = relativePoint
        position.x = x
        position.y = y
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function()
        Core:UpdateAttributeVisibility()
    end)

    for _, key in ipairs(STAT_KEYS) do
        self.attributeLines[key] = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end

    for _, key in ipairs(PROGRESS_KEYS) do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)

        self.attributeProgressBars[key] = bar
    end

    self.attributeFrame = frame
end

function Core:UpdateAttributeDisplay()
    if not self.db or not self.attributeFrame then
        return
    end

    local config = GetConfig()
    local frame = self.attributeFrame

    for _, fontString in pairs(self.attributeLines) do
        ApplyConfiguredFont(fontString, config.fontSize, config.fontOutline and "OUTLINE" or "", config)
        fontString:SetJustifyH(config.align)
        fontString:SetWidth(frame:GetWidth() - 16)
    end

    if config.bgStyle == "none" then
        if frame._yxsBackdropStyle ~= "none" then
            frame:SetBackdrop(nil)
            frame._yxsBackdropStyle = "none"
        end
    else
        if frame._yxsBackdropStyle ~= "default" then
            frame:SetBackdrop(ATTRIBUTE_FRAME_BACKDROP)
            frame._yxsBackdropStyle = "default"
        end
        frame:SetBackdropColor(0.1, 0.1, 0.1, config.bgAlpha)
        frame:SetBackdropBorderColor(0.5, 0.5, 0.5, config.bgAlpha)
    end

    local displayList = attributeScratch.displayList
    local sortable = attributeScratch.sortable
    local usedKeys = attributeScratch.usedKeys
    WipeArray(displayList)
    WipeDictionary(usedKeys)
    local displayCount = 0

    if config.showIlvl then
        local _, equippedIlvl = GetAverageItemLevel("player")
        local averageIlvl = select(1, GetAverageItemLevel("player"))
        local text
        if config.ilvlFormat == "real" then
            text = string.format("装等: %.1f", equippedIlvl)
        else
            text = string.format("装等: %.1f (%.1f)", equippedIlvl, averageIlvl)
        end
        displayCount = displayCount + 1
        local entry = AcquireScratchEntry(displayList, displayCount)
        entry.key = "ilvl"
        entry.text = text
        entry.color = config.colorIlvl
        entry.value = equippedIlvl
    end

    if config.showPrimary then
        local statName, statValue = GetPrimaryStatValue()
        displayCount = displayCount + 1
        local entry = AcquireScratchEntry(displayList, displayCount)
        entry.key = "primary"
        entry.text = statName .. ": " .. statValue
        entry.color = config.colorPrimary
        entry.value = statValue
    end

    local sortableCount = BuildSecondaryStatList(config, sortable)
    for index = 1, sortableCount do
        local entry = sortable[index]
        local text
        if config.secondaryFormat == "percent" then
            text = string.format("%s: %." .. config.decimalPlaces .. "f%%", entry.name, entry.value)
        else
            text = string.format("%s: %d (%." .. config.decimalPlaces .. "f%%)", entry.name, entry.rating, entry.value)
        end

        displayCount = displayCount + 1
        local displayEntry = AcquireScratchEntry(displayList, displayCount)
        displayEntry.key = entry.key
        displayEntry.text = text
        displayEntry.color = entry.color
        displayEntry.value = entry.value
    end

    if config.showSpeed then
        local speed = GetPlayerSpeed()
        local text
        if config.speedFormat == "current" then
            text = string.format("移速: %." .. config.decimalPlaces .. "f%%", speed)
        else
            text = string.format("移速: %." .. config.decimalPlaces .. "f%% (静态)", speed)
        end
        displayCount = displayCount + 1
        local entry = AcquireScratchEntry(displayList, displayCount)
        entry.key = "speed"
        entry.text = text
        entry.color = config.colorSpeed
        entry.value = speed
    end

    for index = displayCount + 1, #displayList do
        displayList[index] = nil
    end

    local yOffset = -8
    for index = 1, displayCount do
        local item = displayList[index]
        local fontString = self.attributeLines[item.key]
        local progressBar = self.attributeProgressBars[item.key]
        usedKeys[item.key] = true

        if fontString then
            fontString:ClearAllPoints()
            fontString:SetPoint("TOPLEFT", 8, yOffset)
            fontString:SetText(item.text)
            fontString:SetTextColor(item.color.r, item.color.g, item.color.b)
            fontString:Show()
        end

        if progressBar and config.progressBarEnable then
            local currentValue, maxValue
            if item.key == "ilvl" then
                currentValue, maxValue = item.value, config.maxIlvl
            elseif item.key == "primary" then
                currentValue, maxValue = item.value, 5000
            elseif item.key == "crit" or item.key == "haste" or item.key == "mastery" or item.key == "versa" then
                currentValue, maxValue = item.value, 150
            elseif item.key == "speed" then
                currentValue, maxValue = item.value, 1100
            end

            if currentValue and maxValue then
                progressBar:SetMinMaxValues(0, maxValue)
                progressBar:SetValue(currentValue)
                progressBar:SetHeight(config.progressBarHeight)
                progressBar:SetWidth(config.progressBarWidth)
                progressBar:ClearAllPoints()
                progressBar:SetPoint("TOPLEFT", fontString, "BOTTOMLEFT", 0, -2)
                progressBar:SetStatusBarTexture(FetchStatusBar(config.progressBarTexture))
                progressBar:SetStatusBarColor(config.progressBarColor.r, config.progressBarColor.g, config.progressBarColor.b, 1)
                progressBar:Show()
            else
                progressBar:Hide()
            end
        elseif progressBar then
            progressBar:Hide()
        end

        local lineHeight = config.fontSize + config.lineSpacing
        if progressBar and progressBar:IsShown() then
            lineHeight = lineHeight + config.progressBarHeight + 2
        end
        yOffset = yOffset - lineHeight
    end

    for key, fontString in pairs(self.attributeLines) do
        if not usedKeys[key] then
            fontString:Hide()
            if self.attributeProgressBars[key] then
                self.attributeProgressBars[key]:Hide()
            end
        end
    end

    frame:SetHeight(-yOffset + 8)
end

function Core:UpdateAttributeVisibility()
    if not self.db or not self.attributeFrame then
        return
    end

    local config = GetConfig()
    if not config.enabled then
        self.attributeFrame:Hide()
        return
    end

    local inCombat = UnitAffectingCombat("player")
    if config.visibility == "combat" then
        self.attributeFrame:SetShown(inCombat)
    elseif config.visibility == "noncombat" then
        self.attributeFrame:SetShown(not inCombat)
    else
        self.attributeFrame:Show()
    end
end

function Core:ApplyAttributeSettings()
    if not self.db or not self.attributeFrame then
        return
    end

    local config = GetConfig()
    local position = EnsurePosition()
    local relative = _G[position.relativeTo] or UIParent

    self.attributeFrame:ClearAllPoints()
    self.attributeFrame:SetPoint(position.point, relative, position.relativePoint, position.x, position.y)

    if config.locked then
        self.attributeFrame:EnableMouse(false)
        self.attributeFrame:RegisterForDrag()
    else
        self.attributeFrame:EnableMouse(true)
        self.attributeFrame:RegisterForDrag("LeftButton")
    end

    self:UpdateAttributeDisplay()
    self:UpdateAttributeVisibility()
end

function AttributeDisplay:OnPlayerLogin()
    Core:CreateAttributeFrame()

    if Core.attributeUpdateTicker then
        Core.attributeUpdateTicker:Cancel()
    end

    Core.attributeUpdateTicker = C_Timer.NewTicker(0.2, function()
        local config = GetConfig()
        if config and config.enabled then
            Core:UpdateAttributeDisplay()
        end
    end)

    Core:ApplyAttributeSettings()
end

function AttributeDisplay:RefreshFromSettings()
    if not Core.attributeFrame then
        self:OnPlayerLogin()
        return
    end

    Core:ApplyAttributeSettings()
end
