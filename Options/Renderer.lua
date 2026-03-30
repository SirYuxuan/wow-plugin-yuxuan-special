local _, NS = ...

local Options = NS.Options
local Private = Options.Private
local UI = Private.UI
local Colors = Private.Colors
local Sizes = Private.Sizes

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

    local fontSize = isHeader and 17 or (option.fontSize == "medium" and 13 or 12)
    local text = UI.CreateText(parent, fontSize, isHeader and "OUTLINE" or "")
    text:SetPoint("TOPLEFT", 0, top)
    text:SetWidth(self:GetScrollWidth())
    text:SetText(textValue)

    if isHeader then
        text:SetTextColor(Private.UnpackColor(Colors.accent))
    else
        text:SetTextColor(Private.UnpackColor(Colors.text))
    end

    return text:GetStringHeight() + (isHeader and 10 or 8)
end

function Options:RenderToggle(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 66 or 48
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -92, -14)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetPoint("TOPRIGHT", -92, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local disabled = Private.IsDisabled(option)
    local value = Private.IsTruthy(Private.GetOptionValue(option))

    local switch = UI.CreateSwitch(row)
    switch:SetPoint("RIGHT", -16, 0)
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
    local height = Private.TrimText(descText) ~= "" and 72 or 54
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -170, -14)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetPoint("TOPRIGHT", -170, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local disabled = Private.IsDisabled(option)
    local button = UI.CreateButton(row, Private.ResolveText(option.name), 140, 30, "accent")
    button:SetPoint("RIGHT", -16, 0)
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
    local height = Private.TrimText(descText) ~= "" and 98 or 82
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -16, -14)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetPoint("TOPRIGHT", -16, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local sliderHolder = UI.CreateSlider(row)
    sliderHolder:SetPoint("BOTTOMLEFT", 16, 14)
    sliderHolder:SetPoint("BOTTOMRIGHT", -16, 14)

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

function Options:RenderSelect(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 72 or 54
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -220, -14)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetPoint("TOPRIGHT", -220, 0)
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

    local button = UI.CreateButton(row, currentLabel, 190, 30)
    button:SetPoint("RIGHT", -16, 0)
    button:SetEnabled(not disabled)

    if disabled then
        row:SetAlpha(0.60)
        button:SetAlpha(0.45)
    end

    button:SetScript("OnClick", function(anchor)
        if Private.IsDisabled(option) then
            return
        end

        local menu = {}
        for _, entry in ipairs(values) do
            menu[#menu + 1] = {
                text = entry.label,
                checked = entry.value == Private.GetOptionValue(option),
                func = function()
                    Private.SetOptionValue(option, entry.value)
                    self:NotifyChanged()
                end,
            }
        end

        CloseDropDownMenus()
        EasyMenu(menu, Private.EnsureDropdownHelper(), anchor, 0, 0, "MENU", 2)
    end)

    return height + Sizes.rowGap
end

function Options:OpenColorPicker(option)
    local r, g, b, a = Private.SafeCall(option.get)
    r = tonumber(r) or 1
    g = tonumber(g) or 1
    b = tonumber(b) or 1
    a = tonumber(a) or 1

    local function applyColor(restoreValues)
        local nr, ng, nb, na
        if restoreValues then
            nr, ng, nb, na = unpack(restoreValues)
        else
            if ColorPickerFrame.GetColorRGB then
                nr, ng, nb = ColorPickerFrame:GetColorRGB()
            else
                nr, ng, nb = r, g, b
            end

            if option.hasAlpha and OpacitySliderFrame then
                na = 1 - OpacitySliderFrame:GetValue()
            else
                na = 1
            end
        end

        Private.SetOptionValue(option, nr, ng, nb, na)
        self:NotifyChanged()
    end

    -- 新版客户端优先走 SetupColorPickerAndShow，旧版再回退到传统接口。
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = 1 - a,
            hasOpacity = option.hasAlpha and true or false,
            previousValues = { r, g, b, a },
            swatchFunc = function()
                applyColor()
            end,
            opacityFunc = function()
                applyColor()
            end,
            cancelFunc = function(previousValues)
                applyColor(previousValues)
            end,
        })
        return
    end

    ColorPickerFrame.hasOpacity = option.hasAlpha and true or false
    ColorPickerFrame.opacity = 1 - a
    ColorPickerFrame.previousValues = { r, g, b, a }
    ColorPickerFrame.func = function()
        applyColor()
    end
    ColorPickerFrame.opacityFunc = function()
        applyColor()
    end
    ColorPickerFrame.cancelFunc = function(previousValues)
        applyColor(previousValues)
    end
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

