local _, NS = ...
local Core = NS.Core

local ORIENTATION_OPTIONS = {
    HORIZONTAL = "横向",
    VERTICAL = "纵向",
}

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.RaidMarkers
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "raidMarkers")
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

function NS.BuildRaidMarkersOptions()
    return {
        type = "group",
        name = "团队标记",
        order = 7,
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
                        name = "启用团队标记",
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
                    showWhenSolo = {
                        type = "toggle",
                        order = 3,
                        width = 1.0,
                        name = "单人时也显示",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showWhenSolo
                        end,
                        set = function(_, value)
                            GetConfig().showWhenSolo = value and true or false
                            RefreshModule(false)
                        end,
                    },
                },
            },
            layoutRow = {
                type = "group",
                order = 20,
                name = "",
                layout = "row",
                args = {
                    orientation = {
                        type = "select",
                        order = 1,
                        width = 1.0,
                        name = "排列方向",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = function()
                            return ORIENTATION_OPTIONS
                        end,
                        get = function()
                            return GetConfig().orientation
                        end,
                        set = function(_, value)
                            GetConfig().orientation = value
                            RefreshModule(false)
                        end,
                    },
                    spacing = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "按钮间距",
                        min = 0,
                        max = 40,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().spacing
                        end,
                        set = function(_, value)
                            GetConfig().spacing = value
                            RefreshModule(false)
                        end,
                    },
                    iconSize = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "图标大小",
                        min = 20,
                        max = 48,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().iconSize
                        end,
                        set = function(_, value)
                            GetConfig().iconSize = value
                            RefreshModule(false)
                        end,
                    },
                },
            },
            styleRow = {
                type = "group",
                order = 30,
                name = "",
                layout = "row",
                args = {
                    fontPreset = {
                        type = "select",
                        order = 1,
                        width = 1.0,
                        name = "文字字体",
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
                    countdown = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "倒计时秒数",
                        min = 3,
                        max = 15,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().countdown
                        end,
                        set = function(_, value)
                            GetConfig().countdown = math.floor(value)
                            RefreshModule(false)
                        end,
                    },
                    showBackground = {
                        type = "toggle",
                        order = 3,
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
                },
            },
            colorRow = {
                type = "group",
                order = 40,
                name = "",
                layout = "row",
                args = {
                    showBorder = {
                        type = "toggle",
                        order = 1,
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
                    backgroundColor = {
                        type = "color",
                        order = 2,
                        width = 1.0,
                        name = "背景颜色",
                        hasAlpha = true,
                        disabled = function()
                            return not GetConfig().enabled or not GetConfig().showBackground
                        end,
                        get = function()
                            local color = GetConfig().backgroundColor or {}
                            return color.r or 0, color.g or 0, color.b or 0, color.a or 0.35
                        end,
                        set = function(_, r, g, b, a)
                            local color = GetConfig().backgroundColor
                            color.r, color.g, color.b, color.a = r, g, b, a
                            RefreshModule(false)
                        end,
                    },
                    borderColor = {
                        type = "color",
                        order = 3,
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
                    Core:ResetRaidMarkersConfig()
                    RefreshModule(true)
                end,
            },
        },
    }
end
