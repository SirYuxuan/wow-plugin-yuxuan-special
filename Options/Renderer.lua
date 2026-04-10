local _, NS = ...

local Options = NS.Options
local Private = Options.Private
local UI = Private.UI
local Colors = Private.Colors
local Sizes = Private.Sizes
local Meta = Private.Meta
local Assets = Private.Assets

local function GetParentContentWidth(self, parent)
    local width = (parent and parent.GetWidth and parent:GetWidth()) or 0
    if width < 64 then
        width = self:GetScrollWidth()
    end
    return width
end

local function CreateDisabledPlaceholderGroup(message)
    return {
        type = "group",
        args = {
            tip = {
                type = "description",
                order = 1,
                fontSize = "medium",
                name = message or "当前选项暂时不可用",
            },
        },
    }
end

local function NormalizeColorPayload(valueR, valueG, valueB, valueA)
    if type(valueR) == "table" then
        local payload = valueR
        local alpha = payload.a
        if alpha == nil then
            alpha = payload.alpha
        end
        if alpha == nil and payload.opacity ~= nil then
            alpha = 1 - (tonumber(payload.opacity) or 0)
        end

        return tonumber(payload.r or payload.red or payload[1]), tonumber(payload.g or payload.green or payload[2]),
            tonumber(payload.b or payload.blue or payload[3]), tonumber(alpha or payload[4])
    end

    return tonumber(valueR), tonumber(valueG), tonumber(valueB), tonumber(valueA)
end

--[[
这个文件负责把 options table 真正画到屏幕上。

可以把它理解成一个“轻量渲染器”：
1. 读取各模块返回的 group / toggle / range / select 等描述。
2. 转换成我们自己的卡片式界面。
3. 把用户点击和输入再写回原来的 get/set/func 逻辑。

这样做的好处是：
模块层继续只关心“配置项定义”，
渲染层只关心“界面怎么画”，职责会很清楚。
]]

