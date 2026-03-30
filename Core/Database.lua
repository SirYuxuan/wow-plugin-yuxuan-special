local _, NS = ...
local Core = NS.Core

--[[
数据库按 模块 -> 功能 分层 避免后续功能一多就堆成平铺字段
当前结构示意

YuXuanSpecialDB = {
    mapAssist = {
        quickWaypoint = { ... }
    },
    interfaceEnhance = {
        quickChat = { ... }
    },
    combatAssist = {
        trinketMonitor = { ... }
    },
    classAssist = {
        mage = {
            shatterIndicator = { ... }
        }
    }
}
]]

NS.DEFAULTS = {
    general = {
        appearance = {
            fontPreset = "CHAT",
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
        local keyType = type(key)
        local serializedKey

        if keyType == "number" then
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

local function DeserializeProfile(text)
    local rawText = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if rawText == "" then
        return nil, "导入内容不能为空。"
    end

    local loader
    if loadstring then
        loader = loadstring("return " .. rawText)
    elseif load then
        loader = load("return " .. rawText, "YuXuanSpecialImport", "t", {})
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

function Core:InitializeDatabase()
    YuXuanSpecialDB = YuXuanSpecialDB or {}
    self.dbRoot = YuXuanSpecialDB
    self.currentCharacterKey = GetCharacterKey()

    self:MigrateLegacyDatabase()

    self.dbRoot.profileModes = self.dbRoot.profileModes or {}
    self.dbRoot.profiles = self.dbRoot.profiles or {}
    self.dbRoot.profiles.characters = self.dbRoot.profiles.characters or {}
    self.dbRoot.profiles.global = self.dbRoot.profiles.global or CloneTable(NS.DEFAULTS)

    ApplyDefaults(self.dbRoot.profiles.global, NS.DEFAULTS)
    self:RefreshActiveDatabase()
end

function Core:GetConfig(...)
    local current = self.db
    for index = 1, select("#", ...) do
        current = current and current[select(index, ...)]
    end
    return current
end

function Core:MigrateLegacyDatabase()
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
            characters = {},
        }
    end
end

function Core:RefreshActiveDatabase()
    if self:DoesCurrentCharacterUseOwnProfile() then
        self.db = self:GetCharacterProfile(self.currentCharacterKey, true)
    else
        self.db = self:GetGlobalProfile()
    end
end

function Core:GetCurrentCharacterKey()
    return self.currentCharacterKey
end

function Core:GetGlobalProfile()
    self.dbRoot.profiles = self.dbRoot.profiles or {}
    self.dbRoot.profiles.global = self.dbRoot.profiles.global or CloneTable(NS.DEFAULTS)
    ApplyDefaults(self.dbRoot.profiles.global, NS.DEFAULTS)
    return self.dbRoot.profiles.global
end

function Core:GetCharacterProfile(characterKey, createIfMissing)
    local key = characterKey or self.currentCharacterKey
    self.dbRoot.profiles = self.dbRoot.profiles or {}
    self.dbRoot.profiles.characters = self.dbRoot.profiles.characters or {}

    local profile = self.dbRoot.profiles.characters[key]
    if not profile and createIfMissing then
        profile = CloneTable(self.db or self:GetGlobalProfile())
        self.dbRoot.profiles.characters[key] = profile
    end

    if profile then
        ApplyDefaults(profile, NS.DEFAULTS)
    end

    return profile
end

function Core:DoesCurrentCharacterUseOwnProfile()
    local profileModes = self.dbRoot and self.dbRoot.profileModes or {}
    return profileModes and profileModes[self.currentCharacterKey] == "CHARACTER"
end

function Core:SetCurrentCharacterUseOwnProfile(enabled)
    self.dbRoot.profileModes = self.dbRoot.profileModes or {}

    if enabled then
        if not self:GetCharacterProfile(self.currentCharacterKey, false) then
            self.dbRoot.profiles.characters[self.currentCharacterKey] = CloneTable(self.db or self:GetGlobalProfile())
        end
        self.dbRoot.profileModes[self.currentCharacterKey] = "CHARACTER"
    else
        self.dbRoot.profileModes[self.currentCharacterKey] = nil
    end

    self:RefreshActiveDatabase()
end

function Core:CopyGlobalToCurrentCharacter()
    local profile = CloneTable(self:GetGlobalProfile())
    self.dbRoot.profiles.characters[self.currentCharacterKey] = profile
    ApplyDefaults(profile, NS.DEFAULTS)

    if self:DoesCurrentCharacterUseOwnProfile() then
        self.db = profile
    end

    return profile
end

function Core:CopyCurrentProfileToGlobal()
    local profile = CloneTable(self.db or self:GetGlobalProfile())
    self.dbRoot.profiles.global = profile
    ApplyDefaults(profile, NS.DEFAULTS)

    if not self:DoesCurrentCharacterUseOwnProfile() then
        self.db = profile
    end

    return profile
end

function Core:ExportGlobalProfile()
    return SerializeValue(self:GetGlobalProfile())
end

function Core:ImportGlobalProfile(text)
    local imported, errorMessage = DeserializeProfile(text)
    if not imported then
        return false, errorMessage
    end

    local profile = CloneTable(imported)
    ApplyDefaults(profile, NS.DEFAULTS)
    self.dbRoot.profiles.global = profile

    if not self:DoesCurrentCharacterUseOwnProfile() then
        self.db = profile
    end

    return true
end

function Core:ResetQuickWaypointConfig()
    self.db.mapAssist = self.db.mapAssist or {}
    self.db.mapAssist.quickWaypoint = CloneTable(NS.DEFAULTS.mapAssist.quickWaypoint)
    return self.db.mapAssist.quickWaypoint
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
