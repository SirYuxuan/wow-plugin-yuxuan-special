local _, NS = ...

local Options = NS.Options
local Private = Options.Private
local UI = Private.UI
local Colors = Private.Colors
local Sizes = Private.Sizes
local Constants = Private.Constants
local Meta = Private.Meta
local Assets = Private.Assets

--[[
这个文件负责“主窗口骨架和页面容器”。

也就是说：
1. 窗口长什么样、分成几块区域。
2. 左侧导航列表怎么摆。
3. 右侧标题栏和滚动容器怎么初始化。

真正把某个选项渲染成滑条/按钮/开关的逻辑，在 Renderer.lua。
]]

function Options:CaptureWindowPlacement()
    if not self.frame then
        return
    end

    self.windowPlacement = self.windowPlacement or {}
    self.windowPlacement.left = self.frame:GetLeft()
    self.windowPlacement.top = self.frame:GetTop()
    self.windowPlacement.width = self.frame:GetWidth()
    self.windowPlacement.height = self.frame:GetHeight()
end

function Options:RestoreWindowPlacement()
    if not self.frame or not self.windowPlacement then
        return
    end

    local placement = self.windowPlacement
    if placement.width and placement.height then
        self.frame:SetSize(placement.width, placement.height)
    end

    if placement.left and placement.top then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", placement.left, placement.top)
    end
end

--[[
用于 execute + confirm 的统一确认弹窗。
以后如果还要加“重置整套配置”“删除某组阈值”之类的危险操作，
都可以复用这个小窗，不需要各写一套 StaticPopup。
]]
function Options:ShowConfirm(text, onAccept)
    if not self.confirmFrame then
        local frame = CreateFrame("Frame", Constants.CONFIRM_NAME, UIParent, "BackdropTemplate")
        frame:SetSize(420, 180)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetFrameLevel(400)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        UI.CreateBackdrop(frame, Colors.panel, Colors.borderActive)
        UI.CreateShadow(frame)
        frame:Hide()

        local title = UI.CreateText(frame, 16, "OUTLINE")
        title:SetPoint("TOPLEFT", 18, -18)
        title:SetPoint("TOPRIGHT", -48, -18)
        title:SetText("确认操作")
        title:SetTextColor(Private.UnpackColor(Colors.accent))
        frame.title = title

        local closeButton = UI.CreateCloseButton(frame)
        closeButton:SetPoint("TOPRIGHT", -12, -12)
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        local desc = UI.CreateText(frame, 13)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
        desc:SetPoint("TOPRIGHT", -18, 0)
        desc:SetTextColor(Private.UnpackColor(Colors.text))
        frame.desc = desc

        local cancelButton = UI.CreateButton(frame, "取消", 110, 30)
        cancelButton:SetPoint("BOTTOMRIGHT", -18, 18)
        cancelButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        local confirmButton = UI.CreateButton(frame, "确认", 110, 30, "accent")
        confirmButton:SetPoint("RIGHT", cancelButton, "LEFT", -10, 0)
        confirmButton:SetScript("OnClick", function()
            local callback = frame.onAccept
            frame:Hide()
            if callback then
                callback()
            end
        end)

        self.confirmFrame = frame
    end

    self.confirmFrame.desc:SetText(text or "")
    self.confirmFrame.onAccept = onAccept
    self.confirmFrame:Show()
end

function Options:ShowCopyPopup(titleText, copyText)
    if not self.copyFrame then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(420, 132)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetFrameLevel(410)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        UI.CreateBackdrop(frame, Colors.panel, Colors.borderActive)
        UI.CreateShadow(frame)
        frame:Hide()

        local title = UI.CreateText(frame, 15, "OUTLINE")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetPoint("TOPRIGHT", -42, -16)
        title:SetTextColor(Private.UnpackColor(Colors.accent))
        frame.title = title

        local closeButton = UI.CreateCloseButton(frame)
        closeButton:SetPoint("TOPRIGHT", -10, -10)
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        local editBox = UI.CreateEditBox(frame, false)
        editBox:SetPoint("TOPLEFT", 16, -50)
        editBox:SetPoint("TOPRIGHT", -16, -50)
        editBox:SetHeight(32)
        editBox:SetJustifyH("CENTER")
        editBox:SetJustifyV("MIDDLE")
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            frame:Hide()
        end)
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            frame:Hide()
        end)
        frame.editBox = editBox

        local tip = UI.CreateText(frame, 11)
        tip:SetPoint("TOP", editBox, "BOTTOM", 0, -10)
        tip:SetJustifyH("CENTER")
        tip:SetText("按 Ctrl+C 复制群号")
        tip:SetTextColor(Private.UnpackColor(Colors.muted))

        self.copyFrame = frame
    end

    self.copyFrame.title:SetText(titleText or "")
    self.copyFrame.editBox:SetText(copyText or "")
    self.copyFrame.editBox:SetCursorPosition(0)
    self.copyFrame.editBox:HighlightText()
    self.copyFrame:Show()
    self.copyFrame.editBox:SetFocus()
