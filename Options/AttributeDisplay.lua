local _, NS = ...
local Core = NS.Core
local LibSharedMedia = LibStub("LibSharedMedia-3.0")

local ATTRIBUTE_STATS = {
    { key = "showIlvl", color = "colorIlvl", label = "装等" },
    { key = "showPrimary", color = "colorPrimary", label = "主属性" },
    { key = "showCrit", color = "colorCrit", label = "暴击" },
    { key = "showHaste", color = "colorHaste", label = "急速" },
    { key = "showMastery", color = "colorMastery", label = "精通" },
    { key = "showVersa", color = "colorVersa", label = "全能" },
    { key = "showLeech", color = "colorLeech", label = "吸血" },
    { key = "showDodge", color = "colorDodge", label = "躲闪" },
    { key = "showParry", color = "colorParry", label = "招架" },
    { key = "showBlock", color = "colorBlock", label = "格挡" },
    { key = "showSpeed", color = "colorSpeed", label = "移动速度" },
}

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.AttributeDisplay
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "attributeDisplay")
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

local function BuildStatOptionRow(order, stat)
    return {
        type = "group",
        order = order,
        name = "",
        layout = "row",
        args = {
            [stat.key] = {
                type = "toggle",
                order = 1,
                width = 1.0,
                name = "显示" .. stat.label,
                disabled = function()
                    return not GetConfig().enabled
                end,
                get = function()
                    return GetConfig()[stat.key]
                end,
                set = function(_, value)
                    GetConfig()[stat.key] = value and true or false
                    RefreshModule(false)
                end,
            },
            [stat.color] = {
                type = "color",
                order = 2,
                width = 1.0,
                name = stat.label .. "颜色",
                disabled = function()
                    return not GetConfig().enabled or not GetConfig()[stat.key]
                end,
                get = function()
                    local color = GetConfig()[stat.color] or {}
                    return color.r or 1, color.g or 1, color.b or 1, 1
                end,
                set = function(_, r, g, b)
                    local color = GetConfig()[stat.color]
                    color.r, color.g, color.b = r, g, b
                    RefreshModule(false)
                end,
            },
        },
    }
end

