local _, NS = ...
local Core = NS.Core

local pendingMonitorCount = 6
local pendingMonitorColor = { r = 1.00, g = 0.82, b = 0.20, a = 1.00 }

local function GetIndicator()
    return NS.Modules.ClassAssist.Mage.ShatterIndicator
end

local function GetConfig()
    return Core:GetConfig("classAssist", "mage", "shatterIndicator")
end

local function NotifyChanged()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function RefreshIndicator(notifyOptions)
    local indicator = GetIndicator()
    if indicator and indicator.RefreshFromSettings then
        indicator:RefreshFromSettings()
    end
    if notifyOptions then
        NotifyChanged()
    end
end

local function GetCurrentSpecLabel()
    local currentSpecIndex = GetSpecialization()
    if not currentSpecIndex then
        return "当前专精 未检测到专精"
    end

    local specID, specName = GetSpecializationInfo(currentSpecIndex)
    if not specID then
        return "当前专精 未检测到专精"
    end

    if specID == 64 then
        return "当前专精 冰霜 已开放"
    end

    return string.format("当前专精 %s 暂未开放", specName or "未知")
end

local function UpsertMonitorEntry(count, color)
    local config = GetConfig()
    config.monitorList = config.monitorList or {}

    for _, entry in ipairs(config.monitorList) do
        if entry.count == count then
            entry.color = {
                r = color.r,
                g = color.g,
                b = color.b,
                a = color.a or 1,
            }
            return
        end
    end

    table.insert(config.monitorList, {
        count = count,
        color = {
            r = color.r,
            g = color.g,
            b = color.b,
            a = color.a or 1,
        },
    })
end

local function RemoveMonitorEntry(index)
    local config = GetConfig()
    if config.monitorList and config.monitorList[index] then
        table.remove(config.monitorList, index)
    end
end

local function BuildMonitorListArgs()
    local args = {}
    local list = GetConfig().monitorList or {}

    table.sort(list, function(left, right)
        return (left.count or 0) < (right.count or 0)
    end)

    if #list == 0 then
        args.empty = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = "|cFF888888当前还没有监控阈值 使用下方 添加监控 可以新增|r",
        }
        return args
    end

    local order = 10
    for index, entry in ipairs(list) do
        args["entry_" .. index] = {
            type = "group",
            order = order,
            name = string.format("监控 %d", index),
            inline = true,
            args = {
                count = {
                    type = "range",
                    order = 1,
                    name = "数量",
                    min = 1,
                    max = 20,
                    step = 1,
                    width = 1.0,
                    get = function()
                        return entry.count or 1
                    end,
                    set = function(_, value)
                        entry.count = value
                        RefreshIndicator(false)
                    end,
                },
                color = {
                    type = "color",
                    order = 2,
                    name = "颜色",
                    hasAlpha = true,
                    width = 0.8,
                    get = function()
                        local color = entry.color or { r = 1, g = 1, b = 1, a = 1 }
                        return color.r, color.g, color.b, color.a or 1
                    end,
                    set = function(_, r, g, b, a)
                        entry.color = { r = r, g = g, b = b, a = a }
                        RefreshIndicator(false)
                    end,
                },
                remove = {
                    type = "execute",
                    order = 3,
                    name = "删除",
                    width = 0.8,
                    confirm = true,
                    confirmText = "确认删除这个监控阈值吗",
                    func = function()
                        RemoveMonitorEntry(index)
                        RefreshIndicator(true)
                    end,
                },
            },
        }
        order = order + 10
    end

    return args
end

--[[
法师页当前只真正开放冰霜专精
这里把未开放专精保留成占位 是为了后面扩展时树结构稳定
]]

