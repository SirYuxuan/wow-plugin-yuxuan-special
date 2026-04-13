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

    if not subCommand or subCommand == "" then
        if NS.Options:EnsureRegistered() then
            NS.Options:Toggle()
            return
        end
    end

    local handlers = {
        map     = function() return NS.Options:OpenMapAssist() end,
        nav     = function() return NS.Options:OpenQuickWaypoint() end,
        combat  = function() return NS.Options:OpenCombatAssist() end,
        db      = function() return NS.Options:OpenGreatVault() end,
        vault   = function() return NS.Options:OpenGreatVault() end,
        trinket = function() return NS.Options:OpenTrinketMonitor() end,
        mage    = function() return NS.Options:OpenMageAssist() end,
        frost   = function() return NS.Options:OpenMageFrostAssist() end,
        close   = function()
            NS.Options:Close()
            return true
        end,
    }

    if subCommand == "log" or subCommand == "update" or subCommand == "changelog" then
        local updateLog = NS.Modules
            and NS.Modules.InterfaceEnhance
            and NS.Modules.InterfaceEnhance.UpdateLog
        if updateLog and updateLog.Open then
            updateLog:Open(false)
            return
        end
    end

    local handler = handlers[subCommand]
    if handler and handler() then
        return
    end

    Core:Print("无法打开配置窗口")
end

function Core:RegisterSlashCommands()
    SLASH_YUXUANSPECIAL1 = "/yxs"
    SlashCmdList.YUXUANSPECIAL = OpenSettingsByCommand
end
