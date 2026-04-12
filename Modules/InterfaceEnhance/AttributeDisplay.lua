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
    dodge = "闪避",
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
local ATTRIBUTE_FRAME_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBorder",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local lastX, lastY = 0, 0
local wasSwimming = false
local lastUpdateTime = 0
local attributeScratch = {
    displayList = {},
    sortable = {},
    usedKeys = {},
}
local attributeRenderState = {
    orderedKeys = {},
    lineTexts = {},
    frameStyle = {},
    lineStyle = {},
    forceLayout = true,
}
local ATTRIBUTE_FAST_UPDATE_INTERVAL = 0.2
local ATTRIBUTE_SLOW_UPDATE_INTERVAL = 1.0
local attributeDataCache = {
    slowDirty = true,
    speedDirty = true,
    nextSlowRefreshAt = 0,
    nextSpeedRefreshAt = 0,
    ilvlAverage = 0,
    ilvlEquipped = 0,
    primaryName = PRIMARY_STAT_NAMES[1] or "",
    primaryValue = 0,
    secondary = {},
    speed = 0,
}

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

local function RoundToPlaces(value, places)
    local multiplier = 10 ^ (places or 0)
    return math.floor(((tonumber(value) or 0) * multiplier) + 0.5) / multiplier
end

local function InvalidateAttributeLayout()
    attributeRenderState.forceLayout = true
    attributeRenderState.displayCount = nil
end

local function InvalidateAttributeStyles()
    WipeDictionary(attributeRenderState.frameStyle)
    WipeDictionary(attributeRenderState.lineStyle)
    WipeArray(attributeRenderState.orderedKeys)
    InvalidateAttributeLayout()
end

local function MarkAttributeDataDirty(scope)
    if scope == "speed" then
        attributeDataCache.speedDirty = true
        attributeDataCache.nextSpeedRefreshAt = 0
        return
    end

    attributeDataCache.slowDirty = true
    attributeDataCache.speedDirty = true
    attributeDataCache.nextSlowRefreshAt = 0
    attributeDataCache.nextSpeedRefreshAt = 0
end

local function HasOrderedKeysChanged(displayList, count)
    local orderedKeys = attributeRenderState.orderedKeys
    if attributeRenderState.displayCount ~= count then
        return true
    end

    for index = 1, count do
        if orderedKeys[index] ~= displayList[index].key then
            return true
        end
    end

    return false
end

local function RememberOrderedKeys(displayList, count)
    local orderedKeys = attributeRenderState.orderedKeys
    for index = 1, count do
        orderedKeys[index] = displayList[index].key
    end
    for index = count + 1, #orderedKeys do
        orderedKeys[index] = nil
    end
    attributeRenderState.displayCount = count
end

local _secondaryPercentFmts = {}
local _secondaryRatingFmts = {}
local _speedCurrentFmts = {}
local _speedStaticFmts = {}

local function GetSecondaryPercentFmt(decimals)
    local fmt = _secondaryPercentFmts[decimals]
    if not fmt then
        fmt = "%s: %." .. decimals .. "f%%"
        _secondaryPercentFmts[decimals] = fmt
    end
    return fmt
end

local function GetSecondaryRatingFmt(decimals)
    local fmt = _secondaryRatingFmts[decimals]
    if not fmt then
        fmt = "%s: %d (%." .. decimals .. "f%%)"
        _secondaryRatingFmts[decimals] = fmt
    end
    return fmt
end

local function GetSpeedCurrentFmt(decimals)
    local fmt = _speedCurrentFmts[decimals]
    if not fmt then
        fmt = "移速: %." .. decimals .. "f%%"
        _speedCurrentFmts[decimals] = fmt
    end
    return fmt
end

local function GetSpeedStaticFmt(decimals)
    local fmt = _speedStaticFmts[decimals]
    if not fmt then
        fmt = "移速: %." .. decimals .. "f%% (静态)"
        _speedStaticFmts[decimals] = fmt
    end
    return fmt
