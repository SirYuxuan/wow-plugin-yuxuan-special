local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.DISPLAY_NAME = "雨轩工具箱"
NS.VERSION = "0.0.1"
NS.Modules = NS.Modules or {}
NS.Modules.MapAssist = NS.Modules.MapAssist or {}
NS.Modules.InterfaceEnhance = NS.Modules.InterfaceEnhance or {}
NS.Modules.CombatAssist = NS.Modules.CombatAssist or {}
NS.Modules.ClassAssist = NS.Modules.ClassAssist or {}
NS.Modules.ClassAssist.Mage = NS.Modules.ClassAssist.Mage or {}
NS.Options = NS.Options or {}

local Core = {}
NS.Core = Core

local function GetAddOnMetadataCompat(addonName, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local value = C_AddOns.GetAddOnMetadata(addonName, field)
        if type(value) == "table" then
            return value[field] or value.Version or value.version
        end
        return value
    end

    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, field)
    end
end

NS.VERSION = tostring(GetAddOnMetadataCompat(ADDON_NAME, "Version") or NS.VERSION)

--[[
核心入口只负责三件事
1. 初始化 SavedVariables
2. 注册斜杠命令
3. 在合适时机把事件转发给具体模块

这样后续继续扩展功能时 入口文件不需要反复改结构
]]

function Core:Print(message)
    print(string.format("|cFF33FF99%s|r: %s", NS.DISPLAY_NAME, tostring(message or "")))
end

function Core:GetAppearanceConfig()
    self.db = self.db or {}
    self.db.general = self.db.general or {}
    self.db.general.appearance = self.db.general.appearance or {}
    return self.db.general.appearance
end

function Core:CreateMinimapButton()
    if self.minimapButton or not Minimap then
        return self.minimapButton
    end

    local button = CreateFrame("Button", "YuXuanSpecialMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
    button.icon = icon

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("CENTER", 0, 1)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetVertexColor(0, 0, 0, 1)
    button.background = background

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(46, 46)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.85)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:AddLine(NS.DISPLAY_NAME, 1, 0.82, 0.18)
        GameTooltip:AddLine("左键打开设置", 1, 1, 1)
        GameTooltip:AddLine("/yxs", 1, 0.93, 0.25)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        if NS.Options and NS.Options.Open then
            NS.Options:Open()
        end
    end)

    self.minimapButton = button
    return button
end

function Core:UpdateMinimapButtonPosition()
    local button = self.minimapButton
    if not (button and Minimap) then
        return
    end

    local radius = (Minimap:GetWidth() or 140) * 0.5 + 5
    local angle = math.rad(180)
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Core:RefreshMinimapButton()
    local config = self:GetAppearanceConfig()
    local shouldShow = config.showMinimapButton ~= false

    if not shouldShow then
        if self.minimapButton then
            self.minimapButton:Hide()
        end
        return
    end

    local button = self:CreateMinimapButton()
    if not button then
        return
    end

    self:UpdateMinimapButtonPosition()
    button:Show()
end

function Core:SetFrameObjectHidden(frame, hidden)
    if not frame then
        return
    end

    self.hiddenSystemFrame = self.hiddenSystemFrame or CreateFrame("Frame", ADDON_NAME .. "HiddenSystemFrame", UIParent)
    self.hiddenSystemFrame:Hide()

    if hidden then
        if frame.GetParent and frame.SetParent and not frame.__YuXuanOriginalParent then
            frame.__YuXuanOriginalParent = frame:GetParent()
        end

        if frame.GetAlpha and frame.SetAlpha and frame.__YuXuanOriginalAlpha == nil then
            frame.__YuXuanOriginalAlpha = frame:GetAlpha()
        end

        if frame.SetParent then
            pcall(frame.SetParent, frame, self.hiddenSystemFrame)
        end

        if frame.Hide then
            pcall(frame.Hide, frame)
        end

        if frame.SetAlpha then
            pcall(frame.SetAlpha, frame, 0)
        end
        return
    end

    if frame.SetParent and frame.__YuXuanOriginalParent then
        pcall(frame.SetParent, frame, frame.__YuXuanOriginalParent)
    end

    if frame.SetAlpha then
        pcall(frame.SetAlpha, frame, frame.__YuXuanOriginalAlpha ~= nil and frame.__YuXuanOriginalAlpha or 1)
    end

    if frame.Show then
        pcall(frame.Show, frame)
    end
end

function Core:HideFrameObject(frame)
    self:SetFrameObjectHidden(frame, true)
end

function Core:HideAddonCompartment()
    local frame = _G.AddonCompartmentFrame
    if not frame then
        return
    end

    self:HideFrameObject(frame)

    if frame.__YuXuanHideHooked then
        return
    end

    frame.__YuXuanHideHooked = true
    frame:HookScript("OnShow", function(selfFrame)
        if NS.Core and NS.Core.HideFrameObject then
            NS.Core:HideFrameObject(selfFrame)
        end
    end)
end

function Core:OnAddonLoaded()
    self:InitializeDatabase()
    self:RegisterSlashCommands()
end

