local _, NS = ...
local Core = NS.Core

local UpdateLog = {}
NS.Modules.InterfaceEnhance.UpdateLog = UpdateLog

local CreateFrame = rawget(_G, "CreateFrame")
local C_Timer = rawget(_G, "C_Timer")
local PlaySound = rawget(_G, "PlaySound")
local SOUNDKIT = rawget(_G, "SOUNDKIT") or {}
local STANDARD_TEXT_FONT = rawget(_G, "STANDARD_TEXT_FONT")
local UIParent = rawget(_G, "UIParent")
local UISpecialFrames = rawget(_G, "UISpecialFrames")
local unpack = table.unpack or unpack

local CHANGELOG = NS.UpdateLogEntries or {}

local COLORS = {
    bg = { 0.06, 0.07, 0.09, 0.96 },
    panel = { 0.10, 0.11, 0.14, 0.98 },
    card = { 0.12, 0.14, 0.18, 0.98 },
    cardSoft = { 0.09, 0.10, 0.13, 0.94 },
    border = { 0.25, 0.27, 0.32, 1.00 },
    accent = { 0.95, 0.76, 0.18, 1.00 },
    accentSoft = { 0.27, 0.20, 0.06, 0.92 },
    accentBg = { 0.22, 0.17, 0.06, 0.96 },
    text = { 0.95, 0.96, 0.99, 1.00 },
    muted = { 0.66, 0.69, 0.76, 1.00 },
    shadow = { 0.00, 0.00, 0.00, 0.40 },
    success = { 0.28, 0.82, 0.54, 1.00 },
}

local ASSETS = {
    line = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Tga\\Gradient-Line.tga",
    circle = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Tga\\Gradient-Circle.tga",
}

local function GetConfig()
    Core.db = Core.db or {}
    Core.db.general = Core.db.general or {}
    Core.db.general.updateLog = Core.db.general.updateLog or {}

    local config = Core.db.general.updateLog
    local defaults = NS.DEFAULTS and NS.DEFAULTS.general and NS.DEFAULTS.general.updateLog or {}
    for key, value in pairs(defaults) do
        if config[key] == nil then
            config[key] = value
        end
    end

    return config
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function GetFontPreset()
    local optionsPrivate = GetOptionsPrivate()
    local appearance = Core.GetAppearanceConfig and Core:GetAppearanceConfig() or {}
    if optionsPrivate and optionsPrivate.NormalizeFontPreset then
        return optionsPrivate.NormalizeFontPreset(appearance, "font")
    end

    return appearance and appearance.fontPreset or "CHAT"
end

local function ApplyFont(fontString, size, outline)
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, outline or "", GetFontPreset())
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, outline or "")
end

local function SetColor(region, color)
    if not region or not color then
        return
    end

    if region.SetTextColor then
        region:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    elseif region.SetVertexColor then
        region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    elseif region.SetColorTexture then
        region:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

local function CreateBackdrop(frame, backgroundColor, borderColor)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(backgroundColor or COLORS.panel))
    frame:SetBackdropBorderColor(unpack(borderColor or COLORS.border))
end

local function CreateShadow(frame)
    local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    shadow:SetPoint("TOPLEFT", -4, 4)
    shadow:SetPoint("BOTTOMRIGHT", 4, -4)
    shadow:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    shadow:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 4,
    })
    shadow:SetBackdropBorderColor(unpack(COLORS.shadow))
    return shadow
end

local function CreateText(parent, layer, size, outline, color)
    local text = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    ApplyFont(text, size, outline)
    SetColor(text, color or COLORS.text)
    return text
end

local function CreateButton(parent, label, width, height, accent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, height or 30)
    CreateBackdrop(button, accent and COLORS.accentSoft or COLORS.card, accent and COLORS.accent or COLORS.border)

    button.fill = button:CreateTexture(nil, "BACKGROUND")
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    button.fill:SetColorTexture(unpack(accent and { 0.30, 0.22, 0.07, 0.95 } or COLORS.cardSoft))

    button.text = CreateText(button, "OVERLAY", 12, "", accent and { 0.98, 0.93, 0.78, 1 } or COLORS.text)
    button.text:SetPoint("CENTER")
    button.text:SetJustifyH("CENTER")
    button.text:SetJustifyV("MIDDLE")
    button.text:SetText(label or "")

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.accent))
        self.fill:SetColorTexture(0.18, 0.20, 0.25, accent and 0.98 or 0.96)
        self.text:SetTextColor(1, 1, 1, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(accent and COLORS.accent or COLORS.border))
        self.fill:SetColorTexture(unpack(accent and { 0.30, 0.22, 0.07, 0.95 } or COLORS.cardSoft))
        SetColor(self.text, accent and { 0.98, 0.93, 0.78, 1 } or COLORS.text)
    end)

    return button