end

local function GetCachedSecondaryText(key, entry, config)
    local cache = attributeRenderState.lineTexts[key] or {}
    local roundedValue = RoundToPlaces(entry.value, config.decimalPlaces)

    attributeRenderState.lineTexts[key] = cache
    if cache.rating ~= entry.rating
        or cache.value ~= roundedValue
        or cache.format ~= config.secondaryFormat
        or cache.decimals ~= config.decimalPlaces
    then
        cache.rating = entry.rating
        cache.value = roundedValue
        cache.format = config.secondaryFormat
        cache.decimals = config.decimalPlaces

        if config.secondaryFormat == "percent" then
            cache.text = string.format(GetSecondaryPercentFmt(config.decimalPlaces), entry.name, roundedValue)
        else
            cache.text = string.format(GetSecondaryRatingFmt(config.decimalPlaces), entry.name, entry.rating,
                roundedValue)
        end
    end

    return cache.text
end

local function GetCachedSimpleText(key, markerA, markerB, markerC, builder)
    local cache = attributeRenderState.lineTexts[key] or {}
    attributeRenderState.lineTexts[key] = cache

    if cache.markerA ~= markerA or cache.markerB ~= markerB or cache.markerC ~= markerC then
        cache.markerA = markerA
        cache.markerB = markerB
        cache.markerC = markerC
        cache.text = builder()
    end

    return cache.text
end

local function IsFrameStyleDirty(config)
    local style = attributeRenderState.frameStyle
    return style.bgStyle ~= config.bgStyle
        or style.bgAlpha ~= config.bgAlpha
end

local function ApplyFrameStyle(frame, config)
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

    attributeRenderState.frameStyle.bgStyle = config.bgStyle
    attributeRenderState.frameStyle.bgAlpha = config.bgAlpha
end

local function IsLineStyleDirty(frame, config)
    local style = attributeRenderState.lineStyle
    local progressBarColor = config.progressBarColor or {}

    return style.fontSize ~= config.fontSize
        or style.fontOutline ~= config.fontOutline
        or style.fontPreset ~= config.fontPreset
        or style.align ~= config.align
        or style.frameWidth ~= frame:GetWidth()
        or style.progressBarEnable ~= config.progressBarEnable
        or style.progressBarHeight ~= config.progressBarHeight
        or style.progressBarWidth ~= config.progressBarWidth
        or style.progressBarTexture ~= config.progressBarTexture
        or style.progressBarColorR ~= (progressBarColor.r or 1)
        or style.progressBarColorG ~= (progressBarColor.g or 1)
        or style.progressBarColorB ~= (progressBarColor.b or 1)
end

local function ApplyLineStyles(core, frame, config)
    local statusBarTexture = FetchStatusBar(config.progressBarTexture)
    local progressBarColor = config.progressBarColor or {}

    for _, fontString in pairs(core.attributeLines) do
        ApplyConfiguredFont(fontString, config.fontSize, config.fontOutline and "OUTLINE" or "", config)
        fontString:SetJustifyH(config.align)
        fontString:SetWidth(frame:GetWidth() - 16)
    end

    for _, bar in pairs(core.attributeProgressBars) do
        bar:SetStatusBarTexture(statusBarTexture)
        bar:SetStatusBarColor(progressBarColor.r or 1, progressBarColor.g or 1, progressBarColor.b or 1, 1)
    end

    local style = attributeRenderState.lineStyle
    style.fontSize = config.fontSize
    style.fontOutline = config.fontOutline
    style.fontPreset = config.fontPreset
    style.align = config.align
    style.frameWidth = frame:GetWidth()
    style.progressBarEnable = config.progressBarEnable
    style.progressBarHeight = config.progressBarHeight
    style.progressBarWidth = config.progressBarWidth
    style.progressBarTexture = config.progressBarTexture
    style.progressBarColorR = progressBarColor.r or 1
    style.progressBarColorG = progressBarColor.g or 1
    style.progressBarColorB = progressBarColor.b or 1
