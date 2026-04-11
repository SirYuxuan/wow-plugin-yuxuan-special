local _, NS = ...
local Core = NS.Core

local CHANNEL_CHOICES = {
    AUTO = "自动",
    PARTY = "小队",
    RAID = "团队",
    INSTANCE_CHAT = "副本",
    SAY = "说",
    YELL = "喊",
}

local function GetModule()
    return NS.Modules.ClassAssist and NS.Modules.ClassAssist.UtilityAnnouncer
end

local function GetConfig()
    return Core:GetConfig("classAssist", "utilityAnnouncer")
end

local function Refresh(notifyOptions)
    local module = GetModule()
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function IsCurrentClass(classFile)
    local module = GetModule()
    return module and module.IsCurrentClass and module:IsCurrentClass(classFile)
end

local function BuildSpellToggleArgs(classFile)
    local args = {}
    local module = GetModule()
    local entries = module and module.GetClassEntries and module:GetClassEntries(classFile) or {}

    for index, entryInfo in ipairs(entries) do
        local spellKey = entryInfo.key
        local entry = entryInfo.data

        args[spellKey] = {
            type = "toggle",
            order = index * 10,
            width = 1.2,
            name = entry.label,
            desc = entry.detail,
            disabled = function()
                return not GetConfig().enabled
            end,
            get = function()
                return GetConfig().spells[spellKey] ~= false
            end,
            set = function(_, value)
                GetConfig().spells[spellKey] = value and true or false
                Refresh(false)
            end,
        }
    end

    if next(args) then
        return args
    end

    return {
        empty = {
            type = "description",
            order = 10,
            fontSize = "medium",
            name = "|cFF888888当前还没有可配置的技能。|r",
        },
    }
end

function NS.BuildClassUtilityAnnouncerOptions()
    local module = GetModule()

    return {
        type = "group",
        name = "职业技能提示",
        order = 10,
        args = {
            stateRow = {
                type = "group",
                order = 10,
                name = "",
                layout = "row",
                args = {
                    enabled = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "启用职业技能提示",
                        get = function()
                            return GetConfig().enabled
                        end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            Refresh(true)
                        end,
                    },
                    channel = {
                        type = "select",
                        order = 2,
                        width = 1.0,
                        name = "发送频道",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = CHANNEL_CHOICES,
                        get = function()
                            return GetConfig().channel or "AUTO"
                        end,
                        set = function(_, value)
                            GetConfig().channel = value
                            Refresh(false)
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 3,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetClassUtilityAnnouncerConfig()
                            Refresh(true)
                        end,
                    },
                },
            },
            description = {
                type = "description",
                order = 15,
                fontSize = "medium",
                name = "监听当前角色的职业团队技能，施放成功后自动在队伍频道提示。自动频道会优先选择副本、小队或团队。",
            },
            generalGroup = {
                type = "group",
                order = 20,
                name = "通用设置",
                inline = true,
                disabled = function()
                    return not GetConfig().enabled
                end,
                args = {
                    prefix = {
                        type = "input",
                        order = 1,
                        width = 1.6,
                        name = "提示前缀",
                        get = function()
                            return GetConfig().prefix or ""
                        end,
                        set = function(_, value)
                            GetConfig().prefix = value or ""
                            Refresh(false)
                        end,
                    },
                    throttleSeconds = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "重复节流",
                        min = 0,
                        max = 10,
                        step = 1,
                        get = function()
                            return GetConfig().throttleSeconds or 0
                        end,
                        set = function(_, value)
                            GetConfig().throttleSeconds = value
                            Refresh(false)
                        end,
                    },
                },
            },
            mageGroup = {
                type = "group",
                order = 30,
                name = module and module.GetClassLabel and module:GetClassLabel("MAGE") or "法师",
                inline = true,
                disabled = function()
                    return not GetConfig().enabled or not IsCurrentClass("MAGE")
                end,
                disabledTip = "当前角色不是法师",
                args = BuildSpellToggleArgs("MAGE"),
            },
            warlockGroup = {
                type = "group",
                order = 40,
                name = module and module.GetClassLabel and module:GetClassLabel("WARLOCK") or "术士",
                inline = true,
                disabled = function()
                    return not GetConfig().enabled or not IsCurrentClass("WARLOCK")
                end,
                disabledTip = "当前角色不是术士",
                args = BuildSpellToggleArgs("WARLOCK"),
            },
        },
    }
end