end

function Options:UpdateBodyLayout(showSecondNav)
    if not (self.frame and self.frame.body and self.frame.detailPanel) then
        return
    end

    local detailPanel = self.frame.detailPanel
    detailPanel:ClearAllPoints()

    if showSecondNav and self.frame.secondNav then
        self.frame.secondNav:Show()
        if self.frame.secondNavDivider then
            self.frame.secondNavDivider:Show()
        end
        detailPanel:SetPoint("TOPLEFT", self.frame.secondNav, "TOPRIGHT", 12, 0)
    else
        if self.frame.secondNav then
            self.frame.secondNav:Hide()
        end
        if self.frame.secondNavDivider then
            self.frame.secondNavDivider:Hide()
        end
        detailPanel:SetPoint("TOPLEFT", self.frame.body, "TOPLEFT", 0, 0)
    end

    detailPanel:SetPoint("BOTTOMRIGHT", self.frame.body, "BOTTOMRIGHT", 0, 0)
end

function Options:CreateMainFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", Constants.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(Sizes.frameWidth, Sizes.frameHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(200)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    UI.CreateBackdrop(frame, Colors.bg, Colors.border)
    UI.CreateShadow(frame)
    frame:Hide()
    self.frame = frame

    table.insert(UISpecialFrames, Constants.FRAME_NAME)

    -- 标题拖拽层单独做出来，避免影响下面的按钮和滚动区域。
    local headerDrag = CreateFrame("Frame", nil, frame)
    headerDrag:SetPoint("TOPLEFT", 0, 0)
    headerDrag:SetPoint("TOPRIGHT", 0, 0)
    headerDrag:SetHeight(42)
    headerDrag:EnableMouse(true)
    headerDrag:RegisterForDrag("LeftButton")
    headerDrag:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    headerDrag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        Options:CaptureWindowPlacement()
    end)

    frame:SetScript("OnSizeChanged", function()
        Options:CaptureWindowPlacement()
    end)
    frame:SetScript("OnHide", function()
        Options:CaptureWindowPlacement()
    end)

    local nav = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", Sizes.gap, -Sizes.gap)
    nav:SetPoint("BOTTOMLEFT", Sizes.gap, Sizes.gap)
    nav:SetWidth(Sizes.navWidth)
    UI.CreateBackdrop(nav, Colors.bg, Colors.bg)
    frame.nav = nav

    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetWidth(1)
    sep:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, -8)
    sep:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 0, 8)
    sep:SetColorTexture(Private.UnpackColor(Colors.border))
    sep:SetAlpha(0.5)
    frame.navSeparator = sep

    local brandCard = CreateFrame("Frame", nil, nav, "BackdropTemplate")
    brandCard:SetPoint("TOPLEFT", 6, -8)
    brandCard:SetPoint("TOPRIGHT", -8, -8)
    brandCard:SetHeight(Sizes.brandHeight)
    UI.CreateBackdrop(brandCard, Colors.bg, Colors.bg)
    nav.brandCard = brandCard

    local brandTitle = UI.CreateText(brandCard, 15, "OUTLINE")
    brandTitle:SetPoint("TOPLEFT", 6, -8)
    brandTitle:SetPoint("TOPRIGHT", -6, -8)
    brandTitle:SetText("雨轩专业版插件")
    brandTitle:SetTextColor(Private.UnpackColor(Colors.text))

    local version = UI.CreateText(brandCard, 11)
    version:SetPoint("TOPLEFT", brandTitle, "BOTTOMLEFT", 0, -4)
    version:SetPoint("TOPRIGHT", -6, 0)
    version:SetText("版本号 " .. tostring(NS.VERSION or ""))
    version:SetTextColor(Private.UnpackColor(Colors.muted))

    local navDivider = UI.CreateDivider(nav, 0.45)
    navDivider:SetPoint("TOPLEFT", brandCard, "BOTTOMLEFT", 0, -8)
    navDivider:SetPoint("TOPRIGHT", brandCard, "BOTTOMRIGHT", 0, -8)

    local navScroll = CreateFrame("ScrollFrame", nil, nav)
    navScroll:SetPoint("TOPLEFT", 0, -78)
    navScroll:SetPoint("BOTTOMRIGHT", -16, 8)
    nav.navScroll = navScroll

    local navChild = CreateFrame("Frame", nil, navScroll)
    navChild:SetSize(Sizes.navWidth - 24, 1)
    navScroll:SetScrollChild(navChild)
    nav.navChild = navChild
    nav.navScrollBar = UI.AttachCustomScrollBar(navScroll, nav, navScroll)
    navChild:HookScript("OnSizeChanged", function()
        if nav.navScrollBar and nav.navScrollBar.UpdateScrollBar then
            nav.navScrollBar:UpdateScrollBar()
        end
    end)

    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", Sizes.gap, 0)
    content:SetPoint("BOTTOMRIGHT", -Sizes.gap, Sizes.gap)
    UI.CreateBackdrop(content, Colors.bg, Colors.bg)
    frame.content = content

    local header = CreateFrame("Frame", nil, content)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(Sizes.headerHeight)
    frame.header = header

    local title = UI.CreateText(header, 15, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetPoint("TOPRIGHT", -220, -10)
    title:SetText(NS.DISPLAY_NAME)
    header.title = title

    local breadcrumb = UI.CreateText(header, 11)
    breadcrumb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    breadcrumb:SetPoint("TOPRIGHT", -220, 0)
    breadcrumb:SetTextColor(Private.UnpackColor(Colors.muted))
    header.breadcrumb = breadcrumb

    local qqButton = UI.CreateIconTextButton(
        header,
        Assets.qqIcon,
        "QQ群 " .. Meta.qqGroup
    )
    qqButton:SetPoint("RIGHT", -48, 0)
    qqButton:SetScript("OnClick", function()
        Options:ShowCopyPopup("复制 QQ 群号", Meta.qqGroup)
    end)
    header.qqButton = qqButton

    local closeButton = UI.CreateCloseButton(header)
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 12)
    closeButton:SetScript("OnClick", function()
        Options:Close()
    end)
    frame.closeButton = closeButton

    local headerLine = UI.CreateDivider(header, 0.5)
    headerLine:SetPoint("BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.headerLine = headerLine

    local body = CreateFrame("Frame", nil, content)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    body:SetPoint("BOTTOMRIGHT", 0, 8)
    frame.body = body

    local secondNav = CreateFrame("Frame", nil, body, "BackdropTemplate")
    secondNav:SetPoint("TOPLEFT", 0, 0)
    secondNav:SetPoint("BOTTOMLEFT", 0, 0)
    secondNav:SetWidth(Sizes.secondNavWidth)
    UI.CreateBackdrop(secondNav, Colors.bg, Colors.bg)
    secondNav:Hide()
    frame.secondNav = secondNav

    local secondNavScroll = CreateFrame("ScrollFrame", nil, secondNav)
    secondNavScroll:SetPoint("TOPLEFT", 0, -2)
    secondNavScroll:SetPoint("BOTTOMRIGHT", -14, 2)
    secondNav.scrollFrame = secondNavScroll

    local secondNavChild = CreateFrame("Frame", nil, secondNavScroll)
    secondNavChild:SetSize(Sizes.secondNavWidth - 22, 1)
    secondNavScroll:SetScrollChild(secondNavChild)
    secondNav.navChild = secondNavChild
    secondNav.scrollBar = UI.AttachCustomScrollBar(secondNavScroll, secondNav, secondNavScroll)
    secondNavChild:HookScript("OnSizeChanged", function()
        if secondNav.scrollBar and secondNav.scrollBar.UpdateScrollBar then
            secondNav.scrollBar:UpdateScrollBar()
        end
    end)

    local secondNavDivider = content:CreateTexture(nil, "ARTWORK")
    secondNavDivider:SetWidth(1)
    secondNavDivider:SetColorTexture(Private.UnpackColor(Colors.border))
    secondNavDivider:SetAlpha(0.5)
    secondNavDivider:SetPoint("TOPLEFT", secondNav, "TOPRIGHT", 6, 0)
    secondNavDivider:SetPoint("BOTTOMLEFT", secondNav, "BOTTOMRIGHT", 6, 0)
    secondNavDivider:Hide()
    frame.secondNavDivider = secondNavDivider

    local detailPanel = CreateFrame("Frame", nil, body, "BackdropTemplate")
    UI.CreateBackdrop(detailPanel, Colors.bg, Colors.bg)
    frame.detailPanel = detailPanel

    local scrollFrame = CreateFrame("ScrollFrame", nil, detailPanel)
    scrollFrame:SetPoint("TOPLEFT", Sizes.contentInset, -Sizes.contentInset)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(16 + Sizes.contentInset), Sizes.contentInset)
    frame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild
    frame.scrollBar = UI.AttachCustomScrollBar(scrollFrame, detailPanel, scrollFrame)
    scrollChild:HookScript("OnSizeChanged", function()
        if frame.scrollBar and frame.scrollBar.UpdateScrollBar then
            frame.scrollBar:UpdateScrollBar()
        end
    end)

    self:UpdateBodyLayout(false)
