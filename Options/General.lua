local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("general", "appearance")
end

local function RefreshAppearance(notifyOptions)
    local handledByOptions = false
    if NS.Options and NS.Options.RefreshAppearance then
        NS.Options:RefreshAppearance()
        handledByOptions = true
    end

    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.RefreshFromSettings then
        quickWaypoint:RefreshFromSettings()
    end

    local trinketMonitor = NS.Modules.CombatAssist and NS.Modules.CombatAssist.TrinketMonitor
    if trinketMonitor and trinketMonitor.RefreshFromSettings then
        trinketMonitor:RefreshFromSettings()
    end

    local shatterIndicator = NS.Modules.ClassAssist
        and NS.Modules.ClassAssist.Mage
        and NS.Modules.ClassAssist.Mage.ShatterIndicator
    if shatterIndicator and shatterIndicator.RefreshFromSettings then
        shatterIndicator:RefreshFromSettings()
    end

    if notifyOptions and not handledByOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

--[[
通用设置用于承载整个插件共用的外观项。
这里先放 3 类最常用的全局能力：
1. 字体
2. 主题色
3. 设置窗口整体缩放
后续如果还要加音效、动画、窗口行为，也可以继续往这里扩。
]]
function NS.BuildGeneralOptions()
    return {
        type = "group",
        name = "通用设置",
        order = 1,
        args = {
            appearance = {
                type = "group",
                name = "外观设置",
                order = 1,
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "这里可以统一调整插件设置界面的字体、主题色和整体缩放。",
                    },
                    fontPreset = {
                        type = "select",
                        name = "插件字体",
                        order = 10,
                        values = function()
                            return NS.Options.Private.GetFontOptions()
                        end,
                        get = function()
                            return GetConfig().fontPreset
                        end,
                        set = function(_, value)
                            GetConfig().fontPreset = value
                            RefreshAppearance(true)
                        end,
                    },
                    colorMode = {
                        type = "select",
                        name = "主题颜色",
                        order = 11,
                        values = function()
                            return {
                                CLASS = "跟随职业",
                                CUSTOM = "自定义颜色",
                            }
                        end,
                        get = function()
                            return GetConfig().colorMode
                        end,
                        set = function(_, value)
                            GetConfig().colorMode = value
                            RefreshAppearance(true)
                        end,
                    },
                    customColor = {
                        type = "color",
                        name = "自定义主题色",
                        order = 12,
                        hasAlpha = false,
                        disabled = function()
                            return GetConfig().colorMode ~= "CUSTOM"
                        end,
                        get = function()
                            local color = GetConfig().customColor or {}
                            return color.r or 1, color.g or 1, color.b or 1, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            local color = GetConfig().customColor
                            color.r = r
                            color.g = g
                            color.b = b
                            color.a = a or 1
                            RefreshAppearance(true)
                        end,
                    },
                    uiScale = {
                        type = "range",
                        name = "设置界面缩放",
                        order = 13,
                        min = 0.80,
                        max = 1.30,
                        step = 0.05,
                        get = function()
                            return GetConfig().uiScale
                        end,
                        set = function(_, value)
                            GetConfig().uiScale = value
                            RefreshAppearance(true)
                        end,
                    },
                    reset = {
                        type = "execute",
                        name = "恢复外观默认设置",
                        order = 20,
                        confirm = true,
                        confirmText = "确认恢复通用外观设置吗？",
                        func = function()
                            Core:ResetAppearanceConfig()
                            RefreshAppearance(true)
                        end,
                    },
                },
            },
        },
    }
end
