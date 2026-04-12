local _, NS = ...
local Core = NS.Core

local selectedEntries = {
    skills = nil,
    buffs = nil,
}

local pendingIDs = {
    skills = "",
    buffs = "",
}

local createProfileName = ""
local renameProfileName = ""

local VIEW_DEFAULTS = {
    shape = "bar",
    barLength = 200,
    barThickness = 20,
    ringSize = 150,
    showGraphics = true,
    showText = true,
    showIcon = true,
    monitorType = "duration",
    hideWhenInactive = false,
    hideNoTarget = false,
    visibilityMode = "hide",
    x = 0,
    y = 0,
}

local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.GraphicMonitor
end

local function TrimOptionText(value)
    local text = tostring(value or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function NotifyGraphicMonitorChanged()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function GetProfileChoices()
    local module = GetModule()
    return module and module.GetProfileChoices and module:GetProfileChoices() or {}
end

local function GetCurrentProfileKey()
    local module = GetModule()
    return module and module.GetCurrentProfileKey and module:GetCurrentProfileKey() or ""
end

local function SyncProfileEditorState()
    local currentKey = GetCurrentProfileKey()
    if createProfileName == "" then
        createProfileName = ""
    end
    renameProfileName = currentKey or ""
end

local function GetProfileStatusText()
    local currentKey = GetCurrentProfileKey()
    if currentKey == "" then
        return "当前角色还没有技能监控配置。"
    end

    return string.format(
        "当前角色：%s\n当前技能监控配置：%s\n技能监控配置已独立存储，不再跟随全局主配置档切换。",
        tostring(Core:GetCurrentCharacterKey() or "Unknown"),
        tostring(currentKey)
    )
end

local function GetSystem()
    return NS.GraphicMonitorSystem
end

local function GetDB()
    local module = GetModule()
    if module and module.GetDatabase then
        return module:GetDatabase()
    end

    local db = Core:GetConfig("interfaceEnhance", "graphicMonitor")
    db.skills = type(db.skills) == "table" and db.skills or {}
    db.buffs = type(db.buffs) == "table" and db.buffs or {}
    return db
end

local function GetStore(storeKey)
    local db = GetDB()
    db[storeKey] = type(db[storeKey]) == "table" and db[storeKey] or {}
    return db[storeKey]
end

local function GetTrackedEntries(storeKey)
    local system = GetSystem()
    local stateKey = storeKey == "skills" and "trackedSkills" or "trackedBuffs"
    return (system and system.State and system.State.get and system.State.get(stateKey)) or {}
end

local function GetSelectedEntry(storeKey)
    return selectedEntries[storeKey]
end

local function SetSelectedEntry(storeKey, spellID)
    selectedEntries[storeKey] = spellID
end

local function GetExistingConfig(storeKey, spellID)
    if not spellID then
        return nil
    end
    return GetStore(storeKey)[spellID]
end

local function GetConfigView(storeKey, spellID)
    local cfg = GetExistingConfig(storeKey, spellID)
    if cfg then
        return cfg
    end
    return VIEW_DEFAULTS
end

local function GetMonitorTypeValue(storeKey, spellID)
    local cfg = GetConfigView(storeKey, spellID)
    local value = cfg and cfg.monitorType
    if storeKey == "buffs" then
        return value == "stacks" and "stacks" or "duration"
    end
    return value or "cooldown"
end

local function IsStackMonitor(storeKey)
    return storeKey == "buffs" and GetMonitorTypeValue(storeKey, GetSelectedEntry(storeKey)) == "stacks"
end

local function ClampStackThreshold(storeKey, spellID, value)
    local maxStacks = tonumber(GetConfigView(storeKey, spellID).maxStacks) or 5
    return math.max(0, math.min(maxStacks, math.floor((tonumber(value) or 0) + 0.5)))
end

local function EnsureConfig(storeKey, spellID)
    local module = GetModule()
    if not module or not spellID then
        return nil
    end
    return module:GetOrCreateConfig(storeKey, spellID)
end

local function SetConfigValue(storeKey, spellID, keyPath, value)
    local module = GetModule()
    if not module or not spellID then
        return
    end
    EnsureConfig(storeKey, spellID)
    module:SetValue(storeKey, spellID, keyPath, value)
end

local function ResetSelected(storeKey)
    local module = GetModule()
    local spellID = GetSelectedEntry(storeKey)
    if module and spellID then
        module:ResetConfig(storeKey, spellID)
    end
end

local function DeleteSelected(storeKey)
    local module = GetModule()
    local spellID = GetSelectedEntry(storeKey)
    if module and spellID then
        module:DeleteConfig(storeKey, spellID)
        selectedEntries[storeKey] = nil
    end
end

local function ScanStore(storeKey)
    local system = GetSystem()
    if not system then
        return
    end
    if storeKey == "skills" and system.SkillScanner and system.SkillScanner.scan then
        system.SkillScanner.scan()
    elseif storeKey == "buffs" and system.BuffScanner and system.BuffScanner.scan then
        system.BuffScanner.scan()
    end
end

local function EnableSelected(storeKey, enabled)
    local spellID = GetSelectedEntry(storeKey)
    if not spellID then
        return
    end
    if enabled then
        EnsureConfig(storeKey, spellID)
        SetConfigValue(storeKey, spellID, "enabled", true)
    else
        SetConfigValue(storeKey, spellID, "enabled", false)
    end
end

local function TrimText(value)
    local text = tostring(value or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function FillSpellTooltip(tooltip, info)
    if not tooltip or not info then
        return
    end

    local spellID = tonumber(info.spellID)
    local hasSpellTooltip = false
    if spellID and spellID > 0 and tooltip.SetSpellByID then
        hasSpellTooltip = pcall(function()
            tooltip:SetSpellByID(spellID)
        end)
    end

    if not hasSpellTooltip then
        tooltip:AddLine(tostring(info.label or "未知技能"), 1, 0.82, 0.18)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("SpellID: " .. tostring(spellID or "-"), 0.75, 0.78, 0.84)
    tooltip:AddLine(tostring(info.meta or ""), 0.55, 0.85, 0.55)
    if info.tracked == false then
        tooltip:AddLine("未在冷却管理器扫描到该条目，当前为手动配置。", 0.90, 0.68, 0.30, true)
    end
end

local function AddManualEntry(storeKey)
    local spellID = tonumber(TrimText(pendingIDs[storeKey]))
    if not spellID or spellID <= 0 then
        return
    end
    SetSelectedEntry(storeKey, spellID)
    pendingIDs[storeKey] = ""
    EnsureConfig(storeKey, spellID)
end

local function GetSpellPlaceholder(spellID)
    local utils = GetSystem() and GetSystem().Utils
    if utils and utils.placeholderSpellEntry then
        return utils.placeholderSpellEntry(spellID)
    end
    return nil
end

local function BuildEntryItems(storeKey)
    local tracked = GetTrackedEntries(storeKey)
    local store = GetStore(storeKey)
    local merged = {}

    for spellID, entry in pairs(tracked) do
        merged[spellID] = {
            spellID = spellID,
            name = entry.name or ("Spell " .. tostring(spellID)),
            icon = entry.icon,
            tracked = true,
            configured = store[spellID] ~= nil,
            enabled = store[spellID] and store[spellID].enabled or false,
        }
    end

    for spellID, cfg in pairs(store) do
        if not merged[spellID] then
            local placeholder = GetSpellPlaceholder(spellID)
            merged[spellID] = {
                spellID = spellID,
                name = (placeholder and placeholder.name) or ("未知技能 " .. tostring(spellID)),
                icon = (placeholder and placeholder.icon) or 134400,
                tracked = false,
                configured = true,
                enabled = cfg and cfg.enabled or false,
            }
        end
    end

    local ordered = {}
    for _, info in pairs(merged) do
        ordered[#ordered + 1] = info
    end

    table.sort(ordered, function(a, b)
        if a.name == b.name then
            return a.spellID < b.spellID
        end
        return a.name < b.name
    end)

    local currentSelected = selectedEntries[storeKey]
    local hasSelected = false
    if currentSelected then
        for _, info in ipairs(ordered) do
            if info.spellID == currentSelected then
                hasSelected = true
                break
            end
        end
    end

    if not hasSelected then
        selectedEntries[storeKey] = ordered[1] and ordered[1].spellID or nil
    end

    local items = {}
    for _, info in ipairs(ordered) do
        local state = "idle"
        local meta = "未配置"
        if info.enabled then
            state = "enabled"
            meta = "已启动"
        elseif info.configured then
            state = "configured"
            meta = "当前配置"
        elseif info.tracked then
            state = "tracked"
            meta = "已扫描"
        end

        items[#items + 1] = {
            key = tostring(info.spellID),
            spellID = info.spellID,
            icon = info.icon or 134400,
            label = info.name,
            meta = meta,
            state = state,
            tracked = info.tracked,
            tooltip = function(tooltip)
                FillSpellTooltip(tooltip, {
                    spellID = info.spellID,
                    label = info.name,
                    meta = meta,
                    tracked = info.tracked,
                })
            end,
            selected = selectedEntries[storeKey] == info.spellID,
            func = function()
                SetSelectedEntry(storeKey, info.spellID)
            end,
        }
    end

    return items
end

local function BuildSelectedData(storeKey)
    local spellID = GetSelectedEntry(storeKey)
    if not spellID then
        return nil
    end

    local tracked = GetTrackedEntries(storeKey)[spellID]
    local cfg = GetExistingConfig(storeKey, spellID)
    local placeholder = tracked and nil or GetSpellPlaceholder(spellID)
    local enabled = cfg and cfg.enabled or false
    local configured = cfg ~= nil

    return {
        spellID = spellID,
        name = (tracked and tracked.name) or (placeholder and placeholder.name) or ("Spell " .. tostring(spellID)),
        icon = (tracked and tracked.icon) or (placeholder and placeholder.icon) or 134400,
        trackedText = tracked and "已扫描" or "未扫描",
        statusText = enabled and "已启动" or (configured and "当前配置" or "未配置"),
        enabled = enabled,
        configured = configured,
    }
end

local function BuildActionRow(storeKey)
    local spellID = GetSelectedEntry(storeKey)
    local cfg = GetExistingConfig(storeKey, spellID)
    local enabled = cfg and cfg.enabled or false

    return {
        type = "actionRow",
        order = 10,
        name = "当前条目",
        actions = {
            {
                label = enabled and "停用" or "启用",
                width = 56,
                disabled = function()
                    return not GetSelectedEntry(storeKey)
                end,
                func = function()
                    EnableSelected(storeKey, not enabled)
                end,
            },
            {
                label = "重置",
                width = 56,
                disabled = function()
                    return not GetSelectedEntry(storeKey)
                end,
                func = function()
                    ResetSelected(storeKey)
                end,
            },
        },
    }
end

local function BuildAppearanceGroup(storeKey)
    return {
        type = "group",
        order = 30,
        name = "外观",
        args = {
            shapeRow = {
                type = "group",
                order = 1,
                name = "",
                layout = "row",
                args = {
                    shape = {
                        type = "select",
                        order = 1,
                        width = "full",
                        name = "形状",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        values = function()
                            return { bar = "条形", ring = "环形" }
                        end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).shape or "bar"
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "shape", value)
                        end,
                    },
                },
            },
            displayRow = {
                type = "group",
                order = 2,
                name = "",
                layout = "row",
                args = {
                    showGraphics = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "显示图形",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).showGraphics ~= false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "showGraphics", value and true or false)
                        end,
                    },
                    showText = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "显示文本",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).showText ~= false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "showText", value and true or false)
                        end,
                    },
                },
            },
            sizeRow = {
                type = "group",
                order = 3,
                name = "",
                layout = "row",
                args = {
                    barLength = {
                        type = "range",
                        order = 1,
                        width = 1.0,
                        name = "长度",
                        min = 40,
                        max = 500,
                        step = 1,
                        hidden = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).shape ~= "bar" end,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).barLength or
                                VIEW_DEFAULTS.barLength
                        end,
                        set = function(_, value) SetConfigValue(storeKey, GetSelectedEntry(storeKey), "barLength", value) end,
                    },
                    barThickness = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "厚度",
                        min = 4,
                        max = 80,
                        step = 1,
                        hidden = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).shape ~= "bar" end,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).barThickness or
                                VIEW_DEFAULTS.barThickness
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "barThickness",
                                value)
                        end,
                    },
                    ringSize = {
                        type = "range",
                        order = 3,
                        width = 1.0,
                        name = "环大小",
                        min = 24,
                        max = 240,
                        step = 1,
                        hidden = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).shape ~= "ring" end,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).ringSize or
                                VIEW_DEFAULTS.ringSize
                        end,
                        set = function(_, value) SetConfigValue(storeKey, GetSelectedEntry(storeKey), "ringSize", value) end,
                    },
                },
            },
        },
    }
