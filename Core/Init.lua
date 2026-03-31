local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.DISPLAY_NAME = "雨轩专用插件"
NS.VERSION = "0.3.0"
NS.Modules = NS.Modules or {}
NS.Modules.MapAssist = NS.Modules.MapAssist or {}
NS.Modules.InterfaceEnhance = NS.Modules.InterfaceEnhance or {}
NS.Modules.CombatAssist = NS.Modules.CombatAssist or {}
NS.Modules.ClassAssist = NS.Modules.ClassAssist or {}
NS.Modules.ClassAssist.Mage = NS.Modules.ClassAssist.Mage or {}
NS.Options = NS.Options or {}

local Core = {}
NS.Core = Core

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

function Core:OnAddonLoaded()
    self:InitializeDatabase()
    self:RegisterSlashCommands()
end

function Core:OnPlayerLogin()
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.OnPlayerLogin then
        quickWaypoint:OnPlayerLogin()
    end

    local quartermasterPins = NS.Modules.MapAssist and NS.Modules.MapAssist.QuartermasterPins
    if quartermasterPins and quartermasterPins.OnPlayerLogin then
        quartermasterPins:OnPlayerLogin()
    end

    local quickChat = NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.QuickChat
    if quickChat and quickChat.OnPlayerLogin then
        quickChat:OnPlayerLogin()
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
end

function Core:OnWorldMapLoaded()
    local quickWaypoint = NS.Modules.MapAssist and NS.Modules.MapAssist.QuickWaypoint
    if quickWaypoint and quickWaypoint.OnWorldMapLoaded then
        quickWaypoint:OnWorldMapLoaded()
    end

    local quartermasterPins = NS.Modules.MapAssist and NS.Modules.MapAssist.QuartermasterPins
    if quartermasterPins and quartermasterPins.OnWorldMapLoaded then
        quartermasterPins:OnWorldMapLoaded()
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