function NS.BuildMageAssistOptions()
    return {
        type = "group",
        name = "法师",
        order = 10,
        args = {
            status = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = function()
                    return "|cFFCCCCCC" .. GetCurrentSpecLabel() .. "|r"
                end,
            },
            spacer1 = {
                type = "description",
                order = 2,
                name = " ",
                width = "full",
            },
            arcane = {
                type = "group",
                order = 10,
                name = "奥术专精",
                args = {
                    desc = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "|cFF888888暂未开放|r",
                    },
                },
            },
            fire = {
                type = "group",
                order = 20,
                name = "火焰专精",
                args = {
                    desc = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "|cFF888888暂未开放|r",
                    },
                },
            },
            frost = {
                type = "group",
                order = 30,
                name = "冰霜专精",
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "碎冰指示会实时监控当前目标身上的冻结层数",
                    },
                    enabled = {
                        type = "toggle",
                        order = 10,
                        width = 1.2,
                        name = "碎冰指示",
                        desc = "未勾选时不注册运行时事件 不加载任何实际监控逻辑",
                        get = function()
                            return GetConfig().enabled
                        end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            RefreshIndicator(false)
                        end,
                    },
                    unlocked = {
                        type = "toggle",
                        order = 11,
                        width = 1.0,
                        name = "解锁框体",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().unlocked
                        end,
                        set = function(_, value)
                            GetConfig().unlocked = value and true or false
                            RefreshIndicator(false)
                        end,
                    },
                    testToggle = {
                        type = "execute",
                        order = 12,
                        width = 0.9,
                        name = function()
                            return GetIndicator():IsTesting() and "结束测试" or "开始测试"
                        end,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        func = function()
                            GetIndicator():ToggleTestMode()
                            RefreshIndicator(true)
                        end,
                    },
                    showOutOfCombat = {
                        type = "toggle",
                        order = 13,
                        width = 1.0,
                        name = "非战斗显示",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showOutOfCombat
                        end,
                        set = function(_, value)
                            GetConfig().showOutOfCombat = value and true or false
                            RefreshIndicator(false)
                        end,
                    },
                    spacer2 = {
                        type = "description",
                        order = 14,
                        name = " ",
                        width = "full",
                    },
                    effectGroup = {
                        type = "group",
                        order = 20,
                        name = "效果选项",
                        inline = true,
                        args = {
                            showIcon = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "显示图标",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().showIcon
                                end,
                                set = function(_, value)
                                    GetConfig().showIcon = value and true or false
                                    RefreshIndicator(false)
                                end,
                            },
                            showBorders = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "显示边框",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().showBorders
                                end,
                                set = function(_, value)
                                    GetConfig().showBorders = value and true or false
                                    RefreshIndicator(false)
                                end,
                            },
                            width = {
                                type = "range",
                                order = 3,
                                width = 1.1,
                                name = "格子宽度",
                                min = 1,
                                max = 100,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().width
                                end,
                                set = function(_, value)
                                    GetConfig().width = value
                                    RefreshIndicator(false)
                                end,
                            },
                            height = {
                                type = "range",
                                order = 4,
                                width = 1.1,
                                name = "格子高度",
                                min = 1,
                                max = 100,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().height
                                end,
                                set = function(_, value)
                                    GetConfig().height = value
                                    RefreshIndicator(false)
                                end,
                            },
                            scale = {
                                type = "range",
                                order = 5,
                                width = 1.1,
                                name = "缩放",
                                min = 1,
                                max = 5,
                                step = 0.05,
                                isPercent = false,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().scale
                                end,
                                set = function(_, value)
                                    GetConfig().scale = value
                                    RefreshIndicator(false)
                                end,
                            },
                            spacing = {
                                type = "range",
                                order = 6,
                                width = 1.1,
                                name = "格子间隔",
                                min = 0,
                                max = 20,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().spacing
                                end,
                                set = function(_, value)
                                    GetConfig().spacing = value
                                    RefreshIndicator(false)
                                end,
                            },
                            texture = {
                                type = "select",
                                order = 7,
                                width = 1.3,
                                name = "格子材质",
                                values = function()
                                    return GetIndicator():GetTextureChoices()
                                end,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().texture
                                end,
                                set = function(_, value)
                                    GetConfig().texture = value
                                    RefreshIndicator(false)
                                end,
                            },
                            defaultColor = {
                                type = "color",
                                order = 8,
                                width = 0.8,
                                name = "默认颜色",
                                hasAlpha = true,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    local color = GetConfig().defaultColor
                                    return color.r, color.g, color.b, color.a or 1
                                end,
                                set = function(_, r, g, b, a)
                                    GetConfig().defaultColor = { r = r, g = g, b = b, a = a }
                                    RefreshIndicator(false)
                                end,
                            },
                        },
                    },
                    monitorList = {
                        type = "group",
                        order = 30,
                        name = "监控列表",
                        inline = true,
                        args = BuildMonitorListArgs(),
                    },
                    addMonitor = {
                        type = "group",
                        order = 40,
                        name = "添加监控",
                        inline = true,
                        args = {
                            addCount = {
                                type = "range",
                                order = 1,
                                width = 1.0,
                                name = "数量",
                                min = 1,
                                max = 20,
                                step = 1,
                                get = function()
                                    return pendingMonitorCount
                                end,
                                set = function(_, value)
                                    pendingMonitorCount = value
                                end,
                            },
                            addColor = {
                                type = "color",
                                order = 2,
                                width = 0.8,
                                name = "颜色",
                                hasAlpha = true,
                                get = function()
                                    return pendingMonitorColor.r, pendingMonitorColor.g, pendingMonitorColor.b,
                                        pendingMonitorColor.a or 1
                                end,
                                set = function(_, r, g, b, a)
                                    pendingMonitorColor = { r = r, g = g, b = b, a = a }
                                end,
                            },
                            addButton = {
                                type = "execute",
                                order = 3,
                                width = 0.9,
                                name = "添加监控",
                                func = function()
                                    UpsertMonitorEntry(pendingMonitorCount, pendingMonitorColor)
                                    RefreshIndicator(true)
                                end,
                            },
                            resetButton = {
                                type = "execute",
                                order = 4,
                                width = 1.1,
                                name = "恢复默认设置",
                                func = function()
                                    Core:ResetMageShatterIndicatorConfig()
                                    RefreshIndicator(true)
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end
