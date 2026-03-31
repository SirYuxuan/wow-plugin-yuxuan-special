local _, NS = ...
local Core = NS.Core

--[[
通用设置负责两类全局能力：
1. 外观设置：字体、主题色等会影响整个插件的展示层。
2. 配置管理：当前角色绑定哪一份配置，以及配置的新建、编辑、导入导出。

这里把配置管理拆成 4 个区块：
1. 当前绑定
2. 新建配置
3. 编辑配置
4. 导入导出
这样操作路径会比之前更清楚。
]]

local PROFILE_KEY_GLOBAL = "GLOBAL"

local createSourceKey = PROFILE_KEY_GLOBAL
local editTargetKey = PROFILE_KEY_GLOBAL
local transferTargetKey = PROFILE_KEY_GLOBAL
local createProfileName = ""
local renameProfileName = ""
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

    local mapIDDisplay = NS.Modules.MapAssist and NS.Modules.MapAssist.MapIDDisplay
    if mapIDDisplay and mapIDDisplay.RefreshFromSettings then
        mapIDDisplay:RefreshFromSettings()
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

local function GetProfileChoices()
    return Core:GetProfileChoices()
end

local function GetCurrentProfileKey()
    return Core:GetCurrentCharacterProfileKey() or PROFILE_KEY_GLOBAL
end

local function GetProfileLabel(profileKey)
    if not profileKey or profileKey == PROFILE_KEY_GLOBAL then
        return "全局配置"
    end

    return tostring(profileKey)
end

local function EnsureSelectableProfileKey(profileKey)
    if not profileKey or profileKey == PROFILE_KEY_GLOBAL then
        return PROFILE_KEY_GLOBAL
    end

    if Core:GetNamedProfile(profileKey, false) then
        return profileKey
    end

    return PROFILE_KEY_GLOBAL
end

local function SetCreateSourceKey(profileKey)
    createSourceKey = EnsureSelectableProfileKey(profileKey)
end

local function SetEditTargetKey(profileKey)
    editTargetKey = EnsureSelectableProfileKey(profileKey)
    if editTargetKey ~= PROFILE_KEY_GLOBAL then
        renameProfileName = tostring(editTargetKey)
    else
        renameProfileName = ""
    end
end

local function SetTransferTargetKey(profileKey)
    transferTargetKey = EnsureSelectableProfileKey(profileKey)
end

local function InitializeManagerState()
    local currentProfileKey = GetCurrentProfileKey()

    if createSourceKey == nil then
        createSourceKey = currentProfileKey
    end
    if editTargetKey == nil then
        editTargetKey = currentProfileKey
    end
    if transferTargetKey == nil then
        transferTargetKey = currentProfileKey
    end

    SetCreateSourceKey(createSourceKey or currentProfileKey)
    SetEditTargetKey(editTargetKey or currentProfileKey)
    SetTransferTargetKey(transferTargetKey or currentProfileKey)
end

local function GetProfileStatusText()
    local characterKey = Core:GetCurrentCharacterKey() or "当前角色"
    return string.format(
        "当前角色 %s 正在使用 %s。所有角色默认都走全局配置，只有手动切换后才会使用自定义配置。",
        characterKey,
        GetProfileLabel(GetCurrentProfileKey())
    )
end

local function GetEditTargetTip()
    if editTargetKey == PROFILE_KEY_GLOBAL then
        return "全局配置是保留配置，不能重命名、删除，也不能通过导入直接覆盖。"
    end

    return string.format("当前正在编辑配置：%s", GetProfileLabel(editTargetKey))
end

local function GetTransferTargetTip()
    if transferTargetKey == PROFILE_KEY_GLOBAL then
        return "全局配置只允许导出，不允许通过导入直接覆盖。"
    end

    return string.format("当前导入导出的目标配置：%s", GetProfileLabel(transferTargetKey))
end

