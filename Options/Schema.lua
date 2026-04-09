local _, NS = ...

local Options = NS.Options
local Private = Options.Private

local function BuildHomeOptions()
    return {
        type = "group",
        name = "首页",
        order = 1,
        args = {
            landing = {
                type = "landing",
                order = 1,
                title = "欢迎来到雨轩工具箱",
                badge = function()
                    return "v" .. tostring(NS.VERSION or "")
                end,
                summary = "把常用入口、界面美化、配置管理和更新记录集中在一个首页里，登录后先从这里开始会更顺手。",
                highlights = {
                    "首页直接放常用跳转，不用来回找目录。",
                    "角色信息相关功能已经合并到“界面美化”。",
                    "更新记录、配置管理和常用模块都能一屏看到。",
                    "这次顺手补了背包文字颜色设置的回写保护。",
                },
                shortcutsTitle = "快速开始",
                shortcuts = {
                    {
                        title = "常用功能",
                        desc = "快捷导航、快捷频道、游戏条和任务工具都放在这里。",
                        buttonText = "进入常用功能",
                        meta = "高频入口",
                        path = { "commonFeatures" },
                    },
                    {
                        title = "界面美化",
                        desc = "界面整理、鼠标提示、背包文字、属性与货币显示统一集中。",
                        buttonText = "进入界面美化",
                        meta = "布局最常调",
                        path = { "beautifyCenter" },
                    },
                    {
                        title = "探索与团队",
                        desc = "地图信息、狩猎助手、事件追踪和团队标记放在同一组。",
                        buttonText = "进入探索与团队",
                        meta = "野外 / 小队",
                        path = { "explorationTeam" },
                    },
                    {
                        title = "战斗与职业",
                        desc = "快速焦点、饰品监控和法师模块入口现在更容易找到。",
                        buttonText = "进入战斗与职业",
                        meta = "战斗期常用",
                        path = { "combatAndClass" },
                    },
                    {
                        title = "配置管理",
                        desc = "角色绑定、配置新建、编辑、导入导出都在通用页里。",
                        buttonText = "打开配置管理",
                        meta = "存档管理",
                        path = { "general", "profileManager" },
                    },
                    {
                        title = "更新记录",
                        desc = "查看 1.1.6 的变更说明，也可以随时回顾最近版本更新。",
                        buttonText = "打开更新记录",
                        meta = "本次更新",
                        action = function()
                            local updateLog = NS.Modules
                                and NS.Modules.InterfaceEnhance
                                and NS.Modules.InterfaceEnhance.UpdateLog
                            if updateLog and updateLog.Open then
                                updateLog:Open(false)
                            end
                        end,
                    },
                },
                newsTitle = "1.1.6 更新摘要",
                newsItems = {
                    "新增首页，把高频入口、配置管理和更新记录集中展示。",
                    "设置窗口重新按用户视角分组，角色信息整体并入“界面美化”。",
                    "修正背包文字颜色选择的设置回写链路，并优化配置编辑区布局。",
                },
            },
        },
    }
