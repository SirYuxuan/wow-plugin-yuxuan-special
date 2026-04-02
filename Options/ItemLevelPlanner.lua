local _, NS = ...
local Core = NS.Core

local SLOT_VALUES = {
    HEAD = "头部",
    NECK = "项链",
    SHOULDER = "肩部",
    CHEST = "胸部",
    WAIST = "腰部",
    LEGS = "腿部",
    FEET = "脚部",
    WRIST = "手腕",
    HANDS = "手部",
    FINGER1 = "戒指 1",
    FINGER2 = "戒指 2",
    TRINKET1 = "饰品 1",
    TRINKET2 = "饰品 2",
    BACK = "披风",
    MAINHAND = "主手",
    OFFHAND = "副手",
}

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "itemLevelPlanner")
end

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.ItemLevelPlanner
end

local function RefreshModule(notifyOptions)
    local module = GetModule()
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function NS.BuildItemLevelPlannerOptions()
    return {
        type = "group",
        name = "装等预估",
        order = 6,
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
                        name = "启用装等预估",
                        get = function()
                            return GetConfig().enabled
                        end,
                        set = function(_, value)
                            GetConfig().enabled = value and true or false
                            RefreshModule(true)
                        end,
                    },
                    showCharacterButton = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "角色面板按钮",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showCharacterButton
                        end,
                        set = function(_, value)
                            GetConfig().showCharacterButton = value and true or false
                            RefreshModule(false)
                        end,
                    },
                    showTooltipPreview = {
                        type = "toggle",
                        order = 3,
                        width = 1.0,
                        name = "装备提示预估",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().showTooltipPreview
                        end,
                        set = function(_, value)
                            GetConfig().showTooltipPreview = value and true or false
                            RefreshModule(false)
                        end,
                    },
                },
            },
            controlRow = {
                type = "group",
                order = 20,
                name = "",
                layout = "row",
                args = {
                    locked = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "锁定窗口",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().locked
                        end,
                        set = function(_, value)
                            GetConfig().locked = value and true or false
                            RefreshModule(false)
                        end,
                    },
                    selectedSlot = {
                        type = "select",
                        order = 2,
                        width = 1.0,
                        name = "默认槽位",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        values = SLOT_VALUES,
                        get = function()
                            return GetConfig().selectedSlot or "HEAD"
                        end,
                        set = function(_, value)
                            GetConfig().selectedSlot = value
                            RefreshModule(false)
                        end,
                    },
                    targetItemLevel = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "默认目标装等",
                        min = 1,
                        max = 999,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().targetItemLevel or 665
                        end,
                        set = function(_, value)
                            GetConfig().targetItemLevel = value
                            RefreshModule(false)
                        end,
                    },
                },
            },
            styleRow = {
                type = "group",
                order = 30,
                name = "",
                layout = "row",
                args = {
                    fontPreset = {
                        type = "select",
                        order = 1,
                        width = 1.0,
                        name = "字体",
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
                            RefreshModule(false)
                        end,
                    },
                    fontSize = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "字体大小",
                        min = 10,
                        max = 22,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().fontSize or 13
                        end,
                        set = function(_, value)
                            GetConfig().fontSize = value
                            RefreshModule(false)
                        end,
                    },
                    decimalPlaces = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "小数位数",
                        min = 0,
                        max = 2,
                        step = 1,
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        get = function()
                            return GetConfig().decimalPlaces or 1
                        end,
                        set = function(_, value)
                            GetConfig().decimalPlaces = value
                            RefreshModule(false)
                        end,
                    },
                },
            },
            actionRow = {
                type = "group",
                order = 40,
                name = "",
                layout = "row",
                args = {
                    toggleWindow = {
                        type = "execute",
                        order = 1,
                        width = 1.0,
                        name = "打开/关闭窗口",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        func = function()
                            local module = GetModule()
                            if module and module.ToggleFrame then
                                module:ToggleFrame()
                            end
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 2,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetItemLevelPlannerConfig()
                            RefreshModule(true)
                        end,
                    },
                },
            },
        },
    }
end
