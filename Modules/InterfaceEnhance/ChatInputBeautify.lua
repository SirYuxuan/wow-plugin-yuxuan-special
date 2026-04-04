local _, NS = ...

local InterfaceBeautify = {}
NS.Modules.InterfaceEnhance.InterfaceBeautify = InterfaceBeautify

local ChatFrame_AddMessageEventFilter = rawget(_G, "ChatFrame_AddMessageEventFilter")
local ChatFrame_RemoveMessageEventFilter = rawget(_G, "ChatFrame_RemoveMessageEventFilter")
local CreateFrame = rawget(_G, "CreateFrame")
local GameTooltip = rawget(_G, "GameTooltip")
local GameTooltip_Hide = rawget(_G, "GameTooltip_Hide")
local NUM_CHAT_WINDOWS = rawget(_G, "NUM_CHAT_WINDOWS") or 10

local LINK_TOOLTIP_TYPES = {
    achievement = true,
    battlepet = true,
    battlePetAbil = true,
    currency = true,
    enchant = true,
    garrfollower = true,
    instancelock = true,
    item = true,
    keystone = true,
    quest = true,
    spell = true,
    talent = true,
    transmogappearance = true,
    transmogillusion = true,
}

local FIXED_CHANNEL_LABELS = {
    PARTY = "队",
    PARTY_LEADER = "队",
    RAID = "团",
    RAID_LEADER = "团",
    RAID_WARNING = "警",
    INSTANCE_CHAT = "副",
    INSTANCE_CHAT_LEADER = "副",
    GUILD = "会",
    OFFICER = "官",
    BATTLEGROUND = "战",
    BATTLEGROUND_LEADER = "战",
    YELL = "喊",
    WHISPER = "密",
}

local TARGETS = {
    {
        frameName = "AddonCompartmentFrame",
        configKey = "hideAddonCompartment",
    },
    {
        frameName = "ChatFrameChannelButton",
        configKey = "hideChatChannelButton",
    },
    {
        frameName = "ChatFrameMenuButton",
        configKey = "hideChatMenuButton",
    },
}

local GetConfig

local function GetShortChannelName(channelName)
    if type(channelName) ~= "string" or #channelName == 0 then
        return nil
    end

    if channelName:find("世界", 1, true) then
        return "世界"
    end

    if channelName:find("综合", 1, true) then
        return "综"
    end

    if channelName:find("交易", 1, true) then
        return "交"
    end

    if channelName:find("本地防务", 1, true) or channelName:find("防务", 1, true) then
        return "防"
    end

    if channelName:find("寻求组队", 1, true) or channelName:find("组队", 1, true) then
        return "组"
    end

    if channelName:find("公会招募", 1, true) then
        return "招"
    end

    if channelName:find("公会", 1, true) then
        return "会"
    end

    if channelName:find("官员", 1, true) then
        return "官"
    end

    return nil
end

GetConfig = function()
    local config = NS.Core:GetConfig("interfaceEnhance", "interfaceBeautify")
    local defaults = NS.DEFAULTS and NS.DEFAULTS.interfaceEnhance and NS.DEFAULTS.interfaceEnhance.interfaceBeautify or
    {}

    for key, value in pairs(defaults) do
        if config[key] == nil then
            config[key] = value
        end
    end

    return config
end

local function IsTooltipLinkSupported(link)
    if type(link) ~= "string" or #link == 0 then
        return false
    end

    local linkType = link:match("^(.-):")
    return linkType and LINK_TOOLTIP_TYPES[linkType] == true
end

local function ReplaceChannelLinkLabel(text, linkTarget, label)
    return (text:gsub("(|Hchannel:" .. linkTarget .. "|h)%[[^%]]+%](|h)", "%1[" .. label .. "]%2"))
end

local function ReplaceCustomChannelLabels(text)
    local function replacer(prefix, channelName, suffix)
        local shortName = GetShortChannelName(channelName)
        if shortName then
            return prefix .. "[" .. shortName .. "]" .. suffix
        end

        return prefix .. "[" .. channelName .. "]" .. suffix
    end

    local updated = text
    updated = updated:gsub("(|Hchannel:channel:%d+|h)%[([^%]]+)%](|h)", replacer)
    updated = updated:gsub("(|Hchannel:CHANNEL:%d+|h)%[([^%]]+)%](|h)", replacer)
    return updated
end