end

local function GetProgressRangeForKey(key, value, config)
    if key == "ilvl" then
        return value, config.maxIlvl
    end
    if key == "primary" then
        return value, 5000
    end
    if key == "crit" or key == "haste" or key == "mastery" or key == "versa" then
        return value, 150
    end
    if key == "speed" then
        return value, 1100
    end
end

local function LayoutDisplayEntries(core, frame, displayList, displayCount, usedKeys, config)
    local yOffset = -8

    for index = 1, displayCount do
        local item = displayList[index]
        local fontString = core.attributeLines[item.key]
        local progressBar = core.attributeProgressBars[item.key]
        usedKeys[item.key] = true

        if fontString then
            fontString:ClearAllPoints()
            fontString:SetPoint("TOPLEFT", 8, yOffset)
            fontString:Show()
        end

        if progressBar and config.progressBarEnable and item.maxValue then
            progressBar:SetHeight(config.progressBarHeight)
            progressBar:SetWidth(config.progressBarWidth)
            progressBar:ClearAllPoints()
            progressBar:SetPoint("TOPLEFT", fontString, "BOTTOMLEFT", 0, -2)
        end

        local lineHeight = config.fontSize + config.lineSpacing
        if progressBar and config.progressBarEnable and item.maxValue then
            lineHeight = lineHeight + config.progressBarHeight + 2
        end
        yOffset = yOffset - lineHeight
    end

    for key, fontString in pairs(core.attributeLines) do
        if not usedKeys[key] then
            fontString:Hide()
            if core.attributeProgressBars[key] then
                core.attributeProgressBars[key]:Hide()
            end
        end
    end

    frame:SetHeight(-yOffset + 8)
end

local function SetDisplayEntry(entry, key, text, color, currentValue, maxValue)
    entry.key = key
    entry.text = text
    entry.color = color
    entry.currentValue = currentValue
    entry.maxValue = maxValue
end

local function SetFontStringState(fontString, item)
    if not fontString or not item then
        return
    end

    if fontString._yxsText ~= item.text then
        fontString:SetText(item.text)
        fontString._yxsText = item.text
    end

    local color = item.color or {}
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    if fontString._yxsColorR ~= r or fontString._yxsColorG ~= g or fontString._yxsColorB ~= b then
        fontString:SetTextColor(r, g, b, 1)
        fontString._yxsColorR = r
        fontString._yxsColorG = g
        fontString._yxsColorB = b
    end

    fontString:Show()
end

local function UpdateProgressBar(progressBar, item, config)
    if not progressBar or not config.progressBarEnable or not item.maxValue then
        if progressBar then
            progressBar:Hide()
        end
        return
    end

    if progressBar._yxsMaxValue ~= item.maxValue then
        progressBar:SetMinMaxValues(0, item.maxValue)
        progressBar._yxsMaxValue = item.maxValue
    end

    local currentValue = item.currentValue or 0
    if progressBar._yxsCurrentValue ~= currentValue then
        progressBar:SetValue(currentValue)
        progressBar._yxsCurrentValue = currentValue
    end

    progressBar:Show()
end

local function SecondaryStatSorter(left, right)
    if left.value == right.value then
        return (left.name or "") < (right.name or "")
    end
    return left.value > right.value
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
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
        return false
    end

    for _, spellID in ipairs(DRAGON_RIDING_SPELL_IDS) do
        if C_UnitAuras.GetPlayerAuraBySpellID(spellID) then
            return true
        end
    end
    return false
end

