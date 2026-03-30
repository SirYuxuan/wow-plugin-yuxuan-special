local _, NS = ...
local Core = NS.Core

--[[
通用设置负责两类全局能力：
1. 外观设置：字体、主题色等会影响整个插件的展示层。
2. 配置管理：共享全局配置、当前角色独立配置，以及全局配置的导入导出。

这里不直接操作控件，只负责提供 options 定义和刷新逻辑。
]]

local profileTransferText = ""

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetAppearanceConfig()
    return Core:GetConfig("general", "appearance")
end

local function RefreshAllSettings(notifyOptions)
    -- 设置界面的字体、主题色属于外观层，优先刷新设置窗口本身。
    if NS.Options and NS.Options.RefreshAppearance then
        NS.Options:RefreshAppearance()
    end

    -- 下面这些模块都有独立的 RefreshFromSettings，用来同步运行中框体。
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.RefreshFromSettings then
        quickWaypoint:RefreshFromSettings()
    end

    local quickChat = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.QuickChat
    if quickChat and quickChat.RefreshFromSettings then
        quickChat:RefreshFromSettings()
    end

    local quickFocus = NS.Modules.CombatAssist and NS.Modules.CombatAssist.QuickFocus
    if quickFocus and quickFocus.RefreshFromSettings then
        quickFocus:RefreshFromSettings()
    end

    local trinketMonitor = NS.Modules.CombatAssist and NS.Modules.CombatAssist.TrinketMonitor
    if trinketMonitor and trinketMonitor.RefreshFromSettings then
        trinketMonitor:RefreshFromSettings()
    end

    local shatterIndicator = NS.Modules.ClassAssist
        and NS.Modules.ClassAssist.Mage
        and NS.Modules.ClassAssist.Mage.ShatterIndicator
    if shatterIndicator and shatterIndicator.RefreshFromSettings then
        shatterIndicator:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function GetProfileStatusText()
    local characterKey = Core:GetCurrentCharacterKey() or "当前角色"
    if Core:DoesCurrentCharacterUseOwnProfile() then
        return string.format("当前角色 %s 正在使用独立配置。", characterKey)
    end

    return string.format("当前角色 %s 正在使用全局共享配置。", characterKey)
end

function NS.BuildGeneralOptions()
    return {
        type = "group",
        name = "通用设置",
        order = 1,
        args = {
            appearance = {
                type = "group",
                name = "外观设置",
                order = 1,
                args = {
                    intro = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = "这里可以统一调整插件设置界面的字体和主题色。",
                    },
                    fontPreset = {
                        type = "select",
                        name = "插件字体",
                        order = 10,
                        values = function()
                            return NS.Options.Private.GetFontOptions()
                        end,
                        get = function()
                            return GetAppearanceConfig().fontPreset
                        end,
                        set = function(_, value)
                            GetAppearanceConfig().fontPreset = value
                            RefreshAllSettings(true)
                        end,
                    },
                    colorMode = {
                        type = "select",
                        name = "主题颜色",
                        order = 11,
                        values = function()
                            return {
                                CLASS = "跟随职业",
                                CUSTOM = "自定义颜色",
                            }
                        end,
                        get = function()
                            return GetAppearanceConfig().colorMode
                        end,
                        set = function(_, value)
                            GetAppearanceConfig().colorMode = value
                            RefreshAllSettings(true)
                        end,
                    },
                    customColor = {
                        type = "color",
                        name = "自定义主题色",
                        order = 12,
                        hasAlpha = false,
                        disabled = function()
                            return GetAppearanceConfig().colorMode ~= "CUSTOM"
                        end,
                        get = function()
                            local color = GetAppearanceConfig().customColor or {}
                            return color.r or 1, color.g or 1, color.b or 1, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            local color = GetAppearanceConfig().customColor
                            color.r = r
                            color.g = g
                            color.b = b
                            color.a = a or 1
                            RefreshAllSettings(true)
                        end,
                    },
                    reset = {
                        type = "execute",
                        name = "恢复外观默认设置",
                        order = 20,
                        confirm = true,
                        confirmText = "确认恢复通用外观设置吗？",
                        func = function()
                            Core:ResetAppearanceConfig()
                            RefreshAllSettings(true)
                        end,
                    },
                },
            },
            profileManager = {
                type = "group",
                name = "配置管理",
                order = 2,
                args = {
                    status = {
                        type = "description",
                        order = 1,
                        fontSize = "medium",
                        name = function()
                            return GetProfileStatusText()
                        end,
                    },
                    useCharacterProfile = {
                        type = "toggle",
                        order = 10,
                        width = 1.4,
                        name = "当前角色使用独立配置",
                        desc = "开启时会复制当前配置给本角色单独使用；关闭后切回全局共享配置。",
                        get = function()
                            return Core:DoesCurrentCharacterUseOwnProfile()
                        end,
                        set = function(_, value)
                            Core:SetCurrentCharacterUseOwnProfile(value and true or false)
                            RefreshAllSettings(true)
                        end,
                    },
                    copyGlobalToCharacter = {
                        type = "execute",
                        order = 11,
                        width = 1.0,
                        name = "全局覆盖当前角色",
                        disabled = function()
                            return not Core:DoesCurrentCharacterUseOwnProfile()
                        end,
                        confirm = true,
                        confirmText = "确认用全局配置覆盖当前角色的独立配置吗？",
                        func = function()
                            Core:CopyGlobalToCurrentCharacter()
                            Core:Print("已用全局配置覆盖当前角色。")
                            RefreshAllSettings(true)
                        end,
                    },
                    copyCurrentToGlobal = {
                        type = "execute",
                        order = 12,
                        width = 1.0,
                        name = "当前配置写入全局",
                        confirm = true,
                        confirmText = "确认用当前配置覆盖全局配置吗？",
                        func = function()
                            Core:CopyCurrentProfileToGlobal()
                            Core:Print("已将当前配置写入全局配置。")
                            RefreshAllSettings(true)
                        end,
                    },
                    exportGlobal = {
                        type = "execute",
                        order = 20,
                        width = 1.0,
                        name = "导出全局配置",
                        func = function()
                            profileTransferText = Core:ExportGlobalProfile()
                            Core:Print("已生成全局配置导出文本。")
                            if NS.Options and NS.Options.NotifyChanged then
                                NS.Options:NotifyChanged()
                            end
                        end,
                    },
                    importGlobal = {
                        type = "execute",
                        order = 21,
                        width = 1.0,
                        name = "导入到全局配置",
                        disabled = function()
                            return TrimText(profileTransferText) == ""
                        end,
                        confirm = true,
                        confirmText = "确认把文本内容导入到全局配置吗？这会覆盖现有全局配置。",
                        func = function()
                            local ok, errorMessage = Core:ImportGlobalProfile(profileTransferText)
                            if not ok then
                                Core:Print(errorMessage or "全局配置导入失败。")
                                return
                            end

                            Core:Print("已导入全局配置。")
                            RefreshAllSettings(true)
                        end,
                    },
                    transferBox = {
                        type = "input",
                        order = 30,
                        width = "full",
                        multiline = 10,
                        name = "全局配置文本",
                        desc = "可以导出全局配置到这里，也可以把别处的全局配置文本粘贴回来导入。",
                        get = function()
                            return profileTransferText
                        end,
                        set = function(_, value)
                            profileTransferText = value or ""
                        end,
                    },
                },
            },
        },
    }
end