end

local function BuildBehaviorGroup(storeKey)
    return {
        type = "group",
        order = 40,
        name = "行为",
        args = {
            typeRow = {
                type = "group",
                order = 1,
                name = "",
                layout = "row",
                hidden = function() return storeKey ~= "buffs" end,
                args = {
                    monitorType = {
                        type = "select",
                        order = 1,
                        width = "full",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        name = "BUFF 类型",
                        values = function()
                            return { duration = "持续时间", stacks = "层数" }
                        end,
                        get = function()
                            return GetMonitorTypeValue(storeKey, GetSelectedEntry(storeKey))
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "monitorType", value)
                        end,
                    },
                },
            },
            hideRow = {
                type = "group",
                order = 2,
                name = "",
                layout = "row",
                args = {
                    hideWhenInactive = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "未激活时隐藏",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideWhenInactive or
                                false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideWhenInactive",
                                value and true or false)
                        end,
                    },
                    hideNoTarget = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "无目标时隐藏",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideNoTarget or false end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideNoTarget",
                                value and true or false)
                        end,
                    },
                },
            },
            stackHeaderRow = {
                type = "group",
                order = 3,
                name = "",
                layout = "row",
                hidden = function() return not IsStackMonitor(storeKey) end,
                args = {
                    maxStacks = {
                        type = "range",
                        order = 1,
                        width = 1.0,
                        name = "最大层数",
                        min = 1,
                        max = 20,
                        step = 1,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).maxStacks) or 5
                        end,
                        set = function(_, value)
                            local maxStacks = math.max(1, math.floor((tonumber(value) or 1) + 0.5))
                            local spellID = GetSelectedEntry(storeKey)
                            local cfg = GetConfigView(storeKey, spellID)
                            SetConfigValue(storeKey, spellID, "maxStacks", maxStacks)
                            if (tonumber(cfg.stackThreshold1) or 0) > maxStacks then
                                SetConfigValue(storeKey, spellID, "stackThreshold1", maxStacks)
                            end
                            if (tonumber(cfg.stackThreshold2) or 0) > maxStacks then
                                SetConfigValue(storeKey, spellID, "stackThreshold2", maxStacks)
                            end
                            if (tonumber(cfg.stackThreshold3) or 0) > maxStacks then
                                SetConfigValue(storeKey, spellID, "stackThreshold3", maxStacks)
                            end
                        end,
                    },
                    defaultColor = {
                        type = "color",
                        order = 2,
                        width = 0.9,
                        name = "默认颜色",
                        hasAlpha = true,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            local color = GetConfigView(storeKey, GetSelectedEntry(storeKey)).barColor or
                                { r = 0.26, g = 0.80, b = 0.54, a = 1 }
                            return color.r, color.g, color.b, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "barColor",
                                { r = r, g = g, b = b, a = a })
                        end,
                    },
                },
            },
            posRow = {
                type = "group",
                order = 4,
                name = "",
                layout = "row",
                args = {
                    x = {
                        type = "range",
                        order = 1,
                        width = 1.0,
                        name = "X 偏移",
                        min = -1200,
                        max = 1200,
                        step = 1,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).x or 0 end,
                        set = function(_, value) SetConfigValue(storeKey, GetSelectedEntry(storeKey), "x", value) end,
                    },
                    y = {
                        type = "range",
                        order = 2,
                        width = 1.0,
                        name = "Y 偏移",
                        min = -1200,
                        max = 1200,
                        step = 1,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).y or 0 end,
                        set = function(_, value) SetConfigValue(storeKey, GetSelectedEntry(storeKey), "y", value) end,
                    },
                },
            },
            stackRow1 = {
                type = "group",
                order = 5,
                name = "",
                layout = "row",
                hidden = function() return not IsStackMonitor(storeKey) end,
                args = {
                    stackThreshold1 = {
                        type = "range",
                        order = 1,
                        width = 1.0,
                        name = "阈值一",
                        min = 0,
                        max = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).maxStacks) or 5
                        end,
                        step = 1,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).stackThreshold1) or 0
                        end,
                        set = function(_, value)
                            local spellID = GetSelectedEntry(storeKey)
                            SetConfigValue(storeKey, spellID, "stackThreshold1",
                                ClampStackThreshold(storeKey, spellID, value))
                        end,
                    },
                    stackColor1 = {
                        type = "color",
                        order = 2,
                        width = 0.9,
                        name = "阈值一颜色",
                        hasAlpha = true,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            local color = GetConfigView(storeKey, GetSelectedEntry(storeKey)).stackColor1 or
                                VIEW_DEFAULTS.barColor
                            return color.r, color.g, color.b, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "stackColor1",
                                { r = r, g = g, b = b, a = a })
                        end,
                    },
                },
            },
            stackRow2 = {
                type = "group",
                order = 6,
                name = "",
                layout = "row",
                hidden = function() return not IsStackMonitor(storeKey) end,
                args = {
                    stackThreshold2 = {
                        type = "range",
                        order = 1,
                        width = 1.0,
                        name = "阈值二",
                        min = 0,
                        max = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).maxStacks) or 5
                        end,
                        step = 1,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).stackThreshold2) or 0
                        end,
                        set = function(_, value)
                            local spellID = GetSelectedEntry(storeKey)
                            SetConfigValue(storeKey, spellID, "stackThreshold2",
                                ClampStackThreshold(storeKey, spellID, value))
                        end,
                    },
                    stackColor2 = {
                        type = "color",
                        order = 2,
                        width = 0.9,
                        name = "阈值二颜色",
                        hasAlpha = true,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            local color = GetConfigView(storeKey, GetSelectedEntry(storeKey)).stackColor2 or
                                VIEW_DEFAULTS.barColor
                            return color.r, color.g, color.b, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "stackColor2",
                                { r = r, g = g, b = b, a = a })
                        end,
                    },
                },
            },
            stackRow3 = {
                type = "group",
                order = 7,
                name = "",
                layout = "row",
                hidden = function() return not IsStackMonitor(storeKey) end,
                args = {
                    stackThreshold3 = {
                        type = "range",
                        order = 1,
                        width = 1.0,
                        name = "阈值三",
                        min = 0,
                        max = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).maxStacks) or 5
                        end,
                        step = 1,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return tonumber(GetConfigView(storeKey, GetSelectedEntry(storeKey)).stackThreshold3) or 0
                        end,
                        set = function(_, value)
                            local spellID = GetSelectedEntry(storeKey)
                            SetConfigValue(storeKey, spellID, "stackThreshold3",
                                ClampStackThreshold(storeKey, spellID, value))
                        end,
                    },
                    stackColor3 = {
                        type = "color",
                        order = 2,
                        width = 0.9,
                        name = "阈值三颜色",
                        hasAlpha = true,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            local color = GetConfigView(storeKey, GetSelectedEntry(storeKey)).stackColor3 or
                                VIEW_DEFAULTS.barColor
                            return color.r, color.g, color.b, color.a or 1
                        end,
                        set = function(_, r, g, b, a)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "stackColor3",
                                { r = r, g = g, b = b, a = a })
                        end,
                    },
                },
            },
        },
    }
