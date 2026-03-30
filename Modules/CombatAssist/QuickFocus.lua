local _, NS = ...
local Core = NS.Core

--[[
快捷焦点模块来自用户提供的 ShiftFocus 思路：
1. 按住修饰键 + 鼠标键时，对鼠标悬停目标设置焦点
2. 可选在鼠标悬停为空时清空焦点
3. 可选在设置焦点时自动添加团队标记

这里把它并入雨轩专用插件的战斗辅助模块，统一使用我们的 SavedVariables，
并通过 RefreshFromSettings / OnPlayerLogin 接口接入现有框架。
]]

local QuickFocus = {}
NS.Modules.CombatAssist.QuickFocus = QuickFocus

local SUPPORTED_FRAME_NAMES = {
    -- 暴雪框体
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "FocusFrame",
    "PartyMemberFrame1",
    "PartyMemberFrame2",
    "PartyMemberFrame3",
    "PartyMemberFrame4",
    "PartyMemberFrame5",
    "Boss1TargetFrame",
    "Boss2TargetFrame",
    "Boss3TargetFrame",
    "Boss4TargetFrame",
    "Boss5TargetFrame",
    -- UUF
    "UUF_Player",
    "UUF_Pet",
    "UUF_Target",
    "UUF_TargetTarget",
    "UUF_Focus",
    "UUF_FocusTarget",
    "UUF_Boss1",
    "UUF_Boss2",
    "UUF_Boss3",
    "UUF_Boss4",
    "UUF_Boss5",
    "UUF_Boss6",
    "UUF_Boss7",
    "UUF_Boss8",
    "UUF_Boss9",
    "UUF_Boss10",
    -- Enhance QoL
    "EQOLUFPlayerFrame",
    "EQOLUFTargetFrame",
    "EQOLUFToTFrame",
    "EQOLUFFocusFrame",
    "EQOLUFBoss1Frame",
    "EQOLUFBoss2Frame",
    "EQOLUFBoss3Frame",
    "EQOLUFBoss4Frame",
    "EQOLUFBoss5Frame",
}

local MODIFIER_CHOICES = {
    { value = "shift", label = "Shift" },
    { value = "alt", label = "Alt" },
    { value = "ctrl", label = "Ctrl" },
}

local TEXTS = {
    groupName = "快捷焦点",
    basicTab = "基础",
    markerTab = "标记",
    intro = "按住修饰键 + 鼠标按键，可以对鼠标悬停目标快速设置焦点。",
    enabled = "启用快捷焦点",
    modifier = "修饰键",
    mouseButton = "鼠标按键",
    allowClearFocus = "鼠标下没有目标时清空焦点",
    reset = "恢复默认设置",
    enableMarking = "设置焦点时自动打标",
    selectedMarker = "默认标记",
}

local BUTTON_CHOICES = {
    { value = "1", label = "鼠标左键" },
    { value = "2", label = "鼠标右键" },
    { value = "3", label = "鼠标中键" },
    { value = "4", label = "鼠标按键 4" },
    { value = "5", label = "鼠标按键 5" },
}

local MARKER_TEXTURES = {
    [0] = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14|t",
    [1] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t",
    [2] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14|t",
    [3] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14|t",
    [4] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14|t",
    [5] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14|t",
    [6] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14|t",
    [7] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14|t",
    [8] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14|t",
}

local MARKER_CHOICES = {
    { value = 0, label = MARKER_TEXTURES[0] .. " 不自动标记" },
    { value = 1, label = MARKER_TEXTURES[1] .. " 星星" },
    { value = 2, label = MARKER_TEXTURES[2] .. " 圆圈" },
    { value = 3, label = MARKER_TEXTURES[3] .. " 菱形" },
    { value = 4, label = MARKER_TEXTURES[4] .. " 三角" },
    { value = 5, label = MARKER_TEXTURES[5] .. " 月亮" },
    { value = 6, label = MARKER_TEXTURES[6] .. " 方块" },
    { value = 7, label = MARKER_TEXTURES[7] .. " 叉叉" },
    { value = 8, label = MARKER_TEXTURES[8] .. " 骷髅" },
}

local managedFrames = {}
local eventFrame
local secureButton

local function GetConfig()
    return Core:GetConfig("combatAssist", "quickFocus")
end

local function RememberManagedFrame(frame)
    if not frame then
        return
    end

    managedFrames[frame] = true
end

