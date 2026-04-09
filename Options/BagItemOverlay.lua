local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "bagItemOverlay")
end

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.BagItemOverlay
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

local DEFAULT_FIXED_COLOR = {
    r = 1.00,
    g = 0.82,
    b = 0.20,
    a = 1.00,
}

local function NormalizeColorValue(value, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback
    end

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function BuildStoredColor(currentColor, fallbackColor, r, g, b, a)
    currentColor = currentColor or {}
    fallbackColor = fallbackColor or DEFAULT_FIXED_COLOR

    return {
        r = NormalizeColorValue(r, currentColor.r or fallbackColor.r or DEFAULT_FIXED_COLOR.r),
        g = NormalizeColorValue(g, currentColor.g or fallbackColor.g or DEFAULT_FIXED_COLOR.g),
        b = NormalizeColorValue(b, currentColor.b or fallbackColor.b or DEFAULT_FIXED_COLOR.b),
        a = NormalizeColorValue(a, currentColor.a or fallbackColor.a or DEFAULT_FIXED_COLOR.a),
    }
end

local function CreateOffsetSlider(label, key, order, defaultValue)
    return {
        type = "range",
        order = order,
        width = 0.75,
        name = label,
        min = -30,
        max = 30,
        step = 1,
        disabled = function()
            return not GetConfig().enabled
        end,
        get = function()
            local value = GetConfig()[key]
            if value == nil then
                value = defaultValue or 0
            end
            return value
        end,
        set = function(_, value)
            GetConfig()[key] = value
            RefreshModule(false)
        end,
    }
end

local function CreateLineStyleGroup(name, prefix, order, offsetXDefault, offsetYDefault)
    local fontPresetKey = prefix .. "FontPreset"
    local fontSizeKey = prefix .. "FontSize"
    local colorModeKey = prefix .. "ColorMode"
    local fixedColorKey = prefix .. "FixedColor"
    local offsetXKey = prefix .. "OffsetX"
    local offsetYKey = prefix .. "OffsetY"

    return {
        type = "group",
        order = order,
        name = name,
        args = {
            styleRow = {
                type = "group",
                order = 10,
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
                            return GetConfig()[fontPresetKey] or GetConfig().fontPreset or "CHAT"
                        end,
                        set = function(_, value)
                            GetConfig()[fontPresetKey] = value
                            RefreshModule(false)
                        end,
                    },
                    fontSize = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "字体大小",
                        min = 8,
                        max = 18,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig()[fontSizeKey] or GetConfig().fontSize or 11
                        end,
                        set = function(_, value)
                            GetConfig()[fontSizeKey] = value
                            RefreshModule(false)
                        end,
                    },
                    colorMode = {
                        type = "select",
                        order = 3,
                        width = 1.0,
                        name = "颜色模式",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = {
                            FIXED = "固定颜色",
                            ITEM_LEVEL = "跟随物品品质",
                        },
                        get = function()
                            return GetConfig()[colorModeKey] or GetConfig().colorMode or "FIXED"
                        end,
                        set = function(_, value)
                            GetConfig()[colorModeKey] = value
                            RefreshModule(false)
                        end,
                    },
                },
            },
            colorRow = {
                type = "group",
                order = 20,
                name = "",
                layout = "row",
                args = {
                    fixedColor = {
                        type = "color",
                        order = 1,
                        width = 1.0,
                        name = "固定颜色",
                        hasAlpha = true,
                        disabled = function()
                            return not GetConfig().enabled or (GetConfig()[colorModeKey] or GetConfig().colorMode) == "ITEM_LEVEL"
                        end,
                        get = function()
                            local color = GetConfig()[fixedColorKey] or GetConfig().fixedColor or {}
                            return color.r or 1, color.g or 0.82, color.b or 0.20, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            local config = GetConfig()
                            config[fixedColorKey] = BuildStoredColor(
                                config[fixedColorKey],
                                config.fixedColor,
                                r,
                                g,
                                b,
                                a
                            )
                            RefreshModule(false)
                        end,
                    },
                },
            },
            offsetRow = {
                type = "group",
                order = 30,
                name = "偏移",
                layout = "row",
                args = {
                    offsetX = CreateOffsetSlider("X", offsetXKey, 1, offsetXDefault),
                    offsetY = CreateOffsetSlider("Y", offsetYKey, 2, offsetYDefault),
                },
            },
        },
    }
end

