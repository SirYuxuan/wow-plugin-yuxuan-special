local _, NS = ...
local Core = NS.Core
local C_ChatInfo = rawget(_G, "C_ChatInfo")
local C_Spell = rawget(_G, "C_Spell")
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local LE_PARTY_CATEGORY_INSTANCE = _G.LE_PARTY_CATEGORY_INSTANCE
local SendChatMessage = _G.SendChatMessage
local UnitClass = _G.UnitClass
local UnitName = _G.UnitName

local UtilityAnnouncer = {}
NS.Modules.InterfaceEnhance.UtilityAnnouncer = UtilityAnnouncer

local RULES = {
    {
        key = "mageRefreshment",
        classFile = "MAGE",
        label = "法师面包/餐桌",
        defaultMessage = "面包已放好，请自取。",
        spellIDs = {
            [190336] = true,
            [42955] = true,
        },
        namePatterns = {
            "Refreshment",
            "造餐",
            "餐桌",
        },
    },
    {
        key = "magePortal",
        classFile = "MAGE",
        label = "法师传送门",
        defaultMessage = "传送门已开启：{spell}。",
        namePrefixes = {
            "Portal:",
            "传送门：",
        },
    },
    {
        key = "mageIntellect",
        classFile = "MAGE",
        label = "法师智力",
        defaultMessage = "已补智力。",
        spellIDs = {
            [1459] = true,
        },
        namePatterns = {
            "Arcane Intellect",
            "奥术智慧",
        },
    },
    {
        key = "warlockSoulwell",
        classFile = "WARLOCK",
        label = "术士糖",
        defaultMessage = "糖已放好，请自取。",
        spellIDs = {
            [29893] = true,
        },
        namePatterns = {
            "Soulwell",
            "灵魂之井",
        },
    },
    {
        key = "warlockGateway",
        classFile = "WARLOCK",
        label = "术士恶魔门",
        defaultMessage = "恶魔门已放好。",
        spellIDs = {
            [111771] = true,
        },
        namePatterns = {
            "Demonic Gateway",
            "恶魔传送门",
        },
    },
    {
        key = "warlockSummoning",
        classFile = "WARLOCK",
        label = "术士拉人",
        defaultMessage = "已开始拉人，请点门。",
        spellIDs = {
            [698] = true,
        },
        namePatterns = {
            "Ritual of Summoning",
            "召唤仪式",
        },
    },
    {
        key = "priestFortitude",
        classFile = "PRIEST",
        label = "牧师耐力",
        defaultMessage = "已补耐力。",
        spellIDs = {
            [21562] = true,
        },
        namePatterns = {
            "Power Word: Fortitude",
            "真言术：韧",
        },
    },
    {
        key = "druidMark",
        classFile = "DRUID",
        label = "德鲁伊爪子",
        defaultMessage = "已上爪子。",
        spellIDs = {
            [1126] = true,
        },
        namePatterns = {
            "Mark of the Wild",
            "野性印记",
        },
    },
}

local ruleMap = {}
for _, rule in ipairs(RULES) do
    ruleMap[rule.key] = rule
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "utilityAnnouncer")
end

local function EnsureConfig()
    local config = GetConfig()
    config.rules = config.rules or {}
    config.messages = config.messages or {}
    if config.enabled == nil then
        config.enabled = false
    end
    if config.channel == nil or config.channel == "" then
        config.channel = "AUTO"
    end
    if config.minInterval == nil then
        config.minInterval = 2
    end
    if config.announceInSolo == nil then
        config.announceInSolo = false
    end
    if config.template == nil or config.template == "" then
        config.template = "【雨轩工具箱】{text}"
    end

    for _, rule in ipairs(RULES) do
        if config.rules[rule.key] == nil then
            config.rules[rule.key] = true
        end
        if config.messages[rule.key] == nil or config.messages[rule.key] == "" then
            config.messages[rule.key] = rule.defaultMessage
        end
    end

    return config
end