function Options:ApplyPathSelection(path)
    local topGroups = self:GetTopGroups()
    if not self.selectedTopKey then
        self.selectedTopKey = topGroups[1] and topGroups[1].key or nil
    end

    if #path == 0 then
        return
    end

    local root = self.rootOptions or self:GetRootOptions()
    local selectedTop = root and root.args and root.args[path[1]]
    if not selectedTop then
        return
    end

    self.selectedTopKey = path[1]

    local currentGroup = selectedTop
    local currentPath = { path[1] }

    for index = 2, #path do
        local key = path[index]
        if currentGroup and currentGroup.args and currentGroup.args[key] and currentGroup.args[key].type == "group" then
            self.selectedChildren[Private.PathKey(currentPath)] = key
            currentGroup = currentGroup.args[key]
            currentPath[#currentPath + 1] = key
        else
            break
        end
    end
end

function Options:GetSelectedTopGroup()
    local root = self.rootOptions or self:GetRootOptions()
    if not self.selectedTopKey then
        local groups = self:GetTopGroups()
        self.selectedTopKey = groups[1] and groups[1].key or nil
    end

    return root.args and root.args[self.selectedTopKey], self.selectedTopKey
end

function Options:RenderDescription(parent, option, top, isHeader)
    local textValue = Private.ResolveText(option.name)
    if Private.TrimText(textValue) == "" then
        return 12
    end

    local fontSize = isHeader and 15 or (option.fontSize == "medium" and 12 or 11)
    local text = UI.CreateText(parent, fontSize, isHeader and "OUTLINE" or "")
    text:SetPoint("TOPLEFT", 0, top)
    text:SetWidth(GetParentContentWidth(self, parent))
    text:SetText(textValue)

    if isHeader then
        text:SetTextColor(Private.UnpackColor(Colors.accent))
    else
        text:SetTextColor(Private.UnpackColor(Colors.text))
    end

    return text:GetStringHeight() + (isHeader and 8 or 4)
end

function Options:RenderLanding(parent, option, top)
    local width = GetParentContentWidth(self, parent)
    local shortcuts = option.shortcuts or {}
    local newsItems = option.newsItems or {}
    local startTop = top
    local yOffset = top
    local sectionGap = 14
    local heroHeight = 114

    local hero = self:CreateCard(parent, yOffset, heroHeight)
    hero:SetBackdropColor(Private.UnpackColor(Private.MixColor(Colors.panel, Colors.accentBg, 0.16, 0.98)))
    hero:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
    UI.CreateShadow(hero)

    local heroGlow = hero:CreateTexture(nil, "BACKGROUND")
    heroGlow:SetPoint("TOPLEFT", 1, -1)
    heroGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    if heroGlow.SetGradientAlpha then
        local accent = Colors.accent
        heroGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
        heroGlow:SetGradientAlpha(
            "HORIZONTAL",
            accent[1] or 1,
            accent[2] or 1,
            accent[3] or 1,
            0.28,
            0.08,
            0.10,
            0.14,
            0.04
        )
    else
        heroGlow:SetColorTexture(Private.UnpackColor(Private.MixColor(Colors.accentBg, Colors.bg, 0.3, 0.28)))
    end

    local heroShade = hero:CreateTexture(nil, "BORDER")
    heroShade:SetPoint("TOPLEFT", 0, 0)
    heroShade:SetPoint("BOTTOMRIGHT", 0, 0)
    if heroShade.SetGradientAlpha then
        heroShade:SetTexture("Interface\\Buttons\\WHITE8x8")
        heroShade:SetGradientAlpha("VERTICAL", 0.02, 0.03, 0.05, 0.00, 0.00, 0.00, 0.00, 0.34)
    else
        heroShade:SetColorTexture(0.02, 0.03, 0.05, 0.18)
    end

    local heroAccent = hero:CreateTexture(nil, "ARTWORK")
    heroAccent:SetPoint("TOPLEFT", 0, 0)
    heroAccent:SetPoint("BOTTOMLEFT", 0, 0)
    heroAccent:SetWidth(6)
    heroAccent:SetColorTexture(Private.UnpackColor(Colors.borderActive))

    local title = UI.CreateText(hero, 26, "OUTLINE")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetPoint("TOPRIGHT", -20, -20)
    title:SetText(Private.ResolveText(option.title, "雨轩工具箱"))

    local summary = UI.CreateText(hero, 12)
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    summary:SetPoint("TOPRIGHT", -20, 0)
    summary:SetText(Private.ResolveText(option.summary))
    summary:SetTextColor(Private.UnpackColor(Colors.text))

    yOffset = yOffset - heroHeight - sectionGap

    local shortcutsTitle = UI.CreateText(parent, 15, "OUTLINE")
    shortcutsTitle:SetPoint("TOPLEFT", 0, yOffset)
    shortcutsTitle:SetText(Private.ResolveText(option.shortcutsTitle, "快捷入口"))
    shortcutsTitle:SetTextColor(Private.UnpackColor(Colors.accent))
    yOffset = yOffset - 10

    local shortcutsDesc = UI.CreateText(parent, 11)
    shortcutsDesc:SetPoint("TOPLEFT", shortcutsTitle, "BOTTOMLEFT", 0, -4)
    shortcutsDesc:SetWidth(width)
    shortcutsDesc:SetText("把高频页面和更新入口都放在这里，开窗后可以直接跳过去。")
    shortcutsDesc:SetTextColor(Private.UnpackColor(Colors.muted))
    yOffset = yOffset - 28

    local columns = 2
    local gap = 12
    local cardWidth = math.floor((width - gap) / columns)
    local cardHeight = 128

    for index, shortcut in ipairs(shortcuts) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        card:SetPoint("TOPLEFT", column * (cardWidth + gap), yOffset - row * (cardHeight + gap))
        card:SetSize(cardWidth, cardHeight)
        UI.CreateBackdrop(
            card,
            Private.MixColor(Colors.cardSoft, Colors.accentBg, 0.08 + ((index % 3) * 0.04), 0.95),
            index % 2 == 0 and (Colors.borderSoft or Colors.border) or Colors.borderActive
        )

        local cornerGlow = card:CreateTexture(nil, "BACKGROUND")
        cornerGlow:SetPoint("TOPRIGHT", -2, -2)
        cornerGlow:SetSize(math.floor(cardWidth * 0.42), 44)
        if cornerGlow.SetGradientAlpha then
            local accent = Colors.accent
            cornerGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
            cornerGlow:SetGradientAlpha(
                "HORIZONTAL",
                accent[1] or 1,
                accent[2] or 1,
                accent[3] or 1,
                0.16,
                accent[1] or 1,
                accent[2] or 1,
                accent[3] or 1,
                0.00
            )
        else
            cornerGlow:SetColorTexture(Private.UnpackColor(Private.MixColor(Colors.accentBg, Colors.bg, 0.16, 0.14)))
        end

        local stripe = card:CreateTexture(nil, "ARTWORK")
        stripe:SetPoint("TOPLEFT", 0, 0)
        stripe:SetPoint("TOPRIGHT", 0, 0)
        stripe:SetHeight(3)
        stripe:SetColorTexture(
            Private.UnpackColor(index % 2 == 0 and Private.MixColor(Colors.accent, Colors.text, 0.24, 1) or Colors.accent)
        )

        local number = UI.CreateText(card, 20, "OUTLINE")
        number:SetPoint("TOPRIGHT", -14, -10)
        number:SetText(string.format("%02d", index))
        number:SetTextColor(Private.UnpackColor(Private.MixColor(Colors.accent, Colors.text, 0.45, 0.46)))

        local cardTitle = UI.CreateText(card, 14, "OUTLINE")
        cardTitle:SetPoint("TOPLEFT", 14, -14)
        cardTitle:SetPoint("TOPRIGHT", number, "TOPLEFT", -8, 0)
        cardTitle:SetText(tostring(shortcut.title or ""))
        cardTitle:SetTextColor(Private.UnpackColor(Colors.text))

        local cardDesc = UI.CreateText(card, 11)
        cardDesc:SetPoint("TOPLEFT", cardTitle, "BOTTOMLEFT", 0, -8)
        cardDesc:SetPoint("TOPRIGHT", -14, 0)
        cardDesc:SetText(tostring(shortcut.desc or ""))
        cardDesc:SetTextColor(Private.UnpackColor(Colors.muted))

        local button = UI.CreateButton(card, tostring(shortcut.buttonText or "进入"), 110, 28, "accent")
        button:SetPoint("BOTTOMLEFT", 14, 14)
        button:SetScript("OnClick", function()
            if type(shortcut.action) == "function" then
                shortcut.action()
                return
            end

            if type(shortcut.path) == "table" and NS.Options and NS.Options.Open then
                NS.Options:Open(unpack(shortcut.path))
            end
        end)

        if shortcut.meta and shortcut.meta ~= "" then
            local meta = UI.CreateText(card, 11)
            meta:SetPoint("RIGHT", -14, 0)
            meta:SetPoint("BOTTOM", button, "TOP", 0, 10)
            meta:SetJustifyH("RIGHT")
            meta:SetText(tostring(shortcut.meta))
            meta:SetTextColor(Private.UnpackColor(Colors.accent))
        end
    end

    local shortcutRows = math.max(1, math.ceil(#shortcuts / columns))
    yOffset = yOffset - (shortcutRows * (cardHeight + gap)) - sectionGap

    local lowerGap = 12
    local lowerWidth = math.floor((width - lowerGap) / 2)
    local lowerHeight = 170

    local updateCard = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    updateCard:SetPoint("TOPLEFT", 0, yOffset)
    updateCard:SetSize(lowerWidth, lowerHeight)
    UI.CreateBackdrop(
        updateCard,
        Private.MixColor(Colors.cardSoft, Colors.accentBg, 0.14, 0.96),
        Private.MixColor(Colors.border, Colors.accent, 0.20, 1)
    )
    updateCard:SetBackdropColor(Private.UnpackColor(Private.MixColor(Colors.cardSoft, Colors.accentBg, 0.14, 0.96)))
    updateCard:SetBackdropBorderColor(Private.UnpackColor(Private.MixColor(Colors.border, Colors.accent, 0.20, 1)))

    local updateTitle = UI.CreateText(updateCard, 14, "OUTLINE")
    updateTitle:SetPoint("TOPLEFT", 14, -14)
    updateTitle:SetPoint("TOPRIGHT", -14, -14)
    updateTitle:SetText(Private.ResolveText(option.newsTitle, "本次更新"))
    updateTitle:SetTextColor(Private.UnpackColor(Colors.accent))

    local updateBadge = UI.CreateText(updateCard, 10)
    updateBadge:SetPoint("TOPRIGHT", -14, -17)
    updateBadge:SetText("最近整理")
    updateBadge:SetTextColor(Private.UnpackColor(Colors.muted))

    local newsTop = -46
    for index, item in ipairs(newsItems) do
        local dot = updateCard:CreateTexture(nil, "ARTWORK")
        dot:SetPoint("TOPLEFT", 16, newsTop - (index - 1) * 32)
        dot:SetSize(6, 6)
        dot:SetColorTexture(Private.UnpackColor(Colors.accent))

        if index < #newsItems then
            local line = updateCard:CreateTexture(nil, "ARTWORK")
            line:SetPoint("TOPLEFT", 18, newsTop - 9 - (index - 1) * 32)
            line:SetSize(2, 22)
            line:SetColorTexture(Private.UnpackColor(Private.MixColor(Colors.border, Colors.accent, 0.25, 0.90)))
        end

        local bullet = UI.CreateText(updateCard, 11)
        bullet:SetPoint("TOPLEFT", 30, newsTop + 4 - (index - 1) * 32)
        bullet:SetWidth(lowerWidth - 44)
        bullet:SetText(tostring(item))
        bullet:SetTextColor(Private.UnpackColor(Colors.text))
    end

    local helpWidth = width - lowerWidth - lowerGap
    local helpCard = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    helpCard:SetPoint("TOPLEFT", lowerWidth + lowerGap, yOffset)
    helpCard:SetSize(helpWidth, lowerHeight)
    UI.CreateBackdrop(
        helpCard,
        Private.MixColor(Colors.cardSoft, Colors.panel, 0.18, 0.96),
        Private.MixColor(Colors.border, Colors.accent, 0.12, 1)
    )

    local helpTitle = UI.CreateText(helpCard, 14, "OUTLINE")
    helpTitle:SetPoint("TOPLEFT", 14, -14)
    helpTitle:SetPoint("TOPRIGHT", -14, -14)
    helpTitle:SetText("常用命令")
    helpTitle:SetTextColor(Private.UnpackColor(Colors.accent))

    local helpLines = {
        "/yxs 打开设置窗口",
        "/yxs log 打开更新记录",
        "轻量功能建议可以直接到群里反馈",
    }

    for index, lineText in ipairs(helpLines) do
        local line = UI.CreateText(helpCard, 11)
        line:SetPoint("TOPLEFT", 16, -42 - (index - 1) * 24)
        line:SetPoint("TOPRIGHT", -16, -42 - (index - 1) * 24)
        line:SetText(lineText)
        line:SetTextColor(Private.UnpackColor(index == 3 and Colors.muted or Colors.text))
    end

    local qqIcon = helpCard:CreateTexture(nil, "ARTWORK")
    qqIcon:SetPoint("BOTTOMLEFT", 16, 50)
    qqIcon:SetSize(20, 20)
    qqIcon:SetTexture((Assets and Assets.qqIcon) or "Interface\\Buttons\\WHITE8x8")

    local qqLabel = UI.CreateText(helpCard, 11)
    qqLabel:SetPoint("LEFT", qqIcon, "RIGHT", 8, 0)
    qqLabel:SetWidth(math.max(68, helpWidth - 54))
    qqLabel:SetJustifyV("MIDDLE")
    qqLabel:SetText("QQ 群 " .. tostring(Meta and Meta.qqGroup or ""))
    qqLabel:SetTextColor(Private.UnpackColor(Colors.text))

    local copyButton = UI.CreateButton(helpCard, "复制群号", math.min(110, math.max(92, helpWidth - 32)), 28, "accent")
    copyButton:SetPoint("BOTTOMLEFT", 16, 14)
    copyButton:SetScript("OnClick", function()
        self:ShowCopyPopup("复制 QQ 群号", tostring(Meta and Meta.qqGroup or ""))
    end)

    yOffset = yOffset - lowerHeight - 8
    return startTop - yOffset
end

function Options:RenderToggle(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 58 or 42
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -88, -10)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -88, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local disabled = Private.IsDisabled(option)
    local value = Private.IsTruthy(Private.GetOptionValue(option))

    local switch = UI.CreateSwitch(row)
    switch:SetPoint("RIGHT", -12, 0)
    switch:SetValue(value, disabled)
    switch:SetScript("OnClick", function()
        if Private.IsDisabled(option) then
            return
        end

        Private.SetOptionValue(option, not Private.IsTruthy(Private.GetOptionValue(option)))
        self:NotifyChanged()
    end)

    if disabled then
        title:SetTextColor(Private.UnpackColor(Colors.muted))
        row:SetAlpha(0.65)
    end

    return height + Sizes.rowGap
end

function Options:RenderExecute(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 60 or 44
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -152, -10)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -152, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local disabled = Private.IsDisabled(option)
    local button = UI.CreateButton(row, Private.ResolveText(option.name), 128, 28, "accent")
    button:SetPoint("RIGHT", -12, 0)
    button:SetEnabled(not disabled)
    if disabled then
        button:SetAlpha(0.45)
        row:SetAlpha(0.65)
    end

    button:SetScript("OnClick", function()
        if Private.IsDisabled(option) then
            return
        end

        local run = function()
            Private.RunOption(option)
            self:NotifyChanged()
        end

        if option.confirm then
            self:ShowConfirm(Private.ResolveText(option.confirmText, "确认执行这个操作吗？"), run)
        else
            run()
        end
    end)

    return height + Sizes.rowGap
end

function Options:RenderRange(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 84 or 70
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -12, -10)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -12, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local sliderHolder = UI.CreateSlider(row)
    sliderHolder:SetPoint("BOTTOMLEFT", 12, 12)
    sliderHolder:SetPoint("BOTTOMRIGHT", -12, 12)

    local slider = sliderHolder.slider
    local minValue = tonumber(option.min) or 0
    local maxValue = tonumber(option.max) or 100
    local step = tonumber(option.step) or 1
    local disabled = Private.IsDisabled(option)
    local settingValue = tonumber(Private.GetOptionValue(option)) or minValue

    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetValue(settingValue)
    sliderHolder.valueBox:SetText(Private.FormatNumber(settingValue, step))

    -- 防止 slider 改值时又回写 editBox，形成重复联动。
    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        if updating then
            return
        end

        updating = true
        sliderHolder.valueBox:SetText(Private.FormatNumber(value, step))
        Private.SetOptionValue(option, value)
        updating = false
    end)
    slider:SetScript("OnMouseUp", function()
        self:NotifyChanged()
    end)

    sliderHolder.valueBox:SetScript("OnEnterPressed", function(editBox)
        local value = tonumber(editBox:GetText())
        if value then
            if value < minValue then
                value = minValue
            elseif value > maxValue then
                value = maxValue
            end
            slider:SetValue(value)
            Private.SetOptionValue(option, value)
            self:NotifyChanged()
        else
            editBox:SetText(Private.FormatNumber(slider:GetValue(), step))
        end
        editBox:ClearFocus()
    end)
    sliderHolder.valueBox:SetScript("OnEscapePressed", function(editBox)
        editBox:SetText(Private.FormatNumber(slider:GetValue(), step))
        editBox:ClearFocus()
    end)

    if disabled then
        row:SetAlpha(0.60)
        slider:EnableMouse(false)
        sliderHolder.valueBox:EnableMouse(false)
        sliderHolder.valueBox:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    return height + Sizes.rowGap
end

local function GetInlineOptionUnits(option)
    if option.width == "full" then
        return 3
    end

    local width = tonumber(option.width)
    if width and width > 0 then
        return width
    end

    return 1
end

local function GetInlineOptionMinWidth(option)
    if option.type == "execute" then
        return 92
    end
    if option.type == "select" then
        return 160
    end
    if option.type == "input" then
        return 180
    end
    if option.type == "toggle" then
        return 140
    end
    if option.type == "color" then
        return 170
    end
    if option.type == "range" then
        return 200
    end

    return 180
end

local function GetInlineOptionContentHeight(option)
    if option.type == "range" then
        return 28
    end
    return 28
end

function Options:BindSelectDropdown(button, option, values)
    button:SetScript("OnMouseDown", function(anchor)
        local dropdown = Private.EnsureDropdownHelper()
        local levelOneList = _G["DropDownList1"]
        local isOpenForAnchor = dropdown
            and (
                anchor._yxsDropdownOpen
                or (dropdown._yxsAnchor == anchor and levelOneList and levelOneList:IsShown())
            )

        if isOpenForAnchor then
            anchor._yxsSuppressNextDropdownOpen = true
            anchor._yxsDropdownOpen = nil
            CloseDropDownMenus()
            if dropdown._yxsClearState then
                dropdown:_yxsClearState()
            else
                dropdown._yxsAnchor = nil
                dropdown._yxsIsOpen = nil
            end
        end
    end)

    button:SetScript("OnClick", function(anchor)
        if Private.IsDisabled(option) then
            return
        end
        if anchor._yxsSuppressNextDropdownOpen then
            anchor._yxsSuppressNextDropdownOpen = nil
            return
        end

        local menu = {}
        for _, entry in ipairs(values) do
            local entryValue = entry.value
            local entryLabel = entry.label
            menu[#menu + 1] = {
                text = entryLabel,
                checked = entryValue == Private.GetOptionValue(option),
                func = function()
                    Private.SetOptionValue(option, entryValue)
                    self:NotifyChanged()
                end,
            }
        end

        Private.ShowDropdownMenu(anchor, menu)
    end)
end

function Options:RenderSelect(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 60 or 44
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -196, -10)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -196, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local disabled = Private.IsDisabled(option)
    local currentValue = Private.GetOptionValue(option)
    local values = Private.NormalizeDropdownValues(option.values)
    local currentLabel = tostring(currentValue or "")

    for _, entry in ipairs(values) do
        if entry.value == currentValue then
            currentLabel = entry.label
            break
        end
    end

    local button = UI.CreateDropdownButton(row, 176, 28)
    button:SetPoint("RIGHT", -12, 0)
    button:SetValue(currentLabel)
    button:SetEnabled(not disabled)

    if disabled then
        row:SetAlpha(0.60)
        button:SetAlpha(0.45)
    end

    self:BindSelectDropdown(button, option, values)

    return height + Sizes.rowGap
end

function Options:RenderRadio(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local compact = option.compact and true or false
    local height
    if compact then
        height = 44
    else
        height = Private.TrimText(descText) ~= "" and 82 or 66
    end
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    if compact then
        title:SetPoint("LEFT", 12, 0)
        title:SetPoint("RIGHT", -220, 0)
        title:SetJustifyV("MIDDLE")
    else
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetPoint("TOPRIGHT", -12, -10)
    end
    title:SetText(Private.ResolveText(option.name))

    if not compact and Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -12, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local values = Private.NormalizeDropdownValues(option.values)
    local currentValue = Private.GetOptionValue(option)
    local disabled = Private.IsDisabled(option)
    local gap = 8
    local buttonWidth = option.buttonWidth or 96
    local xOffset = 12
    local totalWidth = 0

    if compact then
        local rowWidth = math.max(320, GetParentContentWidth(self, row))
        totalWidth = (#values * buttonWidth) + math.max(0, (#values - 1) * gap)
        xOffset = math.max(12, rowWidth - totalWidth - 12)
        title:ClearAllPoints()
        title:SetPoint("LEFT", 12, 0)
        title:SetPoint("RIGHT", -(totalWidth + 24), 0)
        title:SetJustifyV("MIDDLE")
    else
        local availableWidth = math.max(220, GetParentContentWidth(self, row) - 24)
        buttonWidth = math.floor((availableWidth - math.max(0, (#values - 1) * gap)) / math.max(#values, 1))
    end

    for _, entry in ipairs(values) do
        local entryValue = entry.value
        local button = UI.CreateChoiceButton(row, entry.label, buttonWidth, 28)
        if compact then
            button:SetPoint("TOPLEFT", xOffset, -8)
        else
            button:SetPoint("BOTTOMLEFT", xOffset, 12)
        end
        button:SetSelected(entryValue == currentValue)
        button:SetEnabled(not disabled)
        if disabled then
            button:SetAlpha(0.45)
        end
        button:SetScript("OnClick", function()
            if Private.IsDisabled(option) then
                return
            end
            Private.SetOptionValue(option, entryValue)
            self:NotifyChanged()
        end)
        xOffset = xOffset + buttonWidth + gap
    end

    if disabled then
        row:SetAlpha(0.60)
    end

    return height + Sizes.rowGap
end

function Options:RenderActionRow(parent, option, top)
    local row = self:CreateCard(parent, top, 42)
    local disabled = Private.IsDisabled(option)

    local title = UI.CreateText(row, 12)
    title:SetPoint("LEFT", 12, 0)
    title:SetPoint("RIGHT", -220, 0)
    title:SetJustifyV("MIDDLE")
    title:SetText(Private.ResolveText(option.name))

    local rightOffset = -12
    local actions = option.actions or {}

    for index = #actions, 1, -1 do
        local action = actions[index]
        local actionDisabled = disabled or Private.Evaluate(action.disabled)
        local button = UI.CreateButton(row, Private.ResolveText(action.label), action.width or 48, 24)
        button:SetPoint("RIGHT", rightOffset, 0)
        button:SetEnabled(not actionDisabled)
        if actionDisabled then
            button:SetAlpha(0.45)
        end
        button:SetScript("OnClick", function()
            if actionDisabled then
                return
            end
            local run = function()
                if action.func then
                    action.func()
                end
                self:NotifyChanged()
            end
            if action.confirm then
                self:ShowConfirm(Private.ResolveText(action.confirmText, "确认执行这个操作吗？"), run)
            else
                run()
            end
        end)
        rightOffset = rightOffset - (button:GetWidth() + 6)
    end

    if option.color then
        local colorButton = CreateFrame("Button", nil, row, "BackdropTemplate")
        colorButton:SetSize(28, 24)
        colorButton:SetPoint("RIGHT", rightOffset, 0)
        UI.CreateBackdrop(colorButton, Colors.card, Colors.border)

        local swatch = colorButton:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("TOPLEFT", 3, -3)
        swatch:SetPoint("BOTTOMRIGHT", -3, 3)
        colorButton.swatch = swatch

        local function updateSwatch()
            local r, g, b = option.color.get()
            swatch:SetColorTexture(r or 1, g or 1, b or 1, 1)
        end

        updateSwatch()
        colorButton:SetEnabled(not disabled)
        if disabled then
            colorButton:SetAlpha(0.45)
        end
        colorButton:SetScript("OnClick", function()
            if disabled then
                return
            end
            self:OpenColorPicker({
                hasAlpha = false,
                get = function()
                    local r, g, b = option.color.get()
                    return r, g, b, 1
                end,
                set = function(_, r, g, b)
                    option.color.set(nil, r, g, b)
                    updateSwatch()
                end,
            })
        end)
        rightOffset = rightOffset - 34
    end

    if disabled then
        row:SetAlpha(0.60)
    end

    return 42 + Sizes.rowGap
end

function Options:OpenColorPicker(option)
    local r, g, b, a = Private.SafeCall(option.get)
    r = tonumber(r) or 1
    g = tonumber(g) or 1
    b = tonumber(b) or 1
    a = tonumber(a) or 1

    local function applyColor(nr, ng, nb, na)
        nr, ng, nb, na = NormalizeColorPayload(nr, ng, nb, na)
        Private.SetOptionValue(
            option,
            nr or r,
            ng or g,
            nb or b,
            option.hasAlpha and (na or a) or 1
        )
        self:NotifyChanged()
    end

    local function readPickerColor()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a
        if option.hasAlpha then
            if ColorPickerFrame.GetColorAlpha then
                na = tonumber(ColorPickerFrame:GetColorAlpha()) or na
            elseif OpacitySliderFrame and OpacitySliderFrame.GetValue then
                na = 1 - (tonumber(OpacitySliderFrame:GetValue()) or 0)
            end
        else
            na = 1
        end
        return nr, ng, nb, na
    end

    ColorPickerFrame:Hide()

    -- 新版客户端优先走 SetupColorPickerAndShow，旧版再回退到传统接口。
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = 1 - a,
            hasOpacity = option.hasAlpha and true or false,
            swatchFunc = function()
                applyColor(readPickerColor())
            end,
            opacityFunc = function()
                applyColor(readPickerColor())
            end,
            cancelFunc = function(previousValues)
                local nr, ng, nb, na = NormalizeColorPayload(previousValues)
                applyColor(nr or r, ng or g, nb or b, na or a)
            end,
        })
        return
    end

    ColorPickerFrame.hasOpacity = option.hasAlpha and true or false
    ColorPickerFrame.opacity = 1 - a
    ColorPickerFrame.func = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        applyColor(nr, ng, nb, option.hasAlpha and a or 1)
    end
    ColorPickerFrame.opacityFunc = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = option.hasAlpha and (1 - OpacitySliderFrame:GetValue()) or 1
        applyColor(nr, ng, nb, na)
    end
    ColorPickerFrame.cancelFunc = function(previousValues)
        local nr, ng, nb, na = NormalizeColorPayload(previousValues)
        applyColor(nr or r, ng or g, nb or b, na or a)
    end
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Show()
end

function Options:RenderColor(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 60 or 44
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -150, -10)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -150, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local r, g, b, a = Private.SafeCall(option.get)
    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetPoint("RIGHT", -12, 0)
    swatch:SetSize(138, 28)
    UI.CreateBackdrop(swatch, Colors.bg, Colors.borderSoft or Colors.border)

    local preview = swatch:CreateTexture(nil, "ARTWORK")
    preview:SetPoint("LEFT", 5, 5)
    preview:SetPoint("BOTTOMLEFT", 5, 5)
    preview:SetSize(18, 18)
    preview:SetColorTexture(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)

    local label = UI.CreateText(swatch, 12)
    label:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    label:SetPoint("RIGHT", -10, 0)
    label:SetJustifyV("MIDDLE")
    label:SetText(Private.FormatHexColor(r, g, b))

    local disabled = Private.IsDisabled(option)
    if disabled then
        row:SetAlpha(0.60)
        swatch:SetAlpha(0.45)
    end

    swatch:SetScript("OnClick", function()
        if Private.IsDisabled(option) then
            return
        end
        self:OpenColorPicker(option)
    end)
    swatch:SetScript("OnEnter", function(selfButton)
        selfButton:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
    end)
    swatch:SetScript("OnLeave", function(selfButton)
        selfButton:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
    end)

    return height + Sizes.rowGap
end

function Options:RenderInput(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local lineCount = tonumber(option.multiline) or 1
    local inputHeight = lineCount > 1 and math.max(70, lineCount * 18) or 28
    local height = inputHeight + (Private.TrimText(descText) ~= "" and 58 or 42)
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 12)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetPoint("TOPRIGHT", -12, -10)
    title:SetText(Private.ResolveText(option.name))

    local topAnchor = title
    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", -12, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
        topAnchor = desc
    end

    local editBox = UI.CreateEditBox(row, lineCount > 1)
    editBox:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -8)
    editBox:SetPoint("RIGHT", -12, 0)
    editBox:SetHeight(inputHeight)
    editBox:SetText(tostring(Private.GetOptionValue(option) or ""))

    if lineCount > 1 then
        editBox:SetScript("OnEscapePressed", function(selfBox)
            selfBox:ClearFocus()
        end)
    else
        editBox:SetScript("OnEnterPressed", function(selfBox)
            Private.SetOptionValue(option, selfBox:GetText())
            self:NotifyChanged()
            selfBox:ClearFocus()
        end)
        editBox:SetScript("OnEscapePressed", function(selfBox)
            selfBox:SetText(tostring(Private.GetOptionValue(option) or ""))
            selfBox:ClearFocus()
        end)
    end

    editBox:SetScript("OnEditFocusLost", function(selfBox)
        selfBox:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
        Private.SetOptionValue(option, selfBox:GetText())
        self:NotifyChanged()
    end)
    editBox:SetScript("OnEditFocusGained", function(selfBox)
        selfBox:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
    end)

    local disabled = Private.IsDisabled(option)
    if disabled then
        row:SetAlpha(0.60)
        editBox:EnableMouse(false)
        editBox:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    return height + Sizes.rowGap
end

function Options:RenderOption(parent, option, top)
    if Private.IsHidden(option) then
        return 0
    end

    if option.type == "header" then
        return self:RenderDescription(parent, option, top, true)
    end
    if option.type == "description" then
        return self:RenderDescription(parent, option, top, false)
    end
    if option.type == "landing" then
        return self:RenderLanding(parent, option, top)
    end
    if option.type == "toggle" then
        return self:RenderToggle(parent, option, top)
    end
    if option.type == "execute" then
        return self:RenderExecute(parent, option, top)
    end
    if option.type == "range" then
        return self:RenderRange(parent, option, top)
    end
    if option.type == "select" then
        return self:RenderSelect(parent, option, top)
    end
    if option.type == "radio" then
        return self:RenderRadio(parent, option, top)
    end
    if option.type == "actionRow" then
        return self:RenderActionRow(parent, option, top)
    end
    if option.type == "color" then
        return self:RenderColor(parent, option, top)
    end
    if option.type == "input" then
        return self:RenderInput(parent, option, top)
    end

    return 0
end

function Options:RenderInlineOption(parent, option, width, refreshInlineStates)
    local optionType = option.type

    if optionType == "execute" then
        local button = UI.CreateButton(parent, Private.ResolveText(option.name), width, 28, "accent")
        button:SetPoint("LEFT", 0, 0)
        local function refreshState()
            local disabled = Private.IsDisabled(option)
            button:SetEnabled(not disabled)
            button:SetAlpha(disabled and 0.45 or 1)
        end
        refreshState()
        parent._yxsRefreshState = refreshState
        button:SetScript("OnClick", function()
            if Private.IsDisabled(option) then
                return
            end

            local run = function()
                Private.RunOption(option)
                self:NotifyChanged()
            end

            if option.confirm then
                self:ShowConfirm(Private.ResolveText(option.confirmText, "确认执行这个操作吗？"), run)
            else
                run()
            end
        end)
        return
    end

    if optionType == "toggle" then
        local title = UI.CreateText(parent, 12)
        title:SetPoint("LEFT", 0, 0)
        title:SetPoint("RIGHT", -76, 0)
        title:SetJustifyV("MIDDLE")
        title:SetText(Private.ResolveText(option.name))

        local switch = UI.CreateSwitch(parent)
        switch:SetPoint("RIGHT", 0, 0)

        local function refreshState()
            local disabled = Private.IsDisabled(option)
            local value = Private.IsTruthy(Private.GetOptionValue(option))
            switch:SetValue(value, disabled)
            if disabled then
                title:SetTextColor(Private.UnpackColor(Colors.muted))
            else
                title:SetTextColor(Private.UnpackColor(Colors.text))
            end
        end

        refreshState()
        parent._yxsRefreshState = refreshState
        switch:SetScript("OnClick", function()
            if Private.IsDisabled(option) then
                return
            end
            Private.SetOptionValue(option, not Private.IsTruthy(Private.GetOptionValue(option)))
            self:NotifyChanged()
        end)
        return
    end

    local labelText = Private.ResolveText(option.name)
    local labelWidth = 0
    if Private.TrimText(labelText) ~= "" then
        local label = UI.CreateText(parent, 12)
        label:SetPoint("LEFT", 0, 0)
        label:SetJustifyV("MIDDLE")
        label:SetText(labelText)
        labelWidth = tonumber(option.inlineLabelWidth) or math.min(
            math.max(label:GetStringWidth() + 10, 56),
            math.max(72, math.floor(width * 0.36))
        )
        label:SetWidth(labelWidth)
        parent._yxsLabel = label
    end

    local controlLeft = labelWidth > 0 and (labelWidth + 6) or 0

    if optionType == "select" then
        local currentValue = Private.GetOptionValue(option)
        local values = Private.NormalizeDropdownValues(option.values)
        local currentLabel = tostring(currentValue or "")

        for _, entry in ipairs(values) do
            if entry.value == currentValue then
                currentLabel = entry.label
                break
            end
        end

        local button = UI.CreateDropdownButton(parent, math.max(80, width - controlLeft), 28)
        button:SetPoint("LEFT", controlLeft, 0)
        button:SetPoint("RIGHT", 0, 0)
        button:SetValue(currentLabel)
        local function refreshState()
            local disabled = Private.IsDisabled(option)
            button:SetEnabled(not disabled)
            button:SetAlpha(disabled and 0.45 or 1)
            if parent._yxsLabel then
                if disabled then
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.muted))
                else
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.text))
                end
            end
        end
        refreshState()
        parent._yxsRefreshState = refreshState
        self:BindSelectDropdown(button, option, values)
        return
    end

    if optionType == "color" then
        local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
        swatch:SetPoint("RIGHT", 0, 0)
        swatch:SetSize(math.min(138, math.max(88, width - controlLeft)), 28)
        UI.CreateBackdrop(swatch, Colors.bg, Colors.borderSoft or Colors.border)

        local preview = swatch:CreateTexture(nil, "ARTWORK")
        preview:SetPoint("LEFT", 5, 0)
        preview:SetSize(18, 18)

        local valueText = UI.CreateText(swatch, 12)
        valueText:SetPoint("LEFT", preview, "RIGHT", 8, 0)
        valueText:SetPoint("RIGHT", -8, 0)
        valueText:SetJustifyV("MIDDLE")

        local function updateColorDisplay()
            local r, g, b, a = Private.SafeCall(option.get)
            preview:SetColorTexture(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)
            valueText:SetText(Private.FormatHexColor(r, g, b))
        end

        local function refreshState()
            local disabled = Private.IsDisabled(option)
            updateColorDisplay()
            swatch:SetEnabled(not disabled)
            swatch:SetAlpha(disabled and 0.45 or 1)
            if parent._yxsLabel then
                if disabled then
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.muted))
                else
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.text))
                end
            end
        end

        refreshState()
        parent._yxsRefreshState = refreshState
        swatch:SetScript("OnClick", function()
            if Private.IsDisabled(option) then
                return
            end
            self:OpenColorPicker(option)
        end)
        swatch:SetScript("OnEnter", function(selfButton)
            selfButton:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
        end)
        swatch:SetScript("OnLeave", function(selfButton)
            selfButton:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
        end)
        return
    end

    if optionType == "input" then
        local editBox = UI.CreateEditBox(parent, false)
        editBox:SetPoint("LEFT", controlLeft, 0)
        editBox:SetPoint("RIGHT", 0, 0)
        editBox:SetHeight(28)
        editBox:SetText(tostring(Private.GetOptionValue(option) or ""))
        local function refreshState()
            local disabled = Private.IsDisabled(option)
            if parent._yxsLabel then
                if disabled then
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.muted))
                else
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.text))
                end
            end
            if disabled then
                editBox:EnableMouse(false)
                editBox:SetTextColor(Private.UnpackColor(Colors.muted))
            else
                editBox:EnableMouse(true)
                editBox:SetTextColor(Private.UnpackColor(Colors.text))
            end
        end
        parent._yxsRefreshState = refreshState
        refreshState()
        local function commitText(selfBox)
            Private.SetOptionValue(option, selfBox:GetText())
            if refreshInlineStates then
                refreshInlineStates()
            end
        end
        editBox:SetScript("OnTextChanged", function(selfBox, userInput)
            if not userInput then
                return
            end
            commitText(selfBox)
        end)
        editBox:SetScript("OnEnterPressed", function(selfBox)
            commitText(selfBox)
            selfBox:ClearFocus()
        end)
        editBox:SetScript("OnEscapePressed", function(selfBox)
            selfBox:SetText(tostring(Private.GetOptionValue(option) or ""))
            selfBox:ClearFocus()
        end)
        editBox:SetScript("OnEditFocusLost", function(selfBox)
            selfBox:SetBackdropBorderColor(Private.UnpackColor(Colors.border))
            commitText(selfBox)
        end)
        editBox:SetScript("OnEditFocusGained", function(selfBox)
            selfBox:SetBackdropBorderColor(Private.UnpackColor(Colors.borderActive))
        end)
        return
    end

    if optionType == "range" then
        local sliderHolder = UI.CreateSlider(parent)
        sliderHolder:SetPoint("LEFT", controlLeft, 0)
        sliderHolder:SetPoint("RIGHT", 0, 0)

        local slider = sliderHolder.slider
        local minValue = tonumber(option.min) or 0
        local maxValue = tonumber(option.max) or 100
        local step = tonumber(option.step) or 1

        local function refreshState()
            local disabled = Private.IsDisabled(option)
            local settingValue = tonumber(Private.GetOptionValue(option)) or minValue
            slider:SetMinMaxValues(minValue, maxValue)
            slider:SetValueStep(step)
            slider:SetValue(settingValue)
            sliderHolder.valueBox:SetText(Private.FormatNumber(settingValue, step))
            slider:EnableMouse(not disabled)
            sliderHolder.valueBox:EnableMouse(not disabled)
            if parent._yxsLabel then
                if disabled then
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.muted))
                else
                    parent._yxsLabel:SetTextColor(Private.UnpackColor(Colors.text))
                end
            end
            sliderHolder.valueBox:SetTextColor(
                Private.UnpackColor(disabled and Colors.muted or Colors.text)
            )
            parent:SetAlpha(disabled and 0.60 or 1)
        end

        local updating = false
        slider:SetScript("OnValueChanged", function(_, value)
            if updating then
                return
            end
            updating = true
            sliderHolder.valueBox:SetText(Private.FormatNumber(value, step))
            Private.SetOptionValue(option, value)
            updating = false
        end)
        slider:SetScript("OnMouseUp", function()
            self:NotifyChanged()
        end)
        sliderHolder.valueBox:SetScript("OnEnterPressed", function(editBox)
            local value = tonumber(editBox:GetText())
            if value then
                if value < minValue then
                    value = minValue
                elseif value > maxValue then
                    value = maxValue
                end
                slider:SetValue(value)
                Private.SetOptionValue(option, value)
                self:NotifyChanged()
            else
                editBox:SetText(Private.FormatNumber(slider:GetValue(), step))
            end
            editBox:ClearFocus()
        end)
        sliderHolder.valueBox:SetScript("OnEscapePressed", function(editBox)
            editBox:SetText(Private.FormatNumber(slider:GetValue(), step))
            editBox:ClearFocus()
        end)

        refreshState()
        parent._yxsRefreshState = refreshState
        return
    end

    self:RenderOption(parent, option, 0)