end

local function BuildVisibilityGroup(storeKey)
    return {
        type = "group",
        order = 45,
        name = "显示条件",
        args = {
            modeRow = {
                type = "group",
                order = 1,
                name = "",
                layout = "row",
                args = {
                    mode = {
                        type = "select",
                        order = 1,
                        width = "full",
                        name = "条件模式",
                        values = function()
                            return {
                                hide = "满足条件时隐藏",
                                show = "满足条件时显示",
                            }
                        end,
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).visibilityMode or "hide"
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "visibilityMode", value)
                        end,
                    },
                },
            },
            row1 = {
                type = "group",
                order = 2,
                name = "",
                layout = "row",
                args = {
                    hideOnMount = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "骑乘时",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideOnMount or false end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideOnMount",
                                value and true or false)
                        end,
                    },
                    hideOnSkyriding = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "驭空时",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideOnSkyriding or
                                false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideOnSkyriding",
                                value and true or false)
                        end,
                    },
                },
            },
            row2 = {
                type = "group",
                order = 3,
                name = "",
                layout = "row",
                args = {
                    hideInSpecial = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "载具/宠物对战",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideInSpecial or
                                false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideInSpecial",
                                value and true or false)
                        end,
                    },
                    hideNoTarget = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "无目标时",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideNoTarget or false end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideNoTarget",
                                value and true or false)
                        end,
                    },
                },
            },
            row3 = {
                type = "group",
                order = 4,
                name = "",
                layout = "row",
                args = {
                    hideWhenInactive = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "未激活时",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideWhenInactive or
                                false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideWhenInactive",
                                value and true or false)
                        end,
                    },
                    hideInCooldownManager = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "冷却管理器中",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey))
                                .hideInCooldownManager or false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey),
                                "hideInCooldownManager", value and true or false)
                        end,
                    },
                },
            },
            row4 = {
                type = "group",
                order = 5,
                name = "",
                layout = "row",
                args = {
                    hideInCombat = {
                        type = "toggle",
                        order = 1,
                        width = 1.0,
                        name = "战斗中",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function() return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideInCombat or false end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey), "hideInCombat",
                                value and true or false)
                        end,
                    },
                    hideInSystemEditMode = {
                        type = "toggle",
                        order = 2,
                        width = 1.0,
                        name = "系统编辑模式中",
                        disabled = function() return not GetSelectedEntry(storeKey) end,
                        get = function()
                            return GetConfigView(storeKey, GetSelectedEntry(storeKey)).hideInSystemEditMode or
                                false
                        end,
                        set = function(_, value)
                            SetConfigValue(storeKey, GetSelectedEntry(storeKey),
                                "hideInSystemEditMode", value and true or false)
                        end,
                    },
                },
            },
        },
    }
