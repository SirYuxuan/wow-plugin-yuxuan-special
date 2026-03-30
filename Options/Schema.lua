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
                name = "当前版本包含地图辅助、战斗辅助与职业辅助，并使用独立自定义窗口进行配置。",
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
                name = "|cFFFFFF00/yxs|r - 打开或关闭配置窗口",
            },
            cmd2 = {
                type = "description",
                order = 12,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs map|r - 打开地图辅助",
            },
            cmd3 = {
                type = "description",
                order = 13,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs nav|r - 打开快捷导航",
            },
            cmd4 = {
                type = "description",
                order = 14,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs combat|r - 打开战斗辅助",
            },
            cmd5 = {
                type = "description",
                order = 15,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs trinket|r - 打开饰品监控",
            },
            cmd6 = {
                type = "description",
                order = 16,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs mage|r - 打开法师辅助",
            },
            cmd7 = {
                type = "description",
                order = 17,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs frost|r - 打开冰霜专精页",
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
            mapAssist = NS.BuildMapAssistOptions(),
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
