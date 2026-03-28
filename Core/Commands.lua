local _, NS = ...
local Core = NS.Core

--[[
/yxs 是插件唯一入口
这里单独收口 后续新增子命令时不需要到处散改
]]

local function OpenSettingsByCommand(message)
    local input = strlower(strtrim(tostring(message or "")))

    if not NS.Options then
        Core:Print("配置模块尚未初始化")
        return
    end

    if input == "" then
        if NS.Options:EnsureRegistered() then
            NS.Options:Toggle()
            return
        end
    elseif input == "map" then
        if NS.Options:OpenMapAssist() then
            return
        end
    elseif input == "nav" then
        if NS.Options:OpenQuickWaypoint() then
            return
        end
    elseif input == "combat" then
        if NS.Options:OpenCombatAssist() then
            return
        end
    elseif input == "trinket" then
        if NS.Options:OpenTrinketMonitor() then
            return
        end
    elseif input == "mage" then
        if NS.Options:OpenMageAssist() then
            return
        end
    elseif input == "frost" then
        if NS.Options:OpenMageFrostAssist() then
            return
        end
    elseif input == "close" then
        NS.Options:Close()
        return
    end

    Core:Print("无法打开配置窗口 请确认 Ace3 已安装并启用")
end

function Core:RegisterSlashCommands()
    SLASH_YUXUANSPECIAL1 = "/yxs"
    SlashCmdList.YUXUANSPECIAL = OpenSettingsByCommand
end
