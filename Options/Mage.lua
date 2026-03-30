local _, NS = ...
local Core = NS.Core

--[[
法师职业辅助设置页。

当前只真正实现了冰霜专精的碎冰监控，
但文件结构故意保留了“职业 -> 专精 -> 具体功能”这条层级。

这样做的目的是：
1. 后续加奥术、火法时，不需要推翻现有页面结构。
2. 自定义设置系统可以直接把这些 group / tab 渲染成导航与标签页。
]]

local pendingMonitorCount = 6
local pendingMonitorColor = { r = 1.00, g = 0.82, b = 0.20, a = 1.00 }
local MAGE_CLASS_FILE = "MAGE"

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
    -- 运行中的碎冰指示器要先吃到最新配置，
    -- 如果当前设置窗口也开着，再通知 UI 重新计算和重绘。
    local indicator = GetIndicator()
    if indicator and indicator.RefreshFromSettings then
        indicator:RefreshFromSettings()
    end
    if notifyOptions then
        NotifyChanged()
    end
end

local function IsIndicatorDisabled()
    return not GetConfig().enabled
end

local function IsMagePlayer()
    local _, classFile = UnitClass("player")
    return classFile == MAGE_CLASS_FILE
end

local function IsCurrentSpec(specID)
    if not IsMagePlayer() then
        return false
    end

    local currentSpecIndex = GetSpecialization()
    if not currentSpecIndex then
        return false
    end

    local currentSpecID = GetSpecializationInfo(currentSpecIndex)
    return currentSpecID == specID
end

local function GetSpecTabName(label, specID)
    if IsCurrentSpec(specID) then
        return label
    end
    return "|cFF7F7F7F" .. label .. "|r"
end

local function GetAutoSpecTabKey()
    if not IsMagePlayer() then
        return nil
    end

    local currentSpecIndex = GetSpecialization and GetSpecialization()
    if not currentSpecIndex then
        return "frost"
    end

    local currentSpecID = GetSpecializationInfo and GetSpecializationInfo(currentSpecIndex)
    if currentSpecID == 62 then
        return "arcane"
    end
    if currentSpecID == 63 then
        return "fire"
    end
    if currentSpecID == 64 then
        return "frost"
    end

    return "frost"
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
            name = "|cFF888888当前还没有监控阈值，使用下方“添加监控”即可新增。|r",
        }
        return args
    end

    local order = 10
    for index, entry in ipairs(list) do
        local entryIndex = index
        local monitorEntry = entry

        args["entry_" .. entryIndex] = {
            type = "group",
            order = order,
            name = string.format("监控 %d", entryIndex),
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
                        return monitorEntry.count or 1
                    end,
                    set = function(_, value)
                        monitorEntry.count = value
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
                        local color = monitorEntry.color or { r = 1, g = 1, b = 1, a = 1 }
                        return color.r, color.g, color.b, color.a or 1
                    end,
                    set = function(_, r, g, b, a)
                        monitorEntry.color = { r = r, g = g, b = b, a = a }
                        RefreshIndicator(false)
                    end,
                },
                remove = {
                    type = "execute",
                    order = 3,
                    name = "删除",
                    width = 0.8,
                    confirm = true,
                    confirmText = "确认删除这个监控阈值吗？",
                    func = function()
                        RemoveMonitorEntry(entryIndex)
                        RefreshIndicator(true)
                        C_Timer.After(0, function()
                            RefreshIndicator(true)
                        end)
                    end,
                },
            },
        }
        order = order + 10
    end

    return args
end

local function BuildUnavailableSpecTab(label, order, specID)
    return {
        type = "group",
        name = function()
            return GetSpecTabName(label, specID)
        end,
        order = order,
        disabled = function()
            return not IsCurrentSpec(specID)
        end,
        disabledTip = "请切换到对应专精后查看",
        args = {
            desc = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = "|cFF888888暂未开放|r",
                width = "full",
            },
        },
    }
end

local function BuildFrostSpecTab()
    return {
        type = "group",
        name = function()
            return GetSpecTabName("冰霜专精", 64)
        end,
        order = 30,
        disabled = function()
            return not IsCurrentSpec(64)
        end,
        disabledTip = "请切换到冰霜专精后查看",
        args = {
            intro = {
                type = "description",
                hidden = true,
                order = 1,
                fontSize = "medium",
                name = "碎冰指示会实时监控当前目标身上的冻结层数。",
                width = "full",
            },
            enabled = {
                type = "toggle",
                order = 10,
                width = 1.2,
                name = "碎冰指示",
                desc = "未勾选时不注册运行时事件，也不会加载任何实际监控逻辑。",
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
                disabled = IsIndicatorDisabled,
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
                disabled = IsIndicatorDisabled,
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
                disabled = IsIndicatorDisabled,
                get = function()
                    return GetConfig().showOutOfCombat
                end,
                set = function(_, value)
                    GetConfig().showOutOfCombat = value and true or false
                    RefreshIndicator(false)
                end,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                        disabled = IsIndicatorDisabled,
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
                            C_Timer.After(0, function()
                                RefreshIndicator(true)
                            end)
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
    }
end

function NS.BuildMageAssistOptions()
    return {
        type = "group",
        name = "法师",
        order = 10,
        childGroups = "tab",
        autoSelectChild = GetAutoSpecTabKey,
        args = {
            arcane = BuildUnavailableSpecTab("奥术专精", 10, 62),
            fire = BuildUnavailableSpecTab("火焰专精", 20, 63),
            frost = BuildFrostSpecTab(),
        },
    }
end
