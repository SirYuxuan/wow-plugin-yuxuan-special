local _, NS = ...
local Core = NS.Core

--[[
快捷频道条参考 YuXuanToolbox 的 QuickChat 做法，
但这里完全接到雨轩专用插件自己的模块体系中：
1. 使用我们自己的 SavedVariables
2. 通过 OnPlayerLogin / RefreshFromSettings 驱动
3. 用现有设置系统管理按钮、颜色、顺序和自定义指令
]]

local QuickChat = {}
NS.Modules.InterfaceEnhance.QuickChat = QuickChat
local DICE_ICON_PATH = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Icons\\dice.png"

local BUILTIN_BUTTONS = {
    { key = "SAY", label = "说", action = "switch", slash = "/s " },
    { key = "YELL", label = "喊话", action = "switch", slash = "/y " },
    { key = "PARTY", label = "小队", action = "switch", slash = "/p " },
    { key = "INSTANCE_CHAT", label = "副本", action = "switch", slash = "/i " },
    { key = "RAID", label = "团队", action = "switch", slash = "/raid " },
    { key = "GUILD", label = "公会", action = "switch", slash = "/g " },
    { key = "WORLD", label = "世界", action = "world" },
    { key = "DICE", label = "骰子", action = "dice" },
}

local DEFAULT_BUTTON_COLORS = {
    SAY = { r = 1.00, g = 1.00, b = 1.00 },
    YELL = { r = 1.00, g = 0.25, b = 0.25 },
    PARTY = { r = 0.66, g = 0.66, b = 1.00 },
    INSTANCE_CHAT = { r = 1.00, g = 0.50, b = 0.20 },
    RAID = { r = 1.00, g = 0.50, b = 0.00 },
    GUILD = { r = 0.25, g = 1.00, b = 0.25 },
    WORLD = { r = 0.30, g = 0.95, b = 1.00 },
    DICE = { r = 1.00, g = 0.82, b = 0.00 },
}

local BUILTIN_LOOKUP = {}
for _, button in ipairs(BUILTIN_BUTTONS) do
    BUILTIN_LOOKUP[button.key] = button
end

local function Trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function CloneColor(color)
    return {
        r = tonumber(color and color.r) or 1,
        g = tonumber(color and color.g) or 1,
        b = tonumber(color and color.b) or 1,
    }
end

local function TableContains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "quickChat")
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function ApplyConfiguredFont(fontString, size)
    if not fontString then
        return
    end

    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 14, "OUTLINE", GetConfig().fontPreset or "CHAT")
        return
    end

    local fontObject = ChatFontNormal
    if fontObject and fontObject.GetFont then
        local fontPath, _, flags = fontObject:GetFont()
        if fontPath then
            fontString:SetFont(fontPath, size or 14, flags or "OUTLINE")
            return
        end
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 14, "OUTLINE")
end

function QuickChat:EnsureData()
    local config = GetConfig()
    config.buttonColors = config.buttonColors or {}
    config.customButtons = config.customButtons or {}
    config.buttonOrder = config.buttonOrder or {}
    config.barPoint = config.barPoint or {}

    if #config.buttonOrder == 0 then
        for _, button in ipairs(BUILTIN_BUTTONS) do
            table.insert(config.buttonOrder, button.key)
        end
    end

    for _, button in ipairs(BUILTIN_BUTTONS) do
        if not config.buttonColors[button.key] then
            config.buttonColors[button.key] = CloneColor(DEFAULT_BUTTON_COLORS[button.key])
        end
    end

    for _, custom in ipairs(config.customButtons) do
        local key = "CUSTOM_" .. tostring(custom.id)
        config.buttonColors[key] = config.buttonColors[key] or { r = 1.00, g = 0.82, b = 0.00 }
        if not TableContains(config.buttonOrder, key) then
            table.insert(config.buttonOrder, key)
        end
    end

    config.nextCustomId = tonumber(config.nextCustomId) or 1
    config.worldChannelName = Trim(config.worldChannelName) ~= "" and Trim(config.worldChannelName) or "大脚世界频道"
    config.fontPreset = config.fontPreset or "CHAT"
    config.spacing = tonumber(config.spacing) or 10
    config.fontSize = tonumber(config.fontSize) or 14
    config.barPoint.point = config.barPoint.point or "CENTER"
    config.barPoint.relativePoint = config.barPoint.relativePoint or "CENTER"
    config.barPoint.x = tonumber(config.barPoint.x) or 0
    config.barPoint.y = tonumber(config.barPoint.y) or -180
end

function QuickChat:GetBuiltinButtons()
    return BUILTIN_BUTTONS
end