end

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
            cmd2 = {
                type = "description",
                order = 12,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs log|r - 打开更新记录",
            },
            changelogHeader = {
                type = "header",
                order = 15,
                name = "更新记录",
            },
            changelogButton = {
                type = "execute",
                order = 16,
                name = "打开更新记录",
                func = function()
                    local updateLog = NS.Modules
                        and NS.Modules.InterfaceEnhance
                        and NS.Modules.InterfaceEnhance.UpdateLog
                    if updateLog and updateLog.Open then
                        updateLog:Open(false)
                    end
                end,
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

local function BuildCommonFeaturesOptions(interfaceEnhance)
    local mapAssist = NS.BuildMapAssistOptions()
    local quickWaypoint = mapAssist.args.quickWaypoint
    local quickChat = interfaceEnhance.args.quickChat
    local gameBar = interfaceEnhance.args.gameBar
    local questTools = interfaceEnhance.args.questTools

    quickWaypoint.order = 10
    quickChat.name = "快捷频道"
    quickChat.order = 20
    gameBar.order = 30
    questTools.order = 40

    return {
        type = "group",
        name = "常用功能",
        order = 10,
        args = {
            quickWaypoint = quickWaypoint,
            quickChat = quickChat,
            gameBar = gameBar,
            questTools = questTools,
        },
    }
end

local function BuildBeautifyOptions(interfaceEnhance)
    local interfaceBeautify = interfaceEnhance.args.interfaceBeautify
    local mouseTooltip = interfaceEnhance.args.mouseCursor.args.mouseTooltip
    local cursorTrail = interfaceEnhance.args.mouseCursor.args.cursorTrail
    local itemLevelPlanner = interfaceEnhance.args.itemLevelPlanner
    local bagItemOverlay = interfaceEnhance.args.bagItemOverlay
    local specTalentBar = interfaceEnhance.args.specTalentBar
    local attributeDisplay = interfaceEnhance.args.attributeDisplay
    local currencyDisplay = interfaceEnhance.args.currencyDisplay
    local distanceMonitor = interfaceEnhance.args.distanceMonitor
    local performanceMonitor = interfaceEnhance.args.performanceMonitor

    interfaceBeautify.order = 10
    mouseTooltip.order = 20
    cursorTrail.order = 30
    itemLevelPlanner.order = 40
    bagItemOverlay.order = 50
    specTalentBar.order = 60
    attributeDisplay.order = 70
    currencyDisplay.order = 80
    distanceMonitor.order = 90
    performanceMonitor.order = 100

    return {
        type = "group",
        name = "界面美化",
        order = 20,
        args = {
            interfaceBeautify = interfaceBeautify,
            mouseTooltip = mouseTooltip,
            cursorTrail = cursorTrail,
            itemLevelPlanner = itemLevelPlanner,
            bagItemOverlay = bagItemOverlay,
            specTalentBar = specTalentBar,
            attributeDisplay = attributeDisplay,
            currencyDisplay = currencyDisplay,
            distanceMonitor = distanceMonitor,
            performanceMonitor = performanceMonitor,
        },
    }
end

local function BuildExplorationTeamOptions(interfaceEnhance)
    local mapAssist = NS.BuildMapAssistOptions()
    local mapIDDisplay = mapAssist.args.mapIDDisplay
    local huntAssist = interfaceEnhance.args.huntAssist
    local eventTracker = interfaceEnhance.args.eventTracker
    local raidMarkers = interfaceEnhance.args.raidMarkers

    mapIDDisplay.name = "地图信息"
    mapIDDisplay.order = 10
    huntAssist.order = 20
    eventTracker.order = 30
    raidMarkers.order = 40

    return {
        type = "group",
        name = "探索与团队",
        order = 30,
        args = {
            mapIDDisplay = mapIDDisplay,
            huntAssist = huntAssist,
            eventTracker = eventTracker,
            raidMarkers = raidMarkers,
        },
    }
end

local function BuildCombatAndClassOptions()
    local combatAssist = NS.BuildCombatAssistOptions()
    local classAssist = NS.BuildClassAssistOptions()
    local quickFocus = combatAssist.args.quickFocus
    local trinketMonitor = combatAssist.args.trinketMonitor
    local mage = classAssist.args.mage

    quickFocus.order = 10
    trinketMonitor.order = 20
    mage.order = 30

    return {
        type = "group",
        name = "战斗与职业",
        order = 40,
        args = {
            quickFocus = quickFocus,
            trinketMonitor = trinketMonitor,
            mage = mage,
        },
    }
end

local function GetOptionsTable()
    local interfaceEnhance = NS.BuildInterfaceEnhanceOptions()
    local general = NS.BuildGeneralOptions()
    general.name = "通用"
    general.order = 90

    return {
        name = string.format("%s v%s", NS.DISPLAY_NAME, NS.VERSION),
        type = "group",
        childGroups = "tree",
        args = {
            home = BuildHomeOptions(),
            commonFeatures = BuildCommonFeaturesOptions(interfaceEnhance),
            beautifyCenter = BuildBeautifyOptions(interfaceEnhance),
            explorationTeam = BuildExplorationTeamOptions(interfaceEnhance),
            combatAndClass = BuildCombatAndClassOptions(),
            general = general,
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