end

local function CreatePill(parent, text, point, x, y, color)
    local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pill:SetSize(120, 24)
    pill:SetPoint(point or "TOPRIGHT", x or 0, y or 0)
    CreateBackdrop(pill, COLORS.accentSoft, color or COLORS.accent)

    local label = CreateText(pill, "OVERLAY", 11, "", color or COLORS.accent)
    label:SetPoint("CENTER")
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(text or "")
    pill.label = label
    return pill
end

local function SetWrappedText(textRegion, width, text)
    textRegion:SetWidth(width)
    textRegion:SetText(text or "")
    return math.ceil(textRegion:GetStringHeight() or 0)
end

function UpdateLog:GetCurrentEntry()
    for _, entry in ipairs(CHANGELOG) do
        if entry.version == NS.VERSION then
            return entry
        end
    end

    return CHANGELOG[1]
end

function UpdateLog:MarkSeen()
    local config = GetConfig()
    config.lastSeenVersion = tostring(NS.VERSION or "")
end

function UpdateLog:RefreshToggle()
    local config = GetConfig()
    local enabled = config.autoShow ~= false
    local toggle = self.frame.autoToggle

    toggle.fill:SetShown(enabled)
    toggle.check:SetShown(enabled)
    toggle.state:SetText(enabled and "已开启" or "已关闭")
    toggle.label:SetText("新版本登录时自动弹出更新记录")

    toggle:SetBackdropColor(unpack(enabled and COLORS.accentBg or COLORS.cardSoft))
    toggle:SetBackdropBorderColor(unpack(enabled and COLORS.accent or COLORS.border))
    toggle.box:SetBackdropColor(unpack(enabled and COLORS.accentSoft or COLORS.card))
    toggle.box:SetBackdropBorderColor(unpack(enabled and COLORS.accent or COLORS.border))

    SetColor(toggle.label, enabled and COLORS.text or COLORS.muted)
    SetColor(toggle.state, enabled and COLORS.accent or COLORS.muted)
end

