local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("mapAssist", "quickWaypoint")
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
        },
    }
end
