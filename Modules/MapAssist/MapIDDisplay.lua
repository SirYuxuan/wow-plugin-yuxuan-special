local _, NS = ...
local Core = NS.Core

local MapIDDisplay = {}
NS.Modules.MapAssist.MapIDDisplay = MapIDDisplay

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

--[[
地图辅助 / 地图ID
1. 在世界地图中显示当前选中的地图 ID
2. 只有启用时才会创建显示面板和更新脚本
3. 关闭后会停止刷新并隐藏面板，避免继续占用运行时更新开销

这里的“地图 ID”取自 WorldMapFrame 当前正在查看的地图，
所以无论是玩家自己切图，还是暴雪界面自动切换地图，文本都会跟着更新。
]]

MapIDDisplay.ANCHOR_PRESETS = {
    MAP_TOP = {
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = 260,
        y = -34,
    },
    MAP_BOTTOM = {
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = 260,
        y = 10,
    },
}

function MapIDDisplay:GetConfig()
    return Core:GetConfig("mapAssist", "mapIDDisplay")
end

function MapIDDisplay:GetAnchorPreset()
    local config = self:GetConfig()
    local presetKey = config and config.anchorPreset or "MAP_TOP"
    return self.ANCHOR_PRESETS[presetKey] or self.ANCHOR_PRESETS.MAP_TOP
end

function MapIDDisplay:GetCurrentMapID()
    if not WorldMapFrame or not WorldMapFrame.GetMapID then
        return nil
    end

    return WorldMapFrame:GetMapID()
end

function MapIDDisplay:GetDisplayText()
    local mapID = self:GetCurrentMapID()
    if not mapID then
        return "地图ID: --"
    end

    return string.format("地图ID: %s", tostring(mapID))
end

function MapIDDisplay:ApplyPosition()
    if not self.panel or not WorldMapFrame then
        return
    end

    local config = self:GetConfig()
    local preset = self:GetAnchorPreset()

    self.panel:ClearAllPoints()
    self.panel:SetPoint(
        preset.point,
        WorldMapFrame,
        preset.relativePoint,
        preset.x + (config.offsetX or 0),
        preset.y + (config.offsetY or 0)
    )
end

function MapIDDisplay:ApplyScale()
    if not self.panel then
        return
    end

    local config = self:GetConfig()
    local scale = tonumber(config.scale) or 1
    scale = math.max(0.8, math.min(1.8, scale))

    self.panel:SetScale(scale)
end

function MapIDDisplay:ApplyBackground()
    if not self.panel then
        return
    end

    local config = self:GetConfig()
    local alpha = math.max(0, math.min(100, tonumber(config.bgAlpha) or 30)) / 100
    local borderAlpha = alpha > 0 and math.min(alpha + 0.15, 1) or 0

    self.panel:SetBackdropColor(0.05, 0.05, 0.06, alpha)
    self.panel:SetBackdropBorderColor(0.28, 0.28, 0.32, borderAlpha)
end

function MapIDDisplay:ApplyFont()
    if not self.text then
        return
    end

    local config = self:GetConfig()
    local fontSize = math.max(10, math.min(28, tonumber(config.fontSize) or 12))
    local optionsPrivate = GetOptionsPrivate()
    local panelHeight = math.max(28, fontSize + 14)

    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(self.text, fontSize, "", config.fontPreset)
    else
        self.text:SetFont(STANDARD_TEXT_FONT, fontSize, "")
    end

    if self.panel then
        self.panel:SetHeight(panelHeight)
    end

    local color = config.textColor or {}
    self.text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
end

function MapIDDisplay:UpdateText(force)
    if not self.text then
        return
    end

    local mapID = self:GetCurrentMapID()
    if not force and self.currentMapID == mapID then
        return
    end

    self.currentMapID = mapID
    self.text:SetText(self:GetDisplayText())

    local textWidth = math.max(88, (self.text:GetStringWidth() or 0) + 24)
    self.panel:SetWidth(textWidth)
end

function MapIDDisplay:RefreshVisibility()
    if not self.panel then
        return
    end

    local config = self:GetConfig()
    local shouldShow = config and config.enabled and WorldMapFrame and WorldMapFrame:IsShown()
    self.panel:SetShown(shouldShow and true or false)

    if shouldShow then
        self.panel:SetScript("OnUpdate", function(_, elapsed)
            MapIDDisplay.elapsed = (MapIDDisplay.elapsed or 0) + elapsed
            if MapIDDisplay.elapsed < 0.10 then
                return
            end

            MapIDDisplay.elapsed = 0
            MapIDDisplay:UpdateText(false)
        end)
    else
        self.panel:SetScript("OnUpdate", nil)
        self.elapsed = 0
    end
end

function MapIDDisplay:CreatePanel()
    if self.panel or not WorldMapFrame then
        return
    end

    local panel = CreateFrame("Frame", nil, WorldMapFrame, "BackdropTemplate")
    panel:SetSize(100, 28)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1) + 20)
    panel:Hide()
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", panel, "LEFT", 12, 0)
    text:SetJustifyH("LEFT")
    text:SetText("地图ID: --")

    self.panel = panel
    self.text = text
end

function MapIDDisplay:RefreshFromSettings()
    local config = self:GetConfig()
    if not WorldMapFrame or not config then
        return
    end

    if not config.enabled then
        self.currentMapID = nil
        if self.panel then
            self.panel:Hide()
            self.panel:SetScript("OnUpdate", nil)
        end
        self.elapsed = 0
        return
    end

    self:CreatePanel()
    self:ApplyPosition()
    self:ApplyScale()
    self:ApplyBackground()
    self:ApplyFont()
    self:UpdateText(true)
    self:RefreshVisibility()
end

function MapIDDisplay:Initialize()
    if self.initialized or not WorldMapFrame then
        return
    end

    self.initialized = true

    WorldMapFrame:HookScript("OnShow", function()
        MapIDDisplay:RefreshFromSettings()
    end)
    WorldMapFrame:HookScript("OnHide", function()
        MapIDDisplay:RefreshVisibility()
    end)

    if WorldMapFrame.SetMapID then
        hooksecurefunc(WorldMapFrame, "SetMapID", function()
            MapIDDisplay:UpdateText(false)
        end)
    end
end

function MapIDDisplay:OnWorldMapLoaded()
    self:Initialize()
    self:RefreshFromSettings()
end

function MapIDDisplay:OnPlayerLogin()
    if WorldMapFrame then
        self:Initialize()
        self:RefreshFromSettings()
    end
end
