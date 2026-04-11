local _, NS = ...
local VFlow = NS.GraphicMonitorSystem
if not VFlow then
    return
end

local MODULE_KEY = "YuXuanSpecial.GraphicMonitor"

local VIEWERS = {
    { name = "EssentialCooldownViewer", storeKey = "skills" },
    { name = "UtilityCooldownViewer", storeKey = "skills" },
    { name = "BuffIconCooldownViewer", storeKey = "buffs" },
    { name = "BuffBarCooldownViewer", storeKey = "buffs" },
}

local hiddenFrames = setmetatable({}, { __mode = "k" })

local function IsUsableSpellID(spellID)
    if type(spellID) ~= "number" then
        return false
    end

    if issecretvalue and issecretvalue(spellID) then
        return false
    end

    return spellID > 0
end

local function AppendCandidate(list, seen, spellID)
    if not IsUsableSpellID(spellID) or seen[spellID] then
        return
    end

    seen[spellID] = true
    list[#list + 1] = spellID
end

local function BuildSpellCandidates(info, storeKey)
    local candidates = {}
    local seen = {}

    if type(info) ~= "table" then
        return candidates
    end

    if storeKey == "buffs" and type(info.linkedSpellIDs) == "table" then
        for _, spellID in ipairs(info.linkedSpellIDs) do
            AppendCandidate(candidates, seen, spellID)
        end
    end

    AppendCandidate(candidates, seen, info.overrideSpellID)

    if storeKey == "skills" and C_Spell and C_Spell.GetOverrideSpell and IsUsableSpellID(info.spellID) then
        AppendCandidate(candidates, seen, C_Spell.GetOverrideSpell(info.spellID))
    end

    if type(info.linkedSpellIDs) == "table" then
        for _, spellID in ipairs(info.linkedSpellIDs) do
            AppendCandidate(candidates, seen, spellID)
        end
    end

    AppendCandidate(candidates, seen, info.spellID)

    if C_Spell and C_Spell.GetBaseSpell then
        local baseCandidates = {}
        for _, spellID in ipairs(candidates) do
            AppendCandidate(baseCandidates, seen, C_Spell.GetBaseSpell(spellID))
        end
        for _, spellID in ipairs(baseCandidates) do
            candidates[#candidates + 1] = spellID
        end
    end

    return candidates
end

local function GetCooldownID(frame)
    if not frame then
        return nil
    end

    if frame.cooldownID then
        return frame.cooldownID
    end

    if frame.cooldownInfo and frame.cooldownInfo.cooldownID then
        return frame.cooldownInfo.cooldownID
    end

    return nil
end

local function GetDatabase()
    return VFlow.getDB(MODULE_KEY)
end

local function HasActiveHideRules()
    local db = GetDatabase()
    if not db then
        return false
    end

    for _, storeKey in ipairs({ "skills", "buffs" }) do
        for _, config in pairs(db[storeKey] or {}) do
            if type(config) == "table" and config.hideInCooldownManager then
                return true
            end
        end
    end

    return false
end

local function ShouldHideFrame(storeKey, frame)
    local db = GetDatabase()
    local store = db and db[storeKey]
    if type(store) ~= "table" then
        return false
    end

    local cooldownID = GetCooldownID(frame)
    if not cooldownID or not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
        return false
    end

    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    for _, spellID in ipairs(BuildSpellCandidates(info, storeKey)) do
        local config = store[spellID]
        if type(config) == "table" and config.hideInCooldownManager then
            return true
        end
    end

    return false
end

local function ApplyHiddenState(frame, hidden)
    if not frame then
        return
    end

    local state = hiddenFrames[frame]
    if hidden then
        if not state then
            local originalAlpha = 1
            if frame.GetAlpha then
                originalAlpha = frame:GetAlpha() or 1
            end

            local mouseEnabled = nil
            if frame.IsMouseEnabled then
                local ok, value = pcall(frame.IsMouseEnabled, frame)
                if ok then
                    mouseEnabled = value
                end
            end

            state = {
                alpha = originalAlpha,
                mouseEnabled = mouseEnabled,
            }
            hiddenFrames[frame] = state
        end

        if frame.SetAlpha then
            pcall(frame.SetAlpha, frame, 0)
        end
        if frame.EnableMouse then
            pcall(frame.EnableMouse, frame, false)
        end
        return
    end

    if not state then
        return
    end

    if frame.SetAlpha then
        pcall(frame.SetAlpha, frame, state.alpha or 1)
    end
    if frame.EnableMouse and state.mouseEnabled ~= nil then
        pcall(frame.EnableMouse, frame, state.mouseEnabled)
    end

    hiddenFrames[frame] = nil
end

local function ApplyToViewer(viewerInfo)
    local viewer = _G[viewerInfo.name]
    if not viewer then
        return
    end

    if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        for frame in viewer.itemFramePool:EnumerateActive() do
            ApplyHiddenState(frame, ShouldHideFrame(viewerInfo.storeKey, frame))
        end
        return
    end

    if viewer.GetChildren then
        for _, frame in ipairs({ viewer:GetChildren() }) do
            ApplyHiddenState(frame, ShouldHideFrame(viewerInfo.storeKey, frame))
        end
    end
end

local function ApplyToAllViewers()
    for _, viewerInfo in ipairs(VIEWERS) do
        ApplyToViewer(viewerInfo)
    end
end

local function RestoreAllHiddenFrames()
    for frame in pairs(hiddenFrames) do
        ApplyHiddenState(frame, false)
    end
end

local function RefreshCooldownHider()
    if HasActiveHideRules() then
        ApplyToAllViewers()
    else
        RestoreAllHiddenFrames()
    end
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.5, RefreshCooldownHider)
end
RefreshCooldownHider()

VFlow.on("PLAYER_ENTERING_WORLD", "GraphicMonitorCooldownHider", function()
    C_Timer.After(0.5, RefreshCooldownHider)
    C_Timer.After(2.0, RefreshCooldownHider)
end)
VFlow.on("PLAYER_SPECIALIZATION_CHANGED", "GraphicMonitorCooldownHider", function()
    C_Timer.After(0.2, RefreshCooldownHider)
end)
VFlow.on("TRAIT_CONFIG_UPDATED", "GraphicMonitorCooldownHider", function()
    C_Timer.After(0.2, RefreshCooldownHider)
end)

VFlow.Store.watch(MODULE_KEY, "GraphicMonitorCooldownHider", function(key)
    if key == "skills" or key == "buffs" or key:find("%.hideInCooldownManager$") then
        RefreshCooldownHider()
    end
end)
