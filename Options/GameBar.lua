local _, NS = ...
local Core = NS.Core

local function GetGameBarModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.GameBar
end

local function GetGameBarConfig()
    return Core:GetConfig("interfaceEnhance", "gameBar")
end

local function RefreshGameBar(notifyOptions)
    local module = GetGameBarModule()
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
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

local function EnsureButtonSlots(sideKey)
    local config = GetGameBarConfig()
    config[sideKey] = config[sideKey] or {}

    if #config[sideKey] == 0 then
        config[sideKey][1] = "NONE"
    end

    return config[sideKey]
end

local function GetButtonChoices()
    local values = {}
    local defs = NS.GameBarButtonDefs or {}
    local ids = NS.GameBarButtonIDs or {}

    for _, id in ipairs(ids) do
        local def = defs[id]
        if def then
            values[id] = def.label or id
        end
    end

    return values
end

local function GetHearthstoneChoices()
    return NS.GetGameBarHearthstoneChoices and NS.GetGameBarHearthstoneChoices() or {
        AUTO = "自动",
        RANDOM = "随机",
    }
end

local function RemoveSlot(sideKey, index)
    local slots = EnsureButtonSlots(sideKey)
    if #slots <= 1 then
        return
    end

    table.remove(slots, index)

    if #slots == 0 then
        slots[1] = "NONE"
    end
end

local function MakeSlotRow(sideKey, index)
    return {
        type = "group",
        order = 20 + index,
        name = "",
        layout = "row",
        hidden = function()
            return index > #EnsureButtonSlots(sideKey)
        end,
        args = {
            slot = {
                type = "select",
                order = 1,
                width = 2.1,
                name = "按钮 " .. tostring(index),
                disabled = function()
                    return not GetGameBarConfig().enabled
                end,
                values = GetButtonChoices,
                get = function()
                    return EnsureButtonSlots(sideKey)[index] or "NONE"
                end,
                set = function(_, value)
                    EnsureButtonSlots(sideKey)[index] = value
                    RefreshGameBar(true)
                end,
            },
            delete = {
                type = "execute",
                order = 2,
                width = 0.7,
                name = "删除",
                disabled = function()
                    return not GetGameBarConfig().enabled or #EnsureButtonSlots(sideKey) <= 1
                end,
                confirm = true,
                confirmText = "确认删除这个按钮槽位吗？",
                func = function()
                    RemoveSlot(sideKey, index)
                    RefreshGameBar(true)
                end,
            },
        },
    }
end

local function BuildSideSlotArgs(sideKey)
    local args = {
        addSlot = {
            type = "execute",
            order = 10,
            width = 1.0,
            name = "新增按钮",
            disabled = function()
                return not GetGameBarConfig().enabled or #EnsureButtonSlots(sideKey) >= 7
            end,
            func = function()
                local slots = EnsureButtonSlots(sideKey)
                if #slots < 7 then
                    table.insert(slots, "NONE")
                    RefreshGameBar(true)
                end
            end,
        },
    }

    for index = 1, 7 do
        args["slotRow" .. tostring(index)] = MakeSlotRow(sideKey, index)
    end

    return args
end

