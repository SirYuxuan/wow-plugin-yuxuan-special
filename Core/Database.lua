local _, NS = ...
local Core = NS.Core

--[[
数据库按 模块 -> 功能 分层 避免后续功能一多就堆成平铺字段
当前结构示意

YuXuanSpecialDB = {
    mapAssist = {
        quickWaypoint = { ... }
    },
    combatAssist = {
        trinketMonitor = { ... }
    },
    classAssist = {
        mage = {
            shatterIndicator = { ... }
        }
    }
}
]]

NS.DEFAULTS = {
    mapAssist = {
        quickWaypoint = {
            enabled = true,
            anchorPreset = "MAP_TOP",
            offsetX = 0,
            offsetY = 0,
            fontSize = 12,
            bgAlpha = 35,
        },
    },
    combatAssist = {
        trinketMonitor = {
            enabled = false,
            unlocked = false,
            combatOnly = false,
            iconSize = 44,
            spacing = 8,
            offsetX = 0,
            offsetY = -220,
            showText = true,
            textSize = 14,
            textPosition = "BOTTOM",
            textColor = {
                r = 1.00,
                g = 1.00,
                b = 1.00,
                a = 1.00,
            },
            highlightReady = true,
            highlightColor = {
                r = 1.00,
                g = 0.82,
                b = 0.20,
                a = 1.00,
            },
            showReadyAlert = true,
            readyText = "饰品好了！",
            readyTextSize = 28,
            readyTextColor = {
                r = 1.00,
                g = 0.82,
                b = 0.20,
                a = 1.00,
            },
            playReadySound = true,
            readySoundPath = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Audio\\SP.mp3",
            readyOffsetX = 0,
            readyOffsetY = 180,
            alertDuration = 1.5,
            blockedItemIDs = "",
        },
    },
    classAssist = {
        mage = {
            shatterIndicator = {
                enabled = false,
                unlocked = false,
                showIcon = true,
                showBorders = true,
                showOutOfCombat = false,
                width = 14,
                height = 18,
                spacing = 2,
                scale = 1.0,
                texture = "纯色",
                defaultColor = {
                    r = 0.25,
                    g = 0.75,
                    b = 1.00,
                    a = 1.00,
                },
                monitorList = {
                    {
                        count = 6,
                        color = { r = 0.30, g = 0.85, b = 1.00, a = 1.00 },
                    },
                    {
                        count = 12,
                        color = { r = 1.00, g = 0.82, b = 0.20, a = 1.00 },
                    },
                    {
                        count = 18,
                        color = { r = 1.00, g = 0.30, b = 0.30, a = 1.00 },
                    },
                },
            },
        },
    },
}

local function CloneTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CloneTable(value)
    end
    return copy
end

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Core:InitializeDatabase()
    YuXuanSpecialDB = YuXuanSpecialDB or {}
    self.db = YuXuanSpecialDB
    ApplyDefaults(self.db, NS.DEFAULTS)
end

function Core:GetConfig(...)
    local current = self.db
    for index = 1, select("#", ...) do
        current = current and current[select(index, ...)]
    end
    return current
end

function Core:ResetQuickWaypointConfig()
    self.db.mapAssist = self.db.mapAssist or {}
    self.db.mapAssist.quickWaypoint = CloneTable(NS.DEFAULTS.mapAssist.quickWaypoint)
    return self.db.mapAssist.quickWaypoint
end

function Core:ResetTrinketMonitorConfig()
    self.db.combatAssist = self.db.combatAssist or {}
    self.db.combatAssist.trinketMonitor = CloneTable(NS.DEFAULTS.combatAssist.trinketMonitor)
    return self.db.combatAssist.trinketMonitor
end

function Core:ResetMageShatterIndicatorConfig()
    self.db.classAssist = self.db.classAssist or {}
    self.db.classAssist.mage = self.db.classAssist.mage or {}
    self.db.classAssist.mage.shatterIndicator = CloneTable(NS.DEFAULTS.classAssist.mage.shatterIndicator)
    return self.db.classAssist.mage.shatterIndicator
end
