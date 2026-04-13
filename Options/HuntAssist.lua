local _, NS = ...
local Core = NS.Core

local function GetConfig()
    local config = Core:GetConfig("interfaceEnhance", "huntAssist")
    config.minimap = config.minimap or {}
    config.autoTrack = config.autoTrack or {}
    config.bar = config.bar or {}
    config.point = config.point or {}
    config.bar.point = config.bar.point or {}

    if config.enabled == nil then
        config.enabled = false
    end
    if config.locked == nil then
        config.locked = true
    end
    if config.fontPreset == nil then
        config.fontPreset = "CHAT"
    end
    if config.fontSize == nil then
        config.fontSize = 12
    end

    if config.minimap.enabled == nil then
        config.minimap.enabled = true
    end
    if config.minimap.hideWhenEmpty == nil then
        config.minimap.hideWhenEmpty = true
    end
    if config.minimap.showBackground == nil then
        config.minimap.showBackground = true
    end
    if config.minimap.showBorder == nil then
        config.minimap.showBorder = true
    end
    if config.minimap.monitorTrap == nil then
        config.minimap.monitorTrap = true
    end
    if config.minimap.monitorPrey == nil then
        config.minimap.monitorPrey = true
    end

    if config.autoTrack.enabled == nil then
        config.autoTrack.enabled = true
    end
    if config.autoTrack.worldQuest == nil then
        config.autoTrack.worldQuest = true
    end
    if config.autoTrack.stageQuest == nil then
        config.autoTrack.stageQuest = true
    end
    if config.autoTrack.chatNotify == nil then
        config.autoTrack.chatNotify = true
    end

    if config.bar.enabled == nil then
        config.bar.enabled = false
    end
    if config.bar.locked == nil then
        config.bar.locked = true
    end
    if config.bar.onlyShowInPreyZone == nil then
        config.bar.onlyShowInPreyZone = false
    end
    if config.bar.hideDefaultPreyIcon == nil then
        config.bar.hideDefaultPreyIcon = false
    end
    if config.bar.width == nil then
        config.bar.width = 160
    end
    if config.bar.height == nil then
        config.bar.height = 29
    end
    if config.bar.fontSize == nil then
        config.bar.fontSize = 12
    end

    return config
end