function NS.BuildGeneralOptions()
    InitializeManagerState()

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
                    themeRow = {
                        type = "group",
                        order = 11,
                        name = "",
                        layout = "row",
                        args = {
                            colorMode = {
                                type = "select",
                                name = "主题颜色",
                                order = 1,
                                width = 1.1,
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
                                order = 2,
                                width = 1.0,
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
                        },
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
                            local currentKey = GetCurrentProfileKey()
                            SetCreateSourceKey(currentKey)
                            SetEditTargetKey(currentKey)
                            SetTransferTargetKey(currentKey)
                            RefreshAllSettings(true)
                        end,
                    },
                    createGroup = {
                        type = "group",
                        order = 20,
                        name = "新建配置",
                        layout = "row",
                        args = {
                            createSource = {
                                type = "select",
                                order = 1,
                                width = 1.2,
                                inlineLabelWidth = 72,
                                name = "复制来源",
                                values = function()
                                    return GetProfileChoices()
                                end,
                                get = function()
                                    return EnsureSelectableProfileKey(createSourceKey)
                                end,
                                set = function(_, value)
                                    SetCreateSourceKey(value)
                                    if NS.Options and NS.Options.NotifyChanged then
                                        NS.Options:NotifyChanged()
                                    end
                                end,
                            },
                            createName = {
                                type = "input",
                                order = 2,
                                width = 1.5,
                                name = "新配置名称",
                                get = function()
                                    return createProfileName
                                end,
                                set = function(_, value)
                                    createProfileName = value or ""
                                end,
                            },
                            createAction = {
                                type = "execute",
                                order = 3,
                                width = 0.8,
                                name = "新建配置",
                                disabled = function()
                                    return TrimText(createProfileName) == ""
                                end,
                                func = function()
                                    local created, errorMessage = Core:CreateNamedProfile(
                                        createProfileName,
                                        EnsureSelectableProfileKey(createSourceKey)
                                    )
                                    if not created then
                                        Core:Print(errorMessage or "新配置创建失败。")
                                        return
                                    end

                                    SetEditTargetKey(created)
                                    SetTransferTargetKey(created)
                                    createProfileName = ""
                                    Core:Print("已创建配置：" .. created)
                                    RefreshAllSettings(true)
                                end,
                            },
                        },
                    },
                    editGroup = {
                        type = "group",
                        order = 30,
                        name = "编辑配置",
                        inline = true,
                        args = {
                            editRow = {
                                type = "group",
                                order = 1,
                                name = "",
                                layout = "row",
                                args = {
                                    editTarget = {
                                        type = "select",
                                        order = 1,
                                        width = 1.2,
                                        inlineLabelWidth = 72,
                                        name = "编辑目标",
                                        values = function()
                                            return GetProfileChoices()
                                        end,
                                        get = function()
                                            return EnsureSelectableProfileKey(editTargetKey)
                                        end,
                                        set = function(_, value)
                                            SetEditTargetKey(value)
                                            if NS.Options and NS.Options.NotifyChanged then
                                                NS.Options:NotifyChanged()
                                            end
                                        end,
                                    },
                                    renameName = {
                                        type = "input",
                                        order = 2,
                                        width = 1.5,
                                        name = "重命名为",
                                        disabled = function()
                                            return EnsureSelectableProfileKey(editTargetKey) == PROFILE_KEY_GLOBAL
                                        end,
                                        get = function()
                                            return renameProfileName
                                        end,
                                        set = function(_, value)
                                            renameProfileName = value or ""
                                        end,
                                    },
                                    renameAction = {
                                        type = "execute",
                                        order = 3,
                                        width = 0.8,
                                        name = "保存名称",
                                        disabled = function()
                                            return EnsureSelectableProfileKey(editTargetKey) == PROFILE_KEY_GLOBAL
                                                or TrimText(renameProfileName) == ""
                                        end,
                                        func = function()
                                            local renamed, errorMessage = Core:RenameNamedProfile(
                                                EnsureSelectableProfileKey(editTargetKey),
                                                renameProfileName
                                            )
                                            if not renamed then
                                                Core:Print(errorMessage or "配置重命名失败。")
                                                return
                                            end

                                            SetEditTargetKey(renamed)
                                            SetTransferTargetKey(renamed)
                                            Core:Print("已重命名配置：" .. renamed)
                                            RefreshAllSettings(true)
                                        end,
                                    },
                                    deleteAction = {
                                        type = "execute",
                                        order = 4,
                                        width = 0.8,
                                        name = "删除配置",
                                        disabled = function()
                                            return EnsureSelectableProfileKey(editTargetKey) == PROFILE_KEY_GLOBAL
                                        end,
                                        confirm = true,
                                        confirmText = "确认删除当前编辑目标配置吗？所有使用这份配置的角色会自动切回全局配置。",
                                        func = function()
                                            local deleted, errorMessage = Core:DeleteNamedProfile(
                                                EnsureSelectableProfileKey(editTargetKey)
                                            )
                                            if not deleted then
                                                Core:Print(errorMessage or "配置删除失败。")
                                                return
                                            end

                                            SetEditTargetKey(PROFILE_KEY_GLOBAL)
                                            SetTransferTargetKey(PROFILE_KEY_GLOBAL)
                                            Core:Print("已删除目标配置。")
                                            RefreshAllSettings(true)
                                        end,
                                    },
                                },
                            },
                            editTip = {
                                type = "description",
                                order = 2,
                                fontSize = "medium",
                                name = function()
                                    return GetEditTargetTip()
                                end,
                            },
                        },
                    },
                    transferGroup = {
                        type = "group",
                        order = 40,
                        name = "导入导出",
                        inline = true,
                        args = {
                            transferRow = {
                                type = "group",
                                order = 1,
                                name = "",
                                layout = "row",
                                args = {
                                    transferTarget = {
                                        type = "select",
                                        order = 1,
                                        width = 1.3,
                                        inlineLabelWidth = 72,
                                        name = "导入导出目标",
                                        values = function()
                                            return GetProfileChoices()
                                        end,
                                        get = function()
                                            return EnsureSelectableProfileKey(transferTargetKey)
                                        end,
                                        set = function(_, value)
                                            SetTransferTargetKey(value)
                                            if NS.Options and NS.Options.NotifyChanged then
                                                NS.Options:NotifyChanged()
                                            end
                                        end,
                                    },
                                    exportAction = {
                                        type = "execute",
                                        order = 2,
                                        width = 0.8,
                                        name = "导出配置",
                                        func = function()
                                            profileTransferText = Core:ExportProfile(
                                                EnsureSelectableProfileKey(transferTargetKey)
                                            )
                                            Core:Print("已生成编码后的配置文本。")
                                            if NS.Options and NS.Options.NotifyChanged then
                                                NS.Options:NotifyChanged()
                                            end
                                        end,
                                    },
                                    importAction = {
                                        type = "execute",
                                        order = 3,
                                        width = 0.8,
                                        name = "导入配置",
                                        disabled = function()
                                            return EnsureSelectableProfileKey(transferTargetKey) == PROFILE_KEY_GLOBAL
                                                or TrimText(profileTransferText) == ""
                                        end,
                                        confirm = true,
                                        confirmText = "确认将文本内容导入到当前导入导出目标吗？这会覆盖目标配置。",
                                        func = function()
                                            local ok, errorMessage = Core:ImportProfile(
                                                EnsureSelectableProfileKey(transferTargetKey),
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
                                },
                            },
                            transferTip = {
                                type = "description",
                                order = 2,
                                fontSize = "medium",
                                name = function()
                                    return GetTransferTargetTip()
                                end,
                            },
                            transferBox = {
                                type = "input",
                                order = 3,
                                width = "full",
                                multiline = 10,
                                name = "配置文本",
                                desc = "这里使用编码后的配置文本。可以导出目标配置到这里，也可以粘贴后导入到指定命名配置。",
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
            },
        },
    }
end