function Options:RenderColor(parent, option, top)
    local descText = Private.ResolveText(option.desc)
    local height = Private.TrimText(descText) ~= "" and 72 or 54
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -180, -14)
    title:SetText(Private.ResolveText(option.name))

    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetPoint("TOPRIGHT", -180, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
    end

    local r, g, b, a = Private.SafeCall(option.get)
    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetPoint("RIGHT", -16, 0)
    swatch:SetSize(148, 30)
    UI.CreateBackdrop(swatch, Colors.cardSoft, Colors.border)

    local preview = swatch:CreateTexture(nil, "ARTWORK")
    preview:SetPoint("LEFT", 6, 6)
    preview:SetPoint("BOTTOMLEFT", 6, 6)
    preview:SetSize(18, 18)
    preview:SetColorTexture(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1)

    local label = UI.CreateText(swatch, 12)
    label:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    label:SetPoint("RIGHT", -10, 0)
    label:SetJustifyV("MIDDLE")
    label:SetText(string.format("%.2f / %.2f / %.2f", tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1))

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
    local inputHeight = lineCount > 1 and math.max(78, lineCount * 20) or 30
    local height = inputHeight + (Private.TrimText(descText) ~= "" and 68 or 50)
    local row = self:CreateCard(parent, top, height)

    local title = UI.CreateText(row, 13)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -16, -14)
    title:SetText(Private.ResolveText(option.name))

    local topAnchor = title
    if Private.TrimText(descText) ~= "" then
        local desc = UI.CreateText(row, 11)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetPoint("TOPRIGHT", -16, 0)
        desc:SetText(descText)
        desc:SetTextColor(Private.UnpackColor(Colors.muted))
        topAnchor = desc
    end

    local editBox = UI.CreateEditBox(row, lineCount > 1)
    editBox:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -10)
    editBox:SetPoint("RIGHT", -16, 0)
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
    if option.type == "color" then
        return self:RenderColor(parent, option, top)
    end
    if option.type == "input" then
        return self:RenderInput(parent, option, top)
    end

    return 0
end

function Options:RenderGroupBody(parent, group, path, top)
    local yOffset = top

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
            local validSelection = false

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

            local tabBar = CreateFrame("Frame", nil, parent)
            tabBar:SetPoint("TOPLEFT", 0, yOffset)
            tabBar:SetSize(self:GetScrollWidth(), 30)
            local tabX = 0

            for _, entry in ipairs(tabEntries) do
                local button = UI.CreateTabButton(tabBar)
                local label = Private.ResolveText(entry.value.name, entry.key)
                UI.SetButtonLabel(button, label)
                button:SetWidth(math.max(96, button.text:GetStringWidth() + 28))
                button:SetPoint("TOPLEFT", tabX, 0)
                button:SetSelected(entry.key == selectedKey)
                button:SetScript("OnClick", function()
                    self.selectedChildren[tabPath] = entry.key
                    self:Render()
                end)

                if Private.IsDisabled(entry.value) and entry.key ~= selectedKey then
                    button:SetAlpha(0.55)
                end

                tabX = tabX + button:GetWidth() + 8
            end

            yOffset = yOffset - 40

            local selectedGroup = group.args[selectedKey]
            if selectedGroup then
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
    for _, entry in ipairs(items) do
        if entry.value.type == "group" then
            if not Private.IsHidden(entry.value) then
                yOffset = yOffset - self:RenderGroupSection(
                    parent,
                    entry.value,
                    Private.AppendPath(path, entry.key),
                    yOffset,
                    false
                )
            end
        else
            yOffset = yOffset - self:RenderOption(parent, entry.value, yOffset)
        end
    end

    return top - yOffset
end

function Options:RenderGroupSection(parent, group, path, top, suppressTitle)
    local card = self:CreateCard(parent, top, 80)
    local contentTop = -16

    local titleText = suppressTitle and "" or Private.ResolveText(group.name)
    if Private.TrimText(titleText) ~= "" then
        local title = UI.CreateText(card, 15, "OUTLINE")
        title:SetPoint("TOPLEFT", 16, contentTop)
        title:SetPoint("TOPRIGHT", -16, contentTop)
        title:SetText(titleText)
        title:SetTextColor(Private.UnpackColor(Colors.accent))
        contentTop = contentTop - 28
    end

    local usedHeight = self:RenderGroupBody(card, group, path, contentTop)
    local totalHeight = math.max(usedHeight + math.abs(contentTop) + 14, 54)
    card:SetHeight(totalHeight)

    if Private.IsDisabled(group) then
        card:SetAlpha(0.70)
    end

    return totalHeight + Sizes.cardGap
end

function Options:Render()
    if not self:EnsureRegistered() then
        return false
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
            renderGroup = selectedGroup
            renderPath = Private.AppendPath(renderPath, selectedKey)
            pageName = Private.ResolveText(selectedGroup.name, selectedKey)
        end
    else
        self:UpdateSecondaryNavigation(nil)
        renderGroup, renderPath = Private.CollapseSingleGroup(topGroup, { topKey })
        pageName = Private.ResolveText(renderGroup and renderGroup.name or topGroup.name, topKey)
    end

    self:UpdateHeader(pageName ~= "" and pageName or moduleName, moduleName)

    local topOffset = -2
    local usedHeight = self:RenderGroupBody(self.frame.scrollChild, renderGroup, renderPath, topOffset)
    self.frame.scrollChild:SetWidth(self:GetScrollWidth())
    self.frame.scrollChild:SetHeight(math.max(usedHeight + 24, self.frame.scrollFrame:GetHeight()))
    self.frame.scrollFrame:SetVerticalScroll(0)

    return true
end

function Options:NotifyChanged()
    if self:IsOpen() then
        self:Render()
    end
end