local function GetSpellNameByID(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName and spellName ~= "" then
            return spellName
        end
    end

    local getSpellInfo = rawget(_G, "GetSpellInfo")
    if getSpellInfo then
        local spellName = getSpellInfo(spellID)
        if spellName and spellName ~= "" then
            return spellName
        end
    end

    return tostring(spellID or "")
end

local function GetPlayerClassFile()
    return select(2, UnitClass("player"))
end

local function GetAnnounceChannel(channelMode)
    if channelMode == "INSTANCE" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or nil
    end
    if channelMode == "RAID" then
        return IsInRaid() and "RAID" or nil
    end
    if channelMode == "PARTY" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        end
        return IsInGroup() and "PARTY" or nil
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function SendGroupChatMessage(message, channel)
    if not message or message == "" or not channel or channel == "" then
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
        return true
    end

    if SendChatMessage then
        SendChatMessage(message, channel)
        return true
    end

    return false
end

local function NormalizeText(text)
    return string.lower(tostring(text or ""))
end

local function StartsWith(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function RuleMatches(rule, spellID, spellName)
    if not rule then
        return false
    end
    if rule.classFile and rule.classFile ~= GetPlayerClassFile() then
        return false
    end

    if rule.spellIDs and rule.spellIDs[tonumber(spellID) or 0] then
        return true
    end

    local rawName = tostring(spellName or "")
    if rawName == "" then
        return false
    end

    local lowered = NormalizeText(rawName)

    for _, prefix in ipairs(rule.namePrefixes or {}) do
        if StartsWith(rawName, prefix) or StartsWith(lowered, NormalizeText(prefix)) then
            return true
        end
    end

    for _, pattern in ipairs(rule.namePatterns or {}) do
        if rawName:find(pattern, 1, true) or lowered:find(NormalizeText(pattern), 1, true) then
            return true
        end
    end

    return false
end

function UtilityAnnouncer:SanitizeChatMessage(message)
    local text = tostring(message or "")
    text = text:gsub("\r", " "):gsub("\n", " ")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    return text
end

function UtilityAnnouncer:FormatMessage(rule, spellName)
    local config = EnsureConfig()
    local messages = config.messages or {}
    local baseText = messages[rule.key] or rule.defaultMessage or "{spell} 已释放。"
    local text = baseText
        :gsub("{spell}", tostring(spellName or rule.label or ""))
        :gsub("{player}", tostring(UnitName("player") or ""))

    local template = tostring(config.template or "【雨轩工具箱】{text}")
    return template
        :gsub("{text}", text)
        :gsub("{spell}", tostring(spellName or rule.label or ""))
        :gsub("{player}", tostring(UnitName("player") or ""))
end

function UtilityAnnouncer:Announce(rule, spellName)
    local config = EnsureConfig()
    if not config.enabled then
        return
    end

    local message = self:SanitizeChatMessage(self:FormatMessage(rule, spellName))
    local channel = GetAnnounceChannel(config.channel or "AUTO")
    if channel and SendGroupChatMessage(message, channel) then
        return
    end

    if config.announceInSolo then
        print(message)
    end
end

function UtilityAnnouncer:HandleSpellcastSucceeded(unitTarget, _, spellID)
    if unitTarget ~= "player" then
        return
    end

    local config = EnsureConfig()
    if not config.enabled then
        return
    end

    local spellName = GetSpellNameByID(spellID)
    local now = GetTime and GetTime() or 0
    local minInterval = math.max(0.5, tonumber(config.minInterval) or 2)
    self.lastAnnounceAt = self.lastAnnounceAt or {}

    for _, rule in ipairs(RULES) do
        if config.rules and config.rules[rule.key] ~= false and RuleMatches(rule, spellID, spellName) then
            local lastTime = self.lastAnnounceAt[rule.key] or 0
            if (now - lastTime) >= minInterval then
                self.lastAnnounceAt[rule.key] = now
                self:Announce(rule, spellName)
            end
            return
        end
    end
end

function UtilityAnnouncer:UpdateEventRegistration()
    self.eventFrame = self.eventFrame or CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, _, ...)
        UtilityAnnouncer:HandleSpellcastSucceeded(...)
    end)
    self.eventFrame:UnregisterAllEvents()

    if EnsureConfig().enabled then
        self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
end

function UtilityAnnouncer:RefreshFromSettings()
    EnsureConfig()
    self:UpdateEventRegistration()
end

function UtilityAnnouncer:OnPlayerLogin()
    self:RefreshFromSettings()
end

function UtilityAnnouncer:GetRuleDefinitions()
    return RULES, ruleMap
end

function UtilityAnnouncer:EnsureConfig()
    return EnsureConfig()
end