local function BuildBasicArgs()
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
                    name = "启用动作条",
                    get = function()
                        return GetGameBarConfig().enabled
                    end,
                    set = function(_, value)
                        GetGameBarConfig().enabled = value and true or false
                        RefreshGameBar(true)
                    end,
                },
                locked = {
                    type = "toggle",
                    order = 2,
                    width = 1.0,
                    name = "锁定位置",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().locked
                    end,
                    set = function(_, value)
                        GetGameBarConfig().locked = value and true or false
                        RefreshGameBar(false)
                    end,
                },
                mouseOver = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "仅鼠标悬停显示",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().mouseOver
                    end,
                    set = function(_, value)
                        GetGameBarConfig().mouseOver = value and true or false
                        RefreshGameBar(false)
                    end,
                },
            },
        },
        appearanceRow1 = {
            type = "group",
            order = 20,
            name = "",
            layout = "row",
            args = {
                buttonSize = {
                    type = "range",
                    order = 1,
                    width = 1.0,
                    name = "按钮大小",
                    min = 16,
                    max = 64,
                    step = 2,
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().buttonSize or 28
                    end,
                    set = function(_, value)
                        GetGameBarConfig().buttonSize = value
                        RefreshGameBar(false)
                    end,
                },
                spacing = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "按钮间距",
                    min = 0,
                    max = 20,
                    step = 1,
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().spacing or 4
                    end,
                    set = function(_, value)
                        GetGameBarConfig().spacing = value
                        RefreshGameBar(false)
                    end,
                },
                middleWidth = {
                    type = "range",
                    order = 3,
                    width = 1.0,
                    name = "中间区域宽度",
                    min = 50,
                    max = 160,
                    step = 2,
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().middleWidth or 80
                    end,
                    set = function(_, value)
                        GetGameBarConfig().middleWidth = value
                        RefreshGameBar(false)
                    end,
                },
            },
        },
        appearanceRow2 = {
            type = "group",
            order = 30,
            name = "",
            layout = "row",
            args = {
                timeFontSize = {
                    type = "range",
                    order = 1,
                    width = 1.0,
                    name = "时间字体大小",
                    min = 10,
                    max = 36,
                    step = 1,
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().timeFontSize or 20
                    end,
                    set = function(_, value)
                        GetGameBarConfig().timeFontSize = value
                        RefreshGameBar(false)
                    end,
                },
                animationDuration = {
                    type = "range",
                    order = 2,
                    width = 1.0,
                    name = "悬停动画时长",
                    min = 0,
                    max = 1,
                    step = 0.01,
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().animationDuration or 0.2
                    end,
                    set = function(_, value)
                        GetGameBarConfig().animationDuration = value
                        RefreshGameBar(false)
                    end,
                },
                showBackground = {
                    type = "toggle",
                    order = 3,
                    width = 1.0,
                    name = "显示背景",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        return GetGameBarConfig().showBackground
                    end,
                    set = function(_, value)
                        GetGameBarConfig().showBackground = value and true or false
                        RefreshGameBar(false)
                    end,
                },
            },
        },
        backgroundColor = {
            type = "color",
            order = 40,
            width = 1.0,
            name = "背景颜色",
            hasAlpha = true,
            disabled = function()
                local config = GetGameBarConfig()
                return not config.enabled or not config.showBackground
            end,
            get = function()
                local color = GetGameBarConfig().backgroundColor or { r = 0, g = 0, b = 0, a = 0.45 }
                return color.r, color.g, color.b, color.a
            end,
            set = function(_, r, g, b, a)
                GetGameBarConfig().backgroundColor = { r = r, g = g, b = b, a = a }
                RefreshGameBar(false)
            end,
        },
        reset = {
            type = "execute",
            order = 100,
            width = 1.0,
            name = "恢复默认设置",
            func = function()
                Core:ResetGameBarConfig()
                RefreshGameBar(true)
            end,
        },
    }
end

function NS.BuildGameBarOptions()
    return {
        type = "group",
        name = "动作条",
        order = 8,
        childGroups = "tab",
        args = {
            basic = BuildTab("基础设置", 10, BuildBasicArgs()),
            leftSlots = BuildTab("左侧按钮", 20, BuildSideSlotArgs("leftButtons")),
            rightSlots = BuildTab("右侧按钮", 30, BuildSideSlotArgs("rightButtons")),
            hearthstone = BuildTab("炉石设置", 40, {
                showBindLocation = {
                    type = "toggle",
                    order = 10,
                    width = 1.0,
                    name = "显示炉石绑定地点",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    get = function()
                        local hearthstone = GetGameBarConfig().hearthstone or {}
                        return hearthstone.showBindLocation ~= false
                    end,
                    set = function(_, value)
                        local config = GetGameBarConfig()
                        config.hearthstone = config.hearthstone or {}
                        config.hearthstone.showBindLocation = value and true or false
                        RefreshGameBar(false)
                    end,
                },
                left = {
                    type = "select",
                    order = 20,
                    width = 1.2,
                    name = "左键",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    values = GetHearthstoneChoices,
                    get = function()
                        local hearthstone = GetGameBarConfig().hearthstone or {}
                        return hearthstone.left or "AUTO"
                    end,
                    set = function(_, value)
                        local config = GetGameBarConfig()
                        config.hearthstone = config.hearthstone or {}
                        config.hearthstone.left = value
                        RefreshGameBar(false)
                    end,
                },
                middle = {
                    type = "select",
                    order = 30,
                    width = 1.2,
                    name = "中键",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    values = GetHearthstoneChoices,
                    get = function()
                        local hearthstone = GetGameBarConfig().hearthstone or {}
                        return hearthstone.middle or "RANDOM"
                    end,
                    set = function(_, value)
                        local config = GetGameBarConfig()
                        config.hearthstone = config.hearthstone or {}
                        config.hearthstone.middle = value
                        RefreshGameBar(false)
                    end,
                },
                right = {
                    type = "select",
                    order = 40,
                    width = 1.2,
                    name = "右键",
                    disabled = function()
                        return not GetGameBarConfig().enabled
                    end,
                    values = GetHearthstoneChoices,
                    get = function()
                        local hearthstone = GetGameBarConfig().hearthstone or {}
                        return hearthstone.right or "AUTO"
                    end,
                    set = function(_, value)
                        local config = GetGameBarConfig()
                        config.hearthstone = config.hearthstone or {}
                        config.hearthstone.right = value
                        RefreshGameBar(false)
                    end,
                },
            }),
        },
    }
end
