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
        name = "棰滆壊 " .. tostring(colorIndex),
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
        -- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鍩虹寮€鍏?鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?        stateRow = {
            type = "group",
            order = 10,
            name = "",
            layout = "row",
            args = {
                enabled = {
                    type = "toggle",
                    order = 1,
                    width = 1.0,
                    name = "鍚敤榧犳爣鎷栧熬",
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
                    name = "浠呮垬鏂椾腑鏄剧ず",
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
        -- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鎷栧熬琛屼负 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?        behaviorTitle = {
            type = "description",
            order = 15,
            fontSize = "medium",
            name = "|cFFFFD200鎷栧熬琛屼负|r",
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
                    name = "褰╄櫣娴佸姩",
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
                    name = "闅忔椂闂寸缉鏀?,
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
                    name = "闅忚窛绂荤缉鏀?,
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
                    name = "鐐归棿璺?,
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
                    name = "瀛樻椿鏃堕棿",
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
                    name = "鏈€澶х偣鏁?,
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
        -- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?澶栬灏哄 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?        sizeTitle = {
            type = "description",
            order = 35,
            fontSize = "medium",
            name = "|cFFFFD200澶栬灏哄|r",
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
                    name = "鐐瑰搴?,
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
                    name = "鐐归珮搴?,
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
                    name = "閫忔槑搴?,
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
                    name = "灞傜骇",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    values = function()
                        return {
                            [1] = "TOOLTIP (鍓嶆櫙)",
                            [2] = "BACKGROUND (鑳屾櫙)",
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
                    name = "娣峰悎妯″紡",
                    disabled = function()
                        return not GetCursorTrailConfig().enabled
                    end,
                    values = function()
                        return {
                            [1] = "鍙戝厜 (ADD)",
                            [2] = "鏅€?(BLEND)",
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
                    name = "X 鍋忕Щ",
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
                    name = "Y 鍋忕Щ",
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
        -- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?绾圭悊涓庨鑹?鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?        colorTitle = {
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
                    name = "浣跨敤鑱屼笟鑹茶鐩?,
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
                    name = "棰滆壊閫熷害",
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
                    name = "浣跨敤棰滆壊鏁?,
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
        -- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鍙抽敭瑙傚療 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?        lookTitle = {
            type = "description",
            order = 100,
            fontSize = "medium",
            name = "|cFFFFD200鍙抽敭瑙傚療|r",
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
                    name = "鍏佽瓒婅繃 UI 杞瑙?,
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
                    name = "浠呮垬鏂椾腑鍏佽杞瑙?,
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
                    name = "鍙抽敭鏃堕珮浜紶鏍?,
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
                    name = "楂樹寒灏哄",
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
        -- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?鎬ц兘涓庤皟璇?鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?        perfTitle = {
            type = "description",
            order = 130,
            fontSize = "medium",
            name = "|cFFFFD200鎬ц兘涓庤皟璇晐r",
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
                    name = "鑷€傚簲鏇存柊棰戠巼",
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
                    name = "鐩爣鏇存柊 Hz",
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
                    name = "鏄剧ず FPS",
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
            name = "鎭㈠榛樿璁剧疆",
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
            name = "|cFF888888褰撳墠娌℃湁鍙樉绀虹殑棰戦亾鎸夐挳銆倈r",
        }
        return args
    end

    for index, def in ipairs(defs) do
        local entryIndex = index
        local key = def.key
        local isCustom = def.action == "custom"
        local rowName = (isCustom and "[鑷畾涔塢 " or "[鍐呯疆] ") .. def.label

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
                    label = "涓婄Щ",
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
                    label = "涓嬬Щ",
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
                    label = isCustom and "鍒犻櫎" or "绉婚櫎",
                    width = 50,
                    confirm = true,
                    confirmText = "纭绉婚櫎杩欎釜鎸夐挳鍚楋紵",
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
        name = "鐣岄潰澧炲己",
        order = 12,
        args = {
            mouseCursor = {
                type = "group",
                name = "榧犳爣鎸囬拡",
                order = 5,
                childGroups = "tab",
                args = {
                    cursorTrail = BuildTab("榧犳爣鎷栧熬", 10, BuildCursorTrailArgs()),
                },
            },
            quickChat = {
                type = "group",
                name = "蹇嵎棰戦亾",
                order = 10,
                childGroups = "tab",
                args = {
                    basic = BuildTab("鍩虹璁剧疆", 10, {
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
                                    name = "鍚敤蹇嵎棰戦亾",
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
                                    name = "瑙ｉ攣浣嶇疆鎷栧姩",
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
                                    name = "涓栫晫棰戦亾鍚嶇О",
                                    disabled = function()
                                        return not GetConfig().enabled
                                    end,
                                    get = function()
                                        return GetConfig().worldChannelName or ""
                                    end,
                                    set = function(_, value)
                                        local text = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                        GetConfig().worldChannelName = text ~= "" and text or "澶ц剼涓栫晫棰戦亾"
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
                                    name = "鎸夐挳闂撮殧",
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
                                    name = "鏂囧瓧澶у皬",
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
                                    name = "蹇嵎鏉″瓧浣?,
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
                            name = "鎭㈠榛樿璁剧疆",
                            func = function()
                                Core:ResetQuickChatConfig()
                                RefreshQuickChat(true)
                            end,
                        },
                    }),
                    buttonManagement = BuildTab("鎸夐挳绠＄悊", 20, BuildButtonManagementArgs()),
                    addCustom = BuildTab("鑷畾涔夋寜閽?, 30, {
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
                                    name = "鎸夐挳鏂囧瓧",
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
                                    name = "鑱婂ぉ鎸囦护",
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
                                    name = "娣诲姞鎸夐挳",
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
                            name = "鎭㈠鍐呯疆鎸夐挳",
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