function InterfaceBeautify:SimplifyRenderedMessage(text)
    if type(text) ~= "string" then
        return text
    end

    -- Some Blizzard chat payloads are protected "secret strings".
    -- String length/pattern operations on them can throw, so fall back to
    -- the original payload when the message cannot be safely inspected.
    local ok, updated = pcall(function()
        if text == "" then
            return text
        end

        local result = text
        for channelKey, label in pairs(FIXED_CHANNEL_LABELS) do
            result = ReplaceChannelLinkLabel(result, channelKey, label)
        end

        result = ReplaceCustomChannelLabels(result)
        return result
    end)

    if ok then
        return updated
    end

    return text
end

function InterfaceBeautify:ApplyChatFormatOverrides()
    -- Keep Blizzard chat event payloads untouched to avoid taint and history errors.
end

function InterfaceBeautify:UpdateChannelFilter()
    if not (ChatFrame_AddMessageEventFilter and ChatFrame_RemoveMessageEventFilter) then
        return
    end

    if self.channelFilterRegistered then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", self.channelFilterRegistered)
        self.channelFilterRegistered = nil
    end
end

function InterfaceBeautify:HandleHyperlinkEnter(frame, link)
    local config = GetConfig()
    if not (config.enabled and config.chatLinkTooltip and GameTooltip and IsTooltipLinkSupported(link)) then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if ok then
        GameTooltip:Show()
    else
        GameTooltip_Hide()
    end
end

function InterfaceBeautify:HandleHyperlinkLeave()
    if GameTooltip_Hide then
        GameTooltip_Hide()
    end
end

function InterfaceBeautify:HookChatFrame(frame)
    if not frame or frame.__YuXuanInterfaceBeautifyHooked then
        return
    end

    frame.__YuXuanInterfaceBeautifyHooked = true

    if type(frame.AddMessage) == "function" and not frame.__YuXuanOriginalAddMessage then
        frame.__YuXuanOriginalAddMessage = frame.AddMessage
        frame.AddMessage = function(chatFrame, text, ...)
            local config = GetConfig()
            if config.enabled and config.simplifyChatChannel then
                text = InterfaceBeautify:SimplifyRenderedMessage(text)
            end

            return chatFrame.__YuXuanOriginalAddMessage(chatFrame, text, ...)
        end
    end

    frame:HookScript("OnHyperlinkEnter", function(self, link)
        InterfaceBeautify:HandleHyperlinkEnter(self, link)
    end)
    frame:HookScript("OnHyperlinkLeave", function()
        InterfaceBeautify:HandleHyperlinkLeave()
    end)
end

function InterfaceBeautify:HookChatFrames()
    for index = 1, NUM_CHAT_WINDOWS do
        self:HookChatFrame(_G["ChatFrame" .. tostring(index)])
    end
end

local function ApplyTarget(target)
    if not target or type(target.frameName) ~= "string" or type(target.configKey) ~= "string" then
        return
    end

    local frame = _G[target.frameName]
    if not frame then
        return
    end

    local config = GetConfig()
    local shouldHide = config.enabled and config[target.configKey]

    if NS.Core and NS.Core.SetFrameObjectHidden then
        NS.Core:SetFrameObjectHidden(frame, shouldHide)
    elseif NS.Core and NS.Core.HideFrameObject and shouldHide then
        NS.Core:HideFrameObject(frame)
    end

    if frame.__YuXuanInterfaceBeautifyTargetHooked then
        return
    end

    frame.__YuXuanInterfaceBeautifyTargetHooked = true
    frame:HookScript("OnShow", function(self)
        local currentConfig = GetConfig()
        local hideOnShow = currentConfig.enabled and currentConfig[target.configKey]
        if NS.Core and NS.Core.SetFrameObjectHidden then
            NS.Core:SetFrameObjectHidden(self, hideOnShow)
        elseif NS.Core and NS.Core.HideFrameObject and hideOnShow then
            NS.Core:HideFrameObject(self)
        end
    end)
end

function InterfaceBeautify:Refresh()
    for _, target in ipairs(TARGETS) do
        ApplyTarget(target)
    end

    self:ApplyChatFormatOverrides()
    self:UpdateChannelFilter()
    self:HookChatFrames()
end

function InterfaceBeautify:RefreshFromSettings()
    self:Refresh()
end

function InterfaceBeautify:OnPlayerLogin()
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
        InterfaceBeautify:Refresh()
    end)

    self.eventFrame = eventFrame
end
