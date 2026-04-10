local _, NS = ...

local MemoryManager = {}
NS.MemoryManager = MemoryManager

local POLL_INTERVAL = 5
local SOFT_DELTA_KB = 768
local HARD_DELTA_KB = 2048
local GC_STEP_SIZE = 200
local GC_STEP_BURST = 3
local FULL_GC_MIN_INTERVAL = 30

local function GetAddonMemoryKB()
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end

    if C_AddOns and C_AddOns.GetAddOnMemoryUsage then
        return tonumber(C_AddOns.GetAddOnMemoryUsage(NS.ADDON_NAME)) or 0
    end

    if GetAddOnMemoryUsage then
        return tonumber(GetAddOnMemoryUsage(NS.ADDON_NAME)) or 0
    end

    return 0
end

function MemoryManager:RunStepGC()
    for _ = 1, GC_STEP_BURST do
        if collectgarbage("step", GC_STEP_SIZE) then
            break
        end
    end
end

function MemoryManager:RunFullGC(now)
    collectgarbage("collect")
    self.lastFullGCAt = now
end

function MemoryManager:Tick()
    local now = GetTime()
    local currentKB = GetAddonMemoryKB()
    if currentKB <= 0 then
        return
    end

    if not self.lowWaterKB or currentKB < self.lowWaterKB then
        self.lowWaterKB = currentKB
        return
    end

    local deltaKB = currentKB - self.lowWaterKB
    if deltaKB < SOFT_DELTA_KB then
        return
    end

    if deltaKB >= HARD_DELTA_KB
        and not InCombatLockdown()
        and ((now - (self.lastFullGCAt or 0)) >= FULL_GC_MIN_INTERVAL)
    then
        self:RunFullGC(now)
    else
        self:RunStepGC()
    end

    local postGCKB = GetAddonMemoryKB()
    if postGCKB > 0 and (not self.lowWaterKB or postGCKB < self.lowWaterKB) then
        self.lowWaterKB = postGCKB
    end
end

function MemoryManager:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    self.lowWaterKB = GetAddonMemoryKB()

    if C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(POLL_INTERVAL, function()
            MemoryManager:Tick()
        end)
    end
end
