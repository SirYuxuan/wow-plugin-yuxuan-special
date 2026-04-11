local _, NS = ...
local Core = NS.Core

local UtilityAnnouncer = {}
NS.Modules.ClassAssist.UtilityAnnouncer = UtilityAnnouncer

local COMBATLOG_OBJECT_AFFILIATION_MINE = rawget(_G, "COMBATLOG_OBJECT_AFFILIATION_MINE")
local CombatLogGetCurrentEventInfo = rawget(_G, "CombatLogGetCurrentEventInfo")
local CreateFrame = rawget(_G, "CreateFrame")
local GetTime = rawget(_G, "GetTime")
local LE_PARTY_CATEGORY_INSTANCE = rawget(_G, "LE_PARTY_CATEGORY_INSTANCE")
local SendChatMessage = rawget(_G, "SendChatMessage")
local bitBand = (bit and bit.band) or (bit32 and bit32.band)

local CLASS_ORDER = {
    "MAGE",
    "WARLOCK",
}

local CLASS_LABELS = {
    MAGE = "法师",
    WARLOCK = "术士",
}

local SPELL_DEFINITIONS = {
    conjureRefreshment = {
        order = 10,
        classFile = "MAGE",
        label = "法师面包",
        detail = "制造餐点",
        announceText = "面包已放好，需要的自取。",
        spellIDs = {
            190336,
            42955,
        },
        aliases = {
            "制造餐点",
            "制造魔法点心",
            "Conjure Refreshment",
            "Refreshment",
        },
    },
    ritualOfSouls = {
        order = 20,
        classFile = "WARLOCK",
        label = "术士糖",
        detail = "灵魂之井",
        announceText = "糖已放好，需要的自取。",
        spellIDs = {
            29893,
            34150,
        },
        aliases = {
            "灵魂之井",
            "Ritual of Souls",
            "Soulwell",
        },
    },
    demonicGateway = {
        order = 30,
        classFile = "WARLOCK",
        label = "术士门",
        detail = "恶魔之门",
        announceText = "门已放好，注意走位。",
        spellIDs = {
            111771,
        },
        aliases = {
            "恶魔之门",
            "Demonic Gateway",
        },
    },
    ritualOfSummoning = {
        order = 40,
        classFile = "WARLOCK",
        label = "术士拉人",
        detail = "召唤仪式",
        announceText = "拉人仪式已开，需要的点一下。",
        spellIDs = {
            698,
        },
        aliases = {
            "召唤仪式",
            "Ritual of Summoning",
        },
    },
}

local function GetConfig()
    return Core:GetConfig("classAssist", "utilityAnnouncer")
end

local function NormalizeSpellName(name)
    return tostring(name or ""):gsub("%s+", ""):lower()
end

local function GetPlayerClass()
    local _, classFile = UnitClass("player")
    return classFile
end

