local _, NS = ...
local Core = NS.Core
local C_ChatInfo = rawget(_G, "C_ChatInfo")
local SendChatMessage = _G.SendChatMessage

local QuestTools = {}
NS.Modules.InterfaceEnhance.QuestTools = QuestTools

local PADDING_X = 10
local PADDING_Y = 8

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "questTools")
end

local function SendGroupChatMessage(message, channel)
    if not message or message == "" or not channel or channel == "" then
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
        return true
    end

    if SendChatMessage then
        SendChatMessage(message, channel)
        return true
    end

    return false
end

local function ApplyFont(fontString, size, outline, preset)
    if not fontString then
        return
    end

    local optionsPrivate = NS.Options and NS.Options.Private
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, outline or "OUTLINE", preset or GetConfig().fontPreset)
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, outline or "OUTLINE")
end

local function Clamp(value, minValue, maxValue)
    local number = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, number))
end

local function Round(value)
    local number = tonumber(value) or 0
    if number >= 0 then
        return math.floor(number + 0.5)
    end
    return math.ceil(number - 0.5)
end

local function RGBToHex(color)
    local r = math.floor(Clamp((color and color.r) or 1, 0, 1) * 255 + 0.5)
    local g = math.floor(Clamp((color and color.g) or 1, 0, 1) * 255 + 0.5)
    local b = math.floor(Clamp((color and color.b) or 1, 0, 1) * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
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
    return ((left + right) * 0.5 - parentWidth * 0.5) / scale, ((bottom + top) * 0.5 - parentHeight * 0.5) / scale
end

local function ProcessLegacyGreetingQuests(selectCompletedOnly)
    if type(GetNumActiveQuests) == "function" and type(SelectActiveQuest) == "function" then
        local activeCount = GetNumActiveQuests() or 0
        for index = 1, activeCount do
            local _, isComplete = GetActiveTitle(index)
            if isComplete then
                SelectActiveQuest(index)
                return true
            end
        end
    end

    if not selectCompletedOnly and type(GetNumAvailableQuests) == "function" and type(SelectAvailableQuest) == "function" then
        local availableCount = GetNumAvailableQuests() or 0
        if availableCount > 0 then
            SelectAvailableQuest(1)
            return true
        end
    end

    return false
end

local function GetGossipQuestIdentifier(info)
    if type(info) ~= "table" then
        return nil
    end
    return info.questID or info.id or info.index
end

local function IsGossipQuestComplete(info)
    if type(info) ~= "table" then
        return false
    end
    if info.isComplete ~= nil then
        return info.isComplete == true
    end
    if info.questID and C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(info.questID) == true
    end
    return false
end

function QuestTools:GetQuestAnnounceChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function QuestTools:GetQuestAnnounceTextByID(questID)
    if not questID then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        return C_QuestLog.GetTitleForQuestID(questID)
    end
    return tostring(questID)
end

function QuestTools:FormatQuestAnnounce(actionText, questName)
    local template = GetConfig().announceTemplate or "|cFF33FF99【雨轩专业版插件】|r |cFFFFFF00{action}|r：{quest}"
    return template:gsub("{action}", tostring(actionText or "")):gsub("{quest}", tostring(questName or ""))
end

function QuestTools:SanitizeChatMessage(message)
    local text = tostring(message or "")
    text = text:gsub("\r", " "):gsub("\n", " ")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    return text
end

function QuestTools:AnnounceQuest(actionText, questID)
    if not GetConfig().autoAnnounceQuest then
        return
    end

    local questText = self:GetQuestAnnounceTextByID(questID)
    if not questText or questText == "" then
        return
    end

    local message = self:FormatQuestAnnounce(actionText, questText)
    local channel = self:GetQuestAnnounceChannel()
    local sanitized = self:SanitizeChatMessage(message)
    if channel and SendGroupChatMessage(sanitized, channel) then
        return
    end

    if channel then
        print(sanitized)
    else
        print(sanitized)
    end
end

function QuestTools:ProcessAutoQuestDialogs(onlyCompleted)
    if not GetConfig().autoQuestTurnIn then
        return false
    end

    if C_GossipInfo then
        if type(C_GossipInfo.GetActiveQuests) == "function" and type(C_GossipInfo.SelectActiveQuest) == "function" then
            for _, info in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
                if IsGossipQuestComplete(info) then
                    local questIdentifier = GetGossipQuestIdentifier(info)
                    if questIdentifier then
                        C_GossipInfo.SelectActiveQuest(questIdentifier)
                        return true
                    end
                end
            end
        end

        if not onlyCompleted and type(C_GossipInfo.GetAvailableQuests) == "function" and type(C_GossipInfo.SelectAvailableQuest) == "function" then
            local firstQuest = (C_GossipInfo.GetAvailableQuests() or {})[1]
            local questIdentifier = GetGossipQuestIdentifier(firstQuest)
            if questIdentifier then
                C_GossipInfo.SelectAvailableQuest(questIdentifier)
                return true
            end
        end
    end

    return ProcessLegacyGreetingQuests(onlyCompleted)
end

function QuestTools:ScheduleAutoQuestSweep(onlyCompleted, remainingPasses)
    local passes = tonumber(remainingPasses) or 12
    if passes <= 0 then
        return
    end

    if not (C_Timer and C_Timer.After) then
        self:ProcessAutoQuestDialogs(onlyCompleted)
        return
    end

    C_Timer.After(0.15, function()
        local handled = QuestTools:ProcessAutoQuestDialogs(onlyCompleted)
        if handled then
            QuestTools:ScheduleAutoQuestSweep(onlyCompleted, passes - 1)
        end
    end)
end

function QuestTools:HandleQuestEvent(event, ...)
    if event == "QUEST_ACCEPTED" then
        local questID = select(2, ...) or select(1, ...)
        self:AnnounceQuest("任务已接取", questID)
        return
    end

    if event == "QUEST_TURNED_IN" then
        self:AnnounceQuest("任务已完成", ...)
        return
    end

    if not GetConfig().autoQuestTurnIn then
        return
    end

    if event == "QUEST_DETAIL" then
        if AcceptQuest then
            AcceptQuest()
        end
        self:ScheduleAutoQuestSweep(false)
    elseif event == "QUEST_PROGRESS" then
        if IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
            CompleteQuest()
        end
        self:ScheduleAutoQuestSweep(true)
    elseif event == "QUEST_COMPLETE" then
        local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
        if GetQuestReward then
            GetQuestReward(math.max(1, numChoices))
        end
        self:ScheduleAutoQuestSweep(false)
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        self:ProcessAutoQuestDialogs(false)
        self:ScheduleAutoQuestSweep(false)
    end
end

function QuestTools:UpdateEventRegistration()
    if not self.eventFrame then
        return
    end

    self.eventFrame:UnregisterAllEvents()

    local config = GetConfig()
    if config.enabled and config.autoAnnounceQuest then
        self.eventFrame:RegisterEvent("QUEST_ACCEPTED")
        self.eventFrame:RegisterEvent("QUEST_TURNED_IN")
    end

    if config.enabled and config.autoQuestTurnIn then
        self.eventFrame:RegisterEvent("QUEST_DETAIL")
        self.eventFrame:RegisterEvent("QUEST_PROGRESS")
        self.eventFrame:RegisterEvent("QUEST_COMPLETE")
        self.eventFrame:RegisterEvent("GOSSIP_SHOW")
        self.eventFrame:RegisterEvent("QUEST_GREETING")
    end
end

function QuestTools:SavePosition()
    if not self.frame then
        return
    end

    local offsetX, offsetY = GetCenterOffset(self.frame)
    local point = GetConfig().point
    point.point = "CENTER"
    point.relativePoint = "CENTER"
    point.x = Round(offsetX)
    point.y = Round(offsetY)
end

function QuestTools:UpdateLayout()
    if not self.frame then
        return
    end

    local config = GetConfig()
    local spacing = Clamp(config.spacing or 18, 0, 300)
    local textColor = config.textColor or { r = 1, g = 1, b = 1, a = 1 }
    local labelHex = RGBToHex(textColor)

    ApplyFont(self.frame.announceButton.text, config.fontSize or 13, "OUTLINE", config.fontPreset)
    ApplyFont(self.frame.turnInButton.text, config.fontSize or 13, "OUTLINE", config.fontPreset)

    local announceState = config.autoAnnounceQuest and "|cFF33FF33开|r" or "|cFFFF5555关|r"
    local turnInState = config.autoQuestTurnIn and "|cFF33FF33开|r" or "|cFFFF5555关|r"
    local announceLabel = config.orientation == "HORIZONTAL" and "通报" or "任务通报"
    local turnInLabel = config.orientation == "HORIZONTAL" and "交接" or "自动交接"

    self.frame.announceButton.text:SetText("|cFF" .. labelHex .. announceLabel .. "|r " .. announceState)
    self.frame.turnInButton.text:SetText("|cFF" .. labelHex .. turnInLabel .. "|r " .. turnInState)

    local height = math.max(26, math.ceil(self.frame.announceButton.text:GetStringHeight() + PADDING_Y * 2))
    local horizontalPadding = config.orientation == "HORIZONTAL" and 12 or (PADDING_X * 2)
    local minButtonWidth = config.orientation == "HORIZONTAL" and 68 or 118
    local announceWidth = math.max(minButtonWidth,
        math.ceil(self.frame.announceButton.text:GetStringWidth() + horizontalPadding))
    local turnInWidth = math.max(minButtonWidth,
        math.ceil(self.frame.turnInButton.text:GetStringWidth() + horizontalPadding))

    self.frame.announceButton:SetSize(announceWidth, height)
    self.frame.turnInButton:SetSize(turnInWidth, height)
    self.frame.announceButton:ClearAllPoints()
    self.frame.turnInButton:ClearAllPoints()

    if config.orientation == "VERTICAL" then
        self.frame.announceButton:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        self.frame.turnInButton:SetPoint("TOPLEFT", self.frame.announceButton, "BOTTOMLEFT", 0, -spacing)
        self.frame:SetSize(math.max(announceWidth, turnInWidth), height * 2 + spacing)
    else
        self.frame.announceButton:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        self.frame.turnInButton:SetPoint("LEFT", self.frame.announceButton, "RIGHT", spacing, 0)
        self.frame:SetSize(announceWidth + turnInWidth + spacing, height)
    end

    self.frame:SetMovable(config.locked ~= true)
    if config.locked then
        self.frame.bg:SetColorTexture(0, 0, 0, 0)
        self.frame.announceButton.bg:SetColorTexture(0, 0, 0, 0)
        self.frame.turnInButton.bg:SetColorTexture(0, 0, 0, 0)
    else
        self.frame.bg:SetColorTexture(0, 0.6, 1, 0.12)
        self.frame.announceButton.bg:SetColorTexture(0, 0, 0, 0.28)
        self.frame.turnInButton.bg:SetColorTexture(0, 0, 0, 0.28)
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        config.point and config.point.point or "CENTER",
        UIParent,
        config.point and config.point.relativePoint or "CENTER",
        Round(config.point and config.point.x or 0),
        Round(config.point and config.point.y or -110)
    )
