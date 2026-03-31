local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("mapAssist", "quickWaypoint")
end

local function GetMapIDConfig()
    return Core:GetConfig("mapAssist", "mapIDDisplay")
end

local ANCHOR_OPTIONS = {
    { value = "MAP_TOP", label = "地图上方" },
    { value = "MAP_BOTTOM", label = "地图下方" },
}

local function RefreshWidget(notifyOptions)
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.RefreshFromSettings then
        quickWaypoint:RefreshFromSettings()
    end

    local mapIDDisplay = NS.Modules.MapAssist and NS.Modules.MapAssist.MapIDDisplay
    if mapIDDisplay and mapIDDisplay.RefreshFromSettings then
        mapIDDisplay:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function GetAnchorOptions()
    return ANCHOR_OPTIONS
end

--[[
地图辅助配置页只描述有哪些项
真正的地图输入框刷新由运行时模块负责
]]

function NS.BuildMapAssistOptions()
    return {
        type = "group",
        name = "地图辅助",
        order = 10,
        args = {
            quickWaypoint = {
                type = "group",
                name = "快捷导航",
                order = 1,
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "在世界地图内嵌一个坐标输入框 用于快速设置当前地图导航点",
                    },
                    usage = {
                        type = "description",
                        order = 2,
                        fontSize = "medium",
                        name = "|cFFCCCCCC支持输入格式|r 12.34 56.78  12.34,56.78  12.34:56.78",
                    },
                    spacer1 = {
                        type = "description",
                        order = 3,
                        name = " ",
                        width = "full",
                    },
                    enabled = {
                        type = "toggle",
                        name = "启用快捷导航输入框",
                        order = 10,
                        width = 1.3,
                        get = function()
                            return GetConfig().enabled
                        end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            RefreshWidget()
                        end,
                    },
                    anchorPreset = {
                        type = "radio",
                        name = "锚点位置",
                        order = 11,
                        compact = true,
                        buttonWidth = 76,
                        values = GetAnchorOptions,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().anchorPreset
                        end,
                        set = function(_, value)
                            GetConfig().anchorPreset = value
                            RefreshWidget()
                        end,
                    },
                    offsetRow = {
                        type = "group",
                        order = 20,
                        name = "",
                        layout = "row",
                        args = {
                            offsetX = {
                                type = "range",
                                name = "X 偏移",
                                order = 1,
                                width = 1.0,
                                min = -1000,
                                max = 1000,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().offsetX
                                end,
                                set = function(_, value)
                                    GetConfig().offsetX = value
                                    RefreshWidget(false)
                                end,
                            },
                            offsetY = {
                                type = "range",
                                name = "Y 偏移",
                                order = 2,
                                width = 1.0,
                                min = -1000,
                                max = 1000,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().offsetY
                                end,
                                set = function(_, value)
                                    GetConfig().offsetY = value
                                    RefreshWidget(false)
                                end,
                            },
                        },
                    },
                    styleRow = {
                        type = "group",
                        order = 22,
                        name = "",
                        layout = "row",
                        args = {
                            fontSize = {
                                type = "range",
                                name = "字体大小",
                                order = 1,
                                width = 1.0,
                                min = 10,
                                max = 24,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().fontSize
                                end,
                                set = function(_, value)
                                    GetConfig().fontSize = value
                                    RefreshWidget(false)
                                end,
                            },
                            bgAlpha = {
                                type = "range",
                                name = "背景透明度",
                                order = 2,
                                width = 1.0,
                                min = 0,
                                max = 100,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().bgAlpha
                                end,
                                set = function(_, value)
                                    GetConfig().bgAlpha = value
                                    RefreshWidget(false)
                                end,
                            },
                        },
                    },
                    spacer3 = {
                        type = "description",
                        order = 24,
                        name = " ",
                        width = "full",
                    },
                    reset = {
                        type = "execute",
                        name = "恢复默认设置",
                        order = 30,
                        width = 1.1,
                        func = function()
                            Core:ResetQuickWaypointConfig()
                            RefreshWidget(true)
                        end,
                    },
                },
            },
            mapIDDisplay = {
                type = "group",
                name = "地图ID",
                order = 2,
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "在世界地图中实时显示当前选中的地图 ID，关闭后不会创建显示面板。",
                    },
                    enabled = {
                        type = "toggle",
                        name = "启用地图ID显示",
                        order = 10,
                        width = 1.2,
                        get = function()
                            return GetMapIDConfig().enabled
                        end,
                        set = function(_, value)
                            GetMapIDConfig().enabled = value and true or false
                            RefreshWidget(true)
                        end,
                    },
                    anchorPreset = {
                        type = "radio",
                        name = "锚点位置",
                        order = 11,
                        compact = true,
                        buttonWidth = 76,
                        values = GetAnchorOptions,
                        disabled = function()
                            return not GetMapIDConfig().enabled
                        end,
                        get = function()
                            return GetMapIDConfig().anchorPreset
                        end,
                        set = function(_, value)
                            GetMapIDConfig().anchorPreset = value
                            RefreshWidget(false)
                        end,
                    },
                    offsetRow = {
                        type = "group",
                        order = 20,
                        name = "",
                        layout = "row",
                        args = {
                            offsetX = {
                                type = "range",
                                name = "X 偏移",
                                order = 1,
                                width = 1.0,
                                min = -1000,
                                max = 1000,
                                step = 1,
                                disabled = function()
                                    return not GetMapIDConfig().enabled
                                end,
                                get = function()
                                    return GetMapIDConfig().offsetX
                                end,
                                set = function(_, value)
                                    GetMapIDConfig().offsetX = value
                                    RefreshWidget(false)
                                end,
                            },
                            offsetY = {
                                type = "range",
                                name = "Y 偏移",
                                order = 2,
                                width = 1.0,
                                min = -1000,
                                max = 1000,
                                step = 1,
                                disabled = function()
                                    return not GetMapIDConfig().enabled
                                end,
                                get = function()
                                    return GetMapIDConfig().offsetY
                                end,
                                set = function(_, value)
                                    GetMapIDConfig().offsetY = value
                                    RefreshWidget(false)
                                end,
                            },
                        },
                    },
                    fontRow = {
                        type = "group",
                        order = 21,
                        name = "",
                        layout = "row",
                        args = {
                            fontPreset = {
                                type = "select",
                                name = "字体",
                                order = 1,
                                width = 1.0,
                                disabled = function()
                                    return not GetMapIDConfig().enabled
                                end,
                                values = function()
                                    return NS.Options.Private.GetFontOptions()
                                end,
                                get = function()
                                    return GetMapIDConfig().fontPreset
                                end,
                                set = function(_, value)
                                    GetMapIDConfig().fontPreset = value
                                    RefreshWidget(false)
                                end,
                            },
                            fontSize = {
                                type = "range",
                                name = "字体大小",
                                order = 2,
                                width = 1.0,
                                min = 10,
                                max = 28,
                                step = 1,
                                disabled = function()
                                    return not GetMapIDConfig().enabled
                                end,
                                get = function()
                                    return GetMapIDConfig().fontSize
                                end,
                                set = function(_, value)
                                    GetMapIDConfig().fontSize = value
                                    RefreshWidget(false)
                                end,
                            },
                        },
                    },
                    styleRow = {
                        type = "group",
                        order = 22,
                        name = "",
                        layout = "row",
                        args = {
                            scale = {
                                type = "range",
                                name = "整体缩放",
                                order = 1,
                                width = 1.0,
                                min = 0.8,
                                max = 1.8,
                                step = 0.05,
                                disabled = function()
                                    return not GetMapIDConfig().enabled
                                end,
                                get = function()
                                    return GetMapIDConfig().scale
                                end,
                                set = function(_, value)
                                    GetMapIDConfig().scale = value
                                    RefreshWidget(false)
                                end,
                            },
                            bgAlpha = {
                                type = "range",
                                name = "背景透明度",
                                order = 2,
                                width = 1.0,
                                min = 0,
                                max = 100,
                                step = 1,
                                disabled = function()
                                    return not GetMapIDConfig().enabled
                                end,
                                get = function()
                                    return GetMapIDConfig().bgAlpha
                                end,
                                set = function(_, value)
                                    GetMapIDConfig().bgAlpha = value
                                    RefreshWidget(false)
                                end,
                            },
                        },
                    },
                    textColor = {
                        type = "color",
                        name = "文字颜色",
                        order = 23,
                        width = 1.0,
                        hasAlpha = false,
                        disabled = function()
                            return not GetMapIDConfig().enabled
                        end,
                        get = function()
                            local color = GetMapIDConfig().textColor or {}
                            return color.r or 1, color.g or 1, color.b or 1, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            local color = GetMapIDConfig().textColor
                            color.r = r
                            color.g = g
                            color.b = b
                            color.a = a or 1
                            RefreshWidget(false)
                        end,
                    },
                    spacer = {
                        type = "description",
                        order = 29,
                        name = " ",
                        width = "full",
                    },
                    reset = {
                        type = "execute",
                        name = "恢复默认设置",
                        order = 30,
                        width = 1.1,
                        func = function()
                            Core:ResetMapIDDisplayConfig()
                            RefreshWidget(true)
                        end,
                    },
                },
            },
        },
    }
end
