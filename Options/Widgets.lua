local _, NS = ...

local Private = NS.Options.Private
local Colors = Private.Colors

--[[
这个文件专门负责“控件长什么样”。

目标是把 YUI 风格里比较统一的视觉元素抽出来：
1. 面板背景 / 边框 / 阴影
2. 按钮、导航按钮、标签按钮
3. 开关、输入框、滑条

这样后面如果你只想改风格，不想碰渲染逻辑，
基本只需要来改这个文件。
]]
Private.UI = Private.UI or {}
local UI = Private.UI

function UI.ShowTooltip(owner, text)
    if not owner or not text or text == "" then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 0.82, 0.18, true)
    GameTooltip:Show()
end

function UI.HideTooltip()
    GameTooltip:Hide()
end

function UI.CreateBackdrop(frame, color, borderColor)
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(Private.UnpackColor(color or Colors.card))
    frame:SetBackdropBorderColor(Private.UnpackColor(borderColor or Colors.border))
end

function UI.CreateShadow(frame)
    if frame._yxsShadow then
        return frame._yxsShadow
    end

    local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    shadow:SetPoint("TOPLEFT", -3, 3)
    shadow:SetPoint("BOTTOMRIGHT", 3, -3)
    shadow:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    shadow:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    shadow:SetBackdropBorderColor(Private.UnpackColor(Colors.shadow))
    frame._yxsShadow = shadow
    return shadow
end

function UI.CreateText(parent, size, outline)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    text:SetTextColor(Private.UnpackColor(Colors.text))
    text._yxsFontSize = size or 12
    text._yxsFontOutline = outline or ""
    Private.ApplyStoredFont(text)

    return text
end

function UI.CreateButton(parent, label, width, height, variant)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, height or 28)

    local normalBg = variant == "accent" and Colors.accentBg or Colors.card
    local normalBorder = variant == "accent" and Colors.borderActive or Colors.border
    local hoverBg = variant == "accent"
        and Private.MixColor(Colors.accentBg, Colors.accent, 0.18, 0.96)
        or Colors.cardSoft

    UI.CreateBackdrop(
        button,
        normalBg,
        normalBorder
    )

    local text = UI.CreateText(button, 12)
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetText(label or "")
    text:SetTextColor(
        Private.UnpackColor(variant == "accent" and { 0.98, 0.92, 0.70, 1 } or Colors.text)
    )
    button.text = text

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
        self:SetBackdropColor(Private.UnpackColor(hoverBg))
        if self.text then
            self.text:SetTextColor(1, 1, 1, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(Private.UnpackColor(normalBorder))
        self:SetBackdropColor(Private.UnpackColor(normalBg))
        if self.text then
            self.text:SetTextColor(
                Private.UnpackColor(variant == "accent" and { 0.98, 0.92, 0.70, 1 } or Colors.text)
            )
        end
    end)
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() and self.text then
            self.text:SetPoint("CENTER", 1, -1)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.text then
            self.text:SetPoint("CENTER", 0, 0)
        end
    end)

    return button
end

function UI.CreateDropdownButton(parent, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 176, height or 28)
    UI.CreateBackdrop(button, Colors.card, Colors.border)

    button.fill = button:CreateTexture(nil, "BACKGROUND")
    button.fill:SetPoint("TOPLEFT", 1, -1)
    button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    button.fill:SetColorTexture(Private.UnpackColor(Colors.cardSoft))

    button.valueText = UI.CreateText(button, 12)
    button.valueText:SetPoint("LEFT", 14, 0)
    button.valueText:SetPoint("RIGHT", -34, 0)
    button.valueText:SetJustifyH("LEFT")
    button.valueText:SetJustifyV("MIDDLE")

    button.arrow = CreateFrame("Frame", nil, button)
    button.arrow:SetSize(10, 10)
    button.arrow:SetPoint("RIGHT", -11, -1)
    button.arrow.lines = {}

    for index, offset in ipairs({ -2, 2 }) do
        local line = button.arrow:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetSize(7, 2)
        line:SetPoint("CENTER", offset, 0)
        line:SetRotation(index == 1 and math.rad(45) or math.rad(-45))
        button.arrow.lines[index] = line
    end

    function button:SetArrowColor(color)
        for _, line in ipairs(self.arrow.lines or {}) do
            line:SetVertexColor(Private.UnpackColor(color or Colors.muted))
        end
    end

    button:SetArrowColor(Colors.muted)

    function button:SetValue(text)
        self.valueText:SetText(text or "")
    end

    button:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(Private.UnpackColor(Colors.card))
        self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
        self:SetArrowColor(Colors.accent)
    end)
    button:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(Private.UnpackColor(Colors.cardSoft))
        self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
        self:SetArrowColor(Colors.muted)
    end)

    return button
