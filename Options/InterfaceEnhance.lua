local _, NS = ...
local Core = NS.Core

local pendingLabel = ""
local pendingCommand = ""

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.QuickChat
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "quickChat")
end

local function GetCursorTrailModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.CursorTrail
end

local function GetCursorTrailConfig()
    return Core:GetConfig("interfaceEnhance", "cursorTrail")
end

local function RefreshQuickChat(notifyOptions)
    local quickChat = GetModule()
    if quickChat and quickChat.RefreshFromSettings then
        quickChat:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function RefreshCursorTrail(notifyOptions)
    local cursorTrail = GetCursorTrailModule()
    if cursorTrail and cursorTrail.RefreshFromSettings then
        cursorTrail:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function BuildTab(name, order, args)
    return {
        type = "group",
        name = name,
        order = order,
        args = args,
    }
end

local function BuildCursorTrailColorOption(colorIndex, order)
    return {
        type = "color",
        order = order,
        width = 1.0,
        name = "颜色 " .. tostring(colorIndex),
        hasAlpha = false,
        disabled = function()
            local config = GetCursorTrailConfig()
            return not config.enabled or config.useClassColor
        end,
        get = function()
            local color = GetCursorTrailConfig()["color" .. tostring(colorIndex)]
            return color[1], color[2], color[3], 1
        end,
        set = function(_, r, g, b)
            GetCursorTrailConfig()["color" .. tostring(colorIndex)] = { r, g, b }
            RefreshCursorTrail(false)
        end,
    }
end

local function BuildCursorTrailColorRow(order, leftIndex, rightIndex)
    return {
        type = "group",
        order = order,
        name = "",
        layout = "row",
        args = {
            ["color" .. tostring(leftIndex)] = BuildCursorTrailColorOption(leftIndex, 1),
            ["color" .. tostring(rightIndex)] = BuildCursorTrailColorOption(rightIndex, 2),
        },
    }
end

