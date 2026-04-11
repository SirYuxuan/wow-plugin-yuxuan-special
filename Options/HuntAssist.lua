local _, NS = ...
local Core = NS.Core

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "huntAssist")
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

function NS.BuildHuntAssistOptions()
    return {
        type = "group",
        name = "狩猎辅助",
        order = 17.1,
        args = {
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
                        name = "锁定监控位置",
                        disabled = function() return not GetConfig().enabled end,
                        get = function() return GetConfig().locked end,
                        set = function(_, value)
                            GetConfig().locked = value and true or false
                            Refresh(false)
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 3,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetHuntAssistConfig()
                            Refresh(true)
                        end,
                    },
                },
            },
            description = {
                type = "description",
                order = 15,
                fontSize = "medium",
                name = "用于狩猎玩法的两个增强：小地图附近的夹子/猎物监控，以及自动追踪并在聊天框提示。",
            },
            minimapGroup = {
                type = "group",
                order = 20,
                name = "小地图监控",
                inline = true,
                disabled = function() return not GetConfig().enabled end,
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
                    fontPreset = {
                        type = "select",
                        order = 3,
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
                        order = 4,
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
                    showBorder = {
                        type = "toggle",
                        order = 5,
                        width = 1.0,
                        name = "显示边框",
                        disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                        get = function() return GetConfig().showBorder ~= false end,
                        set = function(_, value)
                            GetConfig().showBorder = value and true or false
                            Refresh(false)
                        end,
                    },
                    monitorTrap = {
                        type = "toggle",
                        order = 6,
                        width = 1.0,
                        name = "显示夹子图标统计",
                        disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                        get = function() return GetConfig().minimap.monitorTrap end,
                        set = function(_, value)
                            GetConfig().minimap.monitorTrap = value and true or false
                            Refresh(false)
                        end,
                    },
                    monitorPrey = {
                        type = "toggle",
                        order = 7,
                        width = 1.0,
                        name = "显示猎物图标统计",
                        disabled = function() return not GetConfig().enabled or not GetConfig().minimap.enabled end,
                        get = function() return GetConfig().minimap.monitorPrey end,
                        set = function(_, value)
                            GetConfig().minimap.monitorPrey = value and true or false
                            Refresh(false)
                        end,
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
                    stageQuest = {
                        type = "toggle",
                        order = 3,
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
                        order = 4,
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
    }
end