end

function UI.CreateChoiceButton(parent, label, width, height)
    local button = UI.CreateButton(parent, label or "", width or 120, height or 28)

    function button:SetSelected(selected)
        self.selected = selected and true or false
        if self.selected then
            self:SetBackdropColor(Private.UnpackColor(Colors.accentBg))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
            self.text:SetTextColor(Private.UnpackColor(Colors.accent))
        else
            self:SetBackdropColor(Private.UnpackColor(Colors.cardSoft))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
            self.text:SetTextColor(Private.UnpackColor(Colors.text))
        end
    end

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            self:SetBackdropColor(Private.UnpackColor(Colors.card))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
            self.text:SetTextColor(1, 1, 1, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetSelected(self.selected)
    end)

    return button
end

function UI.SetButtonLabel(button, label)
    if button and button.text then
        button.text:SetText(label or "")
    end
end

function UI.CreateCloseButton(parent)
    local button = UI.CreateButton(parent, "X", 26, 26)
    button.text._yxsFontSize = 14
    button.text._yxsFontOutline = ""
    Private.ApplyStoredFont(button.text)
    button:SetBackdropColor(0.48, 0.12, 0.14, 1)
    button:SetBackdropBorderColor(0.68, 0.20, 0.22, 1)

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.68, 0.16, 0.18, 1)
        self:SetBackdropBorderColor(0.88, 0.26, 0.28, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.48, 0.12, 0.14, 1)
        self:SetBackdropBorderColor(0.68, 0.20, 0.22, 1)
    end)

    return button
end

function UI.CreateNavButton(parent, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height or 36)
    UI.CreateBackdrop(button, Colors.bg, Colors.bg)

    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetPoint("TOPLEFT", 1, -1)
    button.accent:SetPoint("BOTTOMLEFT", 1, 1)
    button.accent:SetWidth(3)
    button.accent:SetColorTexture(Private.UnpackColor(Colors.borderActive))
    button.accent:Hide()

    button.hover = button:CreateTexture(nil, "BACKGROUND")
    button.hover:SetPoint("TOPLEFT", 1, -1)
    button.hover:SetPoint("BOTTOMRIGHT", -1, 1)
    button.hover:SetColorTexture(Private.UnpackColor(Colors.cardSoft))
    button.hover:SetAlpha(0)

    button.text = UI.CreateText(button, 13)
    button.text:SetPoint("LEFT", 14, 0)
    button.text:SetPoint("RIGHT", -12, 0)
    button.text:SetJustifyV("MIDDLE")

    function button:SetSelected(selected)
        self.selected = selected and true or false
        self.accent:SetColorTexture(Private.UnpackColor(Colors.borderActive))
        if self.selected then
            self.accent:SetShown(true)
            self.hover:SetAlpha(1)
            self.hover:SetColorTexture(Private.UnpackColor(Colors.accentBg))
            self:SetBackdropColor(Private.UnpackColor(Colors.accentBg))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
            self.text:SetTextColor(Private.UnpackColor(Colors.accent))
        else
            self.accent:SetShown(false)
            self.hover:SetAlpha(0)
            self:SetBackdropColor(0, 0, 0, 0)
            self:SetBackdropBorderColor(0, 0, 0, 0)
            self.text:SetTextColor(Private.UnpackColor(Colors.text))
        end
    end

    function button:SetDisabled(disabled, tip)
        self.isDisabled = disabled and true or false
        self.disabledTip = tip
        if self.isDisabled then
            self:SetAlpha(0.45)
            if not self.selected then
                self.hover:SetAlpha(0)
                self:SetBackdropColor(0, 0, 0, 0)
                self:SetBackdropBorderColor(0, 0, 0, 0)
                self.text:SetTextColor(Private.UnpackColor(Colors.muted))
            end
        else
            self:SetAlpha(1)
            self:SetSelected(self.selected)
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.isDisabled then
            self.text:SetTextColor(Private.UnpackColor(Colors.muted))
            UI.ShowTooltip(self, self.disabledTip or "当前不可用")
            return
        end

        if not self.selected then
            self.hover:SetAlpha(1)
            self.hover:SetColorTexture(Private.UnpackColor(Colors.cardSoft))
            self:SetBackdropColor(Private.UnpackColor(Colors.cardSoft))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
            self.text:SetTextColor(1, 1, 1, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        UI.HideTooltip()
        self:SetSelected(self.selected)
    end)

    return button
