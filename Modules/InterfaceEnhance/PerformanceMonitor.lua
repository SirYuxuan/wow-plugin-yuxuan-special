local addonName, NS = ...
local Core = NS.Core

local PerformanceMonitor = {}
NS.Modules.InterfaceEnhance.PerformanceMonitor = PerformanceMonitor
local LibSharedMedia = LibStub("LibSharedMedia-3.0")

local function PMcfg()
    local profile = Core.db and Core.db.interfaceEnhance or {}
    profile.performanceMonitor = profile.performanceMonitor or {}
    local cfg = profile.performanceMonitor

    if cfg.enabled == nil then cfg.enabled = true end
    if cfg.locked == nil then cfg.locked = true end
    if cfg.font == nil or cfg.font == "" then cfg.font = "Friz Quadrata TT" end
    if cfg.fontSize == nil then cfg.fontSize = 14 end
    if cfg.updateInterval == nil then cfg.updateInterval = 1 end
    if cfg.showBackground == nil then cfg.showBackground = true end
    if cfg.showBorder == nil then cfg.showBorder = false end
    if type(cfg.backgroundColor) ~= "table" then
        cfg.backgroundColor = { r = 0, g = 0, b = 0, a = 0.32 }
    elseif cfg.backgroundColor.a == nil then
        cfg.backgroundColor.a = 0.32
    end
    if type(cfg.borderColor) ~= "table" then
        cfg.borderColor = { r = 0, g = 0.6, b = 1, a = 0.45 }
    elseif cfg.borderColor.a == nil then
        cfg.borderColor.a = 0.45
    end
    if type(cfg.point) ~= "table" then
        cfg.point = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 220,
            y = -20,
        }
    end

    return cfg
end

local function CreateSimpleOutline(parent, layer, thickness)
    local border = {}
    local size = thickness or 1

    border.top = parent:CreateTexture(nil, layer or "BORDER")
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.top:SetHeight(size)

    border.bottom = parent:CreateTexture(nil, layer or "BORDER")
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.bottom:SetHeight(size)

    border.left = parent:CreateTexture(nil, layer or "BORDER")
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.left:SetWidth(size)

    border.right = parent:CreateTexture(nil, layer or "BORDER")
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.right:SetWidth(size)

    return border
end

local function SetSimpleOutlineColor(border, r, g, b, a)
    if type(border) ~= "table" then return end
    for _, edge in pairs(border) do
        edge:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
    end
end

