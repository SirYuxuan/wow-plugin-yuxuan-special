local _, NS = ...
local Core = NS.Core
local GlowLib = LibStub and LibStub("LibCustomGlow-1.0", true)
local TrinketMonitor = {}
NS.Modules.CombatAssist.TrinketMonitor = TrinketMonitor

local TRINKET_SLOTS = {
    { slotID = 13, label = "上饰品" },
    { slotID = 14, label = "下饰品" },
}

local UPDATE_INTERVAL = 0.1
local READY_DASH_SPEED = 6
local DASH_COUNT = 12
local READY_TEXT_DEFAULT = "饰品好了！"

local TEXT_POSITIONS = {
    TOP = "图标上方",
    CENTER = "图标中间",
    BOTTOM = "图标下方",
}

local function Clamp(number, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, tonumber(number) or minValue))
end

local function RoundOffset(value)
    local number = tonumber(value) or 0
    if math.abs(number) < 0.001 then
        return 0
    end
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function ApplyChatLikeFont(fontString, size, outline)
    if not fontString then
        return
    end

    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, outline or "OUTLINE")
        return
    end

    local fontObject = ChatFontNormal
    if fontObject and fontObject.GetFont then
        local fontPath, _, flags = fontObject:GetFont()
        if fontPath then
            fontString:SetFont(fontPath, size or 12, outline or flags or "")
            return
        end
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, outline or "OUTLINE")
end

local function ApplyTextColor(fontString, color)
    if not fontString or not color then
        return
    end

    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

local function GetCenterOffset(frame)
    local scale = frame:GetScale()
    if not scale or scale == 0 then
        return 0, 0
    end

    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then
        return 0, 0
    end

    left, right, top, bottom = left * scale, right * scale, top * scale, bottom * scale
    local parentWidth, parentHeight = UIParent:GetSize()
    local offsetX = ((left + right) * 0.5 - parentWidth * 0.5) / scale
    local offsetY = ((bottom + top) * 0.5 - parentHeight * 0.5) / scale
    return offsetX, offsetY
end

local function FormatCooldownText(remaining)
    if remaining >= 3600 then
        return string.format("%dh", math.ceil(remaining / 3600))
    end
    if remaining >= 60 then
        local minutes = math.floor(remaining / 60)
        local seconds = math.floor(remaining % 60)
        return string.format("%d:%02d", minutes, seconds)
    end
    if remaining >= 10 then
        return tostring(math.ceil(remaining))
    end
    return string.format("%.1f", remaining)
end

local function IsActiveTrinket(itemLocationValue)
    local spellName
    if C_Item and C_Item.GetItemSpell and itemLocationValue then
        spellName = C_Item.GetItemSpell(itemLocationValue)
    end
    if not spellName then
        spellName = GetItemSpell(itemLocationValue)
    end
    return spellName ~= nil and spellName ~= ""
end

local function BuildAlertText(template, itemName)
    local text = tostring(template or READY_TEXT_DEFAULT)
    if itemName and itemName ~= "" then
        text = text:gsub("%%s", itemName)
    end
    return text
end

local function NormalizeSoundPath(path)
    local value = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub('^"(.*)"$', "%1")
    value = value:gsub("/", "\\")
    if value == "" then
        return nil
    end
    if not value:find("^[A-Za-z]+\\") then
        value = "Interface\\AddOns\\YuXuanSpecial\\" .. value
    end
    return value
end

local function ParseBlockedItemIDs(rawValue)
    local text = tostring(rawValue or "")
    local result = {}

    for itemID in text:gmatch("%d+") do
        result[tonumber(itemID)] = true
    end

    return result
end

local function SetCooldownFrame(cooldownFrame, startTime, duration, enable)
    if not cooldownFrame then
        return
    end

    if cooldownFrame.SetCooldown then
        cooldownFrame:SetCooldown(startTime or 0, duration or 0)
        return
    end

    if CooldownFrame_Set then
        CooldownFrame_Set(cooldownFrame, startTime or 0, duration or 0, enable or 0)
    end