function QuickChat:GetAllButtonDefs()
    self:EnsureData()

    local defs = {}
    local config = GetConfig()

    for _, key in ipairs(config.buttonOrder) do
        local builtin = BUILTIN_LOOKUP[key]
        if builtin then
            defs[#defs + 1] = builtin
        elseif key:find("^CUSTOM_") then
            local customID = tonumber(key:gsub("^CUSTOM_", ""))
            for _, custom in ipairs(config.customButtons) do
                if tonumber(custom.id) == customID and Trim(custom.label) ~= "" then
                    defs[#defs + 1] = {
                        key = key,
                        label = Trim(custom.label),
                        action = "custom",
                        command = Trim(custom.command),
                    }
                    break
                end
            end
        end
    end

    self.buttonDefs = defs
    return defs
end

function QuickChat:GetColorForKey(key)
    self:EnsureData()

    local config = GetConfig()
    config.buttonColors[key] = config.buttonColors[key] or { r = 1, g = 1, b = 1 }
    return config.buttonColors[key]
end

function QuickChat:GetCustomButtonByKey(key)
    if not key or not key:find("^CUSTOM_") then
        return nil, nil
    end

    local customID = tonumber(key:gsub("^CUSTOM_", ""))
    if not customID then
        return nil, nil
    end

    for index, custom in ipairs(GetConfig().customButtons or {}) do
        if tonumber(custom.id) == customID then
            return custom, index
        end
    end

    return nil, nil
end

function QuickChat:OpenChatWithSlash(slashText)
    if ChatFrame_OpenChat then
        ChatFrame_OpenChat(slashText or "", DEFAULT_CHAT_FRAME)
    end
end

function QuickChat:GetWorldChannelInfo()
    local channelName = Trim(GetConfig().worldChannelName)
    if channelName == "" then
        channelName = "大脚世界频道"
    end

    local channelID, joinedName = GetChannelName(channelName)
    return channelID or 0, joinedName or channelName, channelName
end

function QuickChat:JoinWorldChannel()
    local channelID, _, channelName = self:GetWorldChannelInfo()
    if channelID > 0 then
        self:OpenChatWithSlash("/" .. tostring(channelID) .. " ")
        return
    end

    local frameID = (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.GetID and DEFAULT_CHAT_FRAME:GetID()) or 1
    JoinChannelByName(channelName, nil, frameID, false)
    Core:Print("正在加入 " .. channelName)

    C_Timer.After(0.6, function()
        local newID = GetChannelName(channelName)
        if newID and newID > 0 then
            QuickChat:OpenChatWithSlash("/" .. tostring(newID) .. " ")
            Core:Print("已加入 " .. channelName .. " (频道 " .. newID .. ")")
        else
            Core:Print("加入世界频道失败，请检查频道名称")
        end
    end)
end

function QuickChat:LeaveWorldChannel()
    local channelID, _, channelName = self:GetWorldChannelInfo()
    if channelID > 0 then
        LeaveChannelByName(channelName)
        Core:Print("已离开 " .. channelName)
    else
        Core:Print("当前未加入 " .. channelName)
    end
end

function QuickChat:HandleButtonClick(def, mouseButton)
    if not def then
        return
    end

    if def.action == "dice" then
        RandomRoll(1, 100)
        return
    end

    if def.action == "switch" then
        self:OpenChatWithSlash(def.slash or "")
        return
    end

    if def.action == "world" then
        if mouseButton == "RightButton" then
            self:LeaveWorldChannel()
        else
            self:JoinWorldChannel()
        end
        return
    end

    if def.action == "custom" then
        local command = Trim(def.command)
        if command == "" then
            Core:Print("自定义按钮还没有设置指令")
            return
        end

        if command:sub(1, 1) ~= "/" then
            command = "/" .. command
        end

        self:OpenChatWithSlash(command .. " ")
    end
end

function QuickChat:SaveBarPosition()
    if not self.barFrame then
        return
    end

    local point, _, relativePoint, x, y = self.barFrame:GetPoint(1)
    local barPoint = GetConfig().barPoint
    barPoint.point = point or "CENTER"
    barPoint.relativePoint = relativePoint or "CENTER"
    barPoint.x = math.floor((x or 0) + 0.5)
    barPoint.y = math.floor((y or 0) + 0.5)
end

function QuickChat:UpdateDraggableState()
    if not self.barFrame then
        return
    end

    local config = GetConfig()
    local unlocked = config.enabled and config.unlocked
    self.barFrame:SetMovable(unlocked)
    self.barFrame:EnableMouse(unlocked)
    if self.barFrame.bg then
        if unlocked then
            self.barFrame.bg:SetColorTexture(0, 0.6, 1, 0.16)
        else
            self.barFrame.bg:SetColorTexture(0, 0, 0, 0)
        end
    end
end

function QuickChat:BuildOrReuseButtons()
    self.quickChatButtons = self.quickChatButtons or {}

    local defs = self:GetAllButtonDefs()
    for index, def in ipairs(defs) do
        local button = self.quickChatButtons[index]
        if not button then
            button = CreateFrame("Button", nil, self.barFrame)
            button:RegisterForClicks("AnyUp")
            button.textFS = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            button.textFS:SetPoint("CENTER")
            button.icon = button:CreateTexture(nil, "OVERLAY")
            button.icon:SetPoint("CENTER")
            button.icon:SetSize(18, 18)
            button.icon:Hide()
            button:SetScript("OnClick", function(frame, mouseButton)
                QuickChat:HandleButtonClick(frame.def, mouseButton)
            end)
            button:SetScript("OnEnter", function(frame)
                if frame.icon then
                    frame.icon:SetAlpha(0.72)
                end
                frame.textFS:SetAlpha(0.72)
                if frame.def and frame.def.action == "world" then
                    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
                    GameTooltip:AddLine("世界频道", 1, 0.82, 0)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("左键: 加入并切换到世界频道", 0.75, 1, 0.75)
                    GameTooltip:AddLine("右键: 离开世界频道", 1, 0.7, 0.7)
                    local channelID = QuickChat:GetWorldChannelInfo()
                    GameTooltip:AddLine(" ")
                    if channelID > 0 then
                        GameTooltip:AddLine("已加入 (频道 " .. channelID .. ")", 0.6, 1, 0.6)
                    else
                        GameTooltip:AddLine("未加入", 0.65, 0.65, 0.65)
                    end
                    GameTooltip:Show()
                elseif frame.def and frame.def.action == "dice" then
                    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
                    GameTooltip:AddLine(frame.def.label or "骰子", 1, 0.82, 0)
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function(frame)
                if frame.icon then
                    frame.icon:SetAlpha(1)
                end
                frame.textFS:SetAlpha(1)
                GameTooltip:Hide()
            end)
            self.quickChatButtons[index] = button
        end

        button.def = def
        if def.key == "DICE" then
            button.textFS:SetText("")
            button.icon:SetTexture(DICE_ICON_PATH)
            button.icon:Show()
        else
            button.textFS:SetText(def.label)
            button.icon:Hide()
        end
        button:Show()
    end

    for index = #defs + 1, #self.quickChatButtons do
        self.quickChatButtons[index]:Hide()
    end
end

function QuickChat:LayoutButtons()
    if not self.barFrame then
        return
    end

    self:BuildOrReuseButtons()

    local config = GetConfig()
    local spacing = tonumber(config.spacing) or 10
    local fontSize = tonumber(config.fontSize) or 14
    local totalWidth = 0
    local maxHeight = 0
    local shownIndex = 0
    local previousButton

    for _, button in ipairs(self.quickChatButtons or {}) do
        if button:IsShown() and button.def then
            shownIndex = shownIndex + 1

            ApplyConfiguredFont(button.textFS, fontSize)
            local color = self:GetColorForKey(button.def.key)
            button.textFS:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)

            local width = math.ceil(button.textFS:GetStringWidth() + 14)
            local height = math.ceil(button.textFS:GetStringHeight() + 10)
            if button.def.key == "DICE" and button.icon then
                button.icon:SetTexture(DICE_ICON_PATH)
                button.icon:SetVertexColor(1, 1, 1, 1)
                width = 26
                height = 26
            end
            button:SetSize(width, height)

            button:ClearAllPoints()
            if previousButton then
                button:SetPoint("LEFT", previousButton, "RIGHT", spacing, 0)
            else
                button:SetPoint("LEFT", self.barFrame, "LEFT", 0, 0)
            end

            totalWidth = totalWidth + width + (shownIndex > 1 and spacing or 0)
            if height > maxHeight then
                maxHeight = height
            end

            previousButton = button
        end
    end

    self.barFrame:SetSize(math.max(40, totalWidth), math.max(22, maxHeight))