end

local function BuildWorkbenchOption(storeKey)
    local emptyText = storeKey == "skills"
        and "打开冷却管理器后会自动补全扫描结果，也可以直接手动输入技能ID。"
        or "进入战斗后会自动补全BUFF扫描结果，也可以直接手动输入BUFF ID。"

    return {
        type = "monitorWorkbench",
        order = 10,
        emptyText = emptyText,
        items = function()
            return BuildEntryItems(storeKey)
        end,
        autoScan = function()
            ScanStore(storeKey)
        end,
        info = function()
            return BuildSelectedData(storeKey)
        end,
        legendItems = {
            { text = "当前配置", color = "accent" },
            { text = "已启动", color = "success" },
        },
        columns = 4,
        manualLabel = storeKey == "skills" and "手动输入技能ID" or "手动输入BUFF ID",
        manualValue = function()
            return pendingIDs[storeKey] or ""
        end,
        setManualValue = function(value)
            pendingIDs[storeKey] = tostring(value or "")
        end,
        addManual = function()
            AddManualEntry(storeKey)
        end,
        addButtonLabel = "添加",
        actionRow = function()
            return BuildActionRow(storeKey)
        end,
        tabKey = storeKey,
        sections = {
            BuildAppearanceGroup(storeKey),
            BuildBehaviorGroup(storeKey),
            BuildVisibilityGroup(storeKey),
        },
    }
