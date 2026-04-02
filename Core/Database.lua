local _, NS = ...
local Core = NS.Core

--[[
数据库按 模块 -> 功能 分层，避免后续功能一多就堆成平铺字段。

当前版本的存档结构分为两层：
1. profiles.global：全局共享配置。
2. profiles.named：可重复复用的命名配置。

每个角色只保存“当前绑定哪一份配置”，真正的配置内容都落在全局或命名配置里。
这样后面就可以做到：
1. 一个角色继续走全局配置。
2. 一个角色切到任意命名配置。
3. 多个角色共用同一份命名配置。
]]

local PROFILE_KEY_GLOBAL = "GLOBAL"
local PROFILE_EXPORT_PREFIX = "YXS1:"
local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_LOOKUP = {}

for index = 1, #BASE64_ALPHABET do
    BASE64_LOOKUP[BASE64_ALPHABET:sub(index, index)] = index - 1
end

NS.DEFAULTS = {
    general = {
        appearance = {
            fontPreset = "CHAT",
            windowScale = 1.0,
            showMinimapButton = true,
            colorMode = "CLASS",
            customColor = {
                r = 0.95,
                g = 0.76,
                b = 0.18,
                a = 1.00,
            },
        },
    },
    mapAssist = {
        quickWaypoint = {
            enabled = true,
            anchorPreset = "MAP_TOP",
            offsetX = 0,
            offsetY = 0,
            fontSize = 12,
            bgAlpha = 35,
        },
        mapIDDisplay = {
            enabled = false,
            anchorPreset = "MAP_TOP",
            offsetX = 260,
            offsetY = 0,
            fontPreset = "CHAT",
            fontSize = 12,
            scale = 1.0,
            bgAlpha = 30,
            textColor = {
                r = 1.00,
                g = 0.82,
                b = 0.20,
                a = 1.00,
            },
        },
    },
    interfaceEnhance = {
        quickChat = {
            enabled = false,
            unlocked = false,
            worldChannelName = "大脚世界频道",
            spacing = 10,
            fontSize = 14,
            fontPreset = "CHAT",
            buttonOrder = {
                "SAY",
                "YELL",
                "PARTY",
                "INSTANCE_CHAT",
                "RAID",
                "GUILD",
                "WORLD",
                "DICE",
            },
            customButtons = {},
            nextCustomId = 1,
            buttonColors = {
                SAY = { r = 1.00, g = 1.00, b = 1.00 },
                YELL = { r = 1.00, g = 0.25, b = 0.25 },
                PARTY = { r = 0.66, g = 0.66, b = 1.00 },
                INSTANCE_CHAT = { r = 1.00, g = 0.50, b = 0.20 },
                RAID = { r = 1.00, g = 0.50, b = 0.00 },
                GUILD = { r = 0.25, g = 1.00, b = 0.25 },
                WORLD = { r = 0.30, g = 0.95, b = 1.00 },
                DICE = { r = 1.00, g = 0.82, b = 0.00 },
            },
            barPoint = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = -180,
            },
        },
        mouseTooltip = {
            enabled = false,
            disableAllTooltips = false,
            tooltipFollowCursor = false,
            opaqueTooltipBackground = false,
            showTooltipHealthBar = false,
            showNPCAliveTime = false,
            npcTimeShowCurrentTime = false,
            npcTimeShowLayer = false,
            npcTimeShowNPCID = false,
            npcTimeUseModifier = false,
        },
        distanceMonitor = {
            enabled = false,
            locked = true,
            fontPreset = "CHAT",
            fontSize = 14,
            updateInterval = 0.2,
            rangeSeparator = " - ",
            showBackground = true,
            showBorder = true,
            backgroundColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 0.32,
            },
            borderColor = {
                r = 0,
                g = 0.6,
                b = 1,
                a = 0.45,
            },
            point = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = -220,
                y = -20,
            },
        },
        raidMarkers = {
            enabled = false,
            locked = true,
            showWhenSolo = false,
            orientation = "HORIZONTAL",
            spacing = 6,
            iconSize = 28,
            countdown = 6,
            showBackground = true,
            showBorder = true,
            fontPreset = "CHAT",
            backgroundColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 0.35,
            },
            borderColor = {
                r = 0,
                g = 0.6,
                b = 1,
                a = 0.45,
            },
            point = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = -30,
            },
        },
        gameBar = {
            enabled = false,
            locked = true,
            buttonSize = 28,
            spacing = 4,
            middleWidth = 80,
            timeFontSize = 20,
            animationDuration = 0.2,
            showBackground = true,
            backgroundColor = {
                r = 0,
                g = 0,
                b = 0,
                a = 0.45,
            },
            mouseOver = false,
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = -20,
            leftButtons = { "CHARACTER", "TALENTS", "SPELLBOOK", "QUESTLOG" },
            rightButtons = { "BAGS", "FRIENDS", "GUILD", "SETTINGS" },
            hearthstone = {
                showBindLocation = true,
                left = "AUTO",
                middle = "RANDOM",
                right = "AUTO",
            },
        },
        cursorTrail = {
            enabled = false,
            combatOnly = false,
            changeWithTime = true,
            useClassColor = false,
            shrinkWithTime = true,
            shrinkWithDistance = true,
            dotDistance = 3,
            lifetime = 0.35,
            maxDots = 300,
            dotWidth = 50,
            dotHeight = 50,
            alpha = 1.00,
            colorSpeed = 0.5,
            phaseCount = 6,
            cursorLayer = 1,
            blendMode = 1,
            offsetX = 20,
            offsetY = -18,
            adaptiveUpdate = true,
            adaptiveTargetFPS = 90,
            enableLook = false,
            enableCombatLook = false,
            enableIndicator = true,
            cursorFrameSize = 40,
            debugEnabled = false,
            color1 = { 1.00, 0.00, 0.00 },
            color2 = { 0.76, 0.35, 0.00 },
            color3 = { 0.08, 0.73, 0.00 },
            color4 = { 0.00, 0.54, 1.00 },
            color5 = { 0.00, 0.00, 1.00 },
            color6 = { 0.58, 0.00, 1.00 },
            color7 = { 0.00, 0.00, 0.00 },
            color8 = { 0.00, 0.00, 0.00 },
            color9 = { 0.00, 0.00, 0.00 },
            color10 = { 0.00, 0.00, 0.00 },
        },
        specTalentBar = {
            enabled = true,
            locked = true,
            orientation = "HORIZONTAL",
            fontPreset = "CHAT",
            fontSize = 13,
            spacing = 18,
            textColor = {
                r = 1.00,
                g = 1.00,
                b = 1.00,
                a = 1.00,
            },
            point = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = -150,
            },
        },
        questTools = {
            enabled = false,
            locked = true,
            orientation = "HORIZONTAL",
            fontPreset = "CHAT",
            fontSize = 13,
            spacing = 18,
            textColor = {
                r = 1.00,
                g = 1.00,
                b = 1.00,
                a = 1.00,
            },
            autoAnnounceQuest = false,
            autoQuestTurnIn = false,
            announceTemplate = "|cFF33FF99【雨轩专业版插件】|r |cFFFFFF00{action}|r：{quest}",
            point = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = -110,
            },
        },
        eventTracker = {
            enabled = true,
            fontPreset = "CHAT",
            fontSize = 12,
            fontOutline = true,
            trackerWidth = 220,
            trackerHeight = 28,
            backdropAlpha = 0.6,
            alertEnabled = true,
            alertSecond = 60,
            weeklyMN = true,
            professionsWeeklyMN = true,
            stormarionAssault = true,
            weeklyTWW = true,
            nightfall = true,
            theaterTroupe = true,
            ecologicalSuccession = true,
            ringingDeeps = true,
            spreadingTheLight = true,
            underworldOperative = true,
        },
        attributeDisplay = {
            enabled = true,
            locked = false,
            fontPreset = "CHAT",
            fontOutline = false,
            showIlvl = true,
            showPrimary = true,
            showCrit = true,
            showHaste = true,
            showMastery = true,
            showVersa = true,
            showLeech = false,
            showDodge = false,
            showParry = false,
            showBlock = false,
            showSpeed = true,
            colorIlvl = { r = 0.996, g = 0.349, b = 0.827 },
            colorPrimary = { r = 1.00, g = 0.498, b = 0.259 },
            colorCrit = { r = 1.00, g = 0.00, b = 0.071 },
            colorHaste = { r = 0.043, g = 1.00, b = 0.00 },
            colorMastery = { r = 1.00, g = 1.00, b = 1.00 },
            colorVersa = { r = 0.00, g = 0.902, b = 1.00 },
            colorLeech = { r = 0.81, g = 0.39, b = 0.99 },
            colorDodge = { r = 0.85, g = 0.85, b = 0.65 },
            colorParry = { r = 0.65, g = 0.85, b = 0.85 },
            colorBlock = { r = 0.75, g = 0.75, b = 0.75 },
            colorSpeed = { r = 1.00, g = 1.00, b = 0.40 },
            fontSize = 14,
            lineSpacing = 2,
            decimalPlaces = 1,
            bgAlpha = 0.5,
            bgStyle = "semi",
            align = "LEFT",
            visibility = "always",
            ilvlFormat = "real",
            secondaryFormat = "percent",
            speedFormat = "current",
            pos = {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = 0,
                y = 0,
            },
            progressBarEnable = false,
            progressBarHeight = 6,
            progressBarWidth = 180,
            progressBarTexture = "Yuxuan",
            progressBarColor = { r = 1.00, g = 1.00, b = 1.00 },
            maxIlvl = 289,
        },
        currencyDisplay = {
            enabled = false,
            locked = false,
            orientation = "HORIZONTAL",
            spacing = 8,
            iconSize = 16,
            fontPreset = "CHAT",
            fontSize = 14,
            fontOutline = false,
            displayMode = "ICON_TEXT",
            showMoney = true,
            selected = {},
            order = {},
            pos = {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                x = 0,
                y = -220,
            },
        },
        performanceMonitor = {
            enabled = true,
            locked = true,
            fontPreset = "CHAT",
            fontSize = 14,
            updateInterval = 1,
            showBackground = true,
            showBorder = false,
            backgroundColor = { r = 0, g = 0, b = 0, a = 0.32 },
            borderColor = { r = 0, g = 0.6, b = 1, a = 0.45 },
            point = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 220,
                y = -20,
            },
        },
    },
    combatAssist = {
        quickFocus = {
            enabled = false,
            modifier = "shift",
            mouseButton = "1",
            allowClearFocus = false,
            enableMarking = false,
            selectedMarker = 0,
        },
        trinketMonitor = {
            enabled = false,
            unlocked = false,
            combatOnly = false,
            iconSize = 44,
            spacing = 8,
            offsetX = 0,
            offsetY = -220,
            showText = true,
            textSize = 14,
            textPosition = "BOTTOM",
            textColor = {
                r = 1.00,
                g = 1.00,
                b = 1.00,
                a = 1.00,
            },
            highlightReady = true,
            highlightColor = {
                r = 1.00,
                g = 0.82,
                b = 0.20,
                a = 1.00,
            },
            showReadyAlert = true,
            readyText = "饰品好了！",
            readyTextSize = 28,
            readyTextColor = {
                r = 1.00,
                g = 0.82,
                b = 0.20,
                a = 1.00,
            },
            playReadySound = true,
            readySoundPath = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Audio\\SP.mp3",
            readyOffsetX = 0,
            readyOffsetY = 180,
            alertDuration = 1.5,
            blockedItemIDs = "",
        },
    },
    classAssist = {
        mage = {
            shatterIndicator = {
                enabled = false,
                unlocked = false,
                showIcon = true,
                showBorders = true,
                showOutOfCombat = false,
                width = 14,
                height = 18,
                spacing = 2,
                scale = 1.0,
                texture = "纯色",
                defaultColor = {
                    r = 0.25,
                    g = 0.75,
                    b = 1.00,
                    a = 1.00,
                },
                monitorList = {
                    {
                        count = 6,
                        color = { r = 0.30, g = 0.85, b = 1.00, a = 1.00 },
                    },
                    {
                        count = 12,
                        color = { r = 1.00, g = 0.82, b = 0.20, a = 1.00 },
                    },
                    {
                        count = 18,
                        color = { r = 1.00, g = 0.30, b = 0.30, a = 1.00 },
                    },
                },
            },
        },
    },
}

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function CloneTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CloneTable(value)
    end
    return copy
