local _, NS = ...
local Core = NS.Core

local function HandleMemoryAuditCommand(input)
    local audit = NS.MemoryAudit
    if not audit or not audit.Initialize then
        Core:Print("内存审计模块尚未初始化")
        return true
    end

    audit:Initialize()

    local commandText = strtrim(tostring(input or ""))
    local action, rest = commandText:match("^(%S+)%s*(.-)$")
    action = action or ""

    if action == "" or action == "report" then
        audit:Report()
        return true
    end

    if action == "start" then
        audit:StartSampling(tonumber(rest))
        return true
    end

    if action == "stop" then
        audit:StopSampling()
        return true
    end

    if action == "reset" then
        audit:Reset()
        if audit.EmitLine then
            audit:EmitLine("内存审计统计已清空", true)
        else
            Core:Print("内存审计统计已清空")
        end
        return true
    end

    if action == "modules" then
        audit:ReportModules()
        return true
    end

    Core:Print("用法: /yxs mem start|stop|report|reset|modules")
    return true
end

local function HandleDebugCommand(input)
    local audit = NS.MemoryAudit
    if not audit or not audit.Initialize then
        Core:Print("调试窗口模块尚未初始化")
        return true
    end

    audit:Initialize()

    local action = strtrim(tostring(input or ""))
    if action == "" or action == "open" or action == "show" then
        if audit.ShowDebugWindow then
            audit:ShowDebugWindow()
        end
        return true
    end

    if action == "copy" then
        if audit.CopyDebugOutput then
            audit:CopyDebugOutput()
        end
        return true
    end

    if action == "clear" then
        if audit.ClearDebugOutput then
            audit:ClearDebugOutput()
        end
        return true
    end

    if action == "close" or action == "hide" then
        if audit.HideDebugWindow then
            audit:HideDebugWindow()
        end
        return true
    end

    Core:Print("用法: /yxs debug [copy|clear|close]")
    return true
end

--[[
/yxs 是插件唯一入口
这里单独收口 后续新增子命令时不需要到处散改
]]

local function OpenSettingsByCommand(message)
    local input = strlower(strtrim(tostring(message or "")))
    local subCommand, rest = input:match("^(%S+)%s*(.-)$")

    if subCommand == "mem" then
        return HandleMemoryAuditCommand(strlower(strtrim(rest or "")))
    end

    if subCommand == "debug" then
        return HandleDebugCommand(strlower(strtrim(rest or "")))
    end

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
    elseif input == "log" or input == "update" or input == "changelog" then
        local updateLog = NS.Modules
            and NS.Modules.InterfaceEnhance
            and NS.Modules.InterfaceEnhance.UpdateLog
        if updateLog and updateLog.Open then
            updateLog:Open(false)
            return
        end
    elseif input == "close" then
        NS.Options:Close()
        return
    end

    Core:Print("无法打开配置窗口")
end

function Core:RegisterSlashCommands()
    SLASH_YUXUANSPECIAL1 = "/yxs"
    SlashCmdList.YUXUANSPECIAL = OpenSettingsByCommand
end
