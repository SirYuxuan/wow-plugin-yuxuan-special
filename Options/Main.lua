local addonName, NS = ...

local Options = NS.Options

local AceConfig = LibStub and LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)

--[[
配置窗口走独立 AceConfig 弹窗 不注册进暴雪设置页面
这样交互方式更接近原来的 YuXuanToolbox

这里额外处理两件事
1. 给 AceConfig 窗口补一个稳定的拖拽区域
2. 自己保存窗口位置 避免 NotifyChange 时窗口跳回初始位置
]]

local function GetOpenDialogFrame()
    local openFrame = AceConfigDialog
        and AceConfigDialog.OpenFrames
        and AceConfigDialog.OpenFrames[addonName]
    return openFrame and openFrame.frame or nil
end

local function BuildAboutOptions()
    return {
        type = "group",
        name = "关于",
        order = 999,
        args = {
            title = {
                type = "header",
                order = 1,
                name = NS.DISPLAY_NAME,
            },
            version = {
                type = "description",
                order = 2,
                fontSize = "medium",
                name = function()
                    return "|cFFFFCC00版本|r " .. NS.VERSION
                end,
            },
            spacer1 = {
                type = "description",
                order = 3,
                name = " ",
                width = "full",
            },
            desc = {
                type = "description",
                order = 4,
                fontSize = "medium",
                name = "当前版本包含地图辅助与职业辅助 并使用独立弹窗进行配置",
            },
            commandHeader = {
                type = "header",
                order = 10,
                name = "命令",
            },
            cmd1 = {
                type = "description",
                order = 11,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs|r - 打开或关闭配置窗口",
            },
            cmd2 = {
                type = "description",
                order = 12,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs map|r - 打开地图辅助",
            },
            cmd3 = {
                type = "description",
                order = 13,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs nav|r - 打开快捷导航",
            },
            cmd4 = {
                type = "description",
                order = 14,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs mage|r - 打开法师辅助",
            },
            cmd5 = {
                type = "description",
                order = 15,
                fontSize = "medium",
                name = "|cFFFFFF00/yxs frost|r - 打开冰霜专精页",
            },
        },
    }
end

local function GetOptionsTable()
    return {
        name = string.format("|cFF33FF99%s|r  v%s", NS.DISPLAY_NAME, NS.VERSION),
        type = "group",
        childGroups = "tree",
        args = {
            mapAssist = NS.BuildMapAssistOptions(),
            classAssist = NS.BuildClassAssistOptions(),
            about = BuildAboutOptions(),
        },
    }
end

function Options:CaptureWindowPlacement()
    local aceFrame = GetOpenDialogFrame()
    if not aceFrame then
        return
    end

    self.windowPlacement = self.windowPlacement or {}
    self.windowPlacement.left = aceFrame:GetLeft()
    self.windowPlacement.top = aceFrame:GetTop()
    self.windowPlacement.width = aceFrame:GetWidth()
    self.windowPlacement.height = aceFrame:GetHeight()

    local obj = aceFrame.obj
    local status = obj and (obj.status or obj.localstatus)
    if status then
        status.left = self.windowPlacement.left
        status.top = self.windowPlacement.top
        status.width = self.windowPlacement.width
        status.height = self.windowPlacement.height
    end
end

function Options:RestoreWindowPlacement()
    local aceFrame = GetOpenDialogFrame()
    local placement = self.windowPlacement
    if not aceFrame or not placement then
        return
    end

    if placement.width and placement.height then
        aceFrame:SetSize(placement.width, placement.height)
    end

    if placement.left and placement.top then
        aceFrame:ClearAllPoints()
        aceFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", placement.left, placement.top)
    end

    local obj = aceFrame.obj
    local status = obj and (obj.status or obj.localstatus)
    if status then
        status.left = placement.left
        status.top = placement.top
        status.width = placement.width
        status.height = placement.height
    end
end

local function EnhanceDialogDrag()
    local aceFrame = GetOpenDialogFrame()
    if not aceFrame then
        return
    end

    aceFrame:SetUserPlaced(true)

    if not aceFrame._yxsDragRegion then
        local dragRegion = CreateFrame("Frame", nil, aceFrame)
        dragRegion:SetPoint("TOPLEFT", aceFrame, "TOPLEFT", 0, 0)
        dragRegion:SetPoint("TOPRIGHT", aceFrame, "TOPRIGHT", -28, 0)
        dragRegion:SetHeight(28)
        dragRegion:EnableMouse(true)
        dragRegion:RegisterForDrag("LeftButton")
        dragRegion:SetFrameLevel(aceFrame:GetFrameLevel() + 10)
        dragRegion:SetScript("OnDragStart", function()
            aceFrame:StartMoving()
        end)
        dragRegion:SetScript("OnDragStop", function()
            aceFrame:StopMovingOrSizing()
            Options:CaptureWindowPlacement()
        end)
        aceFrame._yxsDragRegion = dragRegion
    end

    if not aceFrame._yxsPlacementHooked then
        aceFrame:HookScript("OnSizeChanged", function()
            Options:CaptureWindowPlacement()
        end)
        aceFrame:HookScript("OnHide", function()
            Options:CaptureWindowPlacement()
        end)
        aceFrame._yxsPlacementHooked = true
    end

    Options:RestoreWindowPlacement()
end

function Options:NotifyChanged()
    if not AceConfigRegistry then
        return
    end

    self:CaptureWindowPlacement()
    AceConfigRegistry:NotifyChange(addonName)

    C_Timer.After(0, function()
        Options:RestoreWindowPlacement()
    end)
    C_Timer.After(0.05, function()
        Options:RestoreWindowPlacement()
    end)
end

function Options:IsAceAvailable()
    return AceConfig ~= nil and AceConfigDialog ~= nil
end

function Options:EnsureRegistered()
    if self.registered then
        return true
    end

    if not self:IsAceAvailable() then
        return false
    end

    AceConfig:RegisterOptionsTable(addonName, GetOptionsTable)
    AceConfigDialog:SetDefaultSize(addonName, 820, 620)
    self.registered = true
    return true
end

function Options:IsOpen()
    return GetOpenDialogFrame() ~= nil
end

function Options:Open(...)
    if not self:EnsureRegistered() then
        return false
    end

    AceConfigDialog:Open(addonName, ...)
    C_Timer.After(0, EnhanceDialogDrag)
    C_Timer.After(0.05, EnhanceDialogDrag)
    return true
end

function Options:Close()
    if AceConfigDialog then
        self:CaptureWindowPlacement()
        AceConfigDialog:Close(addonName)
    end
end

function Options:Toggle(...)
    if self:IsOpen() then
        self:Close()
    else
        self:Open(...)
    end
end

function Options:OpenMapAssist()
    return self:Open("mapAssist")
end

function Options:OpenQuickWaypoint()
    return self:Open("mapAssist", "quickWaypoint")
end

function Options:OpenMageAssist()
    return self:Open("classAssist", "mage")
end

function Options:OpenMageFrostAssist()
    return self:Open("classAssist", "mage", "frost")
end