end

local function ClearCooldownFrame(cooldownFrame)
    if not cooldownFrame then
        return
    end

    if cooldownFrame.Clear then
        cooldownFrame:Clear()
    elseif cooldownFrame.SetCooldown then
        cooldownFrame:SetCooldown(0, 0)
    end
end

local function SetButtonBorderColor(button, r, g, b, a)
    if not button or not button._border then
        return
    end

    for _, texture in ipairs(button._border) do
        texture:SetColorTexture(r, g, b, a)
    end
end

local function SetFrameMouseEnabled(frame, enabled)
    if not frame then
        return
    end

    if InCombatLockdown() then
        frame._pendingMouseEnabled = enabled and true or false
        return
    end

    frame._pendingMouseEnabled = nil
    frame:EnableMouse(enabled and true or false)
end

local function ApplyPendingFrameMouseEnabled(frame)
    if not frame or frame._pendingMouseEnabled == nil or InCombatLockdown() then
        return
    end

    local enabled = frame._pendingMouseEnabled
    frame._pendingMouseEnabled = nil
    frame:EnableMouse(enabled)
end

local function SetReadyDashColor(button, color)
    if not button or not button._readyDashes then
        return
    end

    for _, dash in ipairs(button._readyDashes) do
        dash:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end
end

local function CreateBorder(frame, offset, thickness)
    local border = {}
    local top = frame:CreateTexture(nil, "OVERLAY")
    top:SetHeight(thickness)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", offset, offset)
    table.insert(border, top)

    local bottom = frame:CreateTexture(nil, "OVERLAY")
    bottom:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -offset, -offset)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    table.insert(border, bottom)

    local left = frame:CreateTexture(nil, "OVERLAY")
    left:SetWidth(thickness)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -offset, -offset)
    table.insert(border, left)

    local right = frame:CreateTexture(nil, "OVERLAY")
    right:SetWidth(thickness)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", offset, offset)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
    table.insert(border, right)

    return border
end

local function ApplyCooldownTextAnchor(fontString, parent, position)
    fontString:ClearAllPoints()
    if position == "TOP" then
        fontString:SetPoint("TOP", parent, "TOP", 0, -2)
    elseif position == "BOTTOM" then
        fontString:SetPoint("BOTTOM", parent, "BOTTOM", 0, 2)
    else
        fontString:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
end

local function SetButtonVisualVisible(button, visible)
    local alpha = visible and 1 or 0

    if button.icon then
        button.icon:SetAlpha(alpha)
    end
    if button.shadow then
        button.shadow:SetAlpha(visible and 0.55 or 0)
    end
    if button.cooldown then
        button.cooldown:SetAlpha(alpha)
    end
    if button.text then
        if visible and button._textVisible then
            button.text:Show()
        else
            button.text:Hide()
        end
    end
    if button._border then
        for _, texture in ipairs(button._border) do
            texture:SetAlpha(alpha)
        end
    end
    if button._readyDashes then
        for _, dash in ipairs(button._readyDashes) do
            if visible and button._readyAnimationEnabled and button._usingFallbackDashes then
                dash:Show()
            else
                dash:Hide()
            end
        end
    end
end

local function ApplySecureButtonVisibility(button, visible)
    button._layoutVisible = visible and true or false

    if InCombatLockdown() then
        SetButtonVisualVisible(button, visible)
        return
    end

    if not button:IsShown() then
        button:Show()
    end

    SetButtonVisualVisible(button, visible)
end

local function StopReadyHighlight(button)
    if not button then
        return
    end

    local glowTarget = button._readyGlowTarget or button.overlayFrame or button
    if GlowLib then
        pcall(GlowLib.PixelGlow_Stop, glowTarget)
    end

    if button._readyDashes then
        for _, dash in ipairs(button._readyDashes) do
            dash:Hide()
        end
    end

    button._readyAnimationEnabled = false
    button._dashPhase = nil
    button._usingFallbackDashes = false
    button._glowColorKey = nil
    button._glowSize = nil
    button:SetScript("OnUpdate", nil)
