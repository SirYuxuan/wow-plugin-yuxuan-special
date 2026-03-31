local _, NS = ...
local Core = NS.Core

local QuartermasterPins = {}
NS.Modules.MapAssist.QuartermasterPins = QuartermasterPins

QuartermasterPins.VENDORS = {
    {
        key = "silvermoonCourt",
        label = "银月宫廷",
        mapID = 2395,
        x = 0.435,
        y = 0.474,
    },
    {
        key = "amaniTribe",
        label = "阿曼尼部族",
        mapID = 2437,
        x = 0.459,
        y = 0.659,
    },
    {
        key = "halaiti",
        label = "哈籁提",
        mapID = 2413,
        x = 0.509,
        y = 0.507,
    },
    {
        key = "singularity",
        label = "奇点特勤",
        mapID = 2405,
        x = 0.526,
        y = 0.729,
    },
}

function QuartermasterPins:GetConfig()
    return Core:GetConfig("mapAssist", "quartermasterPins")
end

function QuartermasterPins:IsVendorEnabled(vendorKey)
    local config = self:GetConfig()
    return config and config[vendorKey] == true
end

function QuartermasterPins:SetWaypoint(vendor)
    if not vendor then
        return
    end

    local waypoint = UiMapPoint.CreateFromCoordinates(vendor.mapID, vendor.x, vendor.y)
    if not waypoint then
        Core:Print("当前地图无法创建军需官导航点。")
        return
    end

    C_Map.SetUserWaypoint(waypoint)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    Core:Print(string.format("已导航到 %s %.1f, %.1f", vendor.label, vendor.x * 100, vendor.y * 100))
end

function QuartermasterPins:UpdateButtonStyle(button)
    if not button then
        return
    end

    button:SetBackdropColor(0.14, 0.11, 0.06, 0.96)
    button:SetBackdropBorderColor(0.95, 0.76, 0.18, 1.00)

    if button.label then
        button.label:SetText("军")
        button.label:SetTextColor(1.00, 0.96, 0.88, 1.00)
    end
end

function QuartermasterPins:CreatePinButton(vendor)
    local button = CreateFrame("Button", nil, self.container, "BackdropTemplate")
    button:SetSize(24, 24)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetClampedToScreen(true)
    button.vendor = vendor

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 0)
    label:SetText("军")
    button.label = label

    button:SetScript("OnEnter", function(selfButton)
        selfButton:SetBackdropColor(0.20, 0.15, 0.08, 1.00)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:AddLine(selfButton.vendor.label, 1, 0.82, 0)
        GameTooltip:AddLine(
            string.format("%.1f, %.1f", selfButton.vendor.x * 100, selfButton.vendor.y * 100),
            0.82,
            0.82,
            0.82
        )
        GameTooltip:AddLine("点击设置导航", 0.70, 1.00, 0.70)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(selfButton)
        self:UpdateButtonStyle(selfButton)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(selfButton)
        self:SetWaypoint(selfButton.vendor)
    end)

    self:UpdateButtonStyle(button)
    return button
end

function QuartermasterPins:CreateContainer()
    if self.container or not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return
    end

    local mapChild = WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
    local container = CreateFrame("Frame", nil, mapChild)
    container:SetAllPoints(mapChild)
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel((mapChild:GetFrameLevel() or 1) + 30)
    container:Hide()
    self.container = container
    self.pinButtons = {}

    for _, vendor in ipairs(self.VENDORS) do
        self.pinButtons[vendor.key] = self:CreatePinButton(vendor)
    end
end

function QuartermasterPins:RefreshPins()
    if not self.container or not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return
    end

    local mapChild = WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
    local currentMapID = WorldMapFrame:GetMapID()
    local hasVisiblePin = false

    self.container:SetAllPoints(mapChild)

    for _, vendor in ipairs(self.VENDORS) do
        local button = self.pinButtons and self.pinButtons[vendor.key]
        local shouldShow = button
            and WorldMapFrame:IsShown()
            and currentMapID == vendor.mapID
            and self:IsVendorEnabled(vendor.key)

        if shouldShow then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", mapChild, "TOPLEFT", mapChild:GetWidth() * vendor.x, -mapChild:GetHeight() * vendor.y)
            button:Show()
            hasVisiblePin = true
        elseif button then
            button:Hide()
        end
    end

    self.container:SetShown(hasVisiblePin)
end

function QuartermasterPins:RefreshFromSettings()
    if not self.container then
        return
    end

    self:RefreshPins()
end

function QuartermasterPins:Initialize()
    if self.initialized or not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return
    end

    self.initialized = true
    self:CreateContainer()
    self:RefreshPins()

    WorldMapFrame:HookScript("OnShow", function()
        QuartermasterPins:RefreshPins()
    end)
    WorldMapFrame:HookScript("OnHide", function()
        QuartermasterPins:RefreshPins()
    end)

    self.container:SetScript("OnUpdate", function(_, elapsed)
        QuartermasterPins.elapsed = (QuartermasterPins.elapsed or 0) + elapsed
        if QuartermasterPins.elapsed < 0.15 then
            return
        end

        QuartermasterPins.elapsed = 0
        QuartermasterPins:RefreshPins()
    end)
end

function QuartermasterPins:OnWorldMapLoaded()
    self:Initialize()
end

function QuartermasterPins:OnPlayerLogin()
    if WorldMapFrame then
        self:Initialize()
    end
end