local function GetAddOnInfoCompat(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local info = C_AddOns.GetAddOnInfo(index)
        if type(info) == "table" then
            return info.name or info.Name, info.title or info.Title
        end
        return info
    end

    local getAddOnInfo = rawget(_G, "GetAddOnInfo")
    if getAddOnInfo then
        local name, title = getAddOnInfo(index)
        return name, title
    end
end

local function GetNumAddOnsCompat()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return C_AddOns.GetNumAddOns()
    end

    local getNumAddOns = rawget(_G, "GetNumAddOns")
    return getNumAddOns and getNumAddOns() or 0
end

local function IsAddOnLoadedCompat(indexOrName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(indexOrName)
    end

    local isAddOnLoaded = rawget(_G, "IsAddOnLoaded")
    return isAddOnLoaded and isAddOnLoaded(indexOrName) or false
end

local function FormatMemoryUsage(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then
        return string.format("%.2f MB", kb / 1024)
    end
    return string.format("%.0f KB", kb)
end

local function CollectAddOnMemoryRows()
    local rows = {}
    local total = 0

    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end

    for i = 1, GetNumAddOnsCompat() do
        local name, title = GetAddOnInfoCompat(i)
        if name and IsAddOnLoadedCompat(i) then
            local memory = (GetAddOnMemoryUsage and GetAddOnMemoryUsage(i)) or 0
            total = total + memory
            table.insert(rows, {
                name = title and title ~= "" and title or name,
                memory = memory,
            })
        end
    end

    table.sort(rows, function(a, b)
        if a.memory == b.memory then
            return a.name < b.name
        end
        return a.memory > b.memory
    end)

    return total, rows
end

local function GetPerformanceText()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, _, world = GetNetStats()
    local latency = tonumber(world) or 0
    return string.format("%d FPS  %d MS", fps, latency)
end

local function GetMetricColorHex(value, metric)
    value = tonumber(value) or 0
    if metric == "fps" then
        if value >= 50 then
            return "ff33ff66"
        elseif value >= 30 then
            return "ffffcc33"
        end
        return "ffff5555"
    end

    if value <= 80 then
        return "ff33ff66"
    elseif value <= 150 then
        return "ffffcc33"
    end
    return "ffff5555"
end

local function BuildPerformanceText(fps, latency)
    return string.format(
        "FPS锛殀c%s%d|r MS锛殀c%s%d|r",
        GetMetricColorHex(fps, "fps"),
        tonumber(fps) or 0,
        GetMetricColorHex(latency, "ms"),
        tonumber(latency) or 0
    )
end

local function ApplyPerformanceMonitorFont(frame)
    if not frame or not frame.text then return end

    local cfg = PMcfg()
    local fontPath = LibSharedMedia and LibSharedMedia.Fetch and LibSharedMedia:Fetch("font", cfg.font) or nil
    if not fontPath or fontPath == "" then
        fontPath = STANDARD_TEXT_FONT
    end

    if not frame.text:SetFont(fontPath, cfg.fontSize or 14, "OUTLINE") then
        frame.text:SetFont(STANDARD_TEXT_FONT, cfg.fontSize or 14, "OUTLINE")
    end
end

function Core:SavePerformanceMonitorPosition()
    if not self.performanceMonitorFrame then return end
    local point, _, relativePoint, x, y = self.performanceMonitorFrame:GetPoint(1)
    local pos = PMcfg().point
    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = math.floor((x or 0) + 0.5)
    pos.y = math.floor((y or 0) + 0.5)
end

function Core:UpdatePerformanceMonitorVisibility()
    if not self.performanceMonitorFrame then return end
    if PMcfg().enabled then
        self.performanceMonitorFrame:Show()
    else
        self.performanceMonitorFrame:Hide()
    end
end

function Core:UpdatePerformanceMonitorLayout()
    if not self.performanceMonitorFrame then return end

    local cfg = PMcfg()
    local frame = self.performanceMonitorFrame

    frame:SetMovable(not cfg.locked)
    ApplyPerformanceMonitorFont(frame)
    frame.text:SetPoint("LEFT", frame, "LEFT", 6, 0)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

    local width = math.max(110, math.ceil(frame.text:GetStringWidth() + 14))
    frame:SetSize(width, 24)

    if cfg.showBackground then
        local bg = cfg.backgroundColor or { r = 0, g = 0, b = 0, a = 0.32 }
        frame.bg:SetColorTexture(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.32)
    else
        frame.bg:SetColorTexture(0, 0, 0, 0)
    end

    SetSimpleOutlineColor(frame.border, 0, 0, 0, 0)
end

function Core:RefreshPerformanceMonitor()
    if not self.performanceMonitorFrame then return end

    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, _, world = GetNetStats()
    local latency = tonumber(world) or 0
    local frame = self.performanceMonitorFrame

    ApplyPerformanceMonitorFont(frame)
    frame.text:SetTextColor(1, 1, 1, 1)
    frame.text:SetText(BuildPerformanceText(fps, latency))

    self:UpdatePerformanceMonitorLayout()
    self:UpdatePerformanceMonitorVisibility()
end

function Core:RefreshPerformanceMonitorTooltip()
    if not self.performanceMonitorFrame then return end

    local frame = self.performanceMonitorFrame
    local total, rows = CollectAddOnMemoryRows()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, home, world = GetNetStats()

    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("鎬ц兘鐩戞帶", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("FPS", tostring(fps), 1, 1, 1, 0.25, 1, 0.4)
    GameTooltip:AddDoubleLine("鏈湴寤惰繜", string.format("%d ms", tonumber(home) or 0), 1, 1, 1, 0.35, 0.8, 1)
    GameTooltip:AddDoubleLine("涓栫晫寤惰繜", string.format("%d ms", tonumber(world) or 0), 1, 1, 1, 0.35, 0.8, 1)
    GameTooltip:AddDoubleLine("鎻掍欢鎬诲唴瀛?, FormatMemoryUsage(total), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, entry in ipairs(rows) do
        GameTooltip:AddDoubleLine(entry.name, FormatMemoryUsage(entry.memory), 1, 1, 1, 0.75, 0.9, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Shift + 宸﹂敭锛氱珛鍗冲洖鏀跺唴瀛?, 1, 1, 1)
    GameTooltip:Show()
end

function Core:UpdatePerformanceMonitorTicker()
    if self.performanceMonitorTicker then
        self.performanceMonitorTicker:Cancel()
        self.performanceMonitorTicker = nil
    end

    local cfg = PMcfg()
    if not cfg.enabled then return end

    self.performanceMonitorTicker = C_Timer.NewTicker(math.max(0.2, tonumber(cfg.updateInterval) or 1), function()
        Core:RefreshPerformanceMonitor()
    end)
end

function Core:ApplyPerformanceMonitorSettings()
    if not self.performanceMonitorFrame then
        self:CreatePerformanceMonitorFrame()
    end

    self:RefreshPerformanceMonitor()
    self:UpdatePerformanceMonitorLayout()
    self:UpdatePerformanceMonitorVisibility()
    self:UpdatePerformanceMonitorTicker()
end

function Core:CreatePerformanceMonitorFrame()
    if self.performanceMonitorFrame then return end

    local frame = CreateFrame("Button", addonName .. "PerformanceMonitor", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetSize(110, 24)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)


    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")

    local pos = PMcfg().point
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 220, pos.y or -20)

    frame:SetScript("OnEnter", function(self)
        Core:RefreshPerformanceMonitorTooltip()
        if self.tooltipTicker then
            self.tooltipTicker:Cancel()
        end
        self.tooltipTicker = C_Timer.NewTicker(math.max(0.2, tonumber(PMcfg().updateInterval) or 1), function()
            if GameTooltip:IsOwned(self) then
                Core:RefreshPerformanceMonitor()
                Core:RefreshPerformanceMonitorTooltip()
            end
        end)
    end)
    frame:SetScript("OnLeave", function(self)
        if self.tooltipTicker then
            self.tooltipTicker:Cancel()
            self.tooltipTicker = nil
        end
        GameTooltip:Hide()
    end)
    frame:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" and IsShiftKeyDown() then
            collectgarbage("collect")
            if UpdateAddOnMemoryUsage then
                UpdateAddOnMemoryUsage()
            end
            Core:RefreshPerformanceMonitor()
            if GameTooltip:IsOwned(frame) then
                Core:RefreshPerformanceMonitorTooltip()
            end
        end
    end)
    frame:SetScript("OnDragStart", function(self)
        if PMcfg().locked then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Core:SavePerformanceMonitorPosition()
    end)

    self.performanceMonitorFrame = frame
end

function PerformanceMonitor:OnPlayerLogin()
    Core:ApplyPerformanceMonitorSettings()
end

function PerformanceMonitor:RefreshFromSettings()
    Core:ApplyPerformanceMonitorSettings()
end