end

function UI.CreateTabButton(parent)
    local button = UI.CreateButton(parent, "", 110, 28)

    function button:SetSelected(selected)
        self.selected = selected and true or false
        if self.selected then
            self:SetBackdropColor(Private.UnpackColor(Colors.accentBg))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
            self.text:SetTextColor(Private.UnpackColor(Colors.accent))
        else
            self:SetBackdropColor(Private.UnpackColor(Colors.cardSoft))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
            self.text:SetTextColor(Private.UnpackColor(Colors.text))
        end
    end

    function button:SetDisabled(disabled, tip)
        self.isDisabled = disabled and true or false
        self.disabledTip = tip
        if self.isDisabled then
            self:SetAlpha(self.selected and 0.75 or 0.45)
            if not self.selected then
                self.text:SetTextColor(Private.UnpackColor(Colors.muted))
            end
        else
            self:SetAlpha(1)
            self:SetSelected(self.selected)
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.isDisabled then
            UI.ShowTooltip(self, self.disabledTip or "当前不可用")
            return
        end

        if not self.selected then
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
            self.text:SetTextColor(1, 1, 1, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        UI.HideTooltip()
        self:SetSelected(self.selected)
    end)

    return button
end

--[[
布尔选项不用原生 CheckButton，而是做成更像现代设置页的滑动开关。
这样在视觉上更接近 YUI 的“统一皮肤控件”思路。
]]
function UI.CreateSwitch(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(54, 24)
    UI.CreateBackdrop(button, Colors.disabled, Colors.border)

    local thumb = CreateFrame("Frame", nil, button, "BackdropTemplate")
    thumb:SetSize(20, 20)
    thumb:SetPoint("LEFT", 2, 0)
    UI.CreateBackdrop(thumb, Colors.text, Colors.border)
    button.thumb = thumb

    function button:SetValue(value, disabled)
        self.value = value and true or false
        self.disabled = disabled and true or false

        if self.disabled then
            self:SetBackdropColor(Private.UnpackColor(Colors.disabled))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
            self.thumb:SetBackdropColor(0.55, 0.57, 0.62, 1)
            self.thumb:SetPoint("LEFT", self.value and 32 or 2, 0)
        elseif self.value then
            self:SetBackdropColor(Private.UnpackColor(Colors.success))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
            self.thumb:SetBackdropColor(0.95, 0.98, 0.95, 1)
            self.thumb:SetPoint("LEFT", 32, 0)
        else
            self:SetBackdropColor(Private.UnpackColor(Colors.card))
            self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
            self.thumb:SetBackdropColor(0.92, 0.92, 0.96, 1)
            self.thumb:SetPoint("LEFT", 2, 0)
        end
    end

    return button
end

function UI.CreateEditBox(parent, multiline)
    local editBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    UI.CreateBackdrop(editBox, Colors.cardSoft, Colors.border)
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(10, 10, 8, 8)
    editBox._yxsFontSize = 12
    editBox._yxsFontOutline = ""
    Private.ApplyStoredFont(editBox)
    editBox:SetTextColor(Private.UnpackColor(Colors.text))
    if editBox.SetCursorColor then
        editBox:SetCursorColor(Private.UnpackColor(Colors.accent))
    end

    if multiline then
        editBox:SetMultiLine(true)
        editBox:SetJustifyH("LEFT")
        editBox:SetJustifyV("TOP")
    else
        editBox:SetMultiLine(false)
        editBox:SetMaxLetters(0)
    end

    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
    end)

    return editBox
