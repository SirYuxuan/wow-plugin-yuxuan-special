local _, NS = ...
local Core = NS.Core

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.UtilityAnnouncer
end

local function GetConfig()
    local module = GetModule()
    if module and module.EnsureConfig then
        return module:EnsureConfig()
    end
    return Core:GetConfig("interfaceEnhance", "utilityAnnouncer")
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

local function BuildRuleRow(rule, order)
    return {
        type = "group",
        order = order,
        name = "",
        layout = "row",
        args = {
            [rule.key .. "Enabled"] = {
                type = "toggle",
                order = 1,
                width = 1.0,
                name = rule.label,
                disabled = function()
                    return not GetConfig().enabled
                end,
                get = function()
                    return GetConfig().rules[rule.key] ~= false
                end,
                set = function(_, value)
                    GetConfig().rules[rule.key] = value and true or false
                    Refresh(false)
                end,
            },
            [rule.key .. "Message"] = {
                type = "input",
                order = 2,
                width = 1.8,
                name = "通报文案",
                disabled = function()
                    return not GetConfig().enabled or GetConfig().rules[rule.key] == false
                end,
                get = function()
                    return GetConfig().messages[rule.key] or rule.defaultMessage
                end,
                set = function(_, value)
                    local text = tostring(value or "")
                    GetConfig().messages[rule.key] = text ~= "" and text or rule.defaultMessage
                end,
            },
        },
    }
end

function NS.BuildUtilityAnnouncerOptions()
    local module = GetModule()
    local rules = {}
    if module and module.GetRuleDefinitions then
        rules = module:GetRuleDefinitions()
    end

    local ruleArgs = {}
    local order = 10
    for _, rule in ipairs(rules) do
        ruleArgs[rule.key] = BuildRuleRow(rule, order)
        order = order + 10
    end

    return {
        type = "group",
        name = "团队工具通报",
        order = 18,
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
                        name = "启用团队工具通报",
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
                        name = "通报频道",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = {
                            AUTO = "自动",
                            PARTY = "队伍",
                            RAID = "团队",
                            INSTANCE = "副本小队",
                        },
                        get = function()
                            return GetConfig().channel or "AUTO"
                        end,
                        set = function(_, value)
                            GetConfig().channel = value
                            Refresh(false)
                        end,
                    },
                    minInterval = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "最小间隔",
                        min = 0.5,
                        max = 10,
                        step = 0.5,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().minInterval or 2
                        end,
                        set = function(_, value)
                            GetConfig().minInterval = value
                            Refresh(false)
                        end,
                    },
                },
            },
            extraRow = {
                type = "group",
                order = 20,
                name = "",
                layout = "row",
                args = {
                    announceInSolo = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "单人时打印到聊天框",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().announceInSolo
                        end,
                        set = function(_, value)
                            GetConfig().announceInSolo = value and true or false
                            Refresh(false)
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 2,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetUtilityAnnouncerConfig()
                            Refresh(true)
                        end,
                    },
                },
            },
            template = {
                type = "input",
                order = 30,
                width = 1.8,
                name = "全局模板",
                desc = "可用占位符：{text} {spell} {player}",
                disabled = function()
                    return not GetConfig().enabled
                end,
                get = function()
                    return GetConfig().template or "【雨轩工具箱】{text}"
                end,
                set = function(_, value)
                    local text = tostring(value or "")
                    GetConfig().template = text ~= "" and text or "【雨轩工具箱】{text}"
                end,
            },
            rules = {
                type = "group",
                order = 40,
                name = "监控技能",
                inline = true,
                args = ruleArgs,
            },
        },
    }
end
