local _, NS = ...
local Core = NS.Core

local AttributeDisplay = {}
NS.Modules.InterfaceEnhance.AttributeDisplay = AttributeDisplay

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "attributeDisplay")
end
local LibSharedMedia = LibStub("LibSharedMedia-3.0")

-- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
--  Attribute Display Module
--  (Cloned from WeiyuAttribute, adapted for YuXuanToolbox)
-- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?

local STAT_KEYS = { "ilvl", "primary", "crit", "haste", "mastery", "versa", "leech", "dodge", "parry", "block", "speed" }
local PROGRESS_KEYS = { "ilvl", "primary", "crit", "haste", "mastery", "versa", "speed" }
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

-- Dragon riding speed tracking state
local lastX, lastY = 0, 0
local wasSwimming = false
local lastUpdateTime = 0

-- 鈹€鈹€鈹€ Frame creation 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

function Core:CreateAttributeFrame()
    if self.attributeFrame then return end

    local frame = CreateFrame("Frame", "YuXuanAttributeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(200, 250)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("LOW")
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBorder",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(false)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        local cfg = GetConfig()
        if not cfg.locked then self:StartMoving() end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cfg = GetConfig()
        local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
        cfg.pos = {
            point = point,
            relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end)

    -- Create font strings
    for _, key in ipairs(STAT_KEYS) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.attributeLines[key] = fs
    end

    -- Create progress bars
    for _, key in ipairs(PROGRESS_KEYS) do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetHeight(6)
        bar:SetWidth(180)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)
        bar:Show()

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)

        self.attributeProgressBars[key] = bar
    end

    self.attributeFrame = frame

    -- Visibility events
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function() Core:UpdateAttributeVisibility() end)

    -- Update ticker
    C_Timer.NewTicker(0.2, function()
        if Core.db and GetConfig().enabled then
            Core:UpdateAttributeDisplay()
        end
    end)
end

-- 鈹€鈹€鈹€ Stat calculation 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

local function IsDragonRiding()
    local spellIDs = DRAGON_RIDING_SPELL_IDS
    if not spellIDs then return false end
    for _, id in ipairs(spellIDs) do
        if C_UnitAuras.GetPlayerAuraBySpellID(id) then
            return true
        end
    end
    return false
end

local function GetDragonSpeed()
    local dragonSpeed = 0
    local dt = GetTime() - lastUpdateTime
    lastUpdateTime = GetTime()
    local map = C_Map.GetBestMapForUnit("player")
    if map then
        local position = C_Map.GetPlayerMapPosition(map, "player")
        if position then
            local x, y = position.x, position.y
            local w, h = C_Map.GetMapWorldSize(map)
            x = x * w
            y = y * h
            local dx = x - lastX
            local dy = y - lastY
            lastX = x
            lastY = y
            if dt > 0 then
                dragonSpeed = math.sqrt(dx * dx + dy * dy) / dt
            end
        end
    end
    return dragonSpeed
end

local function GetPlayerSpeed()
    local unit = "player"
    local currentSpeed, _, _, swimSpeed = GetUnitSpeed(unit)
    local speed = currentSpeed
    local swimming = IsSwimming(unit)
    if UnitInVehicle(unit) then
        speed = GetUnitSpeed("Vehicle") / BASE_MOVEMENT_SPEED * 100
    elseif swimming then
        speed = swimSpeed
    elseif UnitOnTaxi("player") then
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

local function GetAttributeValues(cfg)
    local values = {}
    if cfg.showCrit then
        values.crit = { rating = GetCombatRating(CR_CRIT_MELEE), percent = GetCritChance("player") or 0 }
    end
    if cfg.showHaste then
        values.haste = { rating = GetCombatRating(CR_HASTE_MELEE), percent = UnitSpellHaste("player") or 0 }
    end
    if cfg.showMastery then
        values.mastery = { rating = GetCombatRating(CR_MASTERY), percent = GetMasteryEffect("player") or 0 }
    end
    if cfg.showVersa then
        values.versa = {
            rating = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE),
            percent = GetCombatRatingBonus(
                CR_VERSATILITY_DAMAGE_DONE) or 0
        }
    end
    if cfg.showLeech then
        values.leech = { rating = GetCombatRating(CR_LIFESTEAL), percent = GetLifesteal() or 0 }
    end
    if cfg.showDodge then
        values.dodge = { rating = GetCombatRating(CR_DODGE), percent = GetDodgeChance() or 0 }
    end
    if cfg.showParry then
        values.parry = { rating = GetCombatRating(CR_PARRY), percent = GetParryChance() or 0 }
    end
    if cfg.showBlock then
        values.block = { rating = GetCombatRating(CR_BLOCK), percent = GetBlockChance() or 0 }
    end
    return values