end

local function SetReadyAnimationEnabled(button, enabled, color)
    if not button or not button._readyDashes then
        return
    end

    local glowTarget = button._readyGlowTarget or button.overlayFrame or button

    if enabled ~= true then
        StopReadyHighlight(button)
        return
    end

    button._readyAnimationEnabled = true
    button._dashPhase = button._dashPhase or 0
    button._usingFallbackDashes = false

    if GlowLib then
        local rgba = {
            color and color.r or 1,
            color and color.g or 1,
            color and color.b or 1,
            color and color.a or 1,
        }
        local colorKey = table.concat(rgba, ":")
        local size = button:GetWidth() or 50

        if button._glowColorKey ~= colorKey or button._glowSize ~= size then
            pcall(GlowLib.PixelGlow_Stop, glowTarget)
            pcall(GlowLib.PixelGlow_Start, glowTarget, rgba, 8, 0.25, (10 / 50) * size, math.max(1.25, (0.8 / 50) * size), 1, 1, false, nil, 2)
            button._glowColorKey = colorKey
            button._glowSize = size
        end

        for _, dash in ipairs(button._readyDashes) do
            dash:Hide()
        end

        button:SetScript("OnUpdate", nil)
        return
    end

    button._usingFallbackDashes = true
    button._glowColorKey = nil
    button._glowSize = nil
    SetReadyDashColor(button, color or {})

    for _, dash in ipairs(button._readyDashes) do
        dash:Show()
    end

    button:SetScript("OnUpdate", function(self, elapsed)
        self._dashPhase = (self._dashPhase or 0) + elapsed * READY_DASH_SPEED
        local activeIndex = math.floor(self._dashPhase) % DASH_COUNT

        for index, dash in ipairs(self._readyDashes) do
            local distance = (index - 1 - activeIndex) % DASH_COUNT
            if distance == 0 then
                dash:SetAlpha(1.0)
            elseif distance == 1 or distance == DASH_COUNT - 1 then
                dash:SetAlpha(0.7)
            elseif distance == 2 or distance == DASH_COUNT - 2 then
                dash:SetAlpha(0.45)
            else
                dash:SetAlpha(0.18)
            end
        end
    end)
end

function TrinketMonitor:GetConfig()
    return Core:GetConfig("combatAssist", "trinketMonitor")
end

function TrinketMonitor:IsEnabled()
    return self:GetConfig().enabled == true
end

function TrinketMonitor:GetTextPositionChoices()
    return TEXT_POSITIONS
end

function TrinketMonitor:GetBlockedItemIDSet()
    local rawValue = self:GetConfig().blockedItemIDs or ""
    if self._blockedItemIDsRaw ~= rawValue then
        self._blockedItemIDsRaw = rawValue
        self._blockedItemIDs = ParseBlockedItemIDs(rawValue)
    end
    return self._blockedItemIDs or {}
end

