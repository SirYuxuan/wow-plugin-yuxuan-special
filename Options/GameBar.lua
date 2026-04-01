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
        AUTO = "Auto",
        RANDOM = "Random",
    }
end

local function MakeSlotOption(sideKey, index)
    return {
        type = "select",
        order = 10 + index,
        width = 1.0,
        name = "Button " .. tostring(index),
        hidden = function()
            return index > #EnsureButtonSlots(sideKey)
        end,
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
    }
end

local function BuildSideSlotArgs(sideKey)
    local args = {}

    for index = 1, 7 do
        args["slot" .. tostring(index)] = MakeSlotOption(sideKey, index)
    end

    args.controlRow = {
        type = "group",
        order = 200,
        name = "",
        layout = "row",
        args = {
            addSlot = {
                type = "execute",
                order = 1,
                width = 0.8,
                name = "Add Slot",
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
            removeSlot = {
                type = "execute",
                order = 2,
                width = 0.8,
                name = "Remove Slot",
                disabled = function()
                    return not GetGameBarConfig().enabled or #EnsureButtonSlots(sideKey) <= 1
                end,
                confirm = true,
                confirmText = "Remove the last button slot?",
                func = function()
                    local slots = EnsureButtonSlots(sideKey)
                    if #slots > 1 then
                        table.remove(slots)
                        RefreshGameBar(true)
                    end
                end,
            },
        },
    }

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
                    name = "Enable Bar",
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
                    name = "Lock Position",
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
                    name = "Mouseover Only",
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
                    name = "Button Size",
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
                    name = "Spacing",
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
                    name = "Middle Width",
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
                    name = "Time Font",
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
                    name = "Hover Anim",
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
                    name = "Show Background",
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
            name = "Background Color",
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
            name = "Reset Defaults",
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
        name = "Action Bar",
        order = 8,
        childGroups = "tab",
        args = {
            basic = BuildTab("Basic", 10, BuildBasicArgs()),
            leftSlots = BuildTab("Left Buttons", 20, BuildSideSlotArgs("leftButtons")),
            rightSlots = BuildTab("Right Buttons", 30, BuildSideSlotArgs("rightButtons")),
            hearthstone = BuildTab("Hearthstone", 40, {
                showBindLocation = {
                    type = "toggle",
                    order = 10,
                    width = 1.0,
                    name = "Show Bind Location",
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
                selectRow = {
                    type = "group",
                    order = 20,
                    name = "",
                    layout = "row",
                    args = {
                        left = {
                            type = "select",
                            order = 1,
                            width = 1.0,
                            name = "Left Click",
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
                            order = 2,
                            width = 1.0,
                            name = "Middle Click",
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
                            order = 3,
                            width = 1.0,
                            name = "Right Click",
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
                    },
                },
            }),
        },
    }
end
