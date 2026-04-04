local _, NS = ...

local Options = NS.Options
local Private = Options.Private

--[[
这个文件只负责“设置数据总表”。

重点说明：
1. 这里不关心控件怎么画，只关心有哪些顶级页面。
2. 各模块自己的选项仍然由 CombatAssist / Mage / MapAssist 等文件负责。
3. 每次打开或刷新时都会重新构造一份 options table，确保动态 name/get/disabled 生效。
]]

local function BuildAboutOptions()
    return {
        type = "group",
        name = "关于",
        order = 999,
        args = {
            title = {
                type = "header",
                order = 1,
                name = NS.DISPLAY_NAME,
            },
            version = {
                type = "description",
                order = 2,
                fontSize = "medium",
                name = function()
                    return "|cFFFFCC00版本|r " .. NS.VERSION
                end,
            },
            spacer1 = {
                type = "description",
                order = 3,
                name = " ",
                width = "full",
            },
            desc = {
                type = "description",
                order = 4,
                fontSize = "medium",
                name = "当前提供地图辅助、界面增强、战斗辅助与法师冰霜相关功能。",
            },
            commandHeader = {
                type = "header",
                order = 10,
                name = "命令",
            },
            cmd1 = {
                type = "description",
                order = 11,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs|r - 打开或关闭设置窗口",
            },
            feedbackHeader = {
                type = "header",
                order = 20,
                name = "反馈",
            },
            feedback = {
                type = "description",
                order = 21,
                fontSize = "medium",
                name = "如果你需要插件里还没有实现的轻量单体功能，欢迎加群反馈，我会按实际需求继续补充。",
            },
        },
    }
end

local function BuildMapNavigationOptions()
    local group = NS.BuildMapAssistOptions()
    group.name = "地图导航"
    group.order = 10
    if group.args and group.args.mapIDDisplay then
        group.args.mapIDDisplay.name = "地图信息"
    end
    return group
end

local function BuildChatSocialOptions(interfaceEnhance)
    local quickChat = interfaceEnhance.args.quickChat
    quickChat.name = "快捷聊天"
    quickChat.order = 20

    return {
        type = "group",
        name = "聊天社交",
        order = 20,
        args = {
            chatWindow = {
                type = "group",
                name = "聊天窗口",
                order = 10,
                args = interfaceEnhance.args.interfaceBeautify.args,
            },
            quickChat = quickChat,
        },
    }
end

local function BuildCharacterInfoOptions(interfaceEnhance)
    return {
        type = "group",
        name = "角色信息",
        order = 30,
        args = {
            characterPanel = {
                type = "group",
                name = "角色面板",
                order = 10,
                childGroups = "tab",
                args = {
                    itemLevelPlanner = interfaceEnhance.args.itemLevelPlanner,
                    specTalentBar = interfaceEnhance.args.specTalentBar,
                    attributeDisplay = interfaceEnhance.args.attributeDisplay,
                },
            },
            resourceDisplay = {
                type = "group",
                name = "资源显示",
                order = 20,
                args = interfaceEnhance.args.currencyDisplay.args,
            },
        },
    }
end

local function BuildUtilityToolsOptions(interfaceEnhance)
    return {
        type = "group",
        name = "便捷工具",
        order = 40,
        args = {
            toolBar = {
                type = "group",
                name = "工具条",
                order = 10,
                args = interfaceEnhance.args.gameBar.args,
            },
            questAndExploration = {
                type = "group",
                name = "任务与探索",
                order = 20,
                childGroups = "tab",
                args = {
                    questTools = interfaceEnhance.args.questTools,
                    huntAssist = interfaceEnhance.args.huntAssist,
                },
            },
            teamTools = {
                type = "group",
                name = "团队工具",
                order = 30,
                args = interfaceEnhance.args.raidMarkers.args,
            },
        },
    }
end

local function BuildMonitorAndTipsOptions(interfaceEnhance)
    return {
        type = "group",
        name = "监控与提示",
        order = 50,
        args = {
            mouseTooltip = {
                type = "group",
                name = "鼠标提示",
                order = 10,
                args = interfaceEnhance.args.mouseCursor.args.mouseTooltip.args,
            },
            statusMonitor = {
                type = "group",
                name = "状态监控",
                order = 20,
                childGroups = "tab",
                args = {
                    distanceMonitor = interfaceEnhance.args.distanceMonitor,
                    performanceMonitor = interfaceEnhance.args.performanceMonitor,
                    eventTracker = interfaceEnhance.args.eventTracker,
                },
            },
            visualEffects = {
                type = "group",
                name = "视觉效果",
                order = 30,
                args = interfaceEnhance.args.mouseCursor.args.cursorTrail.args,
            },
        },
    }
end

local function BuildCombatToolsOptions()
    local group = NS.BuildCombatAssistOptions()
    group.name = "战斗辅助"
    group.order = 60
    return group
end

local function BuildClassToolsOptions()
    local group = NS.BuildClassAssistOptions()
    group.name = "职业辅助"
    group.order = 70
    return group
end

local function GetOptionsTable()
    local interfaceEnhance = NS.BuildInterfaceEnhanceOptions()
    local general = NS.BuildGeneralOptions()
    general.name = "通用"

    return {
        name = string.format("%s v%s", NS.DISPLAY_NAME, NS.VERSION),
        type = "group",
        childGroups = "tree",
        args = {
            general = general,
            mapNavigation = BuildMapNavigationOptions(),
            chatSocial = BuildChatSocialOptions(interfaceEnhance),
            characterInfo = BuildCharacterInfoOptions(interfaceEnhance),
            utilityTools = BuildUtilityToolsOptions(interfaceEnhance),
            monitorAndTips = BuildMonitorAndTipsOptions(interfaceEnhance),
            combatAssist = BuildCombatToolsOptions(),
            classAssist = BuildClassToolsOptions(),
            about = BuildAboutOptions(),
        },
    }
end

function Options:GetRootOptions()
    self.rootOptions = GetOptionsTable()
    return self.rootOptions
end

function Options:GetTopGroups()
    local root = self:GetRootOptions()
    return Private.SortArgs(root and root.args or {})
end