function TrinketMonitor:CreateButton(slotInfo)
    local button = CreateFrame("Button", nil, self._mainFrame, "SecureActionButtonTemplate")
    button.slotID = slotInfo.slotID
    button.slotLabel = slotInfo.label
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", string.format("/use %d", slotInfo.slotID))

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local overlayFrame = CreateFrame("Frame", nil, button)
    overlayFrame:SetAllPoints(button)
    overlayFrame:SetFrameLevel(button:GetFrameLevel() + 20)
    overlayFrame:EnableMouse(false)
    button.overlayFrame = overlayFrame

    local glowHost = CreateFrame("Frame", nil, button)
    glowHost:SetAllPoints(button)
    glowHost:SetFrameLevel(button:GetFrameLevel() + 10)
    glowHost:EnableMouse(false)
    button._readyGlowTarget = glowHost

    local shadow = button:CreateTexture(nil, "BACKGROUND")
    shadow:SetAllPoints(button)
    shadow:SetColorTexture(0, 0, 0, 0.55)
    button.shadow = shadow

    button._border = CreateBorder(button, 0, 1)
    SetButtonBorderColor(button, 0, 0, 0, 1)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetFrameLevel(button:GetFrameLevel() + 2)
    button.cooldown = cooldown

    local textLayer = CreateFrame("Frame", nil, button)
    textLayer:SetAllPoints(button)
    textLayer:SetFrameLevel(button:GetFrameLevel() + 30)
    textLayer:EnableMouse(false)
    button.textLayer = textLayer

    local text = textLayer:CreateFontString(nil, "OVERLAY")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetDrawLayer("OVERLAY", 7)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 0.95)
    ApplyChatLikeFont(text, 14, "OUTLINE")
    text:SetText("")
    text:Hide()
    button.text = text
    button._textVisible = false
    button._layoutVisible = true

    button._readyDashes = {}
    for _ = 1, DASH_COUNT do
        local dash = button.overlayFrame:CreateTexture(nil, "OVERLAY")
        dash:Hide()
        table.insert(button._readyDashes, dash)
    end

    button:SetScript("OnDragStart", function()
        if TrinketMonitor:GetConfig().unlocked then
            TrinketMonitor._mainFrame:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function()
        if TrinketMonitor:GetConfig().unlocked then
            TrinketMonitor._mainFrame:StopMovingOrSizing()
            local offsetX, offsetY = GetCenterOffset(TrinketMonitor._mainFrame)
            local config = TrinketMonitor:GetConfig()
            config.offsetX = RoundOffset(offsetX)
            config.offsetY = RoundOffset(offsetY)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not self.itemLink or self._layoutVisible ~= true then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", self.slotID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    return button
end

function TrinketMonitor:LayoutReadyDashes(button)
    local owner = button.overlayFrame or button
    local width = owner:GetWidth() > 0 and owner:GetWidth() or button:GetWidth()
    local height = owner:GetHeight() > 0 and owner:GetHeight() or button:GetHeight()
    local baseSize = math.min(width, height)
    local inset = 1
    local thickness = math.max(2, math.floor(baseSize * 0.06))
    local dashes = button._readyDashes
    if not dashes then
        return
    end

    local usableWidth = math.max(12, math.floor(width - inset * 2))
    local usableHeight = math.max(12, math.floor(height - inset * 2))
    local horizontalGap = math.max(2, math.floor(usableWidth * 0.10))
    local verticalGap = math.max(2, math.floor(usableHeight * 0.10))
    local horizontalLength = math.max(4, math.floor((usableWidth - horizontalGap * 2) / 3))
    local verticalLength = math.max(4, math.floor((usableHeight - verticalGap * 2) / 3))
    local usedWidth = horizontalLength * 3 + horizontalGap * 2
    local usedHeight = verticalLength * 3 + verticalGap * 2
    local horizontalStart = inset + math.floor((usableWidth - usedWidth) * 0.5)
    local verticalStart = inset + math.floor((usableHeight - usedHeight) * 0.5)

    local function layout(index, x, y, dashWidth, dashHeight)
        local dash = dashes[index]
        dash:ClearAllPoints()
        dash:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -y)
        dash:SetSize(dashWidth, dashHeight)
    end

    local topY = verticalStart
    local leftX = horizontalStart
    local rightX = horizontalStart + usedWidth - thickness
    local bottomY = verticalStart + usedHeight - thickness
    local topX2 = leftX + horizontalLength + horizontalGap
    local topX3 = leftX + (horizontalLength + horizontalGap) * 2
    local leftY2 = topY + verticalLength + verticalGap
    local leftY3 = topY + (verticalLength + verticalGap) * 2

    layout(1, leftX, topY, horizontalLength, thickness)
    layout(2, topX2, topY, horizontalLength, thickness)
    layout(3, topX3, topY, horizontalLength, thickness)

    layout(4, rightX, topY, thickness, verticalLength)
    layout(5, rightX, leftY2, thickness, verticalLength)
    layout(6, rightX, leftY3, thickness, verticalLength)

    layout(7, leftX, bottomY, horizontalLength, thickness)
    layout(8, topX2, bottomY, horizontalLength, thickness)
    layout(9, topX3, bottomY, horizontalLength, thickness)

    layout(10, leftX, topY, thickness, verticalLength)
    layout(11, leftX, leftY2, thickness, verticalLength)
    layout(12, leftX, leftY3, thickness, verticalLength)
