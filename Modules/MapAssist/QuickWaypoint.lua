local _, NS = ...
local Core = NS.Core

local QuickWaypoint = {}
NS.Modules.MapAssist.QuickWaypoint = QuickWaypoint

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

--[[
地图辅助 / 快捷导航
1. 在世界地图左上或下方内嵌一个坐标输入框
2. 解析玩家输入的百分比坐标
3. 调用暴雪原生 API 设置用户导航点

这里只处理运行时显示和输入行为
配置页面由 Options 目录单独负责
]]

QuickWaypoint.ANCHOR_PRESETS = {
    MAP_TOP = {
        label = "地图上方",
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = 14,
        y = -34,
    },
    MAP_BOTTOM = {
        label = "地图下方",
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = 14,
        y = 10,
    },
}

local function NormalizeCoordinateInput(text)
    text = tostring(text or "")
    text = text:gsub("，", ",")
    text = text:gsub("：", ":")
    text = text:gsub("；", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function ParseCoordinates(text)
    local normalized = NormalizeCoordinateInput(text)
    local xText, yText = normalized:match("^(%d+%.?%d*)[, :]+(%d+%.?%d*)$")
    if not xText or not yText then
        return nil, nil
    end

    local x = tonumber(xText)
    local y = tonumber(yText)
    if not x or not y then
        return nil, nil
    end

    if x > 1 or y > 1 then
        x = x / 100
        y = y / 100
    end

    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, nil
    end

    return x, y
end

function QuickWaypoint:GetConfig()
    return Core:GetConfig("mapAssist", "quickWaypoint")
end

function QuickWaypoint:GetAnchorPreset()
    local config = self:GetConfig()
    local presetKey = config and config.anchorPreset or "MAP_TOP"
    return self.ANCHOR_PRESETS[presetKey] or self.ANCHOR_PRESETS.MAP_TOP
end

function QuickWaypoint:Notify(message)
    Core:Print(message)
end

function QuickWaypoint:UpdateInputHint()
    if not self.inputBox or not self.inputBox.hint then
        return
    end
    self.inputBox.hint:SetShown(self.inputBox:GetText() == "")
end

function QuickWaypoint:ApplyWaypoint()
    if not self.inputBox then
        return
    end

    local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
    if not mapID then
        self:Notify("当前地图不可用")
        return
    end

    local x, y = ParseCoordinates(self.inputBox:GetText())
    if not x or not y then
        self:Notify("坐标格式错误 示例 12.34 56.78")
        return
    end

    local waypoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
    if not waypoint then
        self:Notify("当前地图无法创建导航点")
        return
    end

    C_Map.SetUserWaypoint(waypoint)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end

    self:Notify(string.format("已设置导航点 %.2f, %.2f", x * 100, y * 100))
    self.inputBox:ClearFocus()
end

function QuickWaypoint:ApplyPosition()
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

function QuickWaypoint:ApplyBackground()
    if not self.panel then
        return
    end

    local config = self:GetConfig()
    local alpha = math.max(0, math.min(100, tonumber(config.bgAlpha) or 35)) / 100
    local borderAlpha = alpha > 0 and math.min(alpha + 0.15, 1) or 0
    self.panel:SetBackdropColor(0.05, 0.05, 0.06, alpha)
    self.panel:SetBackdropBorderColor(0.28, 0.28, 0.32, borderAlpha)
end

function QuickWaypoint:ApplyFontSize()
    if not self.panel then
        return
    end

    local config = self:GetConfig()
    local fontSize = math.max(10, math.min(24, tonumber(config.fontSize) or 12))
    local panelHeight = math.max(36, fontSize + 18)
    local inputHeight = math.max(24, fontSize + 10)

    self.panel:SetHeight(panelHeight)

    if self.inputBox then
        self.inputBox:SetHeight(inputHeight)
        local optionsPrivate = GetOptionsPrivate()
        if optionsPrivate and optionsPrivate.ApplyFont then
            optionsPrivate.ApplyFont(self.inputBox, fontSize, "")
        else
            self.inputBox:SetFont(STANDARD_TEXT_FONT, fontSize, "")
        end
    end

    if self.inputBox and self.inputBox.hint then
        local optionsPrivate = GetOptionsPrivate()
        if optionsPrivate and optionsPrivate.ApplyFont then
            optionsPrivate.ApplyFont(self.inputBox.hint, fontSize, "")
        else
            self.inputBox.hint:SetFont(STANDARD_TEXT_FONT, fontSize, "")
        end
    end

    if self.actionButton then
        self.actionButton:SetHeight(inputHeight)
        local buttonFont = self.actionButton.Text or self.actionButton:GetFontString()
        if buttonFont then
            local optionsPrivate = GetOptionsPrivate()
            if optionsPrivate and optionsPrivate.ApplyFont then
                optionsPrivate.ApplyFont(buttonFont, fontSize, "")
            else
                buttonFont:SetFont(STANDARD_TEXT_FONT, fontSize, "")
            end
        end
    end
end

function QuickWaypoint:RefreshVisibility()
    if not self.panel then
        return
    end

    local config = self:GetConfig()
    local shouldShow = config and config.enabled and WorldMapFrame and WorldMapFrame:IsShown()
    self.panel:SetShown(shouldShow and true or false)
end

function QuickWaypoint:RefreshFromSettings()
    if not self.panel then
        return
    end

    self:ApplyPosition()
    self:ApplyBackground()
    self:ApplyFontSize()
    self:UpdateInputHint()
    self:RefreshVisibility()
end

function QuickWaypoint:CreatePanel()
    if self.panel or not WorldMapFrame then
        return
    end

    local panel = CreateFrame("Frame", nil, WorldMapFrame, "BackdropTemplate")
    panel:SetSize(245, 40)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1) + 20)
    panel:Hide()
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    inputBox:SetSize(150, 24)
    inputBox:SetPoint("LEFT", panel, "LEFT", 10, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(32)
    inputBox:SetTextInsets(6, 6, 0, 0)

    inputBox.hint = inputBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    inputBox.hint:SetPoint("LEFT", inputBox, "LEFT", 8, 0)
    inputBox.hint:SetText("12.34 56.78")

    local actionButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    actionButton:SetSize(68, 24)
    actionButton:SetPoint("LEFT", inputBox, "RIGHT", 8, 0)
    actionButton:SetText("导航")

    actionButton:SetScript("OnClick", function()
        QuickWaypoint:ApplyWaypoint()
    end)
    inputBox:SetScript("OnTextChanged", function()
        QuickWaypoint:UpdateInputHint()
    end)
    inputBox:SetScript("OnEnterPressed", function()
        QuickWaypoint:ApplyWaypoint()
    end)
    inputBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    self.panel = panel
    self.inputBox = inputBox
    self.actionButton = actionButton
end

function QuickWaypoint:Initialize()
    if self.initialized or not WorldMapFrame then
        return
    end

    self.initialized = true
    self:CreatePanel()
    self:RefreshFromSettings()

    WorldMapFrame:HookScript("OnShow", function()
        QuickWaypoint:RefreshVisibility()
    end)
    WorldMapFrame:HookScript("OnHide", function()
        QuickWaypoint:RefreshVisibility()
    end)
end

function QuickWaypoint:OnWorldMapLoaded()
    self:Initialize()
end

function QuickWaypoint:OnPlayerLogin()
    if WorldMapFrame then
        self:Initialize()
    end
end
