local _, NS = ...

local ChatInputBeautify = {}
NS.Modules.InterfaceEnhance.ChatInputBeautify = ChatInputBeautify

local EDITBOX_REGION_SUFFIXES = {
    "Left",
    "Mid",
    "Right",
    "FocusLeft",
    "FocusMid",
    "FocusRight",
}

local function GetChatEditBox(index)
    local chatFrame = _G["ChatFrame" .. tostring(index)]
    if not chatFrame or not chatFrame.GetName then
        return nil
    end

    return _G[chatFrame:GetName() .. "EditBox"]
end

local function EnsureOpaqueBackground(editBox)
    if not editBox or editBox.YXSOpaqueBackground then
        return
    end

    local bg = editBox:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetPoint("TOPLEFT", editBox, "TOPLEFT", -4, 2)
    bg:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 4, -2)
    bg:SetColorTexture(0, 0, 0, 1)
    bg:Hide()
    editBox.YXSOpaqueBackground = bg
end

local function HideDefaultRegions(editBox)
    if not editBox then
        return
    end

    local editBoxName = editBox:GetName()
    if not editBoxName then
        return
    end

    for _, suffix in ipairs(EDITBOX_REGION_SUFFIXES) do
        local region = _G[editBoxName .. suffix]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
    end
end

local function RefreshEditBox(editBox)
    if not editBox then
        return
    end

    EnsureOpaqueBackground(editBox)
    HideDefaultRegions(editBox)

    if editBox.YXSOpaqueBackground then
        editBox.YXSOpaqueBackground:SetShown(editBox:IsShown())
    end
end

local function HookEditBox(editBox)
    if not editBox or editBox.YXSOpaqueBackgroundHooked then
        return
    end

    editBox.YXSOpaqueBackgroundHooked = true

    editBox:HookScript("OnShow", function(self)
        RefreshEditBox(self)
    end)

    editBox:HookScript("OnHide", function(self)
        if self.YXSOpaqueBackground then
            self.YXSOpaqueBackground:Hide()
        end
    end)
end

function ChatInputBeautify:Refresh()
    for index = 1, NUM_CHAT_WINDOWS or 10 do
        local editBox = GetChatEditBox(index)
        if editBox then
            HookEditBox(editBox)
            RefreshEditBox(editBox)
        end
    end
end

function ChatInputBeautify:OnPlayerLogin()
    if self.initialized then
        self:Refresh()
        return
    end

    self.initialized = true
    self:Refresh()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
    eventFrame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    eventFrame:SetScript("OnEvent", function()
        ChatInputBeautify:Refresh()
    end)

    self.eventFrame = eventFrame
end