end

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function SortedKeys(source)
    local keys = {}
    for key in pairs(source or {}) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(left, right)
        if type(left) == type(right) then
            return tostring(left) < tostring(right)
        end
        return type(left) < type(right)
    end)

    return keys
end

local function SerializeValue(value, indent)
    local valueType = type(value)
    indent = indent or ""

    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    if valueType == "string" then
        return string.format("%q", value)
    end

    if valueType ~= "table" then
        return "nil"
    end

    local childIndent = indent .. "    "
    local parts = { "{\n" }

    for _, key in ipairs(SortedKeys(value)) do
        local serializedKey
        if type(key) == "number" then
            serializedKey = "[" .. tostring(key) .. "]"
        else
            serializedKey = "[" .. string.format("%q", tostring(key)) .. "]"
        end

        parts[#parts + 1] = string.format(
            "%s%s = %s,\n",
            childIndent,
            serializedKey,
            SerializeValue(value[key], childIndent)
        )
    end

    parts[#parts + 1] = indent .. "}"
    return table.concat(parts)
end

local function Base64Encode(text)
    local rawText = tostring(text or "")
    local parts = {}

    for index = 1, #rawText, 3 do
        local b1 = string.byte(rawText, index) or 0
        local b2 = string.byte(rawText, index + 1) or 0
        local b3 = string.byte(rawText, index + 2) or 0
        local packed = (b1 * 65536) + (b2 * 256) + b3

        local c1 = math.floor(packed / 262144) % 64 + 1
        local c2 = math.floor(packed / 4096) % 64 + 1
        local c3 = math.floor(packed / 64) % 64 + 1
        local c4 = packed % 64 + 1

        if index + 1 > #rawText then
            parts[#parts + 1] = BASE64_ALPHABET:sub(c1, c1) .. BASE64_ALPHABET:sub(c2, c2) .. "=="
        elseif index + 2 > #rawText then
            parts[#parts + 1] = BASE64_ALPHABET:sub(c1, c1)
                .. BASE64_ALPHABET:sub(c2, c2)
                .. BASE64_ALPHABET:sub(c3, c3)
                .. "="
        else
            parts[#parts + 1] = BASE64_ALPHABET:sub(c1, c1)
                .. BASE64_ALPHABET:sub(c2, c2)
                .. BASE64_ALPHABET:sub(c3, c3)
                .. BASE64_ALPHABET:sub(c4, c4)
        end
    end

    return table.concat(parts)
end

local function Base64Decode(text)
    local cleaned = tostring(text or ""):gsub("%s+", "")
    if cleaned == "" then
        return ""
    end

    if (#cleaned % 4) ~= 0 then
        return nil, "编码长度不正确。"
    end

    local bytes = {}
    for index = 1, #cleaned, 4 do
        local c1 = cleaned:sub(index, index)
        local c2 = cleaned:sub(index + 1, index + 1)
        local c3 = cleaned:sub(index + 2, index + 2)
        local c4 = cleaned:sub(index + 3, index + 3)

        local v1 = BASE64_LOOKUP[c1]
        local v2 = BASE64_LOOKUP[c2]
        local v3 = c3 == "=" and 0 or BASE64_LOOKUP[c3]
        local v4 = c4 == "=" and 0 or BASE64_LOOKUP[c4]

        if v1 == nil or v2 == nil or v3 == nil or v4 == nil then
            return nil, "编码内容不正确。"
        end

        local packed = (v1 * 262144) + (v2 * 4096) + (v3 * 64) + v4
        local b1 = math.floor(packed / 65536) % 256
        local b2 = math.floor(packed / 256) % 256
        local b3 = packed % 256

        bytes[#bytes + 1] = string.char(b1)
        if c3 ~= "=" then
            bytes[#bytes + 1] = string.char(b2)
        end
        if c4 ~= "=" then
            bytes[#bytes + 1] = string.char(b3)
        end
    end

    return table.concat(bytes)
end

local function DeserializeProfile(text)
    local rawText = TrimText(text)
    if rawText == "" then
        return nil, "导入内容不能为空。"
    end

    local payload = rawText
    if payload:sub(1, #PROFILE_EXPORT_PREFIX) == PROFILE_EXPORT_PREFIX then
        payload = payload:sub(#PROFILE_EXPORT_PREFIX + 1)
        local decoded, decodeError = Base64Decode(payload)
        if not decoded then
            return nil, decodeError or "配置编码无法解析。"
        end
        payload = decoded
    end

    local loader
    if loadstring then
        loader = loadstring("return " .. payload)
    elseif load then
        loader = load("return " .. payload, "YuXuanSpecialImport", "t", {})
    end

    if not loader then
        return nil, "配置内容格式不正确。"
    end

    if setfenv then
        setfenv(loader, {})
    end

    local ok, result = pcall(loader)
    if not ok or type(result) ~= "table" then
        return nil, "配置内容无法解析。"
    end

    return result
end

local function GetCharacterKey()
    local name, realm = UnitFullName and UnitFullName("player")
    name = name or UnitName("player") or "Unknown"
    realm = realm or GetRealmName() or "Unknown"
    realm = tostring(realm):gsub("%s+", "")
    return string.format("%s-%s", tostring(name), realm)
end

local function NormalizeProfileName(name)
    local trimmed = TrimText(name)
    if trimmed == "" then
        return nil, "配置名称不能为空。"
    end

    if trimmed == PROFILE_KEY_GLOBAL then
        return nil, "该名称保留给全局配置。"
    end

    return trimmed
end

function Core:FindAvailableProfileName(baseName)
    local normalized = NormalizeProfileName(baseName or "新配置")
    local seed = normalized or "新配置"
    local candidate = seed
    local suffix = 2

    while self:GetNamedProfile(candidate, false) do
        candidate = string.format("%s-%d", seed, suffix)
        suffix = suffix + 1
    end

    return candidate
end

function Core:InitializeDatabase()
    YuXuanSpecialDB = YuXuanSpecialDB or {}
    self.dbRoot = YuXuanSpecialDB
    self.currentCharacterKey = GetCharacterKey()

    self:MigrateLegacyRootStorage()

    self.dbRoot.profiles = self.dbRoot.profiles or {}
    self.dbRoot.profiles.global = self.dbRoot.profiles.global or CloneTable(NS.DEFAULTS)
    self.dbRoot.profiles.named = self.dbRoot.profiles.named or {}
    self.dbRoot.profileAssignments = self.dbRoot.profileAssignments or {}

    self:MigrateLegacyCharacterProfiles()

    ApplyDefaults(self.dbRoot.profiles.global, NS.DEFAULTS)
    for _, profile in pairs(self.dbRoot.profiles.named) do
        ApplyDefaults(profile, NS.DEFAULTS)
    end

    self:RefreshActiveDatabase()
end

function Core:MigrateLegacyRootStorage()
    if self.dbRoot.profiles then
        return
    end

    local migrated = false
    local legacyProfile = {}

    for key in pairs(NS.DEFAULTS) do
        if self.dbRoot[key] ~= nil then
            legacyProfile[key] = CloneTable(self.dbRoot[key])
            self.dbRoot[key] = nil
            migrated = true
        end
    end

    if migrated then
        self.dbRoot.profiles = {
            global = legacyProfile,
        }
    end
end

function Core:MigrateLegacyCharacterProfiles()
    local profiles = self.dbRoot.profiles or {}
    local legacyCharacters = profiles.characters or {}
    local legacyModes = self.dbRoot.profileModes or {}

    profiles.named = profiles.named or {}
    self.dbRoot.profileAssignments = self.dbRoot.profileAssignments or {}

    for characterKey, profile in pairs(legacyCharacters) do
        local profileName = self:FindAvailableProfileName(characterKey)
        profiles.named[profileName] = CloneTable(profile)
        ApplyDefaults(profiles.named[profileName], NS.DEFAULTS)

        if legacyModes[characterKey] == "CHARACTER" and not self.dbRoot.profileAssignments[characterKey] then
            self.dbRoot.profileAssignments[characterKey] = profileName
        end
    end

    profiles.characters = nil
    self.dbRoot.profileModes = nil
end

function Core:GetConfig(...)
    local current = self.db
    for index = 1, select("#", ...) do
        current = current and current[select(index, ...)]
    end
    return current
end

function Core:GetGlobalProfile()
    self.dbRoot.profiles = self.dbRoot.profiles or {}
    self.dbRoot.profiles.global = self.dbRoot.profiles.global or CloneTable(NS.DEFAULTS)
    ApplyDefaults(self.dbRoot.profiles.global, NS.DEFAULTS)
    return self.dbRoot.profiles.global
end

function Core:GetNamedProfile(profileName, createIfMissing, sourceProfileKey)
    local normalized, errorMessage = NormalizeProfileName(profileName)
    if not normalized then
        return nil, errorMessage
    end

    self.dbRoot.profiles = self.dbRoot.profiles or {}
    self.dbRoot.profiles.named = self.dbRoot.profiles.named or {}

    local profile = self.dbRoot.profiles.named[normalized]
    if not profile and createIfMissing then
        local source = self:ResolveProfile(sourceProfileKey or self:GetCurrentCharacterProfileKey())
        profile = CloneTable(source or self:GetGlobalProfile())
        self.dbRoot.profiles.named[normalized] = profile
    end

    if profile then
        ApplyDefaults(profile, NS.DEFAULTS)
    end

    return profile
end

function Core:GetNamedProfileNames()
    local names = {}
    for name in pairs((self.dbRoot.profiles and self.dbRoot.profiles.named) or {}) do
        names[#names + 1] = name
    end

    table.sort(names)
    return names
end

function Core:GetProfileChoices()
    local values = {
        [PROFILE_KEY_GLOBAL] = "全局配置",
    }

    for _, profileName in ipairs(self:GetNamedProfileNames()) do
        values[profileName] = profileName
    end

    return values
end

function Core:GetCurrentCharacterKey()
    return self.currentCharacterKey
end

function Core:GetCurrentCharacterProfileKey()
    self.dbRoot.profileAssignments = self.dbRoot.profileAssignments or {}

    local assigned = self.dbRoot.profileAssignments[self.currentCharacterKey]
    if assigned and self:GetNamedProfile(assigned, false) then
        return assigned
    end

    self.dbRoot.profileAssignments[self.currentCharacterKey] = nil
    return PROFILE_KEY_GLOBAL
end

function Core:SetCurrentCharacterProfileKey(profileKey)
    self.dbRoot.profileAssignments = self.dbRoot.profileAssignments or {}

    if not profileKey or profileKey == PROFILE_KEY_GLOBAL then
        self.dbRoot.profileAssignments[self.currentCharacterKey] = nil
    elseif self:GetNamedProfile(profileKey, false) then
        self.dbRoot.profileAssignments[self.currentCharacterKey] = profileKey
    end

    self:RefreshActiveDatabase()
end

function Core:ResolveProfile(profileKey)
    if not profileKey or profileKey == PROFILE_KEY_GLOBAL then
        return self:GetGlobalProfile()
    end

    local profile = self:GetNamedProfile(profileKey, false)
    if profile then
        return profile
    end

    return self:GetGlobalProfile()
end

function Core:RefreshActiveDatabase()
    self.db = self:ResolveProfile(self:GetCurrentCharacterProfileKey())
end

function Core:CreateNamedProfile(profileName, sourceProfileKey)
    local normalized, errorMessage = NormalizeProfileName(profileName)
    if not normalized then
        return nil, errorMessage
    end

    if self:GetNamedProfile(normalized, false) then
        return nil, "配置名称已存在。"
    end

    local source = self:ResolveProfile(sourceProfileKey)
    self.dbRoot.profiles.named[normalized] = CloneTable(source)
    ApplyDefaults(self.dbRoot.profiles.named[normalized], NS.DEFAULTS)
    return normalized
end

function Core:RenameNamedProfile(oldName, newName)
    local oldProfile, oldError = self:GetNamedProfile(oldName, false)
    if not oldProfile then
        return nil, oldError or "要重命名的配置不存在。"
    end

    local normalized, errorMessage = NormalizeProfileName(newName)
    if not normalized then
        return nil, errorMessage
    end

    if normalized ~= oldName and self:GetNamedProfile(normalized, false) then
        return nil, "新的配置名称已存在。"
    end

    self.dbRoot.profiles.named[normalized] = oldProfile
    if normalized ~= oldName then
        self.dbRoot.profiles.named[oldName] = nil
        for characterKey, profileKey in pairs(self.dbRoot.profileAssignments or {}) do
            if profileKey == oldName then
                self.dbRoot.profileAssignments[characterKey] = normalized
            end
        end
    end

    self:RefreshActiveDatabase()
    return normalized
end

function Core:DeleteNamedProfile(profileName)
    local profile = self:GetNamedProfile(profileName, false)
    if not profile then
        return false, "要删除的配置不存在。"
    end

    self.dbRoot.profiles.named[profileName] = nil
    for characterKey, assignedProfile in pairs(self.dbRoot.profileAssignments or {}) do
        if assignedProfile == profileName then
            self.dbRoot.profileAssignments[characterKey] = nil
        end
    end

    self:RefreshActiveDatabase()
    return true
end

function Core:ExportProfile(profileKey)
    local serialized = SerializeValue(self:ResolveProfile(profileKey))
    return PROFILE_EXPORT_PREFIX .. Base64Encode(serialized)
end

function Core:ImportProfile(profileKey, text)
    local imported, errorMessage = DeserializeProfile(text)
    if not imported then
        return false, errorMessage
    end

    local targetKey = profileKey or PROFILE_KEY_GLOBAL
    if targetKey == PROFILE_KEY_GLOBAL then
        return false, "全局配置不能直接导入覆盖。"
    end

    local target = CloneTable(imported)
    ApplyDefaults(target, NS.DEFAULTS)

    local normalized, normalizeError = NormalizeProfileName(targetKey)
    if not normalized then
        return false, normalizeError
    end

    if not self:GetNamedProfile(normalized, false) then
        return false, "导入目标配置不存在。"
    end

    self.dbRoot.profiles.named[normalized] = target

    self:RefreshActiveDatabase()
    return true
end

-- 兼容上一版“当前角色独立配置”的调用方式。
function Core:DoesCurrentCharacterUseOwnProfile()
    return self:GetCurrentCharacterProfileKey() ~= PROFILE_KEY_GLOBAL
end

function Core:SetCurrentCharacterUseOwnProfile(enabled)
    if enabled then
        local profileKey = self:GetCurrentCharacterProfileKey()
        if profileKey == PROFILE_KEY_GLOBAL then
            local newName = self:FindAvailableProfileName(self.currentCharacterKey)
            local created, errorMessage = self:CreateNamedProfile(newName, PROFILE_KEY_GLOBAL)
            if not created then
                return nil, errorMessage
            end
            self:SetCurrentCharacterProfileKey(created)
            return created
        end

        return profileKey
    end

    self:SetCurrentCharacterProfileKey(PROFILE_KEY_GLOBAL)
    return PROFILE_KEY_GLOBAL
end

function Core:CopyGlobalToCurrentCharacter()
    local profileKey = self:GetCurrentCharacterProfileKey()
    if profileKey == PROFILE_KEY_GLOBAL then
        profileKey = self:SetCurrentCharacterUseOwnProfile(true)
    end

    if not profileKey or profileKey == PROFILE_KEY_GLOBAL then
        return nil
    end

    self.dbRoot.profiles.named[profileKey] = CloneTable(self:GetGlobalProfile())
    ApplyDefaults(self.dbRoot.profiles.named[profileKey], NS.DEFAULTS)
    self:RefreshActiveDatabase()
    return self.dbRoot.profiles.named[profileKey]
end

function Core:CopyCurrentProfileToGlobal()
    self.dbRoot.profiles.global = CloneTable(self.db or self:GetGlobalProfile())
    ApplyDefaults(self.dbRoot.profiles.global, NS.DEFAULTS)
    self:RefreshActiveDatabase()
    return self.dbRoot.profiles.global
end

function Core:ExportGlobalProfile()
    return self:ExportProfile(PROFILE_KEY_GLOBAL)
end

function Core:ImportGlobalProfile(text)
    return self:ImportProfile(PROFILE_KEY_GLOBAL, text)
end

function Core:ResetQuickWaypointConfig()
    self.db.mapAssist = self.db.mapAssist or {}
    self.db.mapAssist.quickWaypoint = CloneTable(NS.DEFAULTS.mapAssist.quickWaypoint)
    return self.db.mapAssist.quickWaypoint
end

function Core:ResetMapIDDisplayConfig()
    self.db.mapAssist = self.db.mapAssist or {}
    self.db.mapAssist.mapIDDisplay = CloneTable(NS.DEFAULTS.mapAssist.mapIDDisplay)
    return self.db.mapAssist.mapIDDisplay
end

function Core:ResetAppearanceConfig()
    self.db.general = self.db.general or {}
    self.db.general.appearance = CloneTable(NS.DEFAULTS.general.appearance)
    return self.db.general.appearance
end

function Core:ResetQuickChatConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.quickChat = CloneTable(NS.DEFAULTS.interfaceEnhance.quickChat)
    return self.db.interfaceEnhance.quickChat
end

function Core:ResetMouseTooltipConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.mouseTooltip = CloneTable(NS.DEFAULTS.interfaceEnhance.mouseTooltip)
    return self.db.interfaceEnhance.mouseTooltip
end

function Core:ResetDistanceMonitorConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.distanceMonitor = CloneTable(NS.DEFAULTS.interfaceEnhance.distanceMonitor)
    return self.db.interfaceEnhance.distanceMonitor
end

function Core:ResetRaidMarkersConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.raidMarkers = CloneTable(NS.DEFAULTS.interfaceEnhance.raidMarkers)
    return self.db.interfaceEnhance.raidMarkers
end

function Core:ResetGameBarConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.gameBar = CloneTable(NS.DEFAULTS.interfaceEnhance.gameBar)
    return self.db.interfaceEnhance.gameBar
end

function Core:ResetCursorTrailConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.cursorTrail = CloneTable(NS.DEFAULTS.interfaceEnhance.cursorTrail)
    return self.db.interfaceEnhance.cursorTrail
end

function Core:ResetSpecTalentBarConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.specTalentBar = CloneTable(NS.DEFAULTS.interfaceEnhance.specTalentBar)
    return self.db.interfaceEnhance.specTalentBar
end

function Core:ResetQuestToolsConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.questTools = CloneTable(NS.DEFAULTS.interfaceEnhance.questTools)
    return self.db.interfaceEnhance.questTools
end

function Core:ResetEventTrackerConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.eventTracker = CloneTable(NS.DEFAULTS.interfaceEnhance.eventTracker)
    return self.db.interfaceEnhance.eventTracker
end

function Core:ResetAttributeDisplayConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.attributeDisplay = CloneTable(NS.DEFAULTS.interfaceEnhance.attributeDisplay)
    return self.db.interfaceEnhance.attributeDisplay
end

function Core:ResetCurrencyDisplayConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.currencyDisplay = CloneTable(NS.DEFAULTS.interfaceEnhance.currencyDisplay)
    return self.db.interfaceEnhance.currencyDisplay
end

function Core:ResetPerformanceMonitorConfig()
    self.db.interfaceEnhance = self.db.interfaceEnhance or {}
    self.db.interfaceEnhance.performanceMonitor = CloneTable(NS.DEFAULTS.interfaceEnhance.performanceMonitor)
    return self.db.interfaceEnhance.performanceMonitor
end

function Core:ResetTrinketMonitorConfig()
    self.db.combatAssist = self.db.combatAssist or {}
    self.db.combatAssist.trinketMonitor = CloneTable(NS.DEFAULTS.combatAssist.trinketMonitor)
    return self.db.combatAssist.trinketMonitor
end

function Core:ResetQuickFocusConfig()
    self.db.combatAssist = self.db.combatAssist or {}
    self.db.combatAssist.quickFocus = CloneTable(NS.DEFAULTS.combatAssist.quickFocus)
    return self.db.combatAssist.quickFocus
end

function Core:ResetMageShatterIndicatorConfig()
    self.db.classAssist = self.db.classAssist or {}
    self.db.classAssist.mage = self.db.classAssist.mage or {}
    self.db.classAssist.mage.shatterIndicator = CloneTable(NS.DEFAULTS.classAssist.mage.shatterIndicator)
    return self.db.classAssist.mage.shatterIndicator
end
