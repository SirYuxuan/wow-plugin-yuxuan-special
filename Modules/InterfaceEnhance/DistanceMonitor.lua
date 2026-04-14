local addonName, NS = ...
local Core = NS.Core
local Utils = NS.Utils

local DistanceMonitor = {}
NS.Modules.InterfaceEnhance.DistanceMonitor = DistanceMonitor

local LibStub = _G.LibStub
local LibRangeCheck = LibStub and LibStub("LibRangeCheck-3.0", true)

local ROW_HEIGHT = 30
local DEFAULT_UPDATE_INTERVAL = 0.2

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "distanceMonitor")
end

local function GetRangeCheckText(unit)
    if not LibRangeCheck or type(LibRangeCheck.GetRange) ~= "function" then
        return nil, nil, nil
    end

    local config = GetConfig()
    local separator = config and config.rangeSeparator or " - "
    if type(separator) ~= "string" or separator == "" then
        separator = " - "
    end

    local minRange, maxRange = LibRangeCheck:GetRange(unit)
    if not minRange then
        return nil, nil, nil
    end

    if maxRange then
        if minRange <= 0 then
            return maxRange, string.format("<= %d", maxRange), maxRange
        end

        return minRange, string.format("%d%s%d", minRange, separator, maxRange), maxRange
    end

    return minRange, string.format("%d+", minRange), nil
end

local function GetDistanceInfo(unit)
    local minRange, rangeText, maxRange = GetRangeCheckText(unit)
    if minRange then
        return minRange, maxRange, rangeText
    end

    return nil, nil, ""
end

local function GetDistanceColor(minRange)
    if not minRange then
        return 0.90, 0.90, 0.90
    elseif minRange >= 40 then
        return 1.00, 0.00, 0.00
    elseif minRange >= 30 then
        return 1.00, 1.00, 0.00
    elseif minRange >= 20 then
        return 0.04, 1.00, 0.00
    elseif minRange >= 5 then
        return 0.06, 1.00, 0.94
    end

    return 0.90, 0.90, 0.90
end

function DistanceMonitor:SavePosition()
    if not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    local pos = GetConfig().point
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = math.floor((x or 0) + 0.5)
    pos.y = math.floor((y or 0) + 0.5)
end

function DistanceMonitor:RefreshVisibility()
    if not self.frame then
        return
    end

    local config = GetConfig()
    if config.enabled and type(UnitExists) == "function" and UnitExists("target") then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function DistanceMonitor:ApplyLayout()
    if not self.frame then
        return
    end

    local config = GetConfig()
    local frame = self.frame

    frame:SetMovable(not config.locked)
    Utils.ApplyConfiguredFont(frame.text, config.fontSize or 14, "OUTLINE", config)
    frame.text:SetJustifyH("CENTER")
    frame.text:ClearAllPoints()
    frame.text:SetPoint("LEFT", frame, "LEFT", 10, 0)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

    local width = math.max(160, math.ceil((frame.text:GetStringWidth() or 0) + 24))
    frame:SetSize(width, ROW_HEIGHT)

    Utils.ApplyFrameBackgroundAndBorder(frame, config)
end

function DistanceMonitor:Refresh()
    if not self.frame then
        return
    end

    if type(UnitExists) == "function" and UnitExists("target") then
        local minRange, _, rangeText = GetDistanceInfo("target")
        local r, g, b = GetDistanceColor(minRange)
        if not LibRangeCheck then
            rangeText = "缺少 LibRangeCheck"
            r, g, b = 1.00, 0.35, 0.35
        end
        self.frame.text:SetText(rangeText)
        self.frame.text:SetTextColor(r, g, b, 1)
    else
        self.frame.text:SetText("")
        self.frame.text:SetTextColor(0.90, 0.90, 0.90, 1)
    end

    local width = math.max(160, math.ceil((self.frame.text:GetStringWidth() or 0) + 24))
    if self.frame._lastWidth ~= width then
        self.frame._lastWidth = width
        self.frame:SetSize(width, ROW_HEIGHT)
    end

    self:RefreshVisibility()
end

function DistanceMonitor:CreateFrame()
    if self.frame then
        return
    end

    local config = GetConfig()
    local frame = CreateFrame("Frame", addonName .. "DistanceMonitorFrame", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.border = Utils.CreateSimpleOutline(frame, "BORDER", 1)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetPoint("LEFT", frame, "LEFT", 10, 0)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

    local pos = config.point
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or -220, pos.y or -20)

    frame:SetScript("OnDragStart", function(selfFrame)
        if GetConfig().locked then
            return
        end

        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        DistanceMonitor:SavePosition()
    end)

    frame:SetSize(180, ROW_HEIGHT)
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_TARGET_CHANGED"
            or event == "PLAYER_FOCUS_CHANGED"
            or event == "UPDATE_MOUSEOVER_UNIT"
            or event == "GROUP_ROSTER_UPDATE"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "ZONE_CHANGED"
            or event == "ZONE_CHANGED_INDOORS"
            or event == "PLAYER_STARTED_MOVING"
            or event == "PLAYER_STOPPED_MOVING"
            or event == "NEW_WMO_CHUNK" then
            DistanceMonitor:Refresh()
        end
    end)

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:RegisterEvent("PLAYER_STARTED_MOVING")
    frame:RegisterEvent("PLAYER_STOPPED_MOVING")
    frame:RegisterEvent("NEW_WMO_CHUNK")

    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        selfFrame._elapsed = (selfFrame._elapsed or 0) + elapsed
        local interval = selfFrame._cachedInterval or DEFAULT_UPDATE_INTERVAL
        if selfFrame._elapsed >= interval then
            selfFrame._elapsed = 0
            DistanceMonitor:Refresh()
        end
    end)

    self._intervalRefresher = self._intervalRefresher or C_Timer.NewTicker(2, function()
        if frame then
            frame._cachedInterval = math.max(0.05,
                math.min(1, tonumber(GetConfig().updateInterval) or DEFAULT_UPDATE_INTERVAL))
        end
    end)
    frame._cachedInterval = math.max(0.05, math.min(1, tonumber(GetConfig().updateInterval) or DEFAULT_UPDATE_INTERVAL))

    self.frame = frame
    self:Refresh()
end

function DistanceMonitor:RefreshFromSettings()
    local config = GetConfig()
    if not config then
        return
    end

    if not config.enabled then
        if self.frame then
            self.frame:Hide()
        end
        return
    end

    if not self.frame then
        self:CreateFrame()
    end

    if not self.frame then
        return
    end

    local pos = config.point or {}
    self.frame:ClearAllPoints()
    self.frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or -220, pos.y or -20)
    self:ApplyLayout()
    self:Refresh()
end

function DistanceMonitor:OnPlayerLogin()
    if GetConfig() and GetConfig().enabled then
        self:CreateFrame()
    end
end
