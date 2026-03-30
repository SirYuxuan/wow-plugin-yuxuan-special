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

local function RefreshQuickChat(notifyOptions)
    local quickChat = GetModule()
    if quickChat and quickChat.RefreshFromSettings then
        quickChat:RefreshFromSettings()
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
