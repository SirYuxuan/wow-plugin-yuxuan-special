local _, NS = ...
local Core = NS.Core

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.DistanceMonitor
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "distanceMonitor")
end

local function RefreshModule(notifyOptions)
    local module = GetModule()
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function NS.BuildDistanceMonitorOptions()
    return {
        type = "group",
        name = "距离监控",
        order = 6,
        args = {
            intro = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "Show target range with the same runtime behavior as YuXuanToolbox.",
            },
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
                        name = "启用距离监控",
                        get = function()
                            return GetConfig().enabled
                        end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            RefreshModule(true)
                        end,
                    },
                    locked = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "锁定位置",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().locked
                        end,
                        set = function(_, value)
                            GetConfig().locked = value and true or false
                            RefreshModule(false)
                        end,
                    },
                },
            },
            fontRow = {
                type = "group",
                order = 20,
                name = "",
                layout = "row",
                args = {
                    fontPreset = {
                        type = "select",
                        order = 1,
                        width = 1.0,
                        name = "字体",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = function()
                            return NS.Options.Private.GetFontOptions()
                        end,
                        get = function()
                            return GetConfig().fontPreset
                        end,
                        set = function(_, value)
                            GetConfig().fontPreset = value
                            RefreshModule(false)
                        end,
                    },
                    fontSize = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "字体大小",
                        min = 10,
                        max = 28,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().fontSize
                        end,
                        set = function(_, value)
                            GetConfig().fontSize = value
                            RefreshModule(false)
                        end,
                    },
                    updateInterval = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "刷新间隔",
                        min = 0.05,
                        max = 1.00,
                        step = 0.05,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().updateInterval
                        end,
                        set = function(_, value)
                            GetConfig().updateInterval = value
                            RefreshModule(false)
                        end,
                    },
                },
            },
            displayRow = {
                type = "group",
                order = 30,
                name = "",
                layout = "row",
                args = {
                    rangeSeparator = {
                        type = "input",
                        order = 1,
                        width = 1.0,
                        name = "Range Separator",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().rangeSeparator or " - "
                        end,
                        set = function(_, value)
                            GetConfig().rangeSeparator = tostring(value or "")
                            RefreshModule(false)
                        end,
                    },
                    showBackground = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "显示背景",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showBackground
                        end,
                        set = function(_, value)
                            GetConfig().showBackground = value and true or false
                            RefreshModule(false)
                        end,
                    },
                    showBorder = {
                        type = "toggle",
                        order = 3,
                        width = 1.0,
                        name = "显示边框",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showBorder
                        end,
                        set = function(_, value)
                            GetConfig().showBorder = value and true or false
                            RefreshModule(false)
                        end,
                    },
                },
            },
            colorRow = {
                type = "group",
                order = 40,
                name = "",
                layout = "row",
                args = {
                    backgroundColor = {
                        type = "color",
                        order = 1,
                        width = 1.0,
                        name = "背景颜色",
                        hasAlpha = true,
                        disabled = function()
                            return not GetConfig().enabled or not GetConfig().showBackground
                        end,
                        get = function()
                            local color = GetConfig().backgroundColor or {}
                            return color.r or 0, color.g or 0, color.b or 0, color.a or 0.32
                        end,
                        set = function(_, r, g, b, a)
                            local color = GetConfig().backgroundColor
                            color.r, color.g, color.b, color.a = r, g, b, a
                            RefreshModule(false)
                        end,
                    },
                    borderColor = {
                        type = "color",
                        order = 2,
                        width = 1.0,
                        name = "边框颜色",
                        hasAlpha = true,
                        disabled = function()
                            return not GetConfig().enabled or not GetConfig().showBorder
                        end,
                        get = function()
                            local color = GetConfig().borderColor or {}
                            return color.r or 0, color.g or 0.6, color.b or 1, color.a or 0.45
                        end,
                        set = function(_, r, g, b, a)
                            local color = GetConfig().borderColor
                            color.r, color.g, color.b, color.a = r, g, b, a
                            RefreshModule(false)
                        end,
                    },
                },
            },
            reset = {
                type = "execute",
                order = 100,
                width = 1.0,
                name = "恢复默认设置",
                func = function()
                    Core:ResetDistanceMonitorConfig()
                    RefreshModule(true)
                end,
            },
        },
    }
end