function UpdateLog:BuildCards()
    local child = self.frame.scrollChild
    local previous = child._yxsCards or {}
    for _, card in ipairs(previous) do
        card:Hide()
    end
    child._yxsCards = {}

    local width = 700
    local cursorY = -4

    for _, entry in ipairs(CHANGELOG) do
        local card = CreateFrame("Frame", nil, child, "BackdropTemplate")
        card:SetPoint("TOPLEFT", 0, cursorY)
        card:SetWidth(width)
        CreateBackdrop(card, entry.version == NS.VERSION and COLORS.card or COLORS.cardSoft, COLORS.border)

        card.stripe = card:CreateTexture(nil, "ARTWORK")
        card.stripe:SetPoint("TOPLEFT", 1, -1)
        card.stripe:SetPoint("BOTTOMLEFT", 1, 1)
        card.stripe:SetWidth(entry.version == NS.VERSION and 4 or 2)
        SetColor(card.stripe, entry.version == NS.VERSION and COLORS.accent or COLORS.border)

        local y = -18

        local tag = CreatePill(card, entry.version == NS.VERSION and "CURRENT BUILD" or "HISTORY", "TOPLEFT", 18, -16, entry.version == NS.VERSION and COLORS.accent or COLORS.muted)
        tag:SetWidth(entry.version == NS.VERSION and 118 or 88)

        local versionText = CreateText(card, "OVERLAY", 21, "OUTLINE", COLORS.text)
        versionText:SetPoint("TOPLEFT", tag, "BOTTOMLEFT", 0, -14)
        versionText:SetText("v" .. tostring(entry.version or ""))

        local titleText = CreateText(card, "OVERLAY", 15, "", entry.version == NS.VERSION and COLORS.accent or COLORS.text)
        titleText:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -8)
        titleText:SetPoint("TOPRIGHT", -18, 0)
        titleText:SetText(entry.tag or "")

        local summaryText = CreateText(card, "OVERLAY", 12, "", COLORS.muted)
        summaryText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -12)
        local summaryHeight = SetWrappedText(summaryText, width - 36, entry.summary)
        y = y - 24 - 26 - 20 - summaryHeight - 18

        local divider = card:CreateTexture(nil, "BORDER")
        divider:SetPoint("TOPLEFT", summaryText, "BOTTOMLEFT", 0, -14)
        divider:SetPoint("TOPRIGHT", -18, 0)
        divider:SetHeight(1)
        divider:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.8)
        y = y - 16

        for _, section in ipairs(entry.sections or {}) do
            local sectionTitle = CreateText(card, "OVERLAY", 13, "OUTLINE", COLORS.success)
            sectionTitle:SetPoint("TOPLEFT", 18, y)
            sectionTitle:SetText(section.title or "")
            y = y - 22

            for _, item in ipairs(section.items or {}) do
                local bullet = CreateText(card, "OVERLAY", 12, "", COLORS.text)
                bullet:SetPoint("TOPLEFT", 26, y)
                local bulletHeight = SetWrappedText(bullet, width - 50, "• " .. tostring(item or ""))
                y = y - bulletHeight - 8
            end

            y = y - 6
        end

        local cardHeight = math.abs(y) + 16
        card:SetHeight(cardHeight)

        child._yxsCards[#child._yxsCards + 1] = card
        cursorY = cursorY - cardHeight - 14
    end

    local tailText = CreateText(child, "OVERLAY", 11, "", COLORS.muted)
    tailText:SetPoint("TOPLEFT", 4, cursorY - 4)
    tailText:SetWidth(width - 8)
    tailText:SetText("后续版本的改动会继续累积在这里。你也可以通过 /yxs log 随时重新打开这个窗口。")
    cursorY = cursorY - math.ceil(tailText:GetStringHeight() or 0) - 16
    child.tailText = tailText

    child:SetSize(width, math.max(1, math.abs(cursorY)))
end

function UpdateLog:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "YuXuanSpecialUpdateLogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(812, 608)
    frame:SetPoint("CENTER", 0, 16)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(120)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    CreateBackdrop(frame, COLORS.panel, COLORS.border)
    CreateShadow(frame)

    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
    end

    frame.accentBar = frame:CreateTexture(nil, "ARTWORK")
    frame.accentBar:SetPoint("TOPLEFT", 1, -1)
    frame.accentBar:SetPoint("BOTTOMLEFT", 1, 1)
    frame.accentBar:SetWidth(4)
    SetColor(frame.accentBar, COLORS.accent)

    frame.banner = frame:CreateTexture(nil, "BACKGROUND")
    frame.banner:SetTexture(ASSETS.line)
    frame.banner:SetPoint("TOPLEFT", 0, 0)
    frame.banner:SetPoint("TOPRIGHT", 0, 0)
    frame.banner:SetHeight(132)
    frame.banner:SetBlendMode("ADD")
    frame.banner:SetVertexColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.12)

    frame.badge = CreatePill(frame, "UPDATE NOTES", "TOPLEFT", 22, -18, COLORS.accent)
    frame.badge:SetWidth(128)

    frame.title = CreateText(frame, "OVERLAY", 24, "OUTLINE", COLORS.text)
    frame.title:SetPoint("TOPLEFT", frame.badge, "BOTTOMLEFT", 0, -16)
    frame.title:SetPoint("TOPRIGHT", -148, 0)
    frame.title:SetText("更新记录")

    frame.subtitle = CreateText(frame, "OVERLAY", 13, "", COLORS.muted)
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
    frame.subtitle:SetPoint("TOPRIGHT", -148, 0)

    frame.versionPill = CreatePill(frame, "v" .. tostring(NS.VERSION or ""), "TOPRIGHT", -58, -20, COLORS.accent)
    frame.versionPill:SetWidth(84)

    local closeButton = CreateButton(frame, "×", 28, 28, false)
    closeButton:SetPoint("TOPRIGHT", -18, -18)
    closeButton.text:SetText("×")
    closeButton.text:SetTextColor(1, 0.86, 0.86, 1)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 22, -118)
    scrollFrame:SetPoint("BOTTOMRIGHT", -34, 86)
    frame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(700, 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    local footerLine = frame:CreateTexture(nil, "BORDER")
    footerLine:SetPoint("BOTTOMLEFT", 18, 72)
    footerLine:SetPoint("BOTTOMRIGHT", -18, 72)
    footerLine:SetHeight(1)
    footerLine:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.9)

    local autoToggle = CreateFrame("Button", nil, frame, "BackdropTemplate")
    autoToggle:SetSize(292, 36)
    autoToggle:SetPoint("BOTTOMLEFT", 22, 22)
    CreateBackdrop(autoToggle, COLORS.cardSoft, COLORS.border)

    autoToggle.box = CreateFrame("Frame", nil, autoToggle, "BackdropTemplate")
    autoToggle.box:SetSize(18, 18)
    autoToggle.box:SetPoint("LEFT", 12, 0)
    CreateBackdrop(autoToggle.box, COLORS.card, COLORS.border)

    autoToggle.fill = autoToggle.box:CreateTexture(nil, "ARTWORK")
    autoToggle.fill:SetPoint("TOPLEFT", 4, -4)
    autoToggle.fill:SetPoint("BOTTOMRIGHT", -4, 4)
    SetColor(autoToggle.fill, COLORS.accent)

    autoToggle.check = CreateText(autoToggle.box, "OVERLAY", 12, "OUTLINE", COLORS.text)
    autoToggle.check:SetPoint("CENTER", 0, 0)
    autoToggle.check:SetJustifyH("CENTER")
    autoToggle.check:SetJustifyV("MIDDLE")
    autoToggle.check:SetText("✓")

    autoToggle.label = CreateText(autoToggle, "OVERLAY", 11, "", COLORS.text)
    autoToggle.label:SetPoint("LEFT", autoToggle.box, "RIGHT", 10, 1)
    autoToggle.label:SetJustifyV("MIDDLE")

    autoToggle.state = CreateText(autoToggle, "OVERLAY", 11, "OUTLINE", COLORS.accent)
    autoToggle.state:SetPoint("RIGHT", -12, 1)
    autoToggle.state:SetJustifyH("RIGHT")
    autoToggle.state:SetJustifyV("MIDDLE")

    autoToggle:SetScript("OnClick", function()
        local config = GetConfig()
        config.autoShow = not (config.autoShow ~= false)
        UpdateLog:RefreshToggle()
    end)
    frame.autoToggle = autoToggle

    frame.commandHint = CreateText(frame, "OVERLAY", 11, "", COLORS.muted)
    frame.commandHint:SetPoint("BOTTOMLEFT", 22, 6)
    frame.commandHint:SetText("快捷命令：/yxs log")

    local settingsButton = CreateButton(frame, "打开设置", 112, 30, false)
    settingsButton:SetPoint("BOTTOMRIGHT", -146, 22)
    settingsButton:SetScript("OnClick", function()
        frame:Hide()
        if NS.Options and NS.Options.Open then
            NS.Options:Open("about")
        end
    end)

    local confirmButton = CreateButton(frame, "知道了", 112, 30, true)
    confirmButton:SetPoint("LEFT", settingsButton, "RIGHT", 10, 0)
    confirmButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.frame = frame
    self:BuildCards()
    self:RefreshToggle()
    frame:Hide()

    return frame
end

function UpdateLog:Refresh()
    local frame = self:EnsureFrame()
    local currentEntry = self:GetCurrentEntry()

    frame.versionPill.label:SetText("v" .. tostring(NS.VERSION or ""))
    if currentEntry and currentEntry.version == NS.VERSION then
        frame.subtitle:SetText(currentEntry.summary or "当前版本亮点与近期改动。")
    else
        frame.subtitle:SetText("当前版本的更新说明尚未整理，这里先展示最近一次发布的更新记录。")
    end
    self:RefreshToggle()
end

function UpdateLog:Open(isAuto)
    local frame = self:EnsureFrame()
    self:Refresh()
    self:MarkSeen()
    frame:Show()
    frame:Raise()

    if isAuto and PlaySound then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN or 850)
    end
end

function UpdateLog:Toggle()
    local frame = self:EnsureFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Open(false)
    end
end

function UpdateLog:OnPlayerLogin()
    local config = GetConfig()
    local currentEntry = self:GetCurrentEntry()
    if config.autoShow == false or config.lastSeenVersion == NS.VERSION then
        return
    end

    if not currentEntry or currentEntry.version ~= NS.VERSION then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            UpdateLog:Open(true)
        end)
    else
        self:Open(true)
    end
end