function NS.BuildAttributeDisplayOptions()
    local displayArgs = {}
    for index, stat in ipairs(ATTRIBUTE_STATS) do
        displayArgs["stat" .. tostring(index)] = BuildStatOptionRow(index * 10, stat)
    end

    displayArgs.reset = {
        type = "execute",
        order = 999,
        width = 1.0,
        name = "恢复默认设置",
        func = function()
            Core:ResetAttributeDisplayConfig()
            RefreshModule(true)
        end,
    }

    return {
        type = "group",
        name = "属性显示",
        order = 8,
        childGroups = "tab",
        args = {
            basic = {
                type = "group",
                name = "基础设置",
                order = 10,
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
                                name = "启用属性显示",
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
                            visibility = {
                                type = "select",
                                order = 3,
                                width = 1.0,
                                name = "可见性",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    always = "始终显示",
                                    combat = "仅战斗中",
                                    noncombat = "仅非战斗",
                                },
                                get = function()
                                    return GetConfig().visibility
                                end,
                                set = function(_, value)
                                    GetConfig().visibility = value
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
                            font = {
                                type = "select",
                                order = 1,
                                width = 1.2,
                                name = "字体",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = LibSharedMedia:HashTable("font"),
                                get = function()
                                    return GetConfig().font
                                end,
                                set = function(_, value)
                                    GetConfig().font = value
                                    RefreshModule(false)
                                end,
                            },
                            fontSize = {
                                type = "range",
                                order = 2,
                                width = 0.9,
                                name = "字体大小",
                                min = 6,
                                max = 30,
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
                            fontOutline = {
                                type = "toggle",
                                order = 3,
                                width = 0.9,
                                name = "字体描边",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().fontOutline
                                end,
                                set = function(_, value)
                                    GetConfig().fontOutline = value and true or false
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    textRow = {
                        type = "group",
                        order = 30,
                        name = "",
                        layout = "row",
                        args = {
                            align = {
                                type = "select",
                                order = 1,
                                width = 1.0,
                                name = "对齐方式",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    LEFT = "左对齐",
                                    CENTER = "居中",
                                    RIGHT = "右对齐",
                                },
                                get = function()
                                    return GetConfig().align
                                end,
                                set = function(_, value)
                                    GetConfig().align = value
                                    RefreshModule(false)
                                end,
                            },
                            lineSpacing = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "行距",
                                min = 0,
                                max = 20,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().lineSpacing
                                end,
                                set = function(_, value)
                                    GetConfig().lineSpacing = value
                                    RefreshModule(false)
                                end,
                            },
                            decimalPlaces = {
                                type = "range",
                                order = 3,
                                width = 1.0,
                                name = "小数位数",
                                min = 0,
                                max = 2,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().decimalPlaces
                                end,
                                set = function(_, value)
                                    GetConfig().decimalPlaces = value
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    backgroundRow = {
                        type = "group",
                        order = 40,
                        name = "",
                        layout = "row",
                        args = {
                            bgStyle = {
                                type = "select",
                                order = 1,
                                width = 1.0,
                                name = "背景样式",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    none = "无背景",
                                    semi = "半透明背景",
                                },
                                get = function()
                                    return GetConfig().bgStyle
                                end,
                                set = function(_, value)
                                    GetConfig().bgStyle = value
                                    RefreshModule(false)
                                end,
                            },
                            bgAlpha = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "背景透明度",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                disabled = function()
                                    return not GetConfig().enabled or GetConfig().bgStyle == "none"
                                end,
                                get = function()
                                    return GetConfig().bgAlpha
                                end,
                                set = function(_, value)
                                    GetConfig().bgAlpha = value
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                },
            },
            stats = {
                type = "group",
                name = "显示项目",
                order = 20,
                args = displayArgs,
            },
            advanced = {
                type = "group",
                name = "高级设置",
                order = 30,
                args = {
                    formatRow = {
                        type = "group",
                        order = 10,
                        name = "",
                        layout = "row",
                        args = {
                            ilvlFormat = {
                                type = "select",
                                order = 1,
                                width = 1.0,
                                name = "装等格式",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    real = "仅实装",
                                    both = "实装 + 平均",
                                },
                                get = function()
                                    return GetConfig().ilvlFormat
                                end,
                                set = function(_, value)
                                    GetConfig().ilvlFormat = value
                                    RefreshModule(false)
                                end,
                            },
                            secondaryFormat = {
                                type = "select",
                                order = 2,
                                width = 1.0,
                                name = "副属性格式",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    percent = "仅百分比",
                                    ["number+percent"] = "数值 + 百分比",
                                },
                                get = function()
                                    return GetConfig().secondaryFormat
                                end,
                                set = function(_, value)
                                    GetConfig().secondaryFormat = value
                                    RefreshModule(false)
                                end,
                            },
                            speedFormat = {
                                type = "select",
                                order = 3,
                                width = 1.0,
                                name = "移速格式",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    current = "当前速度",
                                    static = "静态速度",
                                },
                                get = function()
                                    return GetConfig().speedFormat
                                end,
                                set = function(_, value)
                                    GetConfig().speedFormat = value
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    progressState = {
                        type = "group",
                        order = 20,
                        name = "",
                        layout = "row",
                        args = {
                            progressBarEnable = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "启用进度条",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().progressBarEnable
                                end,
                                set = function(_, value)
                                    GetConfig().progressBarEnable = value and true or false
                                    RefreshModule(false)
                                end,
                            },
                            progressBarTexture = {
                                type = "select",
                                order = 2,
                                width = 1.0,
                                name = "进度条材质",
                                disabled = function()
                                    return not GetConfig().enabled or not GetConfig().progressBarEnable
                                end,
                                values = LibSharedMedia:HashTable("statusbar"),
                                get = function()
                                    return GetConfig().progressBarTexture
                                end,
                                set = function(_, value)
                                    GetConfig().progressBarTexture = value
                                    RefreshModule(false)
                                end,
                            },
                            progressBarColor = {
                                type = "color",
                                order = 3,
                                width = 1.0,
                                name = "进度条颜色",
                                disabled = function()
                                    return not GetConfig().enabled or not GetConfig().progressBarEnable
                                end,
                                get = function()
                                    local color = GetConfig().progressBarColor or {}
                                    return color.r or 1, color.g or 1, color.b or 1, 1
                                end,
                                set = function(_, r, g, b)
                                    local color = GetConfig().progressBarColor
                                    color.r, color.g, color.b = r, g, b
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    progressSize = {
                        type = "group",
                        order = 30,
                        name = "",
                        layout = "row",
                        args = {
                            progressBarWidth = {
                                type = "range",
                                order = 1,
                                width = 1.0,
                                name = "进度条宽度",
                                min = 50,
                                max = 300,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled or not GetConfig().progressBarEnable
                                end,
                                get = function()
                                    return GetConfig().progressBarWidth
                                end,
                                set = function(_, value)
                                    GetConfig().progressBarWidth = value
                                    RefreshModule(false)
                                end,
                            },
                            progressBarHeight = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "进度条高度",
                                min = 2,
                                max = 20,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled or not GetConfig().progressBarEnable
                                end,
                                get = function()
                                    return GetConfig().progressBarHeight
                                end,
                                set = function(_, value)
                                    GetConfig().progressBarHeight = value
                                    RefreshModule(false)
                                end,
                            },
                            maxIlvl = {
                                type = "range",
                                order = 3,
                                width = 1.0,
                                name = "赛季最高装等",
                                min = 100,
                                max = 1000,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().maxIlvl
                                end,
                                set = function(_, value)
                                    GetConfig().maxIlvl = math.floor(value)
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    reset = {
                        type = "execute",
                        order = 90,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetAttributeDisplayConfig()
                            RefreshModule(true)
                        end,
                    },
                },
            },
        },
    }
end