function NS.BuildBagItemOverlayOptions()
    return {
        type = "group",
        name = "背包文字",
        order = 7,
        args = {
            stateRowTop = {
                type = "group",
                order = 10,
                name = "",
                layout = "row",
                args = {
                    enabled = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "启用背包文字",
                        get = function()
                            return GetConfig().enabled
                        end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            RefreshModule(true)
                        end,
                    },
                    showItemLevel = {
                        type = "toggle",
                        order = 2,
                        width = 0.8,
                        name = "顶部装等",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showItemLevel ~= false
                        end,
                        set = function(_, value)
                            GetConfig().showItemLevel = value and true or false
                            RefreshModule(false)
                        end,
                    },
                },
            },
            stateRowBottom = {
                type = "group",
                order = 11,
                name = "",
                layout = "row",
                args = {
                    showBinding = {
                        type = "toggle",
                        order = 1,
                        width = 0.8,
                        name = "中间绑定",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            local value = GetConfig().showBinding
                            if value == nil then
                                value = GetConfig().showWarbound
                            end
                            if value == nil then
                                value = true
                            end
                            return value
                        end,
                        set = function(_, value)
                            GetConfig().showBinding = value and true or false
                            GetConfig().showWarbound = value and true or false
                            RefreshModule(false)
                        end,
                    },
                    showEquipSlot = {
                        type = "toggle",
                        order = 2,
                        width = 0.9,
                        name = "底部显示装备部位",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showEquipSlot
                        end,
                        set = function(_, value)
                            GetConfig().showEquipSlot = value and true or false
                            RefreshModule(false)
                        end,
                    },
                },
            },
            styleRow = {
                type = "group",
                order = 20,
                hidden = true,
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
                        min = 8,
                        max = 18,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().fontSize or 11
                        end,
                        set = function(_, value)
                            GetConfig().fontSize = value
                            RefreshModule(false)
                        end,
                    },
                    colorMode = {
                        type = "select",
                        order = 3,
                        width = 1.0,
                        name = "颜色模式",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = {
                            FIXED = "固定颜色",
                            ITEM_LEVEL = "跟随物品品质",
                        },
                        get = function()
                            return GetConfig().colorMode or "FIXED"
                        end,
                        set = function(_, value)
                            GetConfig().colorMode = value
                            RefreshModule(false)
                        end,
                    },
                },
            },
            colorRow = {
                type = "group",
                order = 30,
                hidden = true,
                name = "",
                layout = "row",
                args = {
                    fixedColor = {
                        type = "color",
                        order = 1,
                        width = 1.0,
                        name = "固定颜色",
                        hasAlpha = true,
                        disabled = function()
                            return not GetConfig().enabled or GetConfig().colorMode == "ITEM_LEVEL"
                        end,
                        get = function()
                            local color = GetConfig().fixedColor or {}
                            return color.r or 1, color.g or 0.82, color.b or 0.20, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            local config = GetConfig()
                            config.fixedColor = BuildStoredColor(config.fixedColor, DEFAULT_FIXED_COLOR, r, g, b, a)
                            RefreshModule(false)
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 2,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetBagItemOverlayConfig()
                            RefreshModule(true)
                        end,
                    },
                },
            },
            lineStyleTabs = {
                type = "group",
                order = 35,
                name = "文字样式",
                childGroups = "tab",
                args = {
                    top = CreateLineStyleGroup("顶部装等", "top", 10, 0, -1),
                    middle = CreateLineStyleGroup("中间绑定", "middle", 20, 0, 0),
                    bottom = CreateLineStyleGroup("底部部位", "bottom", 30, 0, 1),
                },
            },
            offsetTopRow = {
                type = "group",
                order = 40,
                hidden = true,
                name = "顶部装等偏移",
                layout = "row",
                args = {
                    topOffsetX = CreateOffsetSlider("X", "topOffsetX", 1, 0),
                    topOffsetY = CreateOffsetSlider("Y", "topOffsetY", 2, -1),
                },
            },
            offsetMiddleRow = {
                type = "group",
                order = 50,
                hidden = true,
                name = "中间绑定偏移",
                layout = "row",
                args = {
                    middleOffsetX = CreateOffsetSlider("X", "middleOffsetX", 1, 0),
                    middleOffsetY = CreateOffsetSlider("Y", "middleOffsetY", 2, 0),
                },
            },
            offsetBottomRow = {
                type = "group",
                order = 60,
                hidden = true,
                name = "底部部位偏移",
                layout = "row",
                args = {
                    bottomOffsetX = CreateOffsetSlider("X", "bottomOffsetX", 1, 0),
                    bottomOffsetY = CreateOffsetSlider("Y", "bottomOffsetY", 2, 1),
                },
            },
            resetRow = {
                type = "group",
                order = 90,
                name = "",
                layout = "row",
                args = {
                    reset = {
                        type = "execute",
                        order = 1,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetBagItemOverlayConfig()
                            RefreshModule(true)
                        end,
                    },
                },
            },
        },
    }
end
