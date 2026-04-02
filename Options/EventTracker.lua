local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "eventTracker")
end

local function Refresh(notifyOptions)
    local module = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.EventTracker
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end
    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function CreateEventToggle(label, key, order)
    return {
        type = "toggle",
        order = order,
        width = 1.1,
        name = label,
        get = function() return GetConfig()[key] end,
        set = function(_, value)
            GetConfig()[key] = value and true or false
            Refresh(false)
        end,
    }
end

function NS.BuildEventTrackerOptions()
    return {
        type = "group",
        name = "事件追踪器",
        order = 18,
        childGroups = "tab",
        args = {
            basic = {
                type = "group",
                name = "基础设置",
                order = 10,
                args = {
                    basicRow = {
                        type = "group",
                        order = 1,
                        name = "",
                        layout = "row",
                        args = {
                            enabled = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "启用事件追踪器",
                                get = function() return GetConfig().enabled end,
                                set = function(_, value)
                                    GetConfig().enabled = value and true or false
                                    Refresh(true)
                                end,
                            },
                            alertEnabled = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "提前通知",
                                get = function() return GetConfig().alertEnabled end,
                                set = function(_, value)
                                    GetConfig().alertEnabled = value and true or false
                                    Refresh(false)
                                end,
                            },
                            alertSecond = {
                                type = "range",
                                order = 3,
                                width = 1.0,
                                name = "提前秒数",
                                min = 15,
                                max = 300,
                                step = 5,
                                disabled = function() return not GetConfig().alertEnabled end,
                                get = function() return GetConfig().alertSecond or 60 end,
                                set = function(_, value)
                                    GetConfig().alertSecond = value
                                end,
                            },
                        },
                    },
                    styleRow = {
                        type = "group",
                        order = 2,
                        name = "",
                        layout = "row",
                        args = {
                            fontPreset = {
                                type = "select",
                                order = 1,
                                width = 1.0,
                                name = "字体预设",
                                values = function()
                                    return NS.Options.Private.GetFontOptions()
                                end,
                                get = function() return GetConfig().fontPreset end,
                                set = function(_, value)
                                    GetConfig().fontPreset = value
                                    Refresh(false)
                                end,
                            },
                            fontSize = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "字体大小",
                                min = 9,
                                max = 18,
                                step = 1,
                                get = function() return GetConfig().fontSize or 12 end,
                                set = function(_, value)
                                    GetConfig().fontSize = value
                                    Refresh(false)
                                end,
                            },
                            fontOutline = {
                                type = "toggle",
                                order = 3,
                                width = 1.0,
                                name = "字体描边",
                                get = function() return GetConfig().fontOutline end,
                                set = function(_, value)
                                    GetConfig().fontOutline = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    sizeRow = {
                        type = "group",
                        order = 3,
                        name = "",
                        layout = "row",
                        args = {
                            trackerWidth = {
                                type = "range",
                                order = 1,
                                width = 1.0,
                                name = "追踪器宽度",
                                min = 160,
                                max = 320,
                                step = 5,
                                get = function() return GetConfig().trackerWidth or 220 end,
                                set = function(_, value)
                                    GetConfig().trackerWidth = value
                                    Refresh(false)
                                end,
                            },
                            trackerHeight = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "追踪器高度",
                                min = 22,
                                max = 40,
                                step = 1,
                                get = function() return GetConfig().trackerHeight or 28 end,
                                set = function(_, value)
                                    GetConfig().trackerHeight = value
                                    Refresh(false)
                                end,
                            },
                            backdropAlpha = {
                                type = "range",
                                order = 3,
                                width = 1.0,
                                name = "背景透明度",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return GetConfig().backdropAlpha or 0.6 end,
                                set = function(_, value)
                                    GetConfig().backdropAlpha = value
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    reset = {
                        type = "execute",
                        order = 4,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetEventTrackerConfig()
                            Refresh(true)
                        end,
                    },
                },
            },
            events = {
                type = "group",
                name = "事件开关",
                order = 20,
                args = {
                    midnightHeader = {
                        type = "header",
                        order = 10,
                        name = "至暗之夜",
                    },
                    weeklyMN = CreateEventToggle("周常任务（至暗之夜）", "weeklyMN", 11),
                    professionsWeeklyMN = CreateEventToggle("专业周常（至暗之夜）", "professionsWeeklyMN", 12),
                    stormarionAssault = CreateEventToggle("斯托玛兰突袭战", "stormarionAssault", 13),
                    twwHeader = {
                        type = "header",
                        order = 20,
                        name = "地心之战",
                    },
                    weeklyTWW = CreateEventToggle("周常任务（地心之战）", "weeklyTWW", 21),
                    nightfall = CreateEventToggle("夜幕激斗", "nightfall", 22),
                    theaterTroupe = CreateEventToggle("剧团演出", "theaterTroupe", 23),
                    ecologicalSuccession = CreateEventToggle("生态重构", "ecologicalSuccession", 24),
                    ringingDeeps = CreateEventToggle("回响深渊", "ringingDeeps", 25),
                    spreadingTheLight = CreateEventToggle("散布光耀", "spreadingTheLight", 26),
                    underworldOperative = CreateEventToggle("暗影行动", "underworldOperative", 27),
                },
            },
        },
    }
end