end

function TrinketMonitor:CreateFrames()
    if not self._mainFrame then
        local mainFrame = CreateFrame("Frame", "YuXuanTrinketMonitorFrame", UIParent)
        mainFrame:SetFrameStrata("MEDIUM")
        mainFrame:SetFrameLevel(90)
        mainFrame:SetMovable(true)
        mainFrame:SetClampedToScreen(true)
        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:SetScript("OnDragStart", function(frame)
            if self:GetConfig().unlocked then
                frame:StartMoving()
            end
        end)
        mainFrame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            local offsetX, offsetY = GetCenterOffset(frame)
            local config = self:GetConfig()
            config.offsetX = RoundOffset(offsetX)
            config.offsetY = RoundOffset(offsetY)
        end)
        self._mainFrame = mainFrame

        local blocker = CreateFrame("Frame", nil, mainFrame)
        blocker:SetAllPoints(mainFrame)
        blocker:SetFrameLevel(mainFrame:GetFrameLevel() + 100)
        blocker:EnableMouse(true)
        blocker:Hide()
        blocker:SetScript("OnMouseDown", function() end)
        blocker:SetScript("OnMouseUp", function() end)
        self._interactionBlocker = blocker
    end

    self._buttons = self._buttons or {}
    for index, slotInfo in ipairs(TRINKET_SLOTS) do
        if not self._buttons[index] then
            self._buttons[index] = self:CreateButton(slotInfo)
        end
    end

    if not self._alertFrame then
        local alertFrame = CreateFrame("Frame", "YuXuanTrinketMonitorAlert", UIParent)
        alertFrame:SetFrameStrata("HIGH")
        alertFrame:SetFrameLevel(120)
        alertFrame:SetMovable(true)
        alertFrame:SetClampedToScreen(true)
        alertFrame:RegisterForDrag("LeftButton")
        alertFrame:SetScript("OnDragStart", function(frame)
            if self:GetConfig().unlocked then
                frame:StartMoving()
            end
        end)
        alertFrame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            local offsetX, offsetY = GetCenterOffset(frame)
            local config = self:GetConfig()
            config.readyOffsetX = RoundOffset(offsetX)
            config.readyOffsetY = RoundOffset(offsetY)
        end)

        local alertText = alertFrame:CreateFontString(nil, "OVERLAY")
        alertText:SetPoint("CENTER", alertFrame, "CENTER", 0, 0)
        alertText:SetJustifyH("CENTER")
        alertText:SetJustifyV("MIDDLE")
        alertText:SetShadowOffset(1, -1)
        alertText:SetShadowColor(0, 0, 0, 0.95)
        ApplyChatLikeFont(alertText, 28, "OUTLINE")
        alertText:SetText("")

        self._alertFrame = alertFrame
        self._alertText = alertText
    end
end

function TrinketMonitor:EnsureSecureButtonsShown()
    if InCombatLockdown() then
        return
    end

    for _, button in ipairs(self._buttons or {}) do
        if not button:IsShown() then
            button:Show()
        end
    end
end