function Core:OnPlayerLogin()
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.OnPlayerLogin then
        quickWaypoint:OnPlayerLogin()
    end

    local mapIDDisplay = NS.Modules.MapAssist and NS.Modules.MapAssist.MapIDDisplay
    if mapIDDisplay and mapIDDisplay.OnPlayerLogin then
        mapIDDisplay:OnPlayerLogin()
    end

    local quickChat = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.QuickChat
    if quickChat and quickChat.OnPlayerLogin then
        quickChat:OnPlayerLogin()
    end

    local interfaceBeautify = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.InterfaceBeautify
    if interfaceBeautify and interfaceBeautify.OnPlayerLogin then
        interfaceBeautify:OnPlayerLogin()
    end

    local distanceMonitor = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.DistanceMonitor
    if distanceMonitor and distanceMonitor.OnPlayerLogin then
        distanceMonitor:OnPlayerLogin()
    end

    local raidMarkers = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.RaidMarkers
    if raidMarkers and raidMarkers.OnPlayerLogin then
        raidMarkers:OnPlayerLogin()
    end

    local gameBar = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.GameBar
    if gameBar and gameBar.OnPlayerLogin then
        gameBar:OnPlayerLogin()
    end

    local mouseTooltip = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.MouseTooltip
    if mouseTooltip and mouseTooltip.OnPlayerLogin then
        mouseTooltip:OnPlayerLogin()
    end

    local cursorTrail = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.CursorTrail
    if cursorTrail and cursorTrail.OnPlayerLogin then
        cursorTrail:OnPlayerLogin()
    end

    local itemLevelPlanner = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.ItemLevelPlanner
    if itemLevelPlanner and itemLevelPlanner.OnPlayerLogin then
        itemLevelPlanner:OnPlayerLogin()
    end

    local specTalentBar = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.SpecTalentBar
    if specTalentBar and specTalentBar.OnPlayerLogin then
        specTalentBar:OnPlayerLogin()
    end

    local questTools = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.QuestTools
    if questTools and questTools.OnPlayerLogin then
        questTools:OnPlayerLogin()
    end

    local huntAssist = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.HuntAssist
    if huntAssist and huntAssist.OnPlayerLogin then
        huntAssist:OnPlayerLogin()
    end

    local attributeDisplay = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.AttributeDisplay
    if attributeDisplay and attributeDisplay.OnPlayerLogin then
        attributeDisplay:OnPlayerLogin()
    end

    local currencyDisplay = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.CurrencyDisplay
    if currencyDisplay and currencyDisplay.OnPlayerLogin then
        currencyDisplay:OnPlayerLogin()
    end

    local performanceMonitor = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.PerformanceMonitor
    if performanceMonitor and performanceMonitor.OnPlayerLogin then
        performanceMonitor:OnPlayerLogin()
    end

    local bagItemOverlay = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.BagItemOverlay
    if bagItemOverlay and bagItemOverlay.OnPlayerLogin then
        bagItemOverlay:OnPlayerLogin()
    end

    local eventTracker = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.EventTracker
    if eventTracker and eventTracker.OnPlayerLogin then
        eventTracker:OnPlayerLogin()
    end

    local updateLog = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.UpdateLog
    if updateLog and updateLog.OnPlayerLogin then
        updateLog:OnPlayerLogin()
    end

    local quickFocus = NS.Modules.CombatAssist and NS.Modules.CombatAssist.QuickFocus
    if quickFocus and quickFocus.OnPlayerLogin then
        quickFocus:OnPlayerLogin()
    end

    local trinketMonitor = NS.Modules.CombatAssist and NS.Modules.CombatAssist.TrinketMonitor
    if trinketMonitor and trinketMonitor.OnPlayerLogin then
        trinketMonitor:OnPlayerLogin()
    end

    local shatterIndicator = NS.Modules.ClassAssist
        and NS.Modules.ClassAssist.Mage
        and NS.Modules.ClassAssist.Mage.ShatterIndicator
    if shatterIndicator and shatterIndicator.OnPlayerLogin then
        shatterIndicator:OnPlayerLogin()
    end

    self:RefreshMinimapButton()

    print(string.format(
        "|cFF33FF99%s|r |cFFFFD200V%s|r |cFF7CFC00已加载|r |cFFFFFFFF打开设置|r |cFFFFFF00/yxs|r",
        NS.DISPLAY_NAME,
        NS.VERSION
    ))
end

function Core:OnWorldMapLoaded()
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.OnWorldMapLoaded then
        quickWaypoint:OnWorldMapLoaded()
    end

    local mapIDDisplay = NS.Modules.MapAssist and NS.Modules.MapAssist.MapIDDisplay
    if mapIDDisplay and mapIDDisplay.OnWorldMapLoaded then
        mapIDDisplay:OnWorldMapLoaded()
    end

    local eventTracker = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.EventTracker
    if eventTracker and eventTracker.OnWorldMapLoaded then
        eventTracker:OnWorldMapLoaded()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            Core:OnAddonLoaded()
        elseif arg1 == "Blizzard_WorldMap" then
            Core:OnWorldMapLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        Core:OnPlayerLogin()
    end
end)