end

function UI.CreateSlider(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(28)

    local slider = CreateFrame("Slider", nil, container)
    slider:SetPoint("LEFT", 0, 0)
    slider:SetPoint("RIGHT", -76, 0)
    slider:SetHeight(22)
    slider:SetOrientation("HORIZONTAL")
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)
    slider:SetHitRectInsets(0, 0, -8, -8)

    local track = CreateFrame("Frame", nil, container, "BackdropTemplate")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(8)
    track:SetFrameLevel(math.max(slider:GetFrameLevel() - 1, 0))
    UI.CreateBackdrop(track, Colors.card, Colors.border)
    slider.track = track

    local trackFill = track:CreateTexture(nil, "BACKGROUND")
    trackFill:SetPoint("TOPLEFT", 1, -1)
    trackFill:SetPoint("BOTTOMRIGHT", -1, 1)
    trackFill:SetColorTexture(Private.UnpackColor(Colors.bg))
    slider.trackFill = trackFill

    -- 保留系统 slider 的可拖拽行为，只重绘外观。
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(10, 16)
    thumb:SetVertexColor(Private.UnpackColor(Colors.accent))
    slider.thumb = thumb

    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrame:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)
    thumbFrame:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)
    thumbFrame:EnableMouse(false)
    UI.CreateBackdrop(thumbFrame, { 0, 0, 0, 0 }, Colors.borderActive)
    thumbFrame:SetFrameLevel(slider:GetFrameLevel() + 1)
    slider.thumbFrame = thumbFrame

    -- 右侧附带一个数值输入框，方便精确输入。
    local valueBox = UI.CreateEditBox(container, false)
    valueBox:SetPoint("RIGHT", 0, 0)
    valueBox:SetSize(66, 26)
    valueBox:SetJustifyH("CENTER")
    valueBox:SetJustifyV("MIDDLE")
    container.valueBox = valueBox
    container.slider = slider

    return container
end

--[[
右上角的 QQ 入口需要一个“图标 + 文本”的紧凑按钮，
这里单独抽出来，避免把这种头部小控件的创建逻辑塞进 Layout。
]]
function UI.CreateIconTextButton(parent, iconPath, labelText)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(20)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTexture(iconPath)
    button.icon = icon

    local label = UI.CreateText(button, 12)
    label:SetPoint("LEFT", icon, "RIGHT", 6, -1)
    label:SetJustifyV("MIDDLE")
    label:SetText(labelText or "")
    label:SetTextColor(Private.UnpackColor(Colors.text))
    button.label = label

    local width = 16 + 6 + math.max(label:GetStringWidth(), 10)
    button:SetWidth(width)

    button:SetScript("OnEnter", function(self)
        self.label:SetTextColor(Private.UnpackColor(Colors.accent))
    end)
    button:SetScript("OnLeave", function(self)
        self.label:SetTextColor(Private.UnpackColor(Colors.text))
    end)

    return button
end

function UI.CreateDivider(parent, alpha)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(Private.UnpackColor(Colors.border))
    line:SetAlpha(alpha or 0.5)
    return line
end