local function GetDragonSpeed()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition or not C_Map.GetMapWorldSize then
        return 0
    end

    local now = GetTime()
    local elapsed = now - lastUpdateTime
    lastUpdateTime = now

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

    if lastX == 0 and lastY == 0 then
        lastX = x
        lastY = y
        return 0
    end

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
    local baseSpeed = BASE_MOVEMENT_SPEED or 7
    local currentSpeed, _, _, swimSpeed = GetUnitSpeed(unit)
    local speed = currentSpeed
    local swimming = IsSwimming(unit)

    if UnitInVehicle(unit) then
        speed = GetUnitSpeed("vehicle")
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

    return (speed / baseSpeed) * 100
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

local function GetSecondaryCacheEntry(key)
    local entry = attributeDataCache.secondary[key]
    if not entry then
        entry = {}
        attributeDataCache.secondary[key] = entry
    end
    return entry
end

local function UpdateSecondaryCacheEntry(config, key, rating, percent)
    local entry = GetSecondaryCacheEntry(key)
    entry.key = key
    entry.value = percent or 0
    entry.rating = rating or 0
    entry.color = config["color" .. key:sub(1, 1):upper() .. key:sub(2)]
    entry.name = SECONDARY_STAT_NAMES[key]
end

local _slowRefreshChanged = false
local function UpdateTrackedSecondary(config, key, rating, percent)
    local entry = GetSecondaryCacheEntry(key)
    local nextRating = rating or 0
    local nextPercent = percent or 0
    if entry.rating ~= nextRating or entry.value ~= nextPercent then
        _slowRefreshChanged = true
    end
    UpdateSecondaryCacheEntry(config, key, nextRating, nextPercent)
end

local function RefreshSlowAttributeData(config, force)
    local now = GetTime()
    if not force and not attributeDataCache.slowDirty and now < (attributeDataCache.nextSlowRefreshAt or 0) then
        return false
    end

    local averageIlvl, equippedIlvl = GetAverageItemLevel("player")
    averageIlvl = averageIlvl or 0
    equippedIlvl = equippedIlvl or 0

    local statName, statValue = GetPrimaryStatValue()
    statName = statName or ""
    statValue = statValue or 0
    _slowRefreshChanged = force
        or attributeDataCache.ilvlAverage ~= averageIlvl
        or attributeDataCache.ilvlEquipped ~= equippedIlvl
        or attributeDataCache.primaryName ~= statName
        or attributeDataCache.primaryValue ~= statValue

    attributeDataCache.ilvlAverage = averageIlvl
    attributeDataCache.ilvlEquipped = equippedIlvl
    attributeDataCache.primaryName = statName
    attributeDataCache.primaryValue = statValue

    if config.showCrit then
        UpdateTrackedSecondary(config, "crit", GetCombatRating(CR_CRIT_MELEE), GetCritChance("player") or 0)
    end
    if config.showHaste then
        UpdateTrackedSecondary(config, "haste", GetCombatRating(CR_HASTE_MELEE), UnitSpellHaste("player") or 0)
    end
    if config.showMastery then
        UpdateTrackedSecondary(config, "mastery", GetCombatRating(CR_MASTERY), GetMasteryEffect("player") or 0)
    end
    if config.showVersa then
        UpdateTrackedSecondary(config, "versa", GetCombatRating(CR_VERSATILITY_DAMAGE_DONE),
            GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0)
    end
    if config.showLeech then
        UpdateTrackedSecondary(config, "leech", GetCombatRating(CR_LIFESTEAL), GetLifesteal() or 0)
    end
    if config.showDodge then
        UpdateTrackedSecondary(config, "dodge", GetCombatRating(CR_DODGE), GetDodgeChance() or 0)
    end
    if config.showParry then
        UpdateTrackedSecondary(config, "parry", GetCombatRating(CR_PARRY), GetParryChance() or 0)
    end
    if config.showBlock then
        UpdateTrackedSecondary(config, "block", GetCombatRating(CR_BLOCK), GetBlockChance() or 0)
    end

    attributeDataCache.slowDirty = false
    attributeDataCache.nextSlowRefreshAt = now + ATTRIBUTE_SLOW_UPDATE_INTERVAL
    return _slowRefreshChanged
end

