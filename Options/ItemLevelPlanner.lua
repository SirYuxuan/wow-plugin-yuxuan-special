local _, NS = ...
local Core = NS.Core

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
                        name = "显示角色面板按钮",
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
                        name = "显示装备提示预估",
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
            styleRow = {
                type = "group",
                order = 20,
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
                        max = 18,
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
                        name = "结果小数位",
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
                order = 30,
                name = "",
                layout = "row",
                args = {
                    togglePanel = {
                        type = "execute",
                        order = 1,
                        width = 1.0,
                        name = "打开/关闭角色面板左侧预估区",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        func = function()
                            local module = GetModule()
                            if module and module.TogglePanel then
                                module:TogglePanel()
                            end
                        end,
                    },
                    clearAll = {
                        type = "execute",
                        order = 2,
                        width = 1.0,
                        name = "清空全部预估数值",
                        disabled = function()
                            return not GetConfig().enabled
                        end,
                        func = function()
                            local module = GetModule()
                            if module and module.ClearAllOverrides then
                                module:ClearAllOverrides()
                            end
                        end,
                    },
                    reset = {
                        type = "execute",
                        order = 3,
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
