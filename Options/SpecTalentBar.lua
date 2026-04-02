local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "specTalentBar")
end

local function Refresh(notifyOptions)
    local module = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.SpecTalentBar
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end
    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function NS.BuildSpecTalentBarOptions()
    return {
        type = "group",
        name = "专精/天赋条",
        order = 16,
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
                        name = "启用信息条",
                        get = function() return GetConfig().enabled end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            Refresh(true)
                        end,
                    },
                    locked = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "锁定位置",
                        get = function() return GetConfig().locked end,
                        set = function(_, value)
                            GetConfig().locked = value and true or false
                            Refresh(false)
                        end,
                    },
                    orientation = {
                        type = "select",
                        order = 3,
                        width = 1.0,
                        name = "排列方向",
                        values = {
                            HORIZONTAL = "横向",
                            VERTICAL = "纵向",
                        },
                        get = function() return GetConfig().orientation or "HORIZONTAL" end,
                        set = function(_, value)
                            GetConfig().orientation = value
                            Refresh(false)
                        end,
                    },
                },
            },
            styleRow = {
                type = "group",
                order = 20,
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
                        min = 10,
                        max = 24,
                        step = 1,
                        get = function() return GetConfig().fontSize or 13 end,
                        set = function(_, value)
                            GetConfig().fontSize = value
                            Refresh(false)
                        end,
                    },
                    spacing = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "项目间距",
                        min = 1,
                        max = 300,
                        step = 1,
                        get = function() return GetConfig().spacing or 18 end,
                        set = function(_, value)
                            GetConfig().spacing = value
                            Refresh(false)
                        end,
                    },
                },
            },
            colorRow = {
                type = "group",
                order = 30,
                name = "",
                layout = "row",
                args = {
                    textColor = {
                        type = "color",
                        order = 1,
                        width = 1.0,
                        name = "文字颜色",
                        hasAlpha = true,
                        get = function()
                            local color = GetConfig().textColor or { r = 1, g = 1, b = 1, a = 1 }
                            return color.r, color.g, color.b, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            GetConfig().textColor = { r = r, g = g, b = b, a = a }
                            Refresh(false)
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 2,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetSpecTalentBarConfig()
                            Refresh(true)
                        end,
                    },
                },
            },
        },
    }
end