end

function Options:RefreshNavigation()
    if not (self.frame and self.frame.nav and self.frame.nav.navChild) then
        return
    end

    local navChild = self.frame.nav.navChild
    local entries = self:GetTopGroups()
    local yOffset = -2

    for index, entry in ipairs(entries) do
        local button = self.navButtons[index]
        if not button then
            button = UI.CreateNavButton(navChild, Sizes.navWidth - 18, 36)
            self.navButtons[index] = button
        end

        local entryKey = entry.key
        local entryName = Private.ResolveText(entry.value.name, entry.key)
        local isDisabled = Private.IsDisabled(entry.value)
        local disabledTip = Private.GetDisabledTip(entry.value, "当前模块暂时不可用")

        button:Show()
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, yOffset)
        button.text:SetText(entryName)
        button:SetSelected(entryKey == self.selectedTopKey)
        button:SetDisabled(isDisabled, disabledTip)
        button:SetScript("OnClick", function()
            if isDisabled then
                return
            end
            self.selectedTopKey = entryKey
            self:Render()
        end)

        yOffset = yOffset - 38
    end

    for index = #entries + 1, #self.navButtons do
        self.navButtons[index]:Hide()
    end

    navChild:SetHeight(math.max(-yOffset + 8, 1))
end

function Options:UpdateSecondaryNavigation(entries, path)
    if not (self.frame and self.frame.secondNav and self.frame.secondNav.navChild) then
        return
    end

    local secondNav = self.frame.secondNav
    local navChild = secondNav.navChild
    local children = { navChild:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    if not entries or #entries == 0 then
        self:UpdateBodyLayout(false)
        return
    end

    self:UpdateBodyLayout(true)

    local pathKey = Private.PathKey(path)
    local selectedKey = self.selectedChildren[pathKey]
    local validSelection = false

    for _, entry in ipairs(entries) do
        if entry.key == selectedKey then
            validSelection = true
            break
        end
    end

    if not validSelection then
        selectedKey = entries[1].key
        self.selectedChildren[pathKey] = selectedKey
    end

    local yOffset = -2
    for _, entry in ipairs(entries) do
        local entryKey = entry.key
        local label = Private.ResolveText(entry.value.name, entry.key)
        local isDisabled = Private.IsDisabled(entry.value)
        local disabledTip = Private.GetDisabledTip(entry.value, "当前模块暂时不可用")
        local button = UI.CreateNavButton(navChild, Sizes.secondNavWidth - 22, 30)
        UI.SetButtonLabel(button, label)
        button:SetPoint("TOPLEFT", 0, yOffset)
        button:SetSelected(entryKey == selectedKey)
        button:SetDisabled(isDisabled, disabledTip)
        button:SetScript("OnClick", function()
            if isDisabled then
                return
            end
            self.selectedChildren[pathKey] = entryKey
            self:Render()
        end)

        yOffset = yOffset - 32
    end

    navChild:SetHeight(math.max(-yOffset + 6, 1))
    if secondNav.scrollBar and secondNav.scrollBar.UpdateScrollBar then
        secondNav.scrollBar:UpdateScrollBar()
    end
end

function Options:UpdateHeader(title, breadcrumb)
    if not (self.frame and self.frame.header) then
        return
    end

    self.frame.header.title:SetText(title or NS.DISPLAY_NAME)
    self.frame.header.breadcrumb:SetText(breadcrumb or "")
    if self.frame.header.qqButton then
        self.frame.header.qqButton:SetPoint("RIGHT", self.frame.closeButton, "LEFT", -14, -1)
    end
end

function Options:ClearScrollContent()
    if not (self.frame and self.frame.scrollChild) then
        return
    end

    local children = { self.frame.scrollChild:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    local regions = { self.frame.scrollChild:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType then
            local objectType = region:GetObjectType()
            if objectType == "FontString" or objectType == "Texture" then
                region:Hide()
                region:SetParent(nil)
            end
        end
    end
end

function Options:GetScrollWidth()
    if not (self.frame and self.frame.detailPanel) then
        return 720
    end

    local width = self.frame.detailPanel:GetWidth() - (32 + Sizes.contentInset * 2)
    if width < 420 then
        width = 420
    end
    return width
end

function Options:CreateCard(parent, top, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 0, top)
    local width = (parent and parent.GetWidth and parent:GetWidth()) or 0
    if width < 64 then
        width = self:GetScrollWidth()
    end
    card:SetWidth(width)
    card:SetHeight(height)
    UI.CreateBackdrop(card, Colors.cardSoft, Colors.cardSoft)
    return card
end

function Options:CreateSection(parent, top, height)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", 0, top)
    local width = (parent and parent.GetWidth and parent:GetWidth()) or 0
    if width < 64 then
        width = self:GetScrollWidth()
    end
    section:SetWidth(width)
    section:SetHeight(height or 10)
    return section
end