local function Refresh(notifyOptions)
    local module = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.HuntAssist
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function BuildIconMonitorTab()
    return {
        type = "group",
        name = "图标监控",
        order = 10,
        args = {
            description = {
                type = "description",
                order = 5,
                fontSize = "medium",
                name = "当前模式会在小地图附近显示夹子/猎物统计，并保留自动追踪与聊天提示。",
            },
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
                        name = "启用狩猎辅助",
                        get = function() return GetConfig().enabled end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            Refresh(true)
                        end,
                    },
                    locked = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "锁定图标监控位置",
                        disabled = function() return not GetConfig().enabled end,
                        get = function() return GetConfig().locked end,
                        set = function(_, value)
                            GetConfig().locked = value and true or false
                            Refresh(false)
                        end,
                    },
                },
            },
            minimapGroup = {
                type = "group",
                order = 20,
                name = "小地图监控",
                inline = true,
                disabled = function() return not GetConfig().enabled end,
                args = {
                    basicRow = {
                        type = "group",
                        order = 1,
                        name = "",
                        layout = "row",
                        args = {
                            minimapEnabled = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "启用夹子监控",
                                get = function() return GetConfig().minimap.enabled end,
                                set = function(_, value)
                                    GetConfig().minimap.enabled = value and true or false
                                    Refresh(false)
                                end,
                            },
                            hideWhenEmpty = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "无目标时自动隐藏",
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                get = function() return GetConfig().minimap.hideWhenEmpty end,
                                set = function(_, value)
                                    GetConfig().minimap.hideWhenEmpty = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    fontRow = {
                        type = "group",
                        order = 2,
                        name = "",
                        layout = "row",
                        args = {
                            fontPreset = {
                                type = "select",
                                order = 1,
                                width = 1.0,
                                name = "字体预设",
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                values = function()
                                    return NS.Options.Private.GetFontOptions()
                                end,
                                get = function() return GetConfig().fontPreset end,
                                set = function(_, value)
                                    GetConfig().fontPreset = value
                                    Refresh(false)
                                end,
                            },
                            fontSize = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "字体大小",
                                min = 10,
                                max = 24,
                                step = 1,
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                get = function() return GetConfig().fontSize or 12 end,
                                set = function(_, value)
                                    GetConfig().fontSize = value
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    styleRow = {
                        type = "group",
                        order = 3,
                        name = "",
                        layout = "row",
                        args = {
                            showBackground = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "显示背景",
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                get = function() return GetConfig().minimap.showBackground ~= false end,
                                set = function(_, value)
                                    GetConfig().minimap.showBackground = value and true or false
                                    Refresh(false)
                                end,
                            },
                            showBorder = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "显示边框",
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                get = function() return GetConfig().minimap.showBorder ~= false end,
                                set = function(_, value)
                                    GetConfig().minimap.showBorder = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    iconRow = {
                        type = "group",
                        order = 4,
                        name = "",
                        layout = "row",
                        args = {
                            monitorTrap = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "显示夹子图标统计",
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                get = function() return GetConfig().minimap.monitorTrap ~= false end,
                                set = function(_, value)
                                    GetConfig().minimap.monitorTrap = value and true or false
                                    Refresh(false)
                                end,
                            },
                            monitorPrey = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "显示猎物图标统计",
                                disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                                get = function() return GetConfig().minimap.monitorPrey ~= false end,
                                set = function(_, value)
                                    GetConfig().minimap.monitorPrey = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                },
            },
            autoTrackGroup = {
                type = "group",
                order = 30,
                name = "自动追踪",
                inline = true,
                disabled = function() return not GetConfig().enabled end,
                args = {
                    firstRow = {
                        type = "group",
                        order = 1,
                        name = "",
                        layout = "row",
                        args = {
                            autoTrackEnabled = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "启用自动追踪",
                                get = function() return GetConfig().autoTrack.enabled end,
                                set = function(_, value)
                                    GetConfig().autoTrack.enabled = value and true or false
                                    Refresh(false)
                                end,
                            },
                            worldQuest = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "自动追踪最近世界任务",
                                disabled = function() return not GetConfig().enabled or not GetConfig().autoTrack.enabled end,
                                get = function() return GetConfig().autoTrack.worldQuest end,
                                set = function(_, value)
                                    GetConfig().autoTrack.worldQuest = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    secondRow = {
                        type = "group",
                        order = 2,
                        name = "",
                        layout = "row",
                        args = {
                            stageQuest = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "自动追踪阶段任务",
                                disabled = function() return not GetConfig().enabled or not GetConfig().autoTrack.enabled end,
                                get = function() return GetConfig().autoTrack.stageQuest end,
                                set = function(_, value)
                                    GetConfig().autoTrack.stageQuest = value and true or false
                                    Refresh(false)
                                end,
                            },
                            chatNotify = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "聊天框输出提示",
                                disabled = function() return not GetConfig().enabled or not GetConfig().autoTrack.enabled end,
                                get = function() return GetConfig().autoTrack.chatNotify end,
                                set = function(_, value)
                                    GetConfig().autoTrack.chatNotify = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                },
            },
            reset = {
                type = "execute",
                order = 100,
                width = 1.0,
                name = "恢复默认设置",
                func = function()
                    Core:ResetHuntAssistConfig()
                    Refresh(true)
                end,
            },
        },
    }
end

local function BuildProgressBarTab()
    return {
        type = "group",
        name = "进度条",
        order = 20,
        args = {
            description = {
                type = "description",
                order = 5,
                fontSize = "medium",
                name = "显示狩猎进度条，并提供隐藏默认狩猎图标的控制。",
            },
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
                        name = "启用狩猎辅助",
                        get = function() return GetConfig().enabled end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            Refresh(true)
                        end,
                    },
                    barEnabled = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "启用进度条模块",
                        disabled = function() return not GetConfig().enabled end,
                        get = function() return GetConfig().bar.enabled end,
                        set = function(_, value)
                            GetConfig().bar.enabled = value and true or false
                            Refresh(false)
                        end,
                    },
                },
            },
            behaviorGroup = {
                type = "group",
                order = 20,
                name = "显示与行为",
                inline = true,
                disabled = function() return not GetConfig().enabled or not GetConfig().bar.enabled end,
                args = {
                    firstRow = {
                        type = "group",
                        order = 1,
                        name = "",
                        layout = "row",
                        args = {
                            barLocked = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "锁定进度条位置",
                                get = function() return GetConfig().bar.locked end,
                                set = function(_, value)
                                    GetConfig().bar.locked = value and true or false
                                    Refresh(false)
                                end,
                            },
                            onlyShowInPreyZone = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "仅在狩猎区域显示",
                                get = function() return GetConfig().bar.onlyShowInPreyZone end,
                                set = function(_, value)
                                    GetConfig().bar.onlyShowInPreyZone = value and true or false
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    secondRow = {
                        type = "group",
                        order = 2,
                        name = "",
                        layout = "row",
                        args = {
                            hideDefaultPreyIcon = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "隐藏默认狩猎图标",
                                get = function() return GetConfig().bar.hideDefaultPreyIcon end,
                                set = function(_, value)
                                    GetConfig().bar.hideDefaultPreyIcon = value and true or false
                                    Refresh(false)
                                end,
                            },
                            barFontSize = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "进度条字体大小",
                                min = 10,
                                max = 22,
                                step = 1,
                                get = function() return GetConfig().bar.fontSize or 12 end,
                                set = function(_, value)
                                    GetConfig().bar.fontSize = value
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                    thirdRow = {
                        type = "group",
                        order = 3,
                        name = "",
                        layout = "row",
                        args = {
                            barWidth = {
                                type = "range",
                                order = 1,
                                width = 1.0,
                                name = "进度条宽度",
                                min = 120,
                                max = 320,
                                step = 2,
                                get = function() return GetConfig().bar.width or 160 end,
                                set = function(_, value)
                                    GetConfig().bar.width = value
                                    Refresh(false)
                                end,
                            },
                            barHeight = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "进度条高度",
                                min = 16,
                                max = 48,
                                step = 1,
                                get = function() return GetConfig().bar.height or 29 end,
                                set = function(_, value)
                                    GetConfig().bar.height = value
                                    Refresh(false)
                                end,
                            },
                        },
                    },
                },
            },
            tips = {
                type = "description",
                order = 30,
                fontSize = "medium",
                name = "说明：开启“隐藏默认狩猎图标”后，阶段 4 可以直接点击进度条打开地图并追踪当前猎物。",
            },
            reset = {
                type = "execute",
                order = 100,
                width = 1.0,
                name = "恢复默认设置",
                func = function()
                    Core:ResetHuntAssistConfig()
                    Refresh(true)
                end,
            },
        },
    }
end

function NS.BuildHuntAssistOptions()
    return {
        type = "group",
        name = "狩猎辅助",
        order = 17.1,
        childGroups = "tab",
        args = {
            monitor = BuildIconMonitorTab(),
            preyBar = BuildProgressBarTab(),
        },
    }
end