local function BuildCursorTrailArgs()
    return {
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
                    name = "启用鼠标拖尾",
                    get = function()
                        return GetCursorTrailConfig().enabled
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().enabled = value and true or false
                        RefreshCursorTrail(true)
                    end,
                },
                combatOnly = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "仅战斗中显示",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().combatOnly
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().combatOnly = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
                useClassColor = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "使用职业色覆盖",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().useClassColor
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().useClassColor = value and true or false
                        RefreshCursorTrail(true)
                    end,
                },
            },
        },
        behaviorRow = {
            type = "group",
            order = 20,
            name = "",
            layout = "row",
            args = {
                changeWithTime = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "彩虹流动",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().changeWithTime
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().changeWithTime = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
                shrinkWithTime = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "随时间缩放",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().shrinkWithTime
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().shrinkWithTime = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
                shrinkWithDistance = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "随距离缩放",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().shrinkWithDistance
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().shrinkWithDistance = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        spacingRow = {
            type = "group",
            order = 30,
            name = "",
            layout = "row",
            args = {
                dotDistance = {
                    type = "range",
                    order = 1,
                    width = 1.0,
                    name = "点间距",
                    min = 1,
                    max = 10,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().dotDistance
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().dotDistance = value
                        RefreshCursorTrail(false)
                    end,
                },
                lifetime = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "存活时间",
                    min = 0.1,
                    max = 5.0,
                    step = 0.05,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().lifetime
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().lifetime = value
                        RefreshCursorTrail(false)
                    end,
                },
                maxDots = {
                    type = "range",
                    order = 3,
                    width = 1.0,
                    name = "最大点数",
                    min = 1,
                    max = 800,
                    step = 5,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().maxDots
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().maxDots = math.floor(value)
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        sizeRow = {
            type = "group",
            order = 40,
            name = "",
            layout = "row",
            args = {
                dotWidth = {
                    type = "range",
                    order = 1,
                    width = 1.0,
                    name = "点宽度",
                    min = 1,
                    max = 256,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().dotWidth
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().dotWidth = value
                        RefreshCursorTrail(false)
                    end,
                },
                dotHeight = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "点高度",
                    min = 1,
                    max = 256,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().dotHeight
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().dotHeight = value
                        RefreshCursorTrail(false)
                    end,
                },
                alpha = {
                    type = "range",
                    order = 3,
                    width = 1.0,
                    name = "透明度",
                    min = 0.0,
                    max = 1.0,
                    step = 0.05,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().alpha
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().alpha = value
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        textureRow = {
            type = "group",
            order = 50,
            name = "",
            layout = "row",
            args = {
                cursorLayer = {
                    type = "select",
                    order = 1,
                    width = 1.0,
                    name = "层级",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    values = function()
                        return {
                            [1] = "TOOLTIP",
                            [2] = "BACKGROUND",
                        }
                    end,
                    get = function()
                        return GetCursorTrailConfig().cursorLayer
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().cursorLayer = value
                        RefreshCursorTrail(false)
                    end,
                },
                blendMode = {
                    type = "select",
                    order = 2,
                    width = 1.0,
                    name = "混合模式",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    values = function()
                        return {
                            [1] = "发光",
                            [2] = "普通",
                        }
                    end,
                    get = function()
                        return GetCursorTrailConfig().blendMode
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().blendMode = value
                        RefreshCursorTrail(false)
                    end,
                },
                phaseCount = {
                    type = "range",
                    order = 3,
                    width = 1.0,
                    name = "颜色数量",
                    min = 1,
                    max = 10,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().phaseCount
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().phaseCount = math.floor(value)
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        offsetRow = {
            type = "group",
            order = 60,
            name = "",
            layout = "row",
            args = {
                offsetX = {
                    type = "range",
                    order = 1,
                    width = 1.0,
                    name = "X 偏移",
                    min = -256,
                    max = 256,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().offsetX
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().offsetX = value
                        RefreshCursorTrail(false)
                    end,
                },
                offsetY = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "Y 偏移",
                    min = -256,
                    max = 256,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().offsetY
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().offsetY = value
                        RefreshCursorTrail(false)
                    end,
                },
                colorSpeed = {
                    type = "range",
                    order = 3,
                    width = 1.0,
                    name = "颜色速度",
                    min = 0.1,
                    max = 10.0,
                    step = 0.1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().colorSpeed
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().colorSpeed = value
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        textureInput = {
            type = "input",
            order = 70,
            width = "full",
            name = "纹理 Atlas 或文件路径",
            disabled = function()
                return not GetCursorTrailConfig().enabled
            end,
            get = function()
                return GetCursorTrailConfig().textureInput or ""
            end,
            set = function(_, value)
                GetCursorTrailConfig().textureInput = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
                RefreshCursorTrail(false)
            end,
        },
        paletteHint = {
            type = "description",
            order = 80,
            fontSize = "medium",
            name = "|cFFCCCCCC示例 atlas|r `titleprestige-starglow`，也支持直接填贴图路径。",
        },
        paletteRow1 = BuildCursorTrailColorRow(90, 1, 2),
        paletteRow2 = BuildCursorTrailColorRow(91, 3, 4),
        paletteRow3 = BuildCursorTrailColorRow(92, 5, 6),
        paletteRow4 = BuildCursorTrailColorRow(93, 7, 8),
        paletteRow5 = BuildCursorTrailColorRow(94, 9, 10),
        lookTitle = {
            type = "description",
            order = 100,
            fontSize = "medium",
            name = "|cFFFFD200右键观察|r",
        },
        lookRow = {
            type = "group",
            order = 110,
            name = "",
            layout = "row",
            args = {
                enableLook = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "允许越过 UI 转视角",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().enableLook
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().enableLook = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
                enableCombatLook = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "仅战斗中允许转视角",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().enableCombatLook
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().enableCombatLook = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
                enableIndicator = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "右键时高亮鼠标",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().enableIndicator
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().enableIndicator = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        cursorFrameSize = {
            type = "range",
            order = 120,
            width = 1.0,
            name = "高亮尺寸",
            min = 10,
            max = 128,
            step = 1,
            disabled = function()
                return not GetCursorTrailConfig().enabled
            end,
            get = function()
                return GetCursorTrailConfig().cursorFrameSize
            end,
            set = function(_, value)
                GetCursorTrailConfig().cursorFrameSize = math.floor(value)
                RefreshCursorTrail(false)
            end,
        },
        perfTitle = {
            type = "description",
            order = 130,
            fontSize = "medium",
            name = "|cFFFFD200性能与调试|r",
        },
        perfRow = {
            type = "group",
            order = 140,
            name = "",
            layout = "row",
            args = {
                adaptiveUpdate = {
                    type = "toggle",
                    order = 1,
                    width = 1.2,
                    name = "自适应更新频率",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().adaptiveUpdate
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().adaptiveUpdate = value and true or false
                        RefreshCursorTrail(true)
                    end,
                },
                adaptiveTargetFPS = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "目标更新 Hz",
                    min = 1,
                    max = 240,
                    step = 1,
                    disabled = function()
                        return not GetCursorTrailConfig().enabled or not GetCursorTrailConfig().adaptiveUpdate
                    end,
                    get = function()
                        return GetCursorTrailConfig().adaptiveTargetFPS
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().adaptiveTargetFPS = math.floor(value)
                        RefreshCursorTrail(false)
                    end,
                },
                debugEnabled = {
                    type = "toggle",
                    order = 3,
                    width = 0.9,
                    name = "显示 FPS",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    get = function()
                        return GetCursorTrailConfig().debugEnabled
                    end,
                    set = function(_, value)
                        GetCursorTrailConfig().debugEnabled = value and true or false
                        RefreshCursorTrail(false)
                    end,
                },
            },
        },
        reset = {
            type = "execute",
            order = 200,
            width = 1.0,
            name = "恢复默认设置",
            func = function()
                Core:ResetCursorTrailConfig()
                RefreshCursorTrail(true)
            end,
        },
    }
end

local function BuildButtonManagementArgs()
    local args = {}
    local quickChat = GetModule()
    local defs = quickChat and quickChat.GetAllButtonDefs and quickChat:GetAllButtonDefs() or {}
    local config = GetConfig()

    if #defs == 0 then
        args.empty = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = "|cFF888888当前没有可显示的频道按钮。|r",
        }
        return args
    end

    for index, def in ipairs(defs) do
        local entryIndex = index
        local key = def.key
        local isCustom = def.action == "custom"
        local rowName = (isCustom and "[自定义] " or "[内置] ") .. def.label

        args["button_" .. key] = {
            type = "actionRow",
            order = entryIndex * 10,
            name = rowName,
            color = {
                get = function()
                    local color = quickChat:GetColorForKey(key)
                    return color.r, color.g, color.b
                end,
                set = function(_, r, g, b)
                    local color = quickChat:GetColorForKey(key)
                    color.r, color.g, color.b = r, g, b
                    RefreshQuickChat(false)
                end,
            },
            actions = {
                {
                    label = "上移",
                    width = 46,
                    disabled = function()
                        return entryIndex == 1
                    end,
                    func = function()
                        local order = config.buttonOrder
                        if entryIndex > 1 then
                            order[entryIndex], order[entryIndex - 1] = order[entryIndex - 1], order[entryIndex]
                            RefreshQuickChat(true)
                        end
                    end,
                },
                {
                    label = "下移",
                    width = 46,
                    disabled = function()
                        return entryIndex == #defs
                    end,
                    func = function()
                        local order = config.buttonOrder
                        if entryIndex < #defs then
                            order[entryIndex], order[entryIndex + 1] = order[entryIndex + 1], order[entryIndex]
                            RefreshQuickChat(true)
                        end
                    end,
                },
                {
                    label = isCustom and "删除" or "移除",
                    width = 50,
                    confirm = true,
                    confirmText = "确认移除这个按钮吗？",
                    func = function()
                        for orderIndex, orderKey in ipairs(config.buttonOrder) do
                            if orderKey == key then
                                table.remove(config.buttonOrder, orderIndex)
                                break
                            end
                        end

                        if isCustom and quickChat and quickChat.GetCustomButtonByKey then
                            local _, customIndex = quickChat:GetCustomButtonByKey(key)
                            if customIndex then
                                table.remove(config.customButtons, customIndex)
                            end
                            config.buttonColors[key] = nil
                        end

                        RefreshQuickChat(true)
                    end,
                },
            },
        }
    end

    return args
end

function NS.BuildInterfaceEnhanceOptions()
    return {
        type = "group",
        name = "界面增强",
        order = 12,
        args = {
            mouseCursor = {
                type = "group",
                name = "鼠标指针",
                order = 5,
                childGroups = "tab",
                args = {
                    cursorTrail = BuildTab("鼠标拖尾", 10, BuildCursorTrailArgs()),
                },
            },
            quickChat = {
                type = "group",
                name = "快捷频道",
                order = 10,
                childGroups = "tab",
                args = {
                    basic = BuildTab("基础设置", 10, {
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
                                    name = "启用快捷频道",
                                    get = function()
                                        return GetConfig().enabled
                                    end,
                                    set = function(_, value)
                                        GetConfig().enabled = value and true or false
                                        RefreshQuickChat(true)
                                    end,
                                },
                                unlocked = {
                                    type = "toggle",
                                    order = 2,
                                    width = 1.0,
                                    name = "解锁位置拖动",
                                    disabled = function()
                                        return not GetConfig().enabled
                                    end,
                                    get = function()
                                        return GetConfig().unlocked
                                    end,
                                    set = function(_, value)
                                        GetConfig().unlocked = value and true or false
                                        RefreshQuickChat(false)
                                    end,
                                },
                            },
                        },
                        worldChannelRow = {
                            type = "group",
                            order = 12,
                            name = "",
                            layout = "row",
                            args = {
                                worldChannelName = {
                                    type = "input",
                                    order = 1,
                                    width = 1.8,
                                    name = "世界频道名称",
                                    disabled = function()
                                        return not GetConfig().enabled
                                    end,
                                    get = function()
                                        return GetConfig().worldChannelName or ""
                                    end,
                                    set = function(_, value)
                                        local text = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                        GetConfig().worldChannelName = text ~= "" and text or "大脚世界频道"
                                        RefreshQuickChat(false)
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
                                spacing = {
                                    type = "range",
                                    order = 1,
                                    width = 1.0,
                                    name = "按钮间隔",
                                    min = 0,
                                    max = 30,
                                    step = 1,
                                    disabled = function()
                                        return not GetConfig().enabled
                                    end,
                                    get = function()
                                        return GetConfig().spacing
                                    end,
                                    set = function(_, value)
                                        GetConfig().spacing = value
                                        RefreshQuickChat(false)
                                    end,
                                },
                                fontSize = {
                                    type = "range",
                                    order = 2,
                                    width = 1.0,
                                    name = "文字大小",
                                    min = 10,
                                    max = 32,
                                    step = 1,
                                    disabled = function()
                                        return not GetConfig().enabled
                                    end,
                                    get = function()
                                        return GetConfig().fontSize
                                    end,
                                    set = function(_, value)
                                        GetConfig().fontSize = value
                                        RefreshQuickChat(false)
                                    end,
                                },
                                fontPreset = {
                                    type = "select",
                                    order = 3,
                                    width = 1.1,
                                    name = "快捷条字体",
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
                                        RefreshQuickChat(false)
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
                                Core:ResetQuickChatConfig()
                                RefreshQuickChat(true)
                            end,
                        },
                    }),
                    buttonManagement = BuildTab("按钮管理", 20, BuildButtonManagementArgs()),
                    addCustom = BuildTab("自定义按钮", 30, {
                        addRow = {
                            type = "group",
                            order = 10,
                            name = "",
                            layout = "row",
                            args = {
                                label = {
                                    type = "input",
                                    order = 1,
                                    width = 1.0,
                                    name = "按钮文字",
                                    get = function()
                                        return pendingLabel
                                    end,
                                    set = function(_, value)
                                        pendingLabel = value or ""
                                    end,
                                },
                                command = {
                                    type = "input",
                                    order = 2,
                                    width = 1.6,
                                    name = "聊天指令",
                                    get = function()
                                        return pendingCommand
                                    end,
                                    set = function(_, value)
                                        pendingCommand = value or ""
                                    end,
                                },
                                add = {
                                    type = "execute",
                                    order = 3,
                                    width = 0.8,
                                    name = "添加按钮",
                                    func = function()
                                        local label = tostring(pendingLabel or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                        local command = tostring(pendingCommand or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                        if label == "" or command == "" then
                                            return
                                        end

                                        local config = GetConfig()
                                        local newID = config.nextCustomId or 1
                                        config.nextCustomId = newID + 1
                                        table.insert(config.customButtons, {
                                            id = newID,
                                            label = label,
                                            command = command,
                                        })
                                        table.insert(config.buttonOrder, "CUSTOM_" .. tostring(newID))
                                        config.buttonColors["CUSTOM_" .. tostring(newID)] = { r = 1.00, g = 0.82, b = 0.00 }

                                        pendingLabel = ""
                                        pendingCommand = ""
                                        RefreshQuickChat(true)
                                    end,
                                },
                            },
                        },
                        restoreBuiltin = {
                            type = "execute",
                            order = 20,
                            width = 1.1,
                            name = "恢复内置按钮",
                            func = function()
                                local config = GetConfig()
                                local quickChat = GetModule()
                                for _, button in ipairs(quickChat:GetBuiltinButtons()) do
                                    quickChat:GetColorForKey(button.key)
                                    local exists = false
                                    for _, key in ipairs(config.buttonOrder) do
                                        if key == button.key then
                                            exists = true
                                            break
                                        end
                                    end
                                    if not exists then
                                        table.insert(config.buttonOrder, button.key)
                                    end
                                end
                                RefreshQuickChat(true)
                            end,
                        },
                    }),
                },
            },
        },
    }
end