end

-- 鈹€鈹€鈹€ Display update 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

function Core:UpdateAttributeDisplay()
    if not self.db or not self.attributeFrame then return end
    local cfg = GetConfig()
    local frame = self.attributeFrame

    local fontPath = LibSharedMedia:Fetch("font", cfg.font) or STANDARD_TEXT_FONT
    for _, fs in pairs(self.attributeLines) do
        fs:SetFont(fontPath, cfg.fontSize, cfg.fontOutline and "OUTLINE" or "")
        fs:SetJustifyH(cfg.align)
        fs:SetWidth(frame:GetWidth() - 16)
    end

    -- Background
    if cfg.bgStyle == "none" then
        frame:SetBackdrop(nil)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBorder",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, cfg.bgAlpha)
        frame:SetBackdropBorderColor(0.5, 0.5, 0.5, cfg.bgAlpha)
    end

    local displayList = {}
    local values = GetAttributeValues(cfg)

    -- Item Level
    if cfg.showIlvl then
        local _, equipIlvl = GetAverageItemLevel("player")
        local avgIlvl = select(1, GetAverageItemLevel("player"))
        local text
        if cfg.ilvlFormat == "real" then
            text = string.format("瑁呯瓑: %.1f", equipIlvl)
        else
            text = string.format("瑁呯瓑: %.1f (%.1f)", equipIlvl, avgIlvl)
        end
        table.insert(displayList, { key = "ilvl", text = text, color = cfg.colorIlvl, value = equipIlvl })
    end

    -- Primary Stat
    if cfg.showPrimary then
        local spec = GetSpecialization()
        local primaryStatTypes = { "STRENGTH", "AGILITY", nil, "INTELLECT" }
        local _, _, _, _, _, primaryStatIndex = GetSpecializationInfo(spec)
        if not primaryStatIndex then primaryStatIndex = 1 end
        local statValue
        if primaryStatIndex == 1 then
            statValue = UnitStat("player", 1)
        elseif primaryStatIndex == 2 then
            statValue = UnitStat("player", 2)
        elseif primaryStatIndex == 4 then
            statValue = UnitStat("player", 4)
        else
            statValue = 0
        end
        local statName = _G["SPEC_FRAME_PRIMARY_STAT_" .. (primaryStatTypes[primaryStatIndex] or "STRENGTH")] or "涓诲睘鎬?
        table.insert(displayList,
            { key = "primary", text = statName .. ": " .. statValue, color = cfg.colorPrimary, value = statValue })
    end

    -- Secondary stats (sorted by value)
    local sortable = {}
    if cfg.showCrit and values.crit then
        table.insert(sortable,
            { key = "crit", value = values.crit.percent, rating = values.crit.rating, color = cfg.colorCrit, name = "鏆村嚮" })
    end
    if cfg.showHaste and values.haste then
        table.insert(sortable,
            {
                key = "haste",
                value = values.haste.percent,
                rating = values.haste.rating,
                color = cfg.colorHaste,
                name =
                "鎬ラ€?
            })
    end
    if cfg.showMastery and values.mastery then
        table.insert(sortable,
            {
                key = "mastery",
                value = values.mastery.percent,
                rating = values.mastery.rating,
                color = cfg.colorMastery,
                name =
                "绮鹃€?
            })
    end
    if cfg.showVersa and values.versa then
        table.insert(sortable,
            {
                key = "versa",
                value = values.versa.percent,
                rating = values.versa.rating,
                color = cfg.colorVersa,
                name =
                "鍏ㄨ兘"
            })
    end
    if cfg.showLeech and values.leech then
        table.insert(sortable,
            {
                key = "leech",
                value = values.leech.percent,
                rating = values.leech.rating,
                color = cfg.colorLeech,
                name =
                "鍚歌"
            })
    end
    if cfg.showDodge and values.dodge then
        table.insert(sortable,
            {
                key = "dodge",
                value = values.dodge.percent,
                rating = values.dodge.rating,
                color = cfg.colorDodge,
                name =
                "韬查棯"
            })
    end
    if cfg.showParry and values.parry then
        table.insert(sortable,
            {
                key = "parry",
                value = values.parry.percent,
                rating = values.parry.rating,
                color = cfg.colorParry,
                name =
                "鎷涙灦"
            })
    end
    if cfg.showBlock and values.block then
        table.insert(sortable,
            {
                key = "block",
                value = values.block.percent,
                rating = values.block.rating,
                color = cfg.colorBlock,
                name =
                "鏍兼尅"
            })
    end

    table.sort(sortable, function(a, b) return a.value > b.value end)

    local function FormatSecondary(name, rating, percent)
        if cfg.secondaryFormat == "percent" then
            return string.format("%s: %." .. cfg.decimalPlaces .. "f%%", name, percent)
        else
            return string.format("%s: %d (%." .. cfg.decimalPlaces .. "f%%)", name, rating, percent)
        end
    end

    for _, item in ipairs(sortable) do
        table.insert(displayList,
            {
                key = item.key,
                text = FormatSecondary(item.name, item.rating, item.value),
                color = item.color,
                value =
                    item.value
            })
    end

    -- Speed
    if cfg.showSpeed then
        local speed = GetPlayerSpeed()
        local text
        if cfg.speedFormat == "current" then
            text = string.format("绉婚€? %." .. cfg.decimalPlaces .. "f%%", speed)
        else
            text = string.format("绉婚€? %." .. cfg.decimalPlaces .. "f%% (闈欐€?", speed)
        end
        table.insert(displayList, { key = "speed", text = text, color = cfg.colorSpeed, value = speed })
    end

    -- Layout lines and progress bars
    local yOffset = -8
    for _, item in ipairs(displayList) do
        local fs = self.attributeLines[item.key]
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 8, yOffset)
            fs:SetText(item.text)
            fs:SetTextColor(item.color.r, item.color.g, item.color.b)
            fs:Show()
        end

        local bar = self.attributeProgressBars[item.key]
        if bar and cfg.progressBarEnable then
            local current, maxValue
            if item.key == "ilvl" then
                current, maxValue = item.value, cfg.maxIlvl
            elseif item.key == "primary" then
                current, maxValue = item.value, 5000
            elseif item.key == "crit" or item.key == "haste" or item.key == "mastery" or item.key == "versa" then
                current, maxValue = item.value, 150
            elseif item.key == "speed" then
                current, maxValue = item.value, 1100
            end

            if current and maxValue then
                bar:SetMinMaxValues(0, maxValue)
                bar:SetValue(current)
                bar:SetHeight(cfg.progressBarHeight)
                bar:SetWidth(cfg.progressBarWidth)
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
                local texturePath = LibSharedMedia:Fetch("statusbar", cfg.progressBarTexture) or
                    "Interface\\TargetingFrame\\UI-StatusBar"
                bar:SetStatusBarTexture(texturePath)
                bar:SetStatusBarColor(cfg.progressBarColor.r, cfg.progressBarColor.g, cfg.progressBarColor.b, 1)
                bar:Show()
            else
                bar:SetValue(0)
                bar:Show()
            end
        elseif bar then
            bar:Hide()
        end

        local lineHeight = cfg.fontSize + cfg.lineSpacing
        if bar and bar:IsShown() then
            lineHeight = lineHeight + cfg.progressBarHeight + 2
        end
        yOffset = yOffset - lineHeight
    end

    -- Hide unused lines
    for key, fs in pairs(self.attributeLines) do
        local found = false
        for _, item in ipairs(displayList) do
            if item.key == key then
                found = true; break
            end
        end
        if not found then
            fs:Hide()
            if self.attributeProgressBars[key] then self.attributeProgressBars[key]:Hide() end
        end
    end

    frame:SetHeight(-yOffset + 8)