end

function Options:RenderInlineOptionRows(parent, group, path, top)
    local width = GetParentContentWidth(self, parent)
    local yOffset = top
    local pending = {}
    local pendingMinWidth = 0

    local function flushRow()
        if #pending == 0 then
            return
        end

        local rowContentHeight = 28
        for _, entry in ipairs(pending) do
            rowContentHeight = math.max(rowContentHeight, GetInlineOptionContentHeight(entry.value))
        end

        local rowHeight = rowContentHeight + 14
        local row = self:CreateCard(parent, yOffset, rowHeight)
        local holders = {}
        local function refreshInlineStates()
            for _, holder in ipairs(holders) do
                if holder._yxsRefreshState then
                    holder._yxsRefreshState()
                end
            end
        end
        local gap = 10
        local innerWidth = width - 24 - math.max(0, (#pending - 1) * gap)
        local totalUnits = 0
        for _, entry in ipairs(pending) do
            totalUnits = totalUnits + entry.units
        end

        local xOffset = 12
        for index, entry in ipairs(pending) do
            local itemWidth
            if index == #pending then
                itemWidth = math.max(80, width - xOffset - 12)
            else
                itemWidth = math.max(80, math.floor(innerWidth * entry.units / math.max(totalUnits, 1)))
            end

            local holder = CreateFrame("Frame", nil, row)
            holder:SetPoint("TOPLEFT", xOffset, -7)
            holder:SetSize(itemWidth, rowContentHeight)
            holders[#holders + 1] = holder
            self:RenderInlineOption(holder, entry.value, itemWidth, refreshInlineStates)
            xOffset = xOffset + itemWidth + gap
        end

        refreshInlineStates()
        yOffset = yOffset - (rowHeight + Sizes.rowGap)
        pending = {}
        pendingMinWidth = 0
    end

    for _, entry in ipairs(Private.SortArgs(group.args or {})) do
        if not Private.IsHidden(entry.value) then
            if entry.value.type == "description" then
                flushRow()
                yOffset = yOffset - self:RenderOption(parent, entry.value, yOffset)
            elseif entry.value.type == "group" then
                flushRow()
                yOffset = yOffset - self:RenderGroupSection(
                    parent,
                    entry.value,
                    Private.AppendPath(path, entry.key),
                    yOffset,
                    false
                )
            else
                local minWidth = GetInlineOptionMinWidth(entry.value)
                local nextWidth = pendingMinWidth + (#pending > 0 and 10 or 0) + minWidth
                if #pending > 0 and nextWidth > (width - 24) then
                    flushRow()
                end

                pending[#pending + 1] = {
                    value = entry.value,
                    units = GetInlineOptionUnits(entry.value),
                }
                pendingMinWidth = pendingMinWidth + (#pending > 1 and 10 or 0) + minWidth
            end
        end
    end

    flushRow()
    return top - yOffset
end

function Options:RenderGroupBody(parent, group, path, top)
    local yOffset = top

    if group.layout == "row" then
        return self:RenderInlineOptionRows(parent, group, path, top)
    end

    -- tab 模式下，当前层只负责切换标签，不直接平铺所有子 group。
    if group.childGroups == "tab" then
        local tabEntries = {}
        for _, entry in ipairs(Private.SortArgs(group.args or {})) do
            if entry.value.type == "group" and not Private.IsHidden(entry.value) then
                tabEntries[#tabEntries + 1] = entry
            end
        end

        if #tabEntries > 0 then
            local tabPath = Private.PathKey(path)
            local selectedKey = self.selectedChildren[tabPath]
            local autoSelectKey = Private.Evaluate(group.autoSelectChild)
            local validSelection = false

            if autoSelectKey then
                for _, entry in ipairs(tabEntries) do
                    if entry.key == autoSelectKey then
                        selectedKey = autoSelectKey
                        self.selectedChildren[tabPath] = autoSelectKey
                        validSelection = true
                        break
                    end
                end
            end

            for _, entry in ipairs(tabEntries) do
                if entry.key == selectedKey then
                    validSelection = true
                    break
                end
            end

            if not validSelection then
                selectedKey = tabEntries[1].key
                self.selectedChildren[tabPath] = selectedKey
            end

            self.tabOffsets = self.tabOffsets or {}
            local tabPageSize = tonumber(group.tabPageSize) or #tabEntries
            local tabOffset = self.tabOffsets[tabPath] or 1
            tabPageSize = math.max(1, math.min(tabPageSize, #tabEntries))
            tabOffset = math.max(1, math.min(tabOffset, math.max(1, #tabEntries - tabPageSize + 1)))

            for index, entry in ipairs(tabEntries) do
                if entry.key == selectedKey and (index < tabOffset or index >= tabOffset + tabPageSize) then
                    tabOffset = math.max(1, math.min(index, math.max(1, #tabEntries - tabPageSize + 1)))
                    break
                end
            end
            self.tabOffsets[tabPath] = tabOffset

            local tabBar = CreateFrame("Frame", nil, parent)
            tabBar:SetPoint("TOPLEFT", 0, yOffset)
            tabBar:SetSize(GetParentContentWidth(self, parent), 28)
            local tabX = 0
            local hasPagedTabs = #tabEntries > tabPageSize

            if hasPagedTabs then
                local prevButton = UI.CreateButton(tabBar, "<", 28, 24)
                prevButton:SetPoint("TOPLEFT", tabX, 0)
                prevButton:SetEnabled(tabOffset > 1)
                prevButton:SetScript("OnClick", function()
                    self.tabOffsets[tabPath] = math.max(1, tabOffset - tabPageSize)
                    self:Render()
                end)
                tabX = tabX + prevButton:GetWidth() + 6
            end

            for visibleIndex = tabOffset, math.min(#tabEntries, tabOffset + tabPageSize - 1) do
                local entry = tabEntries[visibleIndex]
                local entryKey = entry.key
                local label = Private.ResolveText(entry.value.name, entry.key)
                local button = UI.CreateTabButton(tabBar)
                UI.SetButtonLabel(button, label)
                button:SetWidth(math.max(92, button.text:GetStringWidth() + 24))
                button:SetPoint("TOPLEFT", tabX, 0)
                button:SetSelected(entryKey == selectedKey)
                local isDisabled = Private.IsDisabled(entry.value)
                button:SetDisabled(isDisabled, Private.GetDisabledTip(entry.value, "当前选项卡暂时不可用"))
                button:SetScript("OnClick", function()
                    if isDisabled then
                        return
                    end
                    self.selectedChildren[tabPath] = entryKey
                    self:Render()
                end)

                if isDisabled and entryKey ~= selectedKey then
                    button:SetAlpha(0.55)
                end

                tabX = tabX + button:GetWidth() + 6
            end

            if hasPagedTabs then
                local nextButton = UI.CreateButton(tabBar, ">", 28, 24)
                nextButton:SetPoint("TOPLEFT", tabX, 0)
                nextButton:SetEnabled(tabOffset + tabPageSize <= #tabEntries)
                nextButton:SetScript("OnClick", function()
                    self.tabOffsets[tabPath] = math.min(math.max(1, #tabEntries - tabPageSize + 1), tabOffset + tabPageSize)
                    self:Render()
                end)
            end

            yOffset = yOffset - 34

            local selectedGroup = group.args[selectedKey]
            if selectedGroup then
                if Private.IsDisabled(selectedGroup) then
                    selectedGroup = CreateDisabledPlaceholderGroup(
                        "|cFF888888" .. Private.GetDisabledTip(selectedGroup, "当前选项卡暂时不可用") .. "|r"
                    )
                end
                yOffset = yOffset - self:RenderGroupSection(
                    parent,
                    selectedGroup,
                    Private.AppendPath(path, selectedKey),
                    yOffset,
                    true
                )
            end
        end

        return top - yOffset
    end

    local items = Private.SortArgs(group.args or {})
    local index = 1
    while index <= #items do
        local entry = items[index]
        if entry.value.type == "group" then
            if not Private.IsHidden(entry.value) then
                local inlinePairWidth = GetParentContentWidth(self, parent)
                local nextEntry = items[index + 1]
                local canRenderInlinePair = entry.value.inline
                    and inlinePairWidth >= 700
                    and nextEntry
                    and nextEntry.value
                    and nextEntry.value.type == "group"
                    and nextEntry.value.inline
                    and not Private.IsHidden(nextEntry.value)

                if canRenderInlinePair then
                    local pairRow = CreateFrame("Frame", nil, parent)
                    pairRow:SetPoint("TOPLEFT", 0, yOffset)
                    pairRow:SetWidth(inlinePairWidth)

                    local gap = Sizes.sectionGap
                    local columnWidth = math.floor((inlinePairWidth - gap) / 2)
                    local leftColumn = CreateFrame("Frame", nil, pairRow)
                    leftColumn:SetPoint("TOPLEFT", 0, 0)
                    leftColumn:SetWidth(columnWidth)

                    local rightColumn = CreateFrame("Frame", nil, pairRow)
                    rightColumn:SetPoint("TOPLEFT", columnWidth + gap, 0)
                    rightColumn:SetWidth(inlinePairWidth - columnWidth - gap)

                    local leftHeight = self:RenderGroupSection(
                        leftColumn,
                        entry.value,
                        Private.AppendPath(path, entry.key),
                        0,
                        false
                    )
                    local rightHeight = self:RenderGroupSection(
                        rightColumn,
                        nextEntry.value,
                        Private.AppendPath(path, nextEntry.key),
                        0,
                        false
                    )
                    local pairHeight = math.max(leftHeight, rightHeight)
                    pairRow:SetHeight(pairHeight)
                    yOffset = yOffset - pairHeight
                    index = index + 2
                else
                    yOffset = yOffset - self:RenderGroupSection(
                        parent,
                        entry.value,
                        Private.AppendPath(path, entry.key),
                        yOffset,
                        false
                    )
                    index = index + 1
                end
            else
                index = index + 1
            end
        else
            yOffset = yOffset - self:RenderOption(parent, entry.value, yOffset)
            index = index + 1
        end
    end

    return top - yOffset
end

function Options:RenderGroupSection(parent, group, path, top, suppressTitle)
    local section = self:CreateSection(parent, top, 32)
    local contentTop = 0

    local titleText = suppressTitle and "" or Private.ResolveText(group.name)
    if Private.TrimText(titleText) ~= "" then
        local title = UI.CreateText(section, 13, "OUTLINE")
        title:SetPoint("TOPLEFT", 0, -2)
        title:SetPoint("TOPRIGHT", -2, -2)
        title:SetText(titleText)
        title:SetTextColor(Private.UnpackColor(Colors.accent))

        local divider = UI.CreateDivider(section, 0.38)
        divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        divider:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -6)
        contentTop = -22
    end

    local usedHeight = self:RenderGroupBody(section, group, path, contentTop)
    local totalHeight = math.max(usedHeight + math.abs(contentTop), 10)
    section:SetHeight(totalHeight)

    if Private.IsDisabled(group) then
        section:SetAlpha(0.70)
    end

    return totalHeight + Sizes.sectionGap
end

function Options:Render(preserveScroll)
    if not self:EnsureRegistered() then
        return false
    end

    local previousScroll = 0
    if preserveScroll and self.frame and self.frame.scrollFrame and self.frame.scrollFrame.GetVerticalScroll then
        previousScroll = self.frame.scrollFrame:GetVerticalScroll() or 0
    end

    self:GetRootOptions()
    local topGroup, topKey = self:GetSelectedTopGroup()
    if not topGroup then
        return false
    end

    self:RefreshNavigation()
    self:ClearScrollContent()

    local moduleName = Private.ResolveText(topGroup.name, topKey)
    local renderGroup = topGroup
    local renderPath = { topKey }
    local pageName = moduleName

    local directGroups = {}
    local directNonGroups = {}
    for _, entry in ipairs(Private.SortArgs(topGroup.args or {})) do
        if not Private.IsHidden(entry.value) then
            if entry.value.type == "group" then
                directGroups[#directGroups + 1] = entry
            else
                directNonGroups[#directNonGroups + 1] = entry
            end
        end
    end

    if #directGroups > 0 and #directNonGroups == 0 then
        self:UpdateSecondaryNavigation(directGroups, { topKey })

        local selectedKey = self.selectedChildren[Private.PathKey({ topKey })] or directGroups[1].key
        local selectedGroup = topGroup.args[selectedKey]
        if selectedGroup then
            renderPath = Private.AppendPath(renderPath, selectedKey)
            pageName = Private.ResolveText(selectedGroup.name, selectedKey)
            if Private.IsDisabled(selectedGroup) then
                renderGroup = CreateDisabledPlaceholderGroup(
                    "|cFF888888" .. Private.GetDisabledTip(selectedGroup, "当前模块暂时不可用") .. "|r"
                )
            else
                renderGroup = selectedGroup
            end
        end
    else
        self:UpdateSecondaryNavigation(nil)
        renderGroup, renderPath = Private.CollapseSingleGroup(topGroup, { topKey })
        pageName = Private.ResolveText(renderGroup and renderGroup.name or topGroup.name, topKey)
    end

    self:UpdateHeader(pageName ~= "" and pageName or moduleName, moduleName)

    local topOffset = -2
    self.frame.scrollChild:SetWidth(self:GetScrollWidth())
    local usedHeight = self:RenderGroupBody(self.frame.scrollChild, renderGroup, renderPath, topOffset)
    self.frame.scrollChild:SetHeight(math.max(usedHeight + 24, self.frame.scrollFrame:GetHeight()))

    local scrollTarget = 0
    if preserveScroll then
        local maxScroll = self.frame.scrollFrame:GetVerticalScrollRange() or 0
        scrollTarget = math.max(0, math.min(previousScroll, maxScroll))
    end
    self.frame.scrollFrame:SetVerticalScroll(scrollTarget)
    if self.frame.scrollBar and self.frame.scrollBar.UpdateScrollBar then
        self.frame.scrollBar:UpdateScrollBar()
    end

    return true
end

function Options:NotifyChanged()
    if self:IsOpen() then
        self:Render(true)
    end
end