local function RefreshSpeedAttributeData(config, force)
    local now = GetTime()
    if not force and not attributeDataCache.speedDirty and now < (attributeDataCache.nextSpeedRefreshAt or 0) then
        return false
    end

    local nextSpeed = GetPlayerSpeed()
    local changed = force
        or RoundToPlaces(attributeDataCache.speed or 0, config.decimalPlaces) ~= RoundToPlaces(nextSpeed, config.decimalPlaces)
    attributeDataCache.speed = nextSpeed
    attributeDataCache.speedDirty = false
    attributeDataCache.nextSpeedRefreshAt = now + ATTRIBUTE_FAST_UPDATE_INTERVAL
    return changed
end

local function EnsureAttributeData(config, force)
    local refreshed = false

    if config.showSpeed then
        refreshed = RefreshSpeedAttributeData(config, force) or refreshed
    end

    if config.showIlvl
        or config.showPrimary
        or config.showCrit
        or config.showHaste
        or config.showMastery
        or config.showVersa
        or config.showLeech
        or config.showDodge
        or config.showParry
        or config.showBlock
    then
        refreshed = RefreshSlowAttributeData(config, force) or refreshed
    end

    return refreshed
end

local function BuildSecondaryStatList(config, sortable)
    local count = 0

    local function AddStat(key)
        count = count + 1

        local entry = AcquireScratchEntry(sortable, count)
        local cached = attributeDataCache.secondary[key] or {}
        entry.key = key
        entry.value = cached.value or 0
        entry.rating = cached.rating or 0
        entry.color = cached.color or config["color" .. key:sub(1, 1):upper() .. key:sub(2)]
        entry.name = cached.name or SECONDARY_STAT_NAMES[key]
    end

    if config.showCrit then
        AddStat("crit")
    end
    if config.showHaste then
        AddStat("haste")
    end
    if config.showMastery then
        AddStat("mastery")
    end
    if config.showVersa then
        AddStat("versa")
    end
    if config.showLeech then
        AddStat("leech")
    end
    if config.showDodge then
        AddStat("dodge")
    end
    if config.showParry then
        AddStat("parry")
    end
    if config.showBlock then
        AddStat("block")
    end

    for index = count + 1, #sortable do
        sortable[index] = nil
    end

    table.sort(sortable, SecondaryStatSorter)
    return count
end