end

function NS.BuildGraphicMonitorOptions()
    SyncProfileEditorState()

    return {
        type = "group",
        name = "技能监控",
        order = 30,
        childGroups = "tab",
        args = {
            info = {
                type = "group",
                name = "基本信息",
                order = 1,
                args = {
                    profileStatus = {
                        type = "description",
                        order = 0,
                        fontSize = "medium",
                        name = function()
                            return GetProfileStatusText()
                        end,
                    },
                    currentProfile = {
                        type = "select",
                        order = 1,
                        name = "当前角色技能监控配置",
                        values = function()
                            return GetProfileChoices()
                        end,
                        get = function()
                            return GetCurrentProfileKey()
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            if not module or not module.SetCurrentProfileKey then
                                return
                            end

                            local ok, errorMessage = module:SetCurrentProfileKey(value)
                            if not ok then
                                Core:Print(errorMessage or "技能监控配置切换失败。")
                                return
                            end

                            renameProfileName = value or ""
                            NotifyGraphicMonitorChanged()
                        end,
                    },
                    rescanSkills = {
                        type = "execute",
                        order = 5,
                        name = "重新扫描技能",
                        func = function()
                            ScanStore("skills")
                            ScanStore("buffs")
                        end,
                    },
                    createGroup = {
                        type = "group",
                        order = 10,
                        name = "新建技能监控配置",
                        layout = "row",
                        args = {
                            createName = {
                                type = "input",
                                order = 1,
                                width = 1.4,
                                name = "配置名称",
                                get = function()
                                    return createProfileName
                                end,
                                set = function(_, value)
                                    createProfileName = value or ""
                                end,
                            },
                            createAction = {
                                type = "execute",
                                order = 2,
                                width = 0.8,
                                name = "新建",
                                disabled = function()
                                    return TrimOptionText(createProfileName) == ""
                                end,
                                func = function()
                                    local module = GetModule()
                                    if not module or not module.CreateProfile then
                                        return
                                    end

                                    local created, errorMessage = module:CreateProfile(createProfileName,
                                        GetCurrentProfileKey())
                                    if not created then
                                        Core:Print(errorMessage or "技能监控配置创建失败。")
                                        return
                                    end

                                    createProfileName = ""
                                    renameProfileName = created
                                    Core:Print("已创建技能监控配置：" .. tostring(created))
                                    NotifyGraphicMonitorChanged()
                                end,
                            },
                        },
                    },
                    editGroup = {
                        type = "group",
                        order = 20,
                        name = "编辑当前技能监控配置",
                        layout = "row",
                        args = {
                            renameInput = {
                                type = "input",
                                order = 1,
                                width = 1.4,
                                name = "重命名为",
                                get = function()
                                    return renameProfileName
                                end,
                                set = function(_, value)
                                    renameProfileName = value or ""
                                end,
                            },
                            renameAction = {
                                type = "execute",
                                order = 2,
                                width = 0.8,
                                name = "重命名",
                                disabled = function()
                                    return TrimOptionText(renameProfileName) == ""
                                end,
                                func = function()
                                    local module = GetModule()
                                    if not module or not module.RenameProfile then
                                        return
                                    end

                                    local renamed, errorMessage = module:RenameProfile(GetCurrentProfileKey(),
                                        renameProfileName)
                                    if not renamed then
                                        Core:Print(errorMessage or "技能监控配置重命名失败。")
                                        return
                                    end

                                    renameProfileName = renamed
                                    Core:Print("已重命名技能监控配置：" .. tostring(renamed))
                                    NotifyGraphicMonitorChanged()
                                end,
                            },
                            deleteAction = {
                                type = "execute",
                                order = 3,
                                width = 0.8,
                                name = "删除当前配置",
                                confirm = true,
                                confirmText = "确认删除当前技能监控配置吗？使用这份配置的角色会切回各自默认配置。",
                                func = function()
                                    local module = GetModule()
                                    if not module or not module.DeleteProfile then
                                        return
                                    end

                                    local currentKey = GetCurrentProfileKey()
                                    local ok, errorMessage = module:DeleteProfile(currentKey)
                                    if not ok then
                                        Core:Print(errorMessage or "技能监控配置删除失败。")
                                        return
                                    end

                                    renameProfileName = GetCurrentProfileKey()
                                    Core:Print("已删除技能监控配置：" .. tostring(currentKey))
                                    NotifyGraphicMonitorChanged()
                                end,
                            },
                        },
                    },
                },
            },
            skills = {
                type = "group",
                name = "技能",
                order = 10,
                args = {
                    workbench = BuildWorkbenchOption("skills"),
                },
            },
            buffs = {
                type = "group",
                name = "BUFF",
                order = 20,
                args = {
                    workbench = BuildWorkbenchOption("buffs"),
                },
            },
        },
    }
end