end

-- 鈹€鈹€鈹€ Visibility 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

function Core:UpdateAttributeVisibility()
    if not self.db or not self.attributeFrame then return end
    local cfg = GetConfig()

    if not cfg.enabled then
        self.attributeFrame:Hide()
        return
    end

    local inCombat = UnitAffectingCombat("player")
    if cfg.visibility == "always" then
        self.attributeFrame:Show()
    elseif cfg.visibility == "combat" then
        if inCombat then self.attributeFrame:Show() else self.attributeFrame:Hide() end
    elseif cfg.visibility == "noncombat" then
        if not inCombat then self.attributeFrame:Show() else self.attributeFrame:Hide() end
    end
end

-- 鈹€鈹€鈹€ Apply settings 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

function Core:ApplyAttributeSettings()
    if not self.db or not self.attributeFrame then return end
    local cfg = GetConfig()

    local pos = cfg.pos or { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
    local relative = _G[pos.relativeTo] or UIParent
    self.attributeFrame:ClearAllPoints()
    self.attributeFrame:SetPoint(pos.point, relative, pos.relativePoint, pos.x, pos.y)

    if cfg.locked then
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
    Core.attributeLines = Core.attributeLines or {}
    Core.attributeProgressBars = Core.attributeProgressBars or {}
    Core:CreateAttributeFrame()
    Core:ApplyAttributeSettings()
end

function AttributeDisplay:RefreshFromSettings()
    if not Core.attributeFrame then
        self:OnPlayerLogin()
        return
    end

    Core:ApplyAttributeSettings()
end