local function BuildAttributeDisplayList(displayList, sortable, config)
    local displayCount = 0

    if config.showIlvl then
        local averageIlvl = attributeDataCache.ilvlAverage or 0
        local equippedIlvl = attributeDataCache.ilvlEquipped or 0
        local entry = AcquireScratchEntry(displayList, displayCount + 1)
        local text = GetCachedSimpleText("ilvl", config.ilvlFormat, averageIlvl, equippedIlvl, function()
            if config.ilvlFormat == "real" then
                return string.format("装等: %.1f", equippedIlvl or 0)
            end
            return string.format("装等: %.1f (%.1f)", equippedIlvl or 0, averageIlvl or 0)
        end)

        displayCount = displayCount + 1
        SetDisplayEntry(entry, "ilvl", text, config.colorIlvl, equippedIlvl, config.maxIlvl)
    end

    if config.showPrimary then
        local statName = attributeDataCache.primaryName or ""
        local statValue = attributeDataCache.primaryValue or 0
        local entry = AcquireScratchEntry(displayList, displayCount + 1)
        local text = GetCachedSimpleText("primary", statName, statValue, false, function()
            return string.format("%s: %s", statName or "", tostring(statValue or 0))
        end)

        displayCount = displayCount + 1
        SetDisplayEntry(entry, "primary", text, config.colorPrimary, statValue, 5000)
    end

    local sortableCount = BuildSecondaryStatList(config, sortable)
    for index = 1, sortableCount do
        local statEntry = sortable[index]
        local displayEntry = AcquireScratchEntry(displayList, displayCount + 1)
        local currentValue, maxValue = GetProgressRangeForKey(statEntry.key, statEntry.value, config)

        displayCount = displayCount + 1
        SetDisplayEntry(
            displayEntry,
            statEntry.key,
            GetCachedSecondaryText(statEntry.key, statEntry, config),
            statEntry.color,
            currentValue,
            maxValue
        )
    end

    if config.showSpeed then
        local speed = attributeDataCache.speed or 0
        local roundedSpeed = RoundToPlaces(speed, config.decimalPlaces)
        local entry = AcquireScratchEntry(displayList, displayCount + 1)
        local text = GetCachedSimpleText("speed", config.speedFormat, config.decimalPlaces, roundedSpeed, function()
            if config.speedFormat == "current" then
                return string.format(GetSpeedCurrentFmt(config.decimalPlaces), roundedSpeed)
            end
            return string.format(GetSpeedStaticFmt(config.decimalPlaces), roundedSpeed)
        end)

        displayCount = displayCount + 1
        SetDisplayEntry(entry, "speed", text, config.colorSpeed, speed, 1100)
    end

    for index = displayCount + 1, #displayList do
        displayList[index] = nil
    end

    return displayCount
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
    local lineStyleDirty = IsLineStyleDirty(frame, config)

    if IsFrameStyleDirty(config) then
        ApplyFrameStyle(frame, config)
    end

    if lineStyleDirty then
        ApplyLineStyles(self, frame, config)
    end

    EnsureAttributeData(config, false)

    local displayList = attributeScratch.displayList
    local sortable = attributeScratch.sortable
    local usedKeys = attributeScratch.usedKeys

    WipeDictionary(usedKeys)

    local displayCount = BuildAttributeDisplayList(displayList, sortable, config)
    local needsLayout = attributeRenderState.forceLayout or lineStyleDirty or HasOrderedKeysChanged(displayList, displayCount)

    if needsLayout then
        LayoutDisplayEntries(self, frame, displayList, displayCount, usedKeys, config)
        RememberOrderedKeys(displayList, displayCount)
        attributeRenderState.forceLayout = false
    end

    for index = 1, displayCount do
        local item = displayList[index]
        usedKeys[item.key] = true
        SetFontStringState(self.attributeLines[item.key], item)
        UpdateProgressBar(self.attributeProgressBars[item.key], item, config)
    end
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

    InvalidateAttributeStyles()
    MarkAttributeDataDirty("all")
    self:UpdateAttributeDisplay()
    self:UpdateAttributeVisibility()
end

function AttributeDisplay:OnPlayerLogin()
    Core:CreateAttributeFrame()

    if Core.attributeUpdateTicker then
        Core.attributeUpdateTicker:Cancel()
    end

    if not self._eventFrame then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        eventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
        eventFrame:RegisterEvent("UNIT_STATS")
        eventFrame:RegisterEvent("COMBAT_RATING_UPDATE")
        eventFrame:RegisterEvent("MASTERY_UPDATE")
        eventFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_STATS" and unit and unit ~= "player" then
                return
            end

            MarkAttributeDataDirty("all")
            if Core.attributeFrame and Core.attributeFrame:IsShown() and GetConfig().enabled then
                Core:UpdateAttributeDisplay()
            end
        end)
        self._eventFrame = eventFrame
    end

    Core.attributeUpdateTicker = C_Timer.NewTicker(ATTRIBUTE_FAST_UPDATE_INTERVAL, function()
        local config = GetConfig()
        if config and config.enabled then
            local dataChanged = EnsureAttributeData(config, false)
            if attributeRenderState.forceLayout or dataChanged then
                Core:UpdateAttributeDisplay()
            end
        end
    end)

    MarkAttributeDataDirty("all")
    Core:ApplyAttributeSettings()
end

function AttributeDisplay:RefreshFromSettings()
    if not Core.attributeFrame then
        self:OnPlayerLogin()
        return
    end

    Core:ApplyAttributeSettings()
end
