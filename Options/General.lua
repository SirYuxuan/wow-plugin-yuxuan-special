local _, NS = ...
local Core = NS.Core

--[[
通用设置负责两类全局能力：
1. 外观设置：字体、主题色等会影响整个插件的展示层。
2. 配置管理：当前角色绑定哪一份配置，以及配置的导入导出和命名管理。
]]

local PROFILE_KEY_GLOBAL = "GLOBAL"

local managedProfileKey = PROFILE_KEY_GLOBAL
local profileDraftName = ""
local profileTransferText = ""

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetAppearanceConfig()
    return Core:GetConfig("general", "appearance")
end

local function RefreshAllSettings(notifyOptions)
    if NS.Options and NS.Options.RefreshAppearance then
        NS.Options:RefreshAppearance()
    end

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

local function GetCurrentProfileKey()
    return Core:GetCurrentCharacterProfileKey() or PROFILE_KEY_GLOBAL
end

local function GetProfileChoices()
    return Core:GetProfileChoices()
end

local function GetProfileLabel(profileKey)
    if not profileKey or profileKey == PROFILE_KEY_GLOBAL then
        return "全局配置"
    end

    return tostring(profileKey)
end

local function EnsureManagedProfileKey()
    local currentKey = managedProfileKey
    if currentKey == PROFILE_KEY_GLOBAL then
        return currentKey
    end

    if Core:GetNamedProfile(currentKey, false) then
        return currentKey
    end

    managedProfileKey = GetCurrentProfileKey()
    if managedProfileKey ~= PROFILE_KEY_GLOBAL and not Core:GetNamedProfile(managedProfileKey, false) then
        managedProfileKey = PROFILE_KEY_GLOBAL
    end

    return managedProfileKey
end

local function SetManagedProfileKey(profileKey)
    managedProfileKey = profileKey or PROFILE_KEY_GLOBAL
    EnsureManagedProfileKey()
end

local function GetProfileStatusText()
    local characterKey = Core:GetCurrentCharacterKey() or "当前角色"
    local activeProfileKey = GetCurrentProfileKey()

    return string.format(
        "当前角色 %s 正在使用 %s。",
        characterKey,
        GetProfileLabel(activeProfileKey)
    )
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
                    currentProfile = {
                        type = "select",
                        order = 10,
                        name = "当前角色使用配置",
                        values = function()
                            return GetProfileChoices()
                        end,
                        get = function()
                            return GetCurrentProfileKey()
                        end,
                        set = function(_, value)
                            Core:SetCurrentCharacterProfileKey(value)
                            SetManagedProfileKey(value)
                            if value and value ~= PROFILE_KEY_GLOBAL then
                                profileDraftName = tostring(value)
                            end
                            RefreshAllSettings(true)
                        end,
                    },
                    manageTarget = {
                        type = "select",
                        order = 11,
                        name = "管理目标配置",
                        values = function()
                            return GetProfileChoices()
                        end,
                        get = function()
                            return EnsureManagedProfileKey()
                        end,
                        set = function(_, value)
                            SetManagedProfileKey(value)
                            if value and value ~= PROFILE_KEY_GLOBAL then
                                profileDraftName = tostring(value)
                            end
                            if NS.Options and NS.Options.NotifyChanged then
                                NS.Options:NotifyChanged()
                            end
                        end,
                    },
                    profileName = {
                        type = "input",
                        order = 12,
                        width = "full",
                        name = "配置名称",
                        desc = "用于复制新配置或重命名当前管理目标配置。",
                        get = function()
                            return profileDraftName
                        end,
                        set = function(_, value)
                            profileDraftName = value or ""
                        end,
                    },
                    createProfile = {
                        type = "execute",
                        order = 13,
                        width = 1.0,
                        name = "复制目标为新配置",
                        disabled = function()
                            return TrimText(profileDraftName) == ""
                        end,
                        func = function()
                            local created, errorMessage = Core:CreateNamedProfile(
                                profileDraftName,
                                EnsureManagedProfileKey()
                            )
                            if not created then
                                Core:Print(errorMessage or "新配置创建失败。")
                                return
                            end

                            SetManagedProfileKey(created)
                            profileDraftName = created
                            Core:Print("已创建配置：" .. created)
                            RefreshAllSettings(true)
                        end,
                    },
                    renameProfile = {
                        type = "execute",
                        order = 14,
                        width = 1.0,
                        name = "重命名目标配置",
                        disabled = function()
                            return EnsureManagedProfileKey() == PROFILE_KEY_GLOBAL or TrimText(profileDraftName) == ""
                        end,
                        func = function()
                            local renamed, errorMessage = Core:RenameNamedProfile(
                                EnsureManagedProfileKey(),
                                profileDraftName
                            )
                            if not renamed then
                                Core:Print(errorMessage or "配置重命名失败。")
                                return
                            end

                            SetManagedProfileKey(renamed)
                            profileDraftName = renamed
                            Core:Print("已重命名配置：" .. renamed)
                            RefreshAllSettings(true)
                        end,
                    },
                    deleteProfile = {
                        type = "execute",
                        order = 15,
                        width = 1.0,
                        name = "删除目标配置",
                        disabled = function()
                            return EnsureManagedProfileKey() == PROFILE_KEY_GLOBAL
                        end,
                        confirm = true,
                        confirmText = "确认删除当前管理目标配置吗？所有使用这份配置的角色会自动切回全局配置。",
                        func = function()
                            local deleted, errorMessage = Core:DeleteNamedProfile(EnsureManagedProfileKey())
                            if not deleted then
                                Core:Print(errorMessage or "配置删除失败。")
                                return
                            end

                            SetManagedProfileKey(PROFILE_KEY_GLOBAL)
                            Core:Print("已删除目标配置。")
                            RefreshAllSettings(true)
                        end,
                    },
                    exportProfile = {
                        type = "execute",
                        order = 20,
                        width = 1.0,
                        name = "导出目标配置",
                        func = function()
                            profileTransferText = Core:ExportProfile(EnsureManagedProfileKey())
                            Core:Print("已生成编码后的配置文本。")
                            if NS.Options and NS.Options.NotifyChanged then
                                NS.Options:NotifyChanged()
                            end
                        end,
                    },
                    importProfile = {
                        type = "execute",
                        order = 21,
                        width = 1.0,
                        name = "导入到目标配置",
                        disabled = function()
                            return TrimText(profileTransferText) == ""
                        end,
                        confirm = true,
                        confirmText = "确认将文本内容导入到当前管理目标配置吗？这会覆盖目标配置。",
                        func = function()
                            local ok, errorMessage = Core:ImportProfile(
                                EnsureManagedProfileKey(),
                                profileTransferText
                            )
                            if not ok then
                                Core:Print(errorMessage or "配置导入失败。")
                                return
                            end

                            Core:Print("已导入目标配置。")
                            RefreshAllSettings(true)
                        end,
                    },
                    transferBox = {
                        type = "input",
                        order = 30,
                        width = "full",
                        multiline = 10,
                        name = "配置文本",
                        desc = "这里使用编码后的配置文本。可以导出目标配置到这里，也可以粘贴后导入到目标配置。",
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
