local _, NS = ...
local Core = NS.Core

local pendingLabel = ""
local pendingCommand = ""

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetQuickChatModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.QuickChat
end

local function GetQuickChatConfig()
    return Core:GetConfig("interfaceEnhance", "quickChat")
end

local function GetCursorTrailModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.CursorTrail
end

local function GetCursorTrailConfig()
    return Core:GetConfig("interfaceEnhance", "cursorTrail")
end

local function GetMouseTooltipModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.MouseTooltip
end

local function GetMouseTooltipConfig()
    return Core:GetConfig("interfaceEnhance", "mouseTooltip")
end

local function RefreshQuickChat(notifyOptions)
    local quickChat = GetQuickChatModule()
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

local function RefreshMouseTooltip(notifyOptions)
    local mouseTooltip = GetMouseTooltipModule()
    if mouseTooltip and mouseTooltip.RefreshFromSettings then
        mouseTooltip:RefreshFromSettings()
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
            local color = GetCursorTrailConfig()["color" .. tostring(colorIndex)] or { 1, 1, 1 }
            return color[1] or 1, color[2] or 1, color[3] or 1, 1
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
            },
        },
        behaviorTitle = {
            type = "description",
            order = 15,
            fontSize = "medium",
            name = "|cFFFFD200拖尾行为|r",
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
                    name = "颜色随时间变化",
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
                    name = "随时间缩小",
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
                    name = "随距离缩小",
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
        motionRow = {
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
                    name = "最大粒子数",
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
        sizeTitle = {
            type = "description",
            order = 35,
            fontSize = "medium",
            name = "|cFFFFD200尺寸与渲染|r",
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
                    name = "宽度",
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
                    name = "高度",
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
        renderRow = {
            type = "group",
            order = 45,
            name = "",
            layout = "row",
            args = {
                cursorLayer = {
                    type = "select",
                    order = 1,
                    width = 1.0,
                    name = "显示层级",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    values = function()
                        return {
                            [1] = "前景层",
                            [2] = "背景层",
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
                            [1] = "ADD",
                            [2] = "BLEND",
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
            },
        },
        offsetRow = {
            type = "group",
            order = 48,
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
            },
        },
        colorTitle = {
            type = "description",
            order = 49,
            fontSize = "medium",
            name = "|cFFFFD200颜色设置|r",
        },
        colorConfigRow = {
            type = "group",
            order = 55,
            name = "",
            layout = "row",
            args = {
                useClassColor = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "使用职业颜色",
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
                colorSpeed = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "颜色变化速度",
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
                phaseCount = {
                    type = "range",
                    order = 3,
                    width = 1.0,
                    name = "颜色阶段数",
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
        paletteRow1 = BuildCursorTrailColorRow(60, 1, 2),
        paletteRow2 = BuildCursorTrailColorRow(61, 3, 4),
        paletteRow3 = BuildCursorTrailColorRow(62, 5, 6),
        paletteRow4 = BuildCursorTrailColorRow(63, 7, 8),
        paletteRow5 = BuildCursorTrailColorRow(64, 9, 10),
        lookTitle = {
            type = "description",
            order = 100,
            fontSize = "medium",
            name = "|cFFFFD200鼠标观察|r",
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
                    name = "右键穿过 UI 转视角",
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
                    name = "仅战斗时允许转视角",
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
                    name = "显示鼠标高亮",
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
        lookSizeRow = {
            type = "group",
            order = 115,
            name = "",
            layout = "row",
            args = {
                cursorFrameSize = {
                    type = "range",
                    order = 1,
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
            },
        },
        perfTitle = {
            type = "description",
            order = 130,
            fontSize = "medium",
            name = "|cFFFFD200性能设置|r",
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
                    width = 1.0,
                    name = "启用自适应更新",
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
                    name = "目标更新频率",
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

local function BuildMouseTooltipArgs()
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
                    name = "启用鼠标提示增强",
                    get = function()
                        return GetMouseTooltipConfig().enabled
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().enabled = value and true or false
                        RefreshMouseTooltip(true)
                    end,
                },
                disableAllTooltips = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "禁用所有鼠标提示",
                    disabled = function()
                        return not GetMouseTooltipConfig().enabled
                    end,
                    get = function()
                        return GetMouseTooltipConfig().disableAllTooltips
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().disableAllTooltips = value and true or false
                        RefreshMouseTooltip(true)
                    end,
                },
                tooltipFollowCursor = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "提示跟随鼠标",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips
                    end,
                    get = function()
                        return GetMouseTooltipConfig().tooltipFollowCursor
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().tooltipFollowCursor = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
            },
        },
        appearanceTitle = {
            type = "description",
            order = 20,
            fontSize = "medium",
            name = "|cFFFFD200外观设置|r",
        },
        appearanceRow = {
            type = "group",
            order = 30,
            name = "",
            layout = "row",
            args = {
                opaqueTooltipBackground = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "不透明提示背景",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips
                    end,
                    get = function()
                        return GetMouseTooltipConfig().opaqueTooltipBackground
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().opaqueTooltipBackground = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
                showTooltipHealthBar = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "显示提示血条",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips
                    end,
                    get = function()
                        return GetMouseTooltipConfig().showTooltipHealthBar
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().showTooltipHealthBar = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
            },
        },
        npcTitle = {
            type = "description",
            order = 40,
            fontSize = "medium",
            name = "|cFFFFD200NPC 存活时间|r",
        },
        npcStateRow = {
            type = "group",
            order = 50,
            name = "",
            layout = "row",
            args = {
                showNPCAliveTime = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "显示 NPC 存活时间",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips
                    end,
                    get = function()
                        return GetMouseTooltipConfig().showNPCAliveTime
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().showNPCAliveTime = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
                npcTimeUseModifier = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "按住修饰键时显示",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips or not config.showNPCAliveTime
                    end,
                    get = function()
                        return GetMouseTooltipConfig().npcTimeUseModifier
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().npcTimeUseModifier = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
            },
        },
        npcDetailRow = {
            type = "group",
            order = 60,
            name = "",
            layout = "row",
            args = {
                npcTimeShowCurrentTime = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "显示当前时间",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips or not config.showNPCAliveTime
                    end,
                    get = function()
                        return GetMouseTooltipConfig().npcTimeShowCurrentTime
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().npcTimeShowCurrentTime = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
                npcTimeShowLayer = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "显示位面层",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips or not config.showNPCAliveTime
                    end,
                    get = function()
                        return GetMouseTooltipConfig().npcTimeShowLayer
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().npcTimeShowLayer = value and true or false
                        RefreshMouseTooltip(false)
                    end,
                },
                npcTimeShowNPCID = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "显示 NPC ID",
                    disabled = function()
                        local config = GetMouseTooltipConfig()
                        return not config.enabled or config.disableAllTooltips or not config.showNPCAliveTime
                    end,
                    get = function()
                        return GetMouseTooltipConfig().npcTimeShowNPCID
                    end,
                    set = function(_, value)
                        GetMouseTooltipConfig().npcTimeShowNPCID = value and true or false
                        RefreshMouseTooltip(false)
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
                Core:ResetMouseTooltipConfig()
                RefreshMouseTooltip(true)
            end,
        },
    }
end

local function BuildButtonManagementArgs()
    local args = {}
    local quickChat = GetQuickChatModule()
    local defs = quickChat and quickChat.GetAllButtonDefs and quickChat:GetAllButtonDefs() or {}
    local config = GetQuickChatConfig()

    if #defs == 0 then
        args.empty = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = "|cFF888888当前没有可管理的频道按钮。|r",
        }
        return args
    end
    for index, def in ipairs(defs) do
        local entryIndex = index
        local key = def.key
        local isCustom = def.action == "custom"
        local rowName = (isCustom and "[自定义] " or "[内置] ") .. tostring(def.label or key)

        args["button_" .. key] = {
            type = "actionRow",
            order = entryIndex * 10,
            name = rowName,
            color = {
                get = function()
                    local color = quickChat:GetColorForKey(key)
                    return color.r or 1, color.g or 1, color.b or 1
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
                    label = isCustom and "删除" or "隐藏",
                    width = 50,
                    confirm = true,
                    confirmText = "确认要移除这个频道按钮吗？",
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

local function BuildQuickChatBasicArgs()
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
                    name = "启用快捷频道",
                    get = function()
                        return GetQuickChatConfig().enabled
                    end,
                    set = function(_, value)
                        GetQuickChatConfig().enabled = value and true or false
                        RefreshQuickChat(true)
                    end,
                },
                unlocked = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "解锁位置拖动",
                    disabled = function()
                        return not GetQuickChatConfig().enabled
                    end,
                    get = function()
                        return GetQuickChatConfig().unlocked
                    end,
                    set = function(_, value)
                        GetQuickChatConfig().unlocked = value and true or false
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
                        return not GetQuickChatConfig().enabled
                    end,
                    get = function()
                        return GetQuickChatConfig().worldChannelName or ""
                    end,
                    set = function(_, value)
                        local text = TrimText(value)
                        GetQuickChatConfig().worldChannelName = text ~= "" and text or "大脚世界频道"
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
                    name = "按钮间距",
                    min = 0,
                    max = 30,
                    step = 1,
                    disabled = function()
                        return not GetQuickChatConfig().enabled
                    end,
                    get = function()
                        return GetQuickChatConfig().spacing
                    end,
                    set = function(_, value)
                        GetQuickChatConfig().spacing = value
                        RefreshQuickChat(false)
                    end,
                },
                fontSize = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "字体大小",
                    min = 10,
                    max = 32,
                    step = 1,
                    disabled = function()
                        return not GetQuickChatConfig().enabled
                    end,
                    get = function()
                        return GetQuickChatConfig().fontSize
                    end,
                    set = function(_, value)
                        GetQuickChatConfig().fontSize = value
                        RefreshQuickChat(false)
                    end,
                },
                fontPreset = {
                    type = "select",
                    order = 3,
                    width = 1.1,
                    name = "字体预设",
                    disabled = function()
                        return not GetQuickChatConfig().enabled
                    end,
                    values = function()
                        return NS.Options.Private.GetFontOptions()
                    end,
                    get = function()
                        return GetQuickChatConfig().fontPreset
                    end,
                    set = function(_, value)
                        GetQuickChatConfig().fontPreset = value
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
    }
end

local function BuildQuickChatAddCustomArgs()
    return {
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
                    name = "按钮名称",
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
                    name = "指令内容",
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
                        local label = TrimText(pendingLabel)
                        local command = TrimText(pendingCommand)
                        if label == "" or command == "" then
                            return
                        end

                        local config = GetQuickChatConfig()
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
                local config = GetQuickChatConfig()
                local quickChat = GetQuickChatModule()
                if not quickChat then
                    return
                end

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
    }
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
                    mouseTooltip = BuildTab("鼠标提示", 20, BuildMouseTooltipArgs()),
                },
            },
            distanceMonitor = NS.BuildDistanceMonitorOptions(),
            raidMarkers = NS.BuildRaidMarkersOptions(),
            quickChat = {
                type = "group",
                name = "快捷频道",
                order = 10,
                childGroups = "tab",
                args = {
                    basic = BuildTab("基础设置", 10, BuildQuickChatBasicArgs()),
                    buttonManagement = BuildTab("按钮管理", 20, BuildButtonManagementArgs()),
                    addCustom = BuildTab("新增按钮", 30, BuildQuickChatAddCustomArgs()),
                },
            },
            gameBar = NS.BuildGameBarOptions(),
        },
    }
end
