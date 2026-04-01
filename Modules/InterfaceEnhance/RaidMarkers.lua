local addonName, NS = ...
local Core = NS.Core

local RaidMarkers = {}
NS.Modules.InterfaceEnhance.RaidMarkers = RaidMarkers

local RAID_MARKERS_DEFAULT_SIZE = 28
local RAID_MARKERS_MIN_SIZE = 20
local RAID_MARKERS_MAX_SIZE = 48
local RAID_MARKERS_DEFAULT_SPACING = 6
local RAID_MARKERS_DEFAULT_COUNTDOWN = 6
local RAID_MARKERS_BUTTON_PADDING = 4
local RAID_MARKERS_BUTTON_BORDER = 1

local RAID_TARGET_BUTTONS = {
    { key = "STAR", index = 1, label = "星星", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    { key = "CIRCLE", index = 2, label = "大饼", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    { key = "DIAMOND", index = 3, label = "钻石", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    { key = "TRIANGLE", index = 4, label = "三角", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    { key = "MOON", index = 5, label = "月亮", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    { key = "SQUARE", index = 6, label = "方块", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    { key = "CROSS", index = 7, label = "叉叉", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    { key = "SKULL", index = 8, label = "骷髅", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
}

local RAID_ACTION_BUTTONS = {
    {
        key = "CLEAR",
        label = "清",
        texture = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        tooltipTitle = "清除标记",
        tooltipText = "清除当前目标的团队标记。",
    },
    {
        key = "READY",
        label = "就",
        texture = "Interface\\RaidFrame\\ReadyCheck-Ready",
        tooltipTitle = "团队就位",
        tooltipText = "发起就位确认。",
    },
    {
        key = "COUNTDOWN",
        label = "倒",
        texture = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        tooltipTitle = "倒计时",
        tooltipText = "按设定秒数发起团队倒计时。",
    },
}

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "raidMarkers")
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function ApplyConfiguredFont(fontString, size)
    if not fontString then
        return
    end

    local optionsPrivate = GetOptionsPrivate()
    local config = GetConfig()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 13, "OUTLINE", config and config.fontPreset or "CHAT")
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 13, "OUTLINE")
end

local function CreateSimpleOutline(parent, layer, thickness)
    local border = {}
    local size = thickness or 1

    border.top = parent:CreateTexture(nil, layer or "BORDER")
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.top:SetHeight(size)

    border.bottom = parent:CreateTexture(nil, layer or "BORDER")
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.bottom:SetHeight(size)

    border.left = parent:CreateTexture(nil, layer or "BORDER")
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.left:SetWidth(size)

    border.right = parent:CreateTexture(nil, layer or "BORDER")
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.right:SetWidth(size)

    return border
end

local function SetSimpleOutlineColor(border, r, g, b, a)
    if type(border) ~= "table" then
        return
    end

    for _, edge in pairs(border) do
        edge:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
    end
end

local function SetRaidMarkerButtonHoverTarget(button, targetScale)
    if not button then
        return
    end

    button._hoverTargetScale = targetScale or 1
    if button._hoverAnimating then
        return
    end

    button._hoverAnimating = true
    button:SetScript("OnUpdate", function(selfButton, elapsed)
        local current = selfButton._hoverScale or 1
        local target = selfButton._hoverTargetScale or 1
        local nextScale = current + (target - current) * math.min(1, elapsed * 4.5)

        if math.abs(target - nextScale) < 0.01 then
            nextScale = target
        end

        selfButton._hoverScale = nextScale
        selfButton:SetScale(nextScale)

        if nextScale == target then
            selfButton._hoverAnimating = false
            selfButton:SetScript("OnUpdate", nil)
        end
    end)
end

local function GetRaidMarkerMacroText(buttonInfo, countdownSeconds)
    if not buttonInfo or not buttonInfo.key then
        return nil, nil
    end

    if buttonInfo.index then
        return "/tm 0\n/tm " .. tostring(buttonInfo.index), "/tm 0"
    end

    if buttonInfo.key == "CLEAR" then
        return "/tm 0", nil
    elseif buttonInfo.key == "READY" then
        return "/readycheck", nil
    elseif buttonInfo.key == "COUNTDOWN" then
        local seconds = math.max(3, math.min(15, tonumber(countdownSeconds) or RAID_MARKERS_DEFAULT_COUNTDOWN))
        return "/run if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(" .. seconds
            .. ") elseif DoCountdown then DoCountdown(" .. seconds .. ") end", nil
    end

    return nil, nil
end

local function GetVisibleButtons(frame)
    local buttons = {}
    if not frame or not frame.buttons then
        return buttons
    end

    for _, button in ipairs(frame.buttons) do
        buttons[#buttons + 1] = button
    end

    return buttons
end

local function IsInHomeOrInstanceGroup()
    if type(IsInGroup) ~= "function" then
        return false
    end

    if IsInGroup() then
        return true
    end

    if type(LE_PARTY_CATEGORY_HOME) == "number" and IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return true
    end

    if type(LE_PARTY_CATEGORY_INSTANCE) == "number" and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return true
    end

    return false
end

local function CanUseRaidLeaderAction()
    if not IsInHomeOrInstanceGroup() then
        return false, "需要先加入队伍或团队。"
    end

    if type(IsInRaid) == "function" and IsInRaid() then
        local isLeader = type(UnitIsGroupLeader) == "function" and UnitIsGroupLeader("player")
        local isAssistant = type(UnitIsGroupAssistant) == "function" and UnitIsGroupAssistant("player")
        if not isLeader and not isAssistant then
            return false, "团队中需要队长或助理权限。"
        end
    end

    return true
end

local function PrintMessage(message)
    Core:Print(message or "")
end

function RaidMarkers:SavePosition()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    local pos = GetConfig().point
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = math.floor((x or 0) + 0.5)
    pos.y = math.floor((y or 0) + 0.5)
end

function RaidMarkers:UpdateLayout()
    if not self.frame then
        return
    end

    local config = GetConfig()
    local frame = self.frame
    local buttons = GetVisibleButtons(frame)
    local spacing = math.max(0, math.min(40, tonumber(config.spacing) or RAID_MARKERS_DEFAULT_SPACING))
    local iconSize = math.max(RAID_MARKERS_MIN_SIZE, math.min(RAID_MARKERS_MAX_SIZE,
        tonumber(config.iconSize) or RAID_MARKERS_DEFAULT_SIZE))
    local buttonSize = iconSize + RAID_MARKERS_BUTTON_PADDING * 2
    local textSize = math.max(11, math.floor(iconSize * 0.45))
    local bgColor = config.backgroundColor or { r = 0, g = 0, b = 0, a = 0.35 }
    local borderColor = config.borderColor or { r = 0, g = 0.6, b = 1, a = 0.45 }
    local totalWidth = 0
    local totalHeight = 0

    for index, button in ipairs(buttons) do
        button:ClearAllPoints()
        button:SetSize(buttonSize, buttonSize)

        if not InCombatLockdown or not InCombatLockdown() then
            local macro1, macro2 = GetRaidMarkerMacroText(button.buttonInfo, config.countdown)
            if macro1 then
                button:SetAttribute("type1", "macro")
                button:SetAttribute("macrotext1", macro1)
            end

            if macro2 then
                button:SetAttribute("type2", "macro")
                button:SetAttribute("macrotext2", macro2)
            else
                button:SetAttribute("type2", nil)
                button:SetAttribute("macrotext2", nil)
            end
        else
            self.pendingRefresh = true
        end

        if button.icon then
            button.icon:ClearAllPoints()
            button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.icon:SetSize(iconSize, iconSize)
            if button.iconTexture then
                button.icon:SetTexture(button.iconTexture)
                if button.texCoord then
                    button.icon:SetTexCoord(unpack(button.texCoord))
                else
                    button.icon:SetTexCoord(0, 1, 0, 1)
                end
                button.icon:Show()
            else
                button.icon:SetTexture(nil)
                button.icon:Hide()
            end
        end

        if button.label then
            ApplyConfiguredFont(button.label, textSize)
            button.label:SetText(button.textValue or "")
            button.label:SetTextColor(1, 1, 1, 1)
            if (not button.iconTexture) and button.textValue and button.textValue ~= "" then
                button.label:Show()
            else
                button.label:Hide()
            end
        end

        if config.orientation == "VERTICAL" then
            if index == 1 then
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            else
                button:SetPoint("TOPLEFT", buttons[index - 1], "BOTTOMLEFT", 0, -spacing)
            end

            totalWidth = math.max(totalWidth, buttonSize)
            totalHeight = totalHeight + buttonSize + (index > 1 and spacing or 0)
        else
            if index == 1 then
                button:SetPoint("LEFT", frame, "LEFT", 0, 0)
            else
                button:SetPoint("LEFT", buttons[index - 1], "RIGHT", spacing, 0)
            end

            totalWidth = totalWidth + buttonSize + (index > 1 and spacing or 0)
            totalHeight = math.max(totalHeight, buttonSize)
        end

        if config.showBackground then
            button.bg:SetColorTexture(bgColor.r or 0, bgColor.g or 0, bgColor.b or 0, bgColor.a or 0.35)
        else
            button.bg:SetColorTexture(0, 0, 0, 0)
        end
    end

    frame:SetSize(math.max(totalWidth, 1), math.max(totalHeight, 1))
    frame:SetMovable(not config.locked)

    if config.showBackground then
        frame.bg:SetColorTexture(bgColor.r or 0, bgColor.g or 0, bgColor.b or 0, math.min((bgColor.a or 0.35) * 0.55, 0.4))
    else
        frame.bg:SetColorTexture(0, 0, 0, 0)
    end

    if config.showBorder then
        SetSimpleOutlineColor(frame.border, borderColor.r or 0, borderColor.g or 0.6, borderColor.b or 1,
            borderColor.a or 0.45)
    else
        SetSimpleOutlineColor(frame.border, 0, 0, 0, 0)
    end
end

function RaidMarkers:RefreshVisibility()
    if not self.frame then
        return
    end

    local config = GetConfig()
    if config.enabled and ((type(IsInGroup) == "function" and IsInGroup()) or config.showWhenSolo) then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function RaidMarkers:Refresh()
    if not self.frame then
        return
    end

    self:UpdateLayout()
    self:RefreshVisibility()
end

function RaidMarkers:CreateFrame()
    if self.frame then
        return
    end

    local config = GetConfig()
    local frame = CreateFrame("Frame", addonName .. "RaidMarkersFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.border = CreateSimpleOutline(frame, "BORDER", RAID_MARKERS_BUTTON_BORDER)

    local pos = config.point
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or -30)

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end
        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        RaidMarkers:SavePosition()
    end)

    local function CreateMarkerButton(parent)
        local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:RegisterForDrag("LeftButton")
        button:SetScale(1)
        button._hoverScale = 1
        button._hoverTargetScale = 1

        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints(button)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("CENTER")

        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.label:SetPoint("CENTER")

        button:SetScript("OnDragStart", function()
            if GetConfig().locked then
                return
            end
            parent:StartMoving()
        end)

        button:SetScript("OnDragStop", function()
            if GetConfig().locked then
                return
            end
            parent:StopMovingOrSizing()
            RaidMarkers:SavePosition()
        end)

        return button
    end

    frame.buttons = {}

    for _, info in ipairs(RAID_TARGET_BUTTONS) do
        local button = CreateMarkerButton(frame)
        button.buttonInfo = info
        button.tooltipTitle = info.label
        button.tooltipText = "给当前目标设置团队标记。"
        button.iconTexture = info.texture
        button.textValue = nil
        button.icon:SetTexture(info.texture)
        button.icon:Show()
        button.label:Hide()

        button:SetScript("OnEnter", function(selfButton)
            SetRaidMarkerButtonHoverTarget(selfButton, 1.18)
            GameTooltip:SetOwner(selfButton, "ANCHOR_BOTTOM", 0, -8)
            GameTooltip:AddLine(selfButton.tooltipTitle or "团队标记", 1, 0.82, 0)
            GameTooltip:AddLine(selfButton.tooltipText or "", 1, 1, 1)
            GameTooltip:AddLine("左键设置，右键清除。", 0.75, 1, 0.75)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(selfButton)
            SetRaidMarkerButtonHoverTarget(selfButton, 1)
            GameTooltip:Hide()
        end)

        frame.buttons[#frame.buttons + 1] = button
    end

    for _, info in ipairs(RAID_ACTION_BUTTONS) do
        local button = CreateMarkerButton(frame)
        button.buttonInfo = info
        button.textValue = info.label
        button.iconTexture = info.texture
        button.texCoord = info.texCoord
        button.tooltipTitle = info.tooltipTitle
        button.tooltipText = info.tooltipText

        if info.texture then
            button.icon:SetTexture(info.texture)
            if info.texCoord then
                button.icon:SetTexCoord(unpack(info.texCoord))
            end
            button.icon:Show()
            button.label:Hide()
        else
            button.icon:SetTexture(nil)
            button.icon:Hide()
            button.label:Show()
        end

        button:SetScript("OnEnter", function(selfButton)
            SetRaidMarkerButtonHoverTarget(selfButton, 1.18)
            GameTooltip:SetOwner(selfButton, "ANCHOR_BOTTOM", 0, -8)
            GameTooltip:AddLine(selfButton.tooltipTitle or "团队功能", 1, 0.82, 0)
            GameTooltip:AddLine(selfButton.tooltipText or "", 1, 1, 1)
            if info.key == "COUNTDOWN" then
                GameTooltip:AddLine(string.format("当前秒数：%d 秒",
                    math.max(3, math.min(15, tonumber(GetConfig().countdown) or RAID_MARKERS_DEFAULT_COUNTDOWN))), 0.75, 1, 0.75)
            elseif info.key == "CLEAR" then
                GameTooltip:AddLine("右键团队标记按钮也能直接清除。", 0.75, 1, 0.75)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(selfButton)
            SetRaidMarkerButtonHoverTarget(selfButton, 1)
            GameTooltip:Hide()
        end)

        frame.buttons[#frame.buttons + 1] = button
    end

    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if RaidMarkers.pendingRefresh then
                RaidMarkers.pendingRefresh = false
                RaidMarkers:Refresh()
            end
            return
        end

        RaidMarkers:RefreshVisibility()
    end)
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self.frame = frame
    self:Refresh()
end

function RaidMarkers:RefreshFromSettings()
    local config = GetConfig()
    if not config then
        return
    end

    if not config.enabled then
        if self.frame then
            self.frame:Hide()
        end
        return
    end

    if not self.frame then
        self:CreateFrame()
    end

    if not self.frame then
        return
    end

    local pos = config.point or {}
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or -30)
    self:Refresh()
end

function RaidMarkers:OnPlayerLogin()
    if GetConfig() and GetConfig().enabled then
        self:CreateFrame()
    end
end

function RaidMarkers:CanUseRaidLeaderAction()
    return CanUseRaidLeaderAction()
end

function RaidMarkers:StartReadyCheck()
    local canUse, reason = CanUseRaidLeaderAction()
    if not canUse then
        PrintMessage(reason)
        return
    end

    if type(DoReadyCheck) == "function" then
        DoReadyCheck()
    else
        PrintMessage("当前版本不支持团队就位。")
    end
end
