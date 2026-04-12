local _, NS = ...
local Core = NS.Core

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.EnhanceQoLIntegration
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "enhanceQoLIntegration")
end

local function IsTargetLoaded()
    local module = GetModule()
    return module and module.IsTargetLoaded and module:IsTargetLoaded()
end

local function Refresh(notifyOptions)
    local module = GetModule()
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function NS.BuildEnhanceQoLIntegrationOptions()
    return {
        type = "group",
        name = "EnhanceQoL",
        order = 4.5,
        disabled = function()
            return not IsTargetLoaded()
        end,
        disabledTip = "未检测到已加载的 EnhanceQoL",
        args = {
            status = {
                type = "description",
                order = 5,
                fontSize = "medium",
                name = function()
                    if IsTargetLoaded() then
                        return "|cFF33FF99已检测到 EnhanceQoL|r，可以在这里增强它的战斗文字显示。"
                    end
                    return "|cFFFF5555未检测到 EnhanceQoL|r。只有目标插件已加载时，这里的设置才会生效。"
                end,
            },
            enabled = {
                type = "toggle",
                order = 10,
                width = 1.2,
                name = "启用增强",
                get = function()
                    return GetConfig().enabled
                end,
                set = function(_, value)
                    GetConfig().enabled = value and true or false
                    Refresh(true)
                end,
            },
            combatTextGroup = {
                type = "group",
                order = 20,
                name = "战斗文字",
                inline = true,
                disabled = function()
                    return not IsTargetLoaded() or not GetConfig().enabled
                end,
                args = {
                    combatTextEnabled = {
                        type = "toggle",
                        order = 1,
                        width = 1.2,
                        name = "接管进入/离开战斗文字",
                        get = function()
                            return GetConfig().combatTextEnabled
                        end,
                        set = function(_, value)
                            GetConfig().combatTextEnabled = value and true or false
                            Refresh(false)
                        end,
                    },
                    note = {
                        type = "description",
                        order = 2,
                        fontSize = "medium",
                        name = "这里只改 EnhanceQoL 显示出来的文字内容，不会修改它的插件文件。前提是 EnhanceQoL 自己的 CombatText 功能本身已启用。",
                    },
                    enterText = {
                        type = "input",
                        order = 10,
                        width = 1.4,
                        name = "进入战斗文字",
                        disabled = function()
                            return not IsTargetLoaded() or not GetConfig().enabled or not GetConfig().combatTextEnabled
                        end,
                        get = function()
                            return GetConfig().enterText or ""
                        end,
                        set = function(_, value)
                            GetConfig().enterText = value or ""
                            Refresh(false)
                        end,
                    },
                    leaveText = {
                        type = "input",
                        order = 20,
                        width = 1.4,
                        name = "离开战斗文字",
                        disabled = function()
                            return not IsTargetLoaded() or not GetConfig().enabled or not GetConfig().combatTextEnabled
                        end,
                        get = function()
                            return GetConfig().leaveText or ""
                        end,
                        set = function(_, value)
                            GetConfig().leaveText = value or ""
                            Refresh(false)
                        end,
                    },
                    hint = {
                        type = "description",
                        order = 30,
                        fontSize = "medium",
                        name = "留空时会回退到 EnhanceQoL 当前默认文案，例如 +战斗 / -战斗。",
                    },
                },
            },
            reset = {
                type = "execute",
                order = 90,
                width = 1.0,
                name = "恢复默认设置",
                func = function()
                    Core:ResetEnhanceQoLIntegrationConfig()
                    Refresh(true)
                end,
            },
        },
    }
end
