local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("mapAssist", "quickWaypoint")
end

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
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    local values = {}
    for key, preset in pairs(quickWaypoint.ANCHOR_PRESETS) do
        values[key] = preset.label
    end
    return values
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
                        type = "select",
                        name = "锚点位置",
                        order = 11,
                        width = 1.1,
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
                    spacer2 = {
                        type = "description",
                        order = 12,
                        name = " ",
                        width = "full",
                    },
                    offsetX = {
                        type = "range",
                        name = "X 偏移",
                        order = 20,
                        width = 1.1,
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
                        order = 21,
                        width = 1.1,
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
                    fontSize = {
                        type = "range",
                        name = "字体大小",
                        order = 22,
                        width = 1.1,
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
                        order = 23,
                        width = 1.1,
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
                    summary = {
                        type = "description",
                        order = 31,
                        fontSize = "medium",
                        name = function()
                            local config = GetConfig()
                            local quickWaypoint = NS.Modules.MapAssist.QuickWaypoint
                            local preset = quickWaypoint.ANCHOR_PRESETS[config.anchorPreset]
                            local presetLabel = preset and preset.label or "地图上方"

                            return string.format(
                                "|cFFCCCCCC当前配置|r %s  锚点 %s  偏移 X %+d / Y %+d  字体 %d  透明度 %d%%",
                                config.enabled and "已启用" or "已关闭",
                                presetLabel,
                                config.offsetX or 0,
                                config.offsetY or 0,
                                config.fontSize or 12,
                                config.bgAlpha or 35
                            )
                        end,
                    },
                },
            },
        },
    }
end