local function BuildFocusMacro()
    local config = GetConfig()
    local lines = {}

    if config.allowClearFocus then
        lines[#lines + 1] = "/clearfocus [@mouseover,noexists]"
    end

    lines[#lines + 1] = "/focus [@mouseover,exists]"

    if config.enableMarking and (tonumber(config.selectedMarker) or 0) > 0 then
        lines[#lines + 1] = "/tm [@mouseover,exists] " .. tostring(config.selectedMarker)
    end

    return table.concat(lines, "\n")
end

--[[
框体上可能残留上一次设置过的修饰键/按键组合。
每次刷新前统一清空 3 个修饰键 * 5 个鼠标键，避免改配置后旧组合继续生效。
]]
local function ClearFocusAttributes(frame)
    if not (frame and frame.SetAttribute) then
        return
    end

    for _, modifier in ipairs({ "shift", "alt", "ctrl" }) do
        for buttonIndex = 1, 5 do
            local button = tostring(buttonIndex)
            pcall(frame.SetAttribute, frame, modifier .. "-type" .. button, nil)
            pcall(frame.SetAttribute, frame, modifier .. "-macrotext" .. button, nil)
        end
    end
end

local function ApplyFocusBinding(frame, modifier, mouseButton, macroText)
    if not (frame and frame.SetAttribute) then
        return
    end

    RememberManagedFrame(frame)
    ClearFocusAttributes(frame)

    pcall(frame.SetAttribute, frame, modifier .. "-type" .. mouseButton, "macro")
    pcall(frame.SetAttribute, frame, modifier .. "-macrotext" .. mouseButton, macroText)
end

local function ClearManagedFrames()
    for frame in pairs(managedFrames) do
        ClearFocusAttributes(frame)
    end
end

local function ApplyNamedFrames(modifier, mouseButton, macroText)
    for _, frameName in ipairs(SUPPORTED_FRAME_NAMES) do
        ApplyFocusBinding(_G[frameName], modifier, mouseButton, macroText)
    end
end

local function ApplyDandersFrames(modifier, mouseButton, macroText)
    local dandersFrames = _G.DandersFrames
    if not dandersFrames then
        return
    end

    ApplyFocusBinding(dandersFrames.playerFrame, modifier, mouseButton, macroText)

    if dandersFrames.partyFrames then
        for index = 1, 4 do
            ApplyFocusBinding(dandersFrames.partyFrames[index], modifier, mouseButton, macroText)
        end
    end

    if dandersFrames.raidFrames then
        for index = 1, 40 do
            ApplyFocusBinding(dandersFrames.raidFrames[index], modifier, mouseButton, macroText)
        end
    end
end

local function ApplyNamePlates(modifier, mouseButton, macroText)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then
        return
    end

    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        ApplyFocusBinding(plate, modifier, mouseButton, macroText)
    end
end

local function EnsureSecureButton()
    if secureButton then
        return secureButton
    end

    secureButton = CreateFrame(
        "CheckButton",
        "YuXuanSpecialQuickFocusButton",
        UIParent,
        "SecureActionButtonTemplate"
    )
    secureButton:RegisterForClicks("AnyDown", "AnyUp")
    return secureButton
end

local function ClearOverrideHotkey()
    if secureButton and ClearOverrideBindings then
        ClearOverrideBindings(secureButton)
    end
end

local function ApplyOverrideHotkey(modifier, mouseButton, macroText)
    local button = EnsureSecureButton()
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext1", macroText)

    if ClearOverrideBindings then
        ClearOverrideBindings(button)
    end

    if SetOverrideBindingClick then
        SetOverrideBindingClick(button, true, modifier .. "-BUTTON" .. mouseButton, button:GetName())
    end
end

local function ApplyAllBindings()
    if InCombatLockdown() then
        QuickFocus.pendingRefresh = true
        return
    end

    QuickFocus.pendingRefresh = false
    ClearManagedFrames()
    ClearOverrideHotkey()

    local config = GetConfig()
    if not (config and config.enabled) then
        return
    end

    local modifier = tostring(config.modifier or "shift"):lower()
    local mouseButton = tostring(config.mouseButton or "1")
    local macroText = BuildFocusMacro()

    ApplyNamedFrames(modifier, mouseButton, macroText)
    ApplyDandersFrames(modifier, mouseButton, macroText)
    ApplyNamePlates(modifier, mouseButton, macroText)
    ApplyOverrideHotkey(modifier, mouseButton, macroText)
end

local function RefreshLater(delaySeconds)
    C_Timer.After(delaySeconds or 0, function()
        if NS.Modules and NS.Modules.CombatAssist and NS.Modules.CombatAssist.QuickFocus then
            NS.Modules.CombatAssist.QuickFocus:RefreshFromSettings()
        end
    end)
end

function QuickFocus:GetModifierChoices()
    return MODIFIER_CHOICES
end

function QuickFocus:GetOptionText(key)
    return TEXTS[key]
end

function QuickFocus:GetButtonChoices()
    return BUTTON_CHOICES
end

function QuickFocus:GetMarkerChoices()
    return MARKER_CHOICES
end

function QuickFocus:RefreshFromSettings()
    ApplyAllBindings()
end

function QuickFocus:OnPlayerLogin()
    if eventFrame then
        self:RefreshFromSettings()
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:SetScript("OnEvent", function(_, event, unitToken)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if InCombatLockdown() then
                QuickFocus.pendingRefresh = true
                return
            end

            local config = GetConfig()
            if not (config and config.enabled) then
                return
            end

            local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unitToken)
            if plate then
                ApplyFocusBinding(
                    plate,
                    tostring(config.modifier or "shift"):lower(),
                    tostring(config.mouseButton or "1"),
                    BuildFocusMacro()
                )
            end
            return
        end

        RefreshLater(0.2)
    end)

    self:RefreshFromSettings()
end