end

function QuickChat:UpdateBar()
    if not self.barFrame then
        return
    end

    self:EnsureData()

    if GetConfig().enabled then
        self.barFrame:Show()
        self:LayoutButtons()
    else
        self.barFrame:Hide()
    end

    self:UpdateDraggableState()
end

function QuickChat:CreateBar()
    if self.barFrame then
        return
    end

    self:EnsureData()

    local frame = CreateFrame("Frame", "YuXuanSpecialQuickChatBar", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)

    local point = GetConfig().barPoint
    frame:SetPoint(
        point.point or "CENTER",
        UIParent,
        point.relativePoint or "CENTER",
        point.x or 0,
        point.y or -180
    )

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local config = GetConfig()
        if not (config.enabled and config.unlocked) then
            return
        end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        QuickChat:SaveBarPosition()
    end)

    self.barFrame = frame
    self:UpdateBar()
end

function QuickChat:RefreshFromSettings()
    self:EnsureData()
    if not self.barFrame then
        return
    end
    local point = GetConfig().barPoint
    self.barFrame:ClearAllPoints()
    self.barFrame:SetPoint(
        point.point or "CENTER",
        UIParent,
        point.relativePoint or "CENTER",
        point.x or 0,
        point.y or -180
    )
    self:UpdateBar()
end

function QuickChat:OnPlayerLogin()
    self:EnsureData()
    self:CreateBar()
end