function TrinketMonitor:RefreshLayout()
    self:CreateFrames()
    self:EnsureSecureButtonsShown()

    local config = self:GetConfig()
    local iconSize = Clamp(config.iconSize or 44, 20, 120)
    local spacing = Clamp(config.spacing or 8, 0, 40)
    local textSize = Clamp(config.textSize or 14, 8, 36)
    local readyTextSize = Clamp(config.readyTextSize or 28, 10, 72)
    local textColor = config.textColor or { r = 1, g = 1, b = 1, a = 1 }
    local readyTextColor = config.readyTextColor or { r = 1, g = 0.82, b = 0.2, a = 1 }
    local highlightColor = config.highlightColor or { r = 1, g = 0.82, b = 0.2, a = 1 }

    self._mainFrame:SetSize(iconSize * #TRINKET_SLOTS + spacing * math.max(0, #TRINKET_SLOTS - 1), iconSize)
    self._mainFrame:ClearAllPoints()
    self._mainFrame:SetPoint("CENTER", UIParent, "CENTER", RoundOffset(config.offsetX or 0), RoundOffset(config.offsetY or 0))

    for _, button in ipairs(self._buttons or {}) do
        button:SetSize(iconSize, iconSize)
        ApplyChatLikeFont(button.text, textSize, "OUTLINE")
        ApplyTextColor(button.text, textColor)
        ApplyCooldownTextAnchor(button.text, button, config.textPosition or "BOTTOM")
        SetButtonBorderColor(button, 0, 0, 0, 1)
        SetReadyDashColor(button, highlightColor)
        self:LayoutReadyDashes(button)
        if button.cooldown and button.cooldown.SetSwipeColor then
            button.cooldown:SetSwipeColor(0, 0, 0, 0.75)
        end
        SetButtonVisualVisible(button, button._layoutVisible ~= false and button:IsShown())
    end

    ApplyChatLikeFont(self._alertText, readyTextSize, "OUTLINE")
    ApplyTextColor(self._alertText, readyTextColor)
    self._alertFrame:ClearAllPoints()
    self._alertFrame:SetPoint("CENTER", UIParent, "CENTER", RoundOffset(config.readyOffsetX or 0), RoundOffset(config.readyOffsetY or 0))
    self._alertFrame:SetSize(math.max(240, readyTextSize * 10), readyTextSize + 20)

    local unlocked = config.unlocked == true
    SetFrameMouseEnabled(self._mainFrame, unlocked)
    self._mainFrame:SetAlpha(1)
    if not self._mainFrame:IsShown() and not InCombatLockdown() then
        self._mainFrame:Show()
    end
    self._alertFrame:EnableMouse(unlocked)
    if self._interactionBlocker then
        self._interactionBlocker:Hide()
    end

    if unlocked and not self._alertExpiresAt then
        self._alertText:SetText(config.readyText or READY_TEXT_DEFAULT)
        self._alertFrame:Show()
    elseif not self._alertExpiresAt then
        self._alertFrame:Hide()
    end
end

function TrinketMonitor:ShowReadyAlert(itemLink)
    if not self._alertFrame or not self._alertText then
        return
    end

    local config = self:GetConfig()
    if config.showReadyAlert == false then
        return
    end

    local itemName = itemLink and GetItemInfo(itemLink) or nil
    self._alertText:SetText(BuildAlertText(config.readyText, itemName))
    self._alertExpiresAt = GetTime() + Clamp(config.alertDuration or 1.5, 0.5, 10)
    self._alertFrame:Show()
end

function TrinketMonitor:PlayReadySound(forcePlay)
    local config = self:GetConfig()
    if not forcePlay and config.playReadySound == false then
        return
    end

    local soundPath = NormalizeSoundPath(config.readySoundPath)
    if not soundPath then
        return
    end

    if PlaySoundFile then
        pcall(PlaySoundFile, soundPath, "Master")
    end
end

function TrinketMonitor:UpdateAlertFrame(now)
    if not self._alertFrame then
        return
    end

    if self._alertExpiresAt and now < self._alertExpiresAt then
        self._alertFrame:Show()
        return
    end

    self._alertExpiresAt = nil
    if self:GetConfig().unlocked then
        self._alertText:SetText(self:GetConfig().readyText or READY_TEXT_DEFAULT)
        self._alertFrame:Show()
    else
        self._alertFrame:Hide()
    end
end

function TrinketMonitor:RefreshVisibleLayout()
    if not self._mainFrame then
        return
    end

    if InCombatLockdown() then
        self._pendingVisibleLayout = true
        return
    end

    self._pendingVisibleLayout = false

    local config = self:GetConfig()
    local spacing = Clamp(config.spacing or 8, 0, 40)
    local shownButtons = {}

    for _, button in ipairs(self._buttons or {}) do
        if button._layoutVisible then
            table.insert(shownButtons, button)
        end
    end

    if #shownButtons == 0 then
        self._mainFrame:SetSize(1, Clamp(config.iconSize or 44, 20, 120))
        return
    end

    for index, button in ipairs(shownButtons) do
        button:ClearAllPoints()
        if index == 1 then
            button:SetPoint("LEFT", self._mainFrame, "LEFT", 0, 0)
        else
            button:SetPoint("LEFT", shownButtons[index - 1], "RIGHT", spacing, 0)
        end
    end

    local width = Clamp(config.iconSize or 44, 20, 120) * #shownButtons + spacing * math.max(0, #shownButtons - 1)
    self._mainFrame:SetSize(width, Clamp(config.iconSize or 44, 20, 120))
end

function TrinketMonitor:UpdateButton(button, now)
    local config = self:GetConfig()
    self._slotState = self._slotState or {}
    local blockedItemIDs = self:GetBlockedItemIDSet()

    local slotID = button.slotID
    local itemID = GetInventoryItemID("player", slotID)
    local state = self._slotState[slotID] or {}

    if not itemID then
        button.itemLink = nil
        button.icon:SetTexture(134400)
        button.text:SetText("")
        button._textVisible = false
        ClearCooldownFrame(button.cooldown)
        SetReadyAnimationEnabled(button, false)
        ApplySecureButtonVisibility(button, false)
        state.lastItemID = nil
        state.ready = false
        state.hadCooldown = false
        self._slotState[slotID] = state
        return
    end

    if blockedItemIDs[itemID] then
        button.itemLink = nil
        button.icon:SetTexture(134400)
        button.text:SetText("")
        button._textVisible = false
        ClearCooldownFrame(button.cooldown)
        SetReadyAnimationEnabled(button, false)
        ApplySecureButtonVisibility(button, false)
        state.lastItemID = itemID
        state.ready = false
        state.hadCooldown = false
        self._slotState[slotID] = state
        return
    end

    local itemLink = GetInventoryItemLink("player", slotID)
    local itemTexture = GetInventoryItemTexture("player", slotID) or 134400
    local hasUseEffect = IsActiveTrinket(itemLink or itemID)

    if not hasUseEffect then
        button.itemLink = nil
        button.text:SetText("")
        button._textVisible = false
        ClearCooldownFrame(button.cooldown)
        SetReadyAnimationEnabled(button, false)
        ApplySecureButtonVisibility(button, false)
        state.lastItemID = itemID
        state.ready = false
        state.hadCooldown = false
        self._slotState[slotID] = state
        return
    end

    local startTime, duration, enable = GetInventoryItemCooldown("player", slotID)
    if state.lastItemID ~= itemID then
        state.lastItemID = itemID
        state.ready = false
        state.hadCooldown = false
    end

    ApplySecureButtonVisibility(button, true)
    button.itemLink = itemLink
    button.icon:SetTexture(itemTexture)
    button.icon:SetVertexColor(1, 1, 1, 1)

    local remaining = 0
    local isCoolingDown = false
    if enable == 1 and startTime and duration and duration > 1.5 and startTime > 0 then
        remaining = math.max(0, startTime + duration - now)
        isCoolingDown = remaining > 0.05
    end

    if isCoolingDown then
        SetCooldownFrame(button.cooldown, startTime, duration, enable)
    else
        ClearCooldownFrame(button.cooldown)
    end

    if config.showText ~= false and isCoolingDown then
        button.text:SetText(FormatCooldownText(remaining))
        button._textVisible = true
        button.text:Show()
    else
        button.text:SetText("")
        button._textVisible = false
        button.text:Hide()
    end

    local ready = not isCoolingDown
    if isCoolingDown then
        state.hadCooldown = true
    end
    if ready and state.hadCooldown and not state.ready then
        self:ShowReadyAlert(itemLink)
        self:PlayReadySound()
    end

    state.ready = ready
    self._slotState[slotID] = state
    SetReadyAnimationEnabled(button, config.highlightReady ~= false and ready, config.highlightColor)
    SetButtonVisualVisible(button, button._layoutVisible ~= false and button:IsShown())
end

function TrinketMonitor:UpdateDisplay()
    if not self._active or not self._mainFrame then
        return
    end

    self:EnsureSecureButtonsShown()

    local config = self:GetConfig()
    local suppressOutOfCombat = config.combatOnly and not config.unlocked and not InCombatLockdown()

    local now = GetTime()
    local anyVisible = false
    for _, button in ipairs(self._buttons or {}) do
        self:UpdateButton(button, now)
        anyVisible = anyVisible or button._layoutVisible == true
    end

    self:RefreshVisibleLayout()

    if suppressOutOfCombat then
        for _, button in ipairs(self._buttons or {}) do
            StopReadyHighlight(button)
            SetButtonVisualVisible(button, false)
        end
        self._mainFrame:SetAlpha(0)
        SetFrameMouseEnabled(self._mainFrame, false)
        if self._interactionBlocker then
            self._interactionBlocker:Show()
        end
    elseif anyVisible then
        self._mainFrame:SetAlpha(1)
        SetFrameMouseEnabled(self._mainFrame, config.unlocked == true)
        if self._interactionBlocker then
            self._interactionBlocker:Hide()
        end
    else
        for _, button in ipairs(self._buttons or {}) do
            SetButtonVisualVisible(button, false)
        end
        self._mainFrame:SetAlpha(0)
        SetFrameMouseEnabled(self._mainFrame, false)
        if self._interactionBlocker then
            self._interactionBlocker:Show()
        end
    end

    if suppressOutOfCombat then
        self._alertFrame:Hide()
    elseif not config.combatOnly or InCombatLockdown() or config.unlocked then
        self:UpdateAlertFrame(now)
    else
        self._alertFrame:Hide()
    end
end

function TrinketMonitor:StartUpdating()
    if self._updateTicker then
        return
    end

    self._updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        self:UpdateDisplay()
    end)
