local _, NS = ...
local Core = NS.Core

--[[
战斗辅助设置页。

这个文件只负责“描述有哪些配置项”，不负责真正创建界面控件。
界面长什么样、怎么渲染，已经统一交给自定义设置系统处理。

继续保留这种 options-table 写法，后面扩展新配置会很省事：
1. 模块层只需要关心 get / set / desc / values。
2. 渲染层可以独立替换，不会反过来污染业务逻辑。
]]

local DEFAULT_READY_TEXT = "饰品好了！"
local DEFAULT_SOUND_PATH = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Audio\\SP.mp3"

local function GetMonitor()
    return NS.Modules.CombatAssist and NS.Modules.CombatAssist.TrinketMonitor
end

local function GetQuickFocus()
    return NS.Modules.CombatAssist and NS.Modules.CombatAssist.QuickFocus
end

local function GetQuickFocusText(key, fallback)
    local quickFocus = GetQuickFocus()
    if quickFocus and quickFocus.GetOptionText then
        return quickFocus:GetOptionText(key) or fallback
    end
    return fallback
end

local function GetQuickFocusConfig()
    return Core:GetConfig("combatAssist", "quickFocus")
end

local function RefreshQuickFocus(notifyOptions)
    local quickFocus = GetQuickFocus()
    if quickFocus and quickFocus.RefreshFromSettings then
        quickFocus:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function GetConfig()
    return Core:GetConfig("combatAssist", "trinketMonitor")
end

local function IsDisabled()
    return not GetConfig().enabled
end

local function RefreshMonitor(notifyOptions)
    -- 先刷新运行时模块，再按需让设置界面重绘，
    -- 这样配置改动能够即时反馈到屏幕上的监控效果。
    local monitor = GetMonitor()
    if monitor and monitor.RefreshFromSettings then
        monitor:RefreshFromSettings()
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