end

function QuestTools:UpdateVisibility()
    if not self.frame then
        return
    end

    if GetConfig().enabled then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function QuestTools:RefreshFromSettings()
    if not self.frame then
        self:CreateFrame()
    end
    self:UpdateLayout()
    self:UpdateVisibility()
    self:UpdateEventRegistration()
end

function QuestTools:ToggleQuestAnnounce()
    local config = GetConfig()
    if not config.enabled then
        return
    end
    config.autoAnnounceQuest = not config.autoAnnounceQuest
    self:RefreshFromSettings()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function QuestTools:ToggleQuestTurnIn()
    local config = GetConfig()
    if not config.enabled then
        return
    end
    config.autoQuestTurnIn = not config.autoQuestTurnIn
    self:RefreshFromSettings()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

function QuestTools:CreateFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "YuXuanSpecialQuestTools", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)

    local function CreateButton(parent)
        local button = CreateFrame("Button", nil, parent)
        button:RegisterForClicks("AnyUp")
        button:RegisterForDrag("LeftButton")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints(button)

        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("CENTER")

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
            QuestTools:SavePosition()
        end)

        return button
    end

    frame.announceButton = CreateButton(frame)
    frame.turnInButton = CreateButton(frame)

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        QuestTools:SavePosition()
    end)

    frame.announceButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("任务通报", 1, 0.82, 0)
        GameTooltip:AddLine(GetConfig().autoAnnounceQuest and "当前：已开启" or "当前：已关闭", 1, 1, 1)
        GameTooltip:AddLine("点击切换接取/完成任务时的聊天通报。", 0.75, 1, 0.75)
        GameTooltip:Show()
    end)
    frame.announceButton:SetScript("OnLeave", GameTooltip_Hide)
    frame.announceButton:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            QuestTools:ToggleQuestAnnounce()
        end
    end)

    frame.turnInButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("自动交接", 1, 0.82, 0)
        GameTooltip:AddLine(GetConfig().autoQuestTurnIn and "当前：已开启" or "当前：已关闭", 1, 1, 1)
        GameTooltip:AddLine("点击切换自动接任务、交任务和领奖。", 0.75, 1, 0.75)
        GameTooltip:Show()
    end)
    frame.turnInButton:SetScript("OnLeave", GameTooltip_Hide)
    frame.turnInButton:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            QuestTools:ToggleQuestTurnIn()
        end
    end)

    self.frame = frame
end

function QuestTools:OnPlayerLogin()
    self:CreateFrame()
    self.eventFrame = self.eventFrame or CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        QuestTools:HandleQuestEvent(event, ...)
    end)
    self:RefreshFromSettings()
end
