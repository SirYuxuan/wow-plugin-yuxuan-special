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

local function GetOptionsTable()
    return {
        name = string.format("%s v%s", NS.DISPLAY_NAME, NS.VERSION),
        type = "group",
        childGroups = "tree",
        args = {
            general = NS.BuildGeneralOptions(),
            mapAssist = NS.BuildMapAssistOptions(),
            interfaceEnhance = NS.BuildInterfaceEnhanceOptions(),
            combatAssist = NS.BuildCombatAssistOptions(),
            classAssist = NS.BuildClassAssistOptions(),
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