local function GetSpellNameByID(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
end

function UtilityAnnouncer:GetClassOrder()
    return CLASS_ORDER
end

function UtilityAnnouncer:GetClassLabel(classFile)
    return CLASS_LABELS[classFile] or classFile or ""
end

function UtilityAnnouncer:GetSpellDefinition(key)
    return SPELL_DEFINITIONS[key]
end

function UtilityAnnouncer:GetClassEntries(classFile)
    local entries = {}

    for key, entry in pairs(SPELL_DEFINITIONS) do
        if entry.classFile == classFile then
            entries[#entries + 1] = {
                key = key,
                data = entry,
            }
        end
    end

    table.sort(entries, function(left, right)
        return (left.data.order or 0) < (right.data.order or 0)
    end)

    return entries
end

function UtilityAnnouncer:IsCurrentClass(classFile)
    return GetPlayerClass() == classFile
end

function UtilityAnnouncer:IsSpellEnabled(key)
    local config = GetConfig()
    local spellConfig = config and config.spells
    if type(spellConfig) ~= "table" then
        return false
    end

    return spellConfig[key] ~= false
end

function UtilityAnnouncer:BuildSpellLookups()
    self.spellIDLookup = {}
    self.spellNameLookup = {}

    for key, entry in pairs(SPELL_DEFINITIONS) do
        if type(entry.spellIDs) == "table" then
            for _, spellID in ipairs(entry.spellIDs) do
                if spellID then
                    self.spellIDLookup[spellID] = key

                    local spellName = GetSpellNameByID(spellID)
                    if spellName and spellName ~= "" then
                        self.spellNameLookup[NormalizeSpellName(spellName)] = key
                    end
                end
            end
        end

        if type(entry.aliases) == "table" then
            for _, alias in ipairs(entry.aliases) do
                if alias and alias ~= "" then
                    self.spellNameLookup[NormalizeSpellName(alias)] = key
                end
            end
        end
    end
end

function UtilityAnnouncer:FindSpellKey(spellID, spellName)
    if spellID and self.spellIDLookup and self.spellIDLookup[spellID] then
        return self.spellIDLookup[spellID]
    end

    local normalizedName = NormalizeSpellName(spellName)
    if normalizedName ~= "" and self.spellNameLookup then
        return self.spellNameLookup[normalizedName]
    end
end

function UtilityAnnouncer:GetPreferredChannel()
    local config = GetConfig()
    local configuredChannel = config and config.channel or "AUTO"

    if configuredChannel ~= "AUTO" then
        return configuredChannel
    end

    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid and IsInRaid() then
        return "RAID"
    end

    if IsInGroup and IsInGroup() then
        return "PARTY"
    end

    return nil
end

function UtilityAnnouncer:BuildAnnounceMessage(spellKey)
    local config = GetConfig()
    local entry = SPELL_DEFINITIONS[spellKey]
    if not entry then
        return nil
    end

    local prefix = tostring(config and config.prefix or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local body = entry.announceText or entry.label or ""

    if prefix ~= "" then
        return string.format("%s %s", prefix, body)
    end

    return body
end

function UtilityAnnouncer:CanAnnounce(spellKey)
    local config = GetConfig()
    local entry = SPELL_DEFINITIONS[spellKey]
    if not (config and config.enabled and entry) then
        return false
    end

    if entry.classFile ~= GetPlayerClass() then
        return false
    end

    if not self:IsSpellEnabled(spellKey) then
        return false
    end

    local channel = self:GetPreferredChannel()
    if not channel or not SendChatMessage then
        return false
    end

    local now = GetTime and GetTime() or 0
    local throttle = tonumber(config.throttleSeconds) or 0
    self.lastAnnounceAt = self.lastAnnounceAt or {}

    local lastTime = self.lastAnnounceAt[spellKey]
    if lastTime and throttle > 0 and (now - lastTime) < throttle then
        return false
    end

    return true
end

function UtilityAnnouncer:Announce(spellKey)
    if not self:CanAnnounce(spellKey) then
        return
    end

    local message = self:BuildAnnounceMessage(spellKey)
    local channel = self:GetPreferredChannel()
    if not (message and message ~= "" and channel) then
        return
    end

    SendChatMessage(message, channel)
    self.lastAnnounceAt[spellKey] = GetTime and GetTime() or 0
end

function UtilityAnnouncer:IsPlayerCast(sourceGUID, sourceFlags)
    local playerGUID = UnitGUID and UnitGUID("player")
    if playerGUID and sourceGUID == playerGUID then
        return true
    end

    if bitBand and COMBATLOG_OBJECT_AFFILIATION_MINE and sourceFlags then
        return bitBand(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
    end

    return false
end

function UtilityAnnouncer:HandleCombatLog()
    if not CombatLogGetCurrentEventInfo then
        return
    end

    local _, subEvent, _, sourceGUID, _, sourceFlags, _, _, _, _, _, spellID, spellName =
        CombatLogGetCurrentEventInfo()

    if subEvent ~= "SPELL_CAST_SUCCESS" then
        return
    end

    if not self:IsPlayerCast(sourceGUID, sourceFlags) then
        return
    end

    local spellKey = self:FindSpellKey(spellID, spellName)
    if spellKey then
        self:Announce(spellKey)
    end
end

function UtilityAnnouncer:EnsureEventFrame()
    if self.eventFrame then
        return self.eventFrame
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            UtilityAnnouncer:HandleCombatLog()
        end
    end)

    self.eventFrame = frame
    return frame
end

function UtilityAnnouncer:HasAnyEnabledSpellForCurrentClass()
    local classFile = GetPlayerClass()
    for key, entry in pairs(SPELL_DEFINITIONS) do
        if entry.classFile == classFile and self:IsSpellEnabled(key) then
            return true
        end
    end

    return false
end

function UtilityAnnouncer:RefreshFromSettings()
    self:BuildSpellLookups()

    local frame = self:EnsureEventFrame()
    frame:UnregisterAllEvents()

    local config = GetConfig()
    if not (config and config.enabled and self:HasAnyEnabledSpellForCurrentClass()) then
        return
    end

    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function UtilityAnnouncer:OnPlayerLogin()
    self:RefreshFromSettings()
end
