local _, NS = ...
local Core = NS.Core

local MODULE_KEY = "YuXuanSpecial.GraphicMonitor"

local System = {}
NS.GraphicMonitorSystem = System

local GraphicMonitor = {}
NS.Modules.InterfaceEnhance.GraphicMonitor = GraphicMonitor

System.Modules = System.Modules or {}
System.L = setmetatable({}, {
    __index = function(_, key)
        return tostring(key)
    end,
})
System.Profiler = System.Profiler or {}

local eventCallbacks = {}
local moduleRegistry = {}
local moduleProxies = {}
local moduleDefaults = {}
local storeWatchers = {}

local function GetGraphicMonitorCharacterKey()
    local characterKey = Core.GetCurrentCharacterKey and Core:GetCurrentCharacterKey()
    if characterKey and characterKey ~= "" then
        return tostring(characterKey)
    end

    local name, realm = UnitFullName and UnitFullName("player")
    if name and realm and realm ~= "" then
        return string.format("%s-%s", name, realm)
    end

    return tostring(UnitName and UnitName("player") or "Unknown")
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = DeepCopy(nested)
    end
    return copy
end

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults or {}) do
        if target[key] == nil then
            target[key] = DeepCopy(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

local function ParsePath(path)
    local keys = {}
    for key in tostring(path or ""):gmatch("[^%.]+") do
        local numeric = tonumber(key)
        keys[#keys + 1] = numeric or key
    end
    return keys
end

local function SetNestedValue(target, path, value)
    local keys = ParsePath(path)
    if #keys == 0 then
        return false
    end

    local current = target
    for index = 1, #keys - 1 do
        local key = keys[index]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end

    current[keys[#keys]] = value
    return true
end

local function EnsureGraphicMonitorRoot()
    Core.db = Core.db or {}
    Core.db.interfaceEnhance = Core.db.interfaceEnhance or {}
    if type(Core.db.interfaceEnhance.graphicMonitor) ~= "table" then
        Core.db.interfaceEnhance.graphicMonitor = {}
    end

    local container = Core.db.interfaceEnhance.graphicMonitor
    container.characters = type(container.characters) == "table" and container.characters or {}

    local characterKey = GetGraphicMonitorCharacterKey()
    if type(container.characters[characterKey]) ~= "table" then
        local migratedSkills = type(container.skills) == "table" and DeepCopy(container.skills) or {}
        local migratedBuffs = type(container.buffs) == "table" and DeepCopy(container.buffs) or {}
        container.characters[characterKey] = {
            skills = migratedSkills,
            buffs = migratedBuffs,
        }
    end

    local root = container.characters[characterKey]
    root.skills = type(root.skills) == "table" and root.skills or {}
    root.buffs = type(root.buffs) == "table" and root.buffs or {}
    return root
end

local function RebindModuleProxy(moduleKey, defaults)
    local root = EnsureGraphicMonitorRoot()
    ApplyDefaults(root, defaults or moduleDefaults[moduleKey] or {})
    moduleProxies[moduleKey] = root
    return root
end

function System.registerModule(moduleKey, config)
    moduleRegistry[moduleKey] = config or {}
end

function System.hasModule(moduleKey)
    return moduleRegistry[moduleKey] ~= nil
end

local eventFrame = CreateFrame("Frame")
System.eventFrame = eventFrame

function System.on(event, owner, callback, units)
    if type(event) ~= "string" or type(callback) ~= "function" then
        return
    end

    eventCallbacks[event] = eventCallbacks[event] or {}
    for _, entry in ipairs(eventCallbacks[event]) do
        if entry.owner == owner and entry.callback == callback then
            return
        end
    end

    if units then
        local unitList = {}
        for unit in tostring(units):gmatch("[^,]+") do
            unitList[#unitList + 1] = unit
        end
        pcall(eventFrame.RegisterUnitEvent, eventFrame, event, unpack(unitList))
    else
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end

    eventCallbacks[event][#eventCallbacks[event] + 1] = {
        owner = owner,
        callback = callback,
    }
end

function System.off(owner)
    for event, callbacks in pairs(eventCallbacks) do
        for index = #callbacks, 1, -1 do
            if callbacks[index].owner == owner then
                table.remove(callbacks, index)
            end
        end

        if #callbacks == 0 then
            pcall(eventFrame.UnregisterEvent, eventFrame, event)
            eventCallbacks[event] = nil
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local callbacks = eventCallbacks[event]
    if not callbacks then
        return
    end

    for _, entry in ipairs(callbacks) do
        local ok, err = pcall(entry.callback, event, ...)
        if not ok then
            Core:Print("图形监控事件错误: " .. tostring(err))
        end
    end
end)

local State = {}
System.State = State

local stateData = {
    inCombat = false,
    specID = 0,
    playerClass = "",
    playerName = "",
    isMounted = false,
    isSkyriding = false,
    inVehicle = false,
    inPetBattle = false,
    hasTarget = false,
    systemEditMode = false,
    internalEditMode = false,
    isEditMode = false,
    trackedSkills = {},
    trackedUtilitySkills = {},
    trackedBuffs = {},
}

local stateWatchers = {}

function State.watch(stateKey, owner, callback)
    if type(stateKey) ~= "string" or type(callback) ~= "function" then
        return
    end

    stateWatchers[stateKey] = stateWatchers[stateKey] or {}
    stateWatchers[stateKey][owner] = callback
    pcall(callback, stateData[stateKey], nil)
end

function State.unwatch(stateKey, owner)
    if stateWatchers[stateKey] then
        stateWatchers[stateKey][owner] = nil
        if not next(stateWatchers[stateKey]) then
            stateWatchers[stateKey] = nil
        end
    end
end

function State.update(stateKey, value)
    local oldValue = stateData[stateKey]
    if oldValue == value then
        return
    end

    stateData[stateKey] = value
    local watchers = stateWatchers[stateKey]
    if not watchers then
        return
    end

    for _, callback in pairs(watchers) do
        pcall(callback, value, oldValue)
    end
end

function State.get(stateKey)
    return stateData[stateKey]
end

setmetatable(State, {
    __index = stateData,
})

local function IsSkyriding()
    if GetBonusBarIndex and GetBonusBarOffset and GetBonusBarIndex() == 11 and GetBonusBarOffset() == 5 then
        return true
    end

    if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
        local _, canGlide = C_PlayerInfo.GetGlidingInfo()
        return canGlide == true
    end

    return false
end

local playerStateFrame = CreateFrame("Frame")
playerStateFrame:RegisterEvent("PLAYER_LOGIN")
playerStateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
playerStateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
playerStateFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
playerStateFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
playerStateFrame:RegisterEvent("PET_BATTLE_OPENING_START")
playerStateFrame:RegisterEvent("PET_BATTLE_CLOSE")
playerStateFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
playerStateFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
playerStateFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
playerStateFrame:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED")
playerStateFrame:RegisterEvent("PLAYER_IS_GLIDING_CHANGED")
playerStateFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
playerStateFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        State.update("inCombat", InCombatLockdown and InCombatLockdown() or false)
        State.update("playerName", UnitName and (UnitName("player") or "") or "")
        State.update("playerClass", select(2, UnitClass("player")) or "")
        State.update("specID", GetSpecialization and (GetSpecialization() or 0) or 0)
        State.update("isMounted", IsMounted and IsMounted() or false)
        State.update("isSkyriding", IsSkyriding())
        State.update("inVehicle", UnitInVehicle and UnitInVehicle("player") or false)
        State.update("inPetBattle", C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() or false)
        State.update("hasTarget", UnitExists and UnitExists("target") or false)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        State.update("inCombat", true)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        State.update("inCombat", false)
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit and unit ~= "player" then
            return
        end
        State.update("specID", GetSpecialization and (GetSpecialization() or 0) or 0)
        return
    end

    if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if unit == "player" then
            State.update("inVehicle", UnitInVehicle and UnitInVehicle("player") or false)
        end
        return
    end

    if event == "PET_BATTLE_OPENING_START" then
        State.update("inPetBattle", true)
        return
    end

    if event == "PET_BATTLE_CLOSE" then
        State.update("inPetBattle", false)
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        State.update("hasTarget", UnitExists and UnitExists("target") or false)
        return
    end

    State.update("isMounted", IsMounted and IsMounted() or false)
    State.update("isSkyriding", IsSkyriding())
end)

local Store = {}
System.Store = Store

function Store.initModule(moduleKey, defaults)
    moduleDefaults[moduleKey] = defaults or {}
    return RebindModuleProxy(moduleKey, defaults)
end

function Store.watch(moduleKey, owner, callback)
    if type(callback) ~= "function" then
        return
    end
    storeWatchers[moduleKey] = storeWatchers[moduleKey] or {}
    storeWatchers[moduleKey][owner] = callback
end

function Store.unwatch(moduleKey, owner)
    if storeWatchers[moduleKey] then
        storeWatchers[moduleKey][owner] = nil
        if not next(storeWatchers[moduleKey]) then
            storeWatchers[moduleKey] = nil
        end
    end
end

function Store.notifyChange(moduleKey, key, value)
    local watchers = storeWatchers[moduleKey]
    if not watchers then
        return
    end

    for _, callback in pairs(watchers) do
        pcall(callback, key, value)
    end
end

function Store.set(moduleKey, configKey, value)
    local proxy = moduleProxies[moduleKey]
    if not proxy then
        proxy = Store.initModule(moduleKey, moduleDefaults[moduleKey] or {})
    end

    if type(configKey) == "string" and configKey:find("%.") then
        SetNestedValue(proxy, configKey, value)
    else
        proxy[configKey] = value
    end

    Store.notifyChange(moduleKey, configKey, value)
end

function Store.getModuleRef(moduleKey)
    return moduleProxies[moduleKey]
end

function Store.getDefaults(moduleKey)
    return DeepCopy(moduleDefaults[moduleKey] or {})
end

function System.getDB(moduleKey, defaults)
    if not moduleRegistry[moduleKey] then
        System.registerModule(moduleKey, {})
    end

    if defaults ~= nil then
        moduleDefaults[moduleKey] = defaults
    end

    local root = EnsureGraphicMonitorRoot()
    if moduleProxies[moduleKey] ~= root then
        return RebindModuleProxy(moduleKey, moduleDefaults[moduleKey] or defaults or {})
    end

    if not moduleProxies[moduleKey] then
        return Store.initModule(moduleKey, defaults or {})
    end

    return moduleProxies[moduleKey]
end

function System.getDBIfReady(moduleKey)
    return moduleProxies[moduleKey]
end

System.UI = System.UI or {}
function System.UI.applyFont(fontString, fontKey, size, flags)
    if not fontString then
        return
    end

    local optionsPrivate = NS.Options and NS.Options.Private
    local preset = fontKey
    if preset == "默认" then
        preset = "DEFAULT"
    end

    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, flags or "", preset)
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, flags or "")
end

function System.openCooldownManager()
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        HideUIPanel(EditModeManagerFrame)
    end

    if CooldownViewerSettings and CooldownViewerSettings.ShowUIPanel then
        CooldownViewerSettings:ShowUIPanel(false)
    end
end

function System.toggleSystemEditMode()
    if not EditModeManagerFrame then
        return
    end

    if EditModeManagerFrame:IsShown() then
        HideUIPanel(EditModeManagerFrame)
    else
        ShowUIPanel(EditModeManagerFrame)
    end
end

function System.toggleInternalEditMode()
    if System.DragFrame and System.DragFrame.toggleInternalEditMode then
        System.DragFrame.toggleInternalEditMode()
    end
end

local function GetDefaultMonitorType(storeKey)
    if storeKey == "buffs" then
        return "duration"
    end
    return "cooldown"
end

local function NormalizeMonitorType(storeKey, cfg)
    if type(cfg) ~= "table" then
        return
    end

    if storeKey == "buffs" then
        if cfg.monitorType ~= "duration" and cfg.monitorType ~= "stacks" then
            cfg.monitorType = "duration"
        end
    elseif type(cfg.monitorType) ~= "string" or cfg.monitorType == "" then
        cfg.monitorType = "cooldown"
    end
end

local function CreateDefaultMonitorConfig(storeKey)
    return {
        enabled = false,
        monitorType = GetDefaultMonitorType(storeKey),
        isChargeSpell = false,
        shape = "bar",
        frameStrata = "MEDIUM",
        anchorFrame = "uiparent",
        relativePoint = "CENTER",
        playerAnchorPosition = "BOTTOMLEFT",
        x = 0,
        y = 0,
        barLengthMode = "manual",
        barLength = 200,
        barThickness = 20,
        barColor = { r = 0.2, g = 0.6, b = 1, a = 1 },
        rechargeColor = { r = 0.5, g = 0.8, b = 1, a = 1 },
        barTexture = "Solid",
        barDirection = "horizontal",
        barFillMode = "drain",
        barReverse = false,
        ringSize = 150,
        ringTexture = "10",
        ringColor = { r = 0.2, g = 0.6, b = 1, a = 1 },
        bgColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        borderThickness = "1",
        segmentGap = 0,
        showGraphics = true,
        showText = true,
        showIcon = true,
        timerFont = {
            size = 14,
            font = "默认",
            outline = "OUTLINE",
            color = { r = 1, g = 1, b = 1, a = 1 },
            position = "CENTER",
            offsetX = 0,
            offsetY = 0,
        },
        maxStacks = 5,
        stackThreshold1 = 0,
        stackColor1 = { r = 1, g = 0.5, b = 0, a = 1 },
        stackThreshold2 = 0,
        stackColor2 = { r = 1, g = 0, b = 0, a = 1 },
        stackThreshold3 = 0,
        stackColor3 = { r = 0.65, g = 0.2, b = 1, a = 1 },
        iconSize = 20,
        iconPosition = "LEFT",
        iconOffsetX = 0,
        iconOffsetY = 0,
        visibilityMode = "hide",
        hideInCombat = false,
        hideOnMount = false,
        hideOnSkyriding = false,
        hideInSpecial = false,
        hideNoTarget = false,
        hideWhenInactive = false,
        hideInCooldownManager = false,
        hideInSystemEditMode = false,
    }
end

GraphicMonitor.MODULE_KEY = MODULE_KEY
GraphicMonitor.DEFAULTS = {
    skills = {},
    buffs = {},
}

function GraphicMonitor:GetDatabase()
    return System.getDB(MODULE_KEY, self.DEFAULTS)
end

function GraphicMonitor:GetStore(storeKey)
    local db = self:GetDatabase()
    db[storeKey] = type(db[storeKey]) == "table" and db[storeKey] or {}
    return db[storeKey]
end

function GraphicMonitor:IsChargeSpell(spellID)
    local chargeInfo = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
    if not chargeInfo then
        return false
    end

    local maxCharges = chargeInfo.maxCharges
    if not maxCharges or (issecretvalue and issecretvalue(maxCharges)) then
        return false
    end

    return maxCharges >= 2
end

function GraphicMonitor:GetOrCreateConfig(storeKey, spellID)
    local store = self:GetStore(storeKey)
    if type(store[spellID]) ~= "table" then
        store[spellID] = CreateDefaultMonitorConfig(storeKey)
    end

    ApplyDefaults(store[spellID], CreateDefaultMonitorConfig(storeKey))
    NormalizeMonitorType(storeKey, store[spellID])
    if storeKey == "skills" then
        store[spellID].isChargeSpell = self:IsChargeSpell(spellID)
    else
        store[spellID].isChargeSpell = false
    end
    return store[spellID]
end

function GraphicMonitor:SetValue(storeKey, spellID, keyPath, value)
    self:GetOrCreateConfig(storeKey, spellID)
    Store.set(MODULE_KEY, string.format("%s.%s.%s", storeKey, tostring(spellID), tostring(keyPath)), value)
end

function GraphicMonitor:NotifyStore(storeKey, spellID, keyPath)
    local config = self:GetOrCreateConfig(storeKey, spellID)
    local leafValue = config
    for _, key in ipairs(ParsePath(keyPath)) do
        leafValue = type(leafValue) == "table" and leafValue[key] or nil
    end
    Store.notifyChange(MODULE_KEY, string.format("%s.%s.%s", storeKey, tostring(spellID), tostring(keyPath)), leafValue)
end

function GraphicMonitor:DeleteConfig(storeKey, spellID)
    local store = self:GetStore(storeKey)
    store[spellID] = nil
    Store.notifyChange(MODULE_KEY, string.format("%s.%s", storeKey, tostring(spellID)), nil)
end

function GraphicMonitor:ResetConfig(storeKey, spellID)
    local store = self:GetStore(storeKey)
    store[spellID] = CreateDefaultMonitorConfig(storeKey)
    NormalizeMonitorType(storeKey, store[spellID])
    if storeKey == "skills" then
        store[spellID].isChargeSpell = self:IsChargeSpell(spellID)
    else
        store[spellID].isChargeSpell = false
    end
    Store.notifyChange(MODULE_KEY, string.format("%s.%s", storeKey, tostring(spellID)), store[spellID])
end

function GraphicMonitor:OpenCooldownManager()
    System.openCooldownManager()
end

function GraphicMonitor:ToggleEditMode(config)
    if config and config.hideInSystemEditMode then
        System.toggleInternalEditMode()
    else
        System.toggleSystemEditMode()
    end
end

function GraphicMonitor:OnPlayerLogin()
    self:GetDatabase()
end

function GraphicMonitor:OnProfileChanged()
    return RebindModuleProxy(MODULE_KEY, self.DEFAULTS)
end

System.registerModule(MODULE_KEY, {
    name = "自定义图形监控",
    description = "技能冷却与BUFF图形监控",
})