--[[
自绘滚动条。

不再使用 UIPanelScrollFrameTemplate 自带的旧式滚动条，
而是统一换成窄轨道 + 金色滑块，视觉上会更贴近当前设置面板。
]]
function UI.AttachCustomScrollBar(scrollFrame, sliderParent, anchorTarget)
    local parent = sliderParent or scrollFrame:GetParent()
    local target = anchorTarget or scrollFrame
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(14)
    slider:SetPoint("TOPRIGHT", target, "TOPRIGHT", -2, -1)
    slider:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -2, 1)
    slider:SetMinMaxValues(0, 0)
    slider:SetValue(0)
    slider:SetValueStep(1)

    local track = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    track:SetWidth(8)
    track:SetFrameLevel(math.max(slider:GetFrameLevel() - 1, 0))
    UI.CreateBackdrop(track, Colors.card, Colors.border)
    slider.track = track

    local trackFill = track:CreateTexture(nil, "BACKGROUND")
    trackFill:SetPoint("TOPLEFT", 1, -1)
    trackFill:SetPoint("BOTTOMRIGHT", -1, 1)
    trackFill:SetColorTexture(Private.UnpackColor(Colors.bg))
    slider.trackFill = trackFill

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(6, 36)
    thumb:SetVertexColor(Private.UnpackColor(Colors.accent))
    slider.thumb = thumb

    local thumbFrame = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    thumbFrame:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)
    thumbFrame:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)
    thumbFrame:EnableMouse(false)
    UI.CreateBackdrop(thumbFrame, { 0, 0, 0, 0 }, Colors.borderActive)
    thumbFrame:SetFrameLevel(slider:GetFrameLevel() + 1)
    slider.thumbFrame = thumbFrame

    local syncing = false

    local function UpdateScrollBar()
        if not scrollFrame then
            return
        end

        thumb:SetVertexColor(Private.UnpackColor(Colors.accent))
        thumbFrame:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
        track:SetBackdropBorderColor(Private.UnpackColor(Colors.border))

        local range = scrollFrame:GetVerticalScrollRange() or 0
        slider:SetMinMaxValues(0, range)

        local value = math.min(scrollFrame:GetVerticalScroll() or 0, range)
        syncing = true
        slider:SetValue(value)
        syncing = false

        local ratio = 1
        local viewHeight = scrollFrame:GetHeight() or 0
        local child = scrollFrame:GetScrollChild()
        local childHeight = child and child:GetHeight() or 0
        if childHeight > 0 and viewHeight > 0 then
            ratio = math.max(0.18, math.min(1, viewHeight / childHeight))
        end
        thumb:SetHeight(math.max(28, (slider:GetHeight() or 0) * ratio))

        slider:SetShown(range > 0.5)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if syncing then
            return
        end
        scrollFrame:SetVerticalScroll(value)
    end)

    slider:SetScript("OnEnter", function()
        thumb:SetVertexColor(Private.UnpackColor(Private.MixColor(Colors.accent, { 1, 1, 1, 1 }, 0.18, 1)))
    end)
    slider:SetScript("OnLeave", function()
        thumb:SetVertexColor(Private.UnpackColor(Colors.accent))
    end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        if range <= 0 then
            return
        end

        local step = math.max(range / 12, 24)
        local nextValue = (self:GetVerticalScroll() or 0) - delta * step
        if nextValue < 0 then
            nextValue = 0
        elseif nextValue > range then
            nextValue = range
        end

        syncing = true
        self:SetVerticalScroll(nextValue)
        slider:SetValue(nextValue)
        syncing = false
    end)

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        if syncing then
            return
        end
        syncing = true
        slider:SetValue(offset)
        syncing = false
    end)

    scrollFrame:HookScript("OnShow", UpdateScrollBar)
    scrollFrame:HookScript("OnSizeChanged", UpdateScrollBar)
    scrollFrame:HookScript("OnScrollRangeChanged", UpdateScrollBar)

    slider.UpdateScrollBar = UpdateScrollBar
    scrollFrame._yxsScrollBar = slider

    return slider
end