function NS.BuildCombatAssistOptions()
    return {
        type = "group",
        name = "战斗辅助",
        order = 15,
        args = {
            quickFocus = {
                type = "group",
                name = function()
                    return GetQuickFocusText("groupName", "Quick Focus")
                end,
                order = 5,
                childGroups = "tab",
                args = {
                    basic = BuildTab(function()
                        return GetQuickFocusText("basicTab", "Basic")
                    end, 10, {
                        intro = {
                            type = "description",
                            order = 1,
                            fontSize = "medium",
                            name = function()
                                return GetQuickFocusText("intro", "Hold modifier + mouse button to focus mouseover target.")
                            end,
                            width = "full",
                        },
                        enabled = {
                            type = "toggle",
                            order = 10,
                            width = 1.0,
                            name = function()
                                return GetQuickFocusText("enabled", "Enable Quick Focus")
                            end,
                            get = function()
                                return GetQuickFocusConfig().enabled
                            end,
                            set = function(_, value)
                                GetQuickFocusConfig().enabled = value and true or false
                                RefreshQuickFocus(false)
                            end,
                        },
                        modifier = {
                            type = "select",
                            order = 11,
                            width = 1.0,
                            name = function()
                                return GetQuickFocusText("modifier", "Modifier")
                            end,
                            disabled = function()
                                return not GetQuickFocusConfig().enabled
                            end,
                            values = function()
                                local quickFocus = GetQuickFocus()
                                return quickFocus and quickFocus.GetModifierChoices and quickFocus:GetModifierChoices() or {}
                            end,
                            get = function()
                                return GetQuickFocusConfig().modifier
                            end,
                            set = function(_, value)
                                GetQuickFocusConfig().modifier = value
                                RefreshQuickFocus(false)
                            end,
                        },
                        mouseButton = {
                            type = "select",
                            order = 12,
                            width = 1.1,
                            name = function()
                                return GetQuickFocusText("mouseButton", "Mouse Button")
                            end,
                            disabled = function()
                                return not GetQuickFocusConfig().enabled
                            end,
                            values = function()
                                local quickFocus = GetQuickFocus()
                                return quickFocus and quickFocus.GetButtonChoices and quickFocus:GetButtonChoices() or {}
                            end,
                            get = function()
                                return GetQuickFocusConfig().mouseButton
                            end,
                            set = function(_, value)
                                GetQuickFocusConfig().mouseButton = value
                                RefreshQuickFocus(false)
                            end,
                        },
                        allowClearFocus = {
                            type = "toggle",
                            order = 13,
                            width = 1.2,
                            name = function()
                                return GetQuickFocusText("allowClearFocus", "Clear focus when mouseover is empty")
                            end,
                            disabled = function()
                                return not GetQuickFocusConfig().enabled
                            end,
                            get = function()
                                return GetQuickFocusConfig().allowClearFocus
                            end,
                            set = function(_, value)
                                GetQuickFocusConfig().allowClearFocus = value and true or false
                                RefreshQuickFocus(false)
                            end,
                        },
                        reset = {
                            type = "execute",
                            order = 90,
                            width = 1.0,
                            name = function()
                                return GetQuickFocusText("reset", "Reset")
                            end,
                            func = function()
                                Core:ResetQuickFocusConfig()
                                RefreshQuickFocus(true)
                            end,
                        },
                    }),
                    marker = BuildTab(function()
                        return GetQuickFocusText("markerTab", "Marking")
                    end, 20, {
                        enableMarking = {
                            type = "toggle",
                            order = 10,
                            width = 1.0,
                            name = function()
                                return GetQuickFocusText("enableMarking", "Mark target on focus")
                            end,
                            disabled = function()
                                return not GetQuickFocusConfig().enabled
                            end,
                            get = function()
                                return GetQuickFocusConfig().enableMarking
                            end,
                            set = function(_, value)
                                GetQuickFocusConfig().enableMarking = value and true or false
                                RefreshQuickFocus(false)
                            end,
                        },
                        selectedMarker = {
                            type = "select",
                            order = 11,
                            width = "full",
                            name = function()
                                return GetQuickFocusText("selectedMarker", "Marker")
                            end,
                            disabled = function()
                                local config = GetQuickFocusConfig()
                                return (not config.enabled) or (not config.enableMarking)
                            end,
                            values = function()
                                local quickFocus = GetQuickFocus()
                                return quickFocus and quickFocus.GetMarkerChoices and quickFocus:GetMarkerChoices() or {}
                            end,
                            get = function()
                                return GetQuickFocusConfig().selectedMarker
                            end,
                            set = function(_, value)
                                GetQuickFocusConfig().selectedMarker = value
                                RefreshQuickFocus(false)
                            end,
                        },
                    }),
                },
            },
            trinketMonitor = {
                type = "group",
                name = "饰品监控",
                order = 10,
                childGroups = "tab",
                args = {
                    basic = BuildTab("基础", 10, {
                        intro = {
                            type = "description",
                            order = 1,
                            fontSize = "medium",
                            name = "仅显示有主动效果的已装备饰品，支持点击施放、冷却显示、高亮、提示与音效。",
                            width = "full",
                        },
                        enabled = {
                            type = "toggle",
                            order = 10,
                            width = 1.0,
                            name = "启用饰品监控",
                            get = function()
                                return GetConfig().enabled
                            end,
                            set = function(_, value)
                                GetConfig().enabled = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        combatOnly = {
                            type = "toggle",
                            order = 11,
                            width = 1.0,
                            name = "非战斗状态隐藏",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().combatOnly
                            end,
                            set = function(_, value)
                                GetConfig().combatOnly = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        unlocked = {
                            type = "toggle",
                            order = 12,
                            width = 1.1,
                            name = "统一解锁位置",
                            desc = "开启后可以拖动饰品图标组和提示文字位置。",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().unlocked
                            end,
                            set = function(_, value)
                                GetConfig().unlocked = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        testAlert = {
                            type = "execute",
                            order = 13,
                            width = 0.9,
                            name = "测试提示",
                            disabled = IsDisabled,
                            func = function()
                                local monitor = GetMonitor()
                                if monitor and monitor.TestReadyAlert then
                                    monitor:TestReadyAlert()
                                end
                            end,
                        },
                        testSound = {
                            hidden = true,
                            type = "execute",
                            order = 14,
                            width = 0.9,
                            name = "试听音效",
                            disabled = IsDisabled,
                            func = function()
                                local monitor = GetMonitor()
                                if monitor and monitor.TestReadySound then
                                    monitor:TestReadySound()
                                end
                            end,
                        },
                        reset = {
                            type = "execute",
                            order = 90,
                            width = 1.1,
                            name = "恢复默认设置",
                            func = function()
                                Core:ResetTrinketMonitorConfig()
                                RefreshMonitor(true)
                            end,
                        },
                    }),
                    layout = BuildTab("图标布局", 20, {
                        iconSize = {
                            type = "range",
                            order = 10,
                            width = 1.1,
                            name = "图标大小",
                            min = 20,
                            max = 120,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().iconSize
                            end,
                            set = function(_, value)
                                GetConfig().iconSize = value
                                RefreshMonitor(false)
                            end,
                        },
                        spacing = {
                            type = "range",
                            order = 11,
                            width = 1.1,
                            name = "图标间距",
                            min = 0,
                            max = 40,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().spacing
                            end,
                            set = function(_, value)
                                GetConfig().spacing = value
                                RefreshMonitor(false)
                            end,
                        },
                        offsetX = {
                            type = "range",
                            order = 12,
                            width = 1.1,
                            name = "图标 X 偏移",
                            min = -1200,
                            max = 1200,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().offsetX
                            end,
                            set = function(_, value)
                                GetConfig().offsetX = value
                                RefreshMonitor(false)
                            end,
                        },
                        offsetY = {
                            type = "range",
                            order = 13,
                            width = 1.1,
                            name = "图标 Y 偏移",
                            min = -1200,
                            max = 1200,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().offsetY
                            end,
                            set = function(_, value)
                                GetConfig().offsetY = value
                                RefreshMonitor(false)
                            end,
                        },
                    }),
                    text = BuildTab("冷却文字", 30, {
                        showText = {
                            type = "toggle",
                            order = 10,
                            width = 1.0,
                            name = "显示文字",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().showText
                            end,
                            set = function(_, value)
                                GetConfig().showText = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        textSize = {
                            type = "range",
                            order = 11,
                            width = 1.1,
                            name = "文字大小",
                            min = 8,
                            max = 36,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().textSize
                            end,
                            set = function(_, value)
                                GetConfig().textSize = value
                                RefreshMonitor(false)
                            end,
                        },
                        textPosition = {
                            type = "select",
                            order = 12,
                            width = 1.1,
                            name = "文字位置",
                            disabled = IsDisabled,
                            values = function()
                                local monitor = GetMonitor()
                                return monitor and monitor.GetTextPositionChoices and monitor:GetTextPositionChoices() or {}
                            end,
                            get = function()
                                return GetConfig().textPosition
                            end,
                            set = function(_, value)
                                GetConfig().textPosition = value
                                RefreshMonitor(false)
                            end,
                        },
                        textColor = {
                            type = "color",
                            order = 13,
                            width = 0.8,
                            name = "文字颜色",
                            hasAlpha = true,
                            disabled = IsDisabled,
                            get = function()
                                local color = GetConfig().textColor
                                return color.r, color.g, color.b, color.a or 1
                            end,
                            set = function(_, r, g, b, a)
                                GetConfig().textColor = { r = r, g = g, b = b, a = a }
                                RefreshMonitor(false)
                            end,
                        },
                    }),
                    alert = BuildTab("高亮与提示", 40, {
                        highlightReady = {
                            type = "toggle",
                            order = 10,
                            width = 1.0,
                            name = "高亮就绪饰品",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().highlightReady
                            end,
                            set = function(_, value)
                                GetConfig().highlightReady = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        highlightColor = {
                            type = "color",
                            order = 11,
                            width = 0.8,
                            name = "高亮颜色",
                            hasAlpha = true,
                            disabled = IsDisabled,
                            get = function()
                                local color = GetConfig().highlightColor
                                return color.r, color.g, color.b, color.a or 1
                            end,
                            set = function(_, r, g, b, a)
                                GetConfig().highlightColor = { r = r, g = g, b = b, a = a }
                                RefreshMonitor(false)
                            end,
                        },
                        showReadyAlert = {
                            type = "toggle",
                            order = 12,
                            width = 1.0,
                            name = "屏幕提示",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().showReadyAlert
                            end,
                            set = function(_, value)
                                GetConfig().showReadyAlert = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        playReadySound = {
                            type = "toggle",
                            order = 13,
                            width = 1.0,
                            name = "播放音效",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().playReadySound
                            end,
                            set = function(_, value)
                                GetConfig().playReadySound = value and true or false
                                RefreshMonitor(false)
                            end,
                        },
                        readyText = {
                            type = "input",
                            order = 14,
                            width = 1.6,
                            name = "提示文字",
                            desc = "支持使用 %s 作为饰品名称占位。",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().readyText or ""
                            end,
                            set = function(_, value)
                                GetConfig().readyText = value ~= "" and value or DEFAULT_READY_TEXT
                                RefreshMonitor(false)
                            end,
                        },
                        readySoundPath = {
                            type = "input",
                            order = 15,
                            width = "full",
                            name = "音效路径",
                            desc = "支持完整路径，或直接填 Assets\\Audio\\SP.mp3 这种相对路径。",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().readySoundPath or ""
                            end,
                            set = function(_, value)
                                GetConfig().readySoundPath = value ~= "" and value or DEFAULT_SOUND_PATH
                                RefreshMonitor(false)
                            end,
                        },
                        testSound = {
                            type = "execute",
                            order = 16,
                            width = 0.9,
                            name = "试听音效",
                            disabled = IsDisabled,
                            func = function()
                                local monitor = GetMonitor()
                                if monitor and monitor.TestReadySound then
                                    monitor:TestReadySound()
                                end
                            end,
                        },
                        readyTextSize = {
                            type = "range",
                            order = 17,
                            width = 1.1,
                            name = "提示字号",
                            min = 10,
                            max = 72,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().readyTextSize
                            end,
                            set = function(_, value)
                                GetConfig().readyTextSize = value
                                RefreshMonitor(false)
                            end,
                        },
                        readyTextColor = {
                            type = "color",
                            order = 18,
                            width = 0.8,
                            name = "提示颜色",
                            hasAlpha = true,
                            disabled = IsDisabled,
                            get = function()
                                local color = GetConfig().readyTextColor
                                return color.r, color.g, color.b, color.a or 1
                            end,
                            set = function(_, r, g, b, a)
                                GetConfig().readyTextColor = { r = r, g = g, b = b, a = a }
                                RefreshMonitor(false)
                            end,
                        },
                        readyOffsetX = {
                            type = "range",
                            order = 19,
                            width = 1.1,
                            name = "提示 X 偏移",
                            min = -1200,
                            max = 1200,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().readyOffsetX
                            end,
                            set = function(_, value)
                                GetConfig().readyOffsetX = value
                                RefreshMonitor(false)
                            end,
                        },
                        readyOffsetY = {
                            type = "range",
                            order = 20,
                            width = 1.1,
                            name = "提示 Y 偏移",
                            min = -1200,
                            max = 1200,
                            step = 1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().readyOffsetY
                            end,
                            set = function(_, value)
                                GetConfig().readyOffsetY = value
                                RefreshMonitor(false)
                            end,
                        },
                        alertDuration = {
                            type = "range",
                            order = 21,
                            width = 1.1,
                            name = "提示时长",
                            min = 0.5,
                            max = 10,
                            step = 0.1,
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().alertDuration
                            end,
                            set = function(_, value)
                                GetConfig().alertDuration = value
                                RefreshMonitor(false)
                            end,
                        },
                    }),
                    filter = BuildTab("过滤", 50, {
                        blockedItemIDs = {
                            type = "input",
                            order = 10,
                            width = "full",
                            multiline = 6,
                            name = "屏蔽饰品 ID",
                            desc = "填入不想显示的饰品 ID，支持逗号、空格或换行分隔，例如：230027, 219308",
                            disabled = IsDisabled,
                            get = function()
                                return GetConfig().blockedItemIDs or ""
                            end,
                            set = function(_, value)
                                GetConfig().blockedItemIDs = value or ""
                                RefreshMonitor(false)
                            end,
                        },
                    }),
                },
            },
        },
    }
end