end

function TrinketMonitor:StopUpdating()
    if self._updateTicker then
        self._updateTicker:Cancel()
        self._updateTicker = nil
    end
end

function TrinketMonitor:Activate()
    if self._active then
        return
    end

    self._active = true
    self._slotState = self._slotState or {}
    self:CreateFrames()
    self:EnsureSecureButtonsShown()
    self:RefreshLayout()
    self:StartUpdating()
    self:UpdateDisplay()
end

function TrinketMonitor:Deactivate()
    if not self._active then
        return
    end

    self._active = false
    self:StopUpdating()
    if self._mainFrame then
        self._mainFrame:SetAlpha(0)
        if not InCombatLockdown() then
            self._mainFrame:Hide()
        end
    end
    if self._alertFrame then
        self._alertFrame:Hide()
    end
end

function TrinketMonitor:EvaluateActivation()
    if self:IsEnabled() then
        self:Activate()
    else
        self:Deactivate()
    end
end

function TrinketMonitor:RefreshFromSettings()
    if self._mainFrame then
        self:RefreshLayout()
        self:UpdateDisplay()
    end
    self:EvaluateActivation()
end

function TrinketMonitor:TestReadyAlert()
    self:CreateFrames()
    self:RefreshLayout()
    self:ShowReadyAlert(nil)
    self:PlayReadySound()
end

function TrinketMonitor:TestReadySound()
    self:PlayReadySound(true)
end

function TrinketMonitor:OnEvent(event, ...)
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
        if self._active then
            self:UpdateDisplay()
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then
            ApplyPendingFrameMouseEnabled(self._mainFrame)
        end
        if self._active then
            self:UpdateDisplay()
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" and self._active then
            self:UpdateDisplay()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:EvaluateActivation()
    end
end

function TrinketMonitor:OnPlayerLogin()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self._eventFrame = eventFrame

    C_Timer.After(1.0, function()
        self:EvaluateActivation()
    end)
end
