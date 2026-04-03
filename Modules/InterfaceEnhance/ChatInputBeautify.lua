local _, NS = ...

local InterfaceBeautify = {}
NS.Modules.InterfaceEnhance.InterfaceBeautify = InterfaceBeautify

local ChatFrame_AddMessageEventFilter = rawget(_G, "ChatFrame_AddMessageEventFilter")
local ChatFrame_RemoveMessageEventFilter = rawget(_G, "ChatFrame_RemoveMessageEventFilter")
local CreateFrame = rawget(_G, "CreateFrame")
local GameTooltip = rawget(_G, "GameTooltip")
local GameTooltip_Hide = rawget(_G, "GameTooltip_Hide")
local NUM_CHAT_WINDOWS = rawget(_G, "NUM_CHAT_WINDOWS") or 10

local CHAT_FORMATS = {
    CHAT_YELL_GET = "|Hchannel:YELL|h[喊]|h %s:\32",
    CHAT_GUILD_GET = "|Hchannel:GUILD|h[会]|h %s:\32",
    CHAT_OFFICER_GET = "|Hchannel:OFFICER|h[官]|h %s:\32",
    CHAT_PARTY_GET = "|Hchannel:PARTY|h[队]|h %s:\32",
    CHAT_PARTY_LEADER_GET = "|Hchannel:PARTY|h[队]|h %s:\32",
    CHAT_RAID_GET = "|Hchannel:RAID|h[团]|h %s:\32",
    CHAT_RAID_LEADER_GET = "|Hchannel:RAID|h[团]|h %s:\32",
    CHAT_RAID_WARNING_GET = "|Hchannel:RAID_WARNING|h[警]|h %s:\32",
    CHAT_INSTANCE_CHAT_GET = "|Hchannel:INSTANCE_CHAT|h[副]|h %s:\32",
    CHAT_INSTANCE_CHAT_LEADER_GET = "|Hchannel:INSTANCE_CHAT|h[副]|h %s:\32",
    CHAT_WHISPER_GET = "|Hchannel:WHISPER|h[密]|h %s:\32",
    CHAT_BN_WHISPER_GET = "|HBNplayer:%s|h[网]|h %s:\32",
}

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

local ORIGINAL_CHAT_FORMATS = {}
local GetConfig

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

local function SaveOriginalChatFormats()
    for key in pairs(CHAT_FORMATS) do
        if ORIGINAL_CHAT_FORMATS[key] == nil then
            ORIGINAL_CHAT_FORMATS[key] = _G[key]
        end
    end
end

local function NormalizeChannelName(channelName)
    local text = tostring(channelName or "")
    if text == "" then
        return text
    end

    if text:find("大脚世界频道", 1, true) or text:find("世界频道", 1, true) or text == "世界" then
        return "世界"
    elseif text:find("公会招募", 1, true) then
        return "招募"
    elseif text:find("本地防务", 1, true) or text:find("防务", 1, true) then
        return "防务"
    elseif text:find("寻求组队", 1, true) or text:find("组队", 1, true) then
        return "组队"
    elseif text:find("交易", 1, true) then
        return "交易"
    elseif text:find("综合", 1, true) then
        return "综合"
    elseif text:find("工会", 1, true) or text:find("公会", 1, true) then
        return "公会"
    end

    return text
end

local function SimplifyChannelMessage(_, _, message, author, languageName, channelName, target, flags, zoneID,
                                      channelIndex, channelBaseName, ...)
    local config = GetConfig()
    if not (config.enabled and config.simplifyChatChannel) then
        return false
    end

    local shortBaseName = NormalizeChannelName(channelBaseName or channelName)
    local newChannelName = shortBaseName
    local index = tonumber(channelIndex)

    if index and index > 0 then
        newChannelName = tostring(index) .. "." .. shortBaseName
    end

    return false, message, author, languageName, newChannelName, target, flags, zoneID, channelIndex, shortBaseName, ...
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
    if type(link) ~= "string" or link == "" then
        return false
    end

    local linkType = link:match("^(.-):")
    return linkType and LINK_TOOLTIP_TYPES[linkType] == true
end

function InterfaceBeautify:ApplyChatFormatOverrides()
    -- Avoid tainting Blizzard chat history/state by mutating global CHAT_* format strings.
    -- Channel name simplification is handled through CHAT_MSG_CHANNEL filtering only.
end

function InterfaceBeautify:UpdateChannelFilter()
    if not (ChatFrame_AddMessageEventFilter and ChatFrame_RemoveMessageEventFilter) then
        return
    end

    if self.channelFilterRegistered then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", SimplifyChannelMessage)
        self.channelFilterRegistered = false
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
    if not frame or frame.__YuXuanChatLinkTooltipHooked then
        return
    end

    frame.__YuXuanChatLinkTooltipHooked = true
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

    if frame.__YuXuanInterfaceBeautifyHooked then
        return
    end

    frame.__YuXuanInterfaceBeautifyHooked = true
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
