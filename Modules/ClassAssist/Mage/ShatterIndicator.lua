local _, NS = ...
local Core = NS.Core

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local ShatterIndicator = {}
NS.Modules.ClassAssist.Mage.ShatterIndicator = ShatterIndicator

-- =========================================================
-- SECTION 1: 常量
-- =========================================================

local MAGE_CLASS_FILE = "MAGE"
local FROST_SPEC_ID = 64
local MAX_STACKS = 20
local TEST_INTERVAL = 0.08
local UPDATE_INTERVAL = 0.1
local MAP_RETRY_INTERVAL = 1.5
local FALLBACK_ICON_SPELL_ID = 228358
-- 这里不再直接盯 Winter's Chill 的 aura spellID。
-- 根据你本地 VFlow 存档，冷却管理器里被真正扫描/配置出来的 spellID 是 1221389。
-- VFlow 的 BuffScanner 也是以这个冷却管理器 spellID 作为监控键。
local TRACKED_SPELL_ID = 1221389
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local CDM_VIEWERS = {
    "BuffIconCooldownViewer",
}

local BUILTIN_TEXTURES = {
    ["纯色"] = "Interface\\Buttons\\WHITE8X8",
    ["暴雪"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["团队"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    ["技能条"] = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
}

-- =========================================================
-- SECTION 2: 通用辅助
-- =========================================================

local function RoundOffset(value)
    local number = tonumber(value) or 0
    if math.abs(number) < 0.001 then return 0 end
    if number >= 0 then return math.floor(number + 0.5) end
    return math.ceil(number - 0.5)
end

local function Clamp(number, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, tonumber(number) or minValue))
end

local function ConfigureStatusBar(bar)
    local texture = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if texture then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function ApplyChatLikeFont(fontString, size)
    if not fontString then
        return
    end

    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, "OUTLINE")
        return
    end

    local fontObject = ChatFontNormal
    if fontObject and fontObject.GetFont then
        local fontPath, _, flags = fontObject:GetFont()
        if fontPath then
            fontString:SetFont(fontPath, size or 12, flags or "")
            return
        end
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
end

local function GetCenterOffset(frame)
    local scale = frame:GetScale()
    if not scale or scale == 0 then return 0, 0 end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return 0, 0 end
    left, right, top, bottom = left * scale, right * scale, top * scale, bottom * scale
    local pw, ph = UIParent:GetSize()
    return ((left + right) * 0.5 - pw * 0.5) / scale, ((bottom + top) * 0.5 - ph * 0.5) / scale
end

local function SortMonitorList(list)
    table.sort(list, function(a, b) return (a.count or 0) < (b.count or 0) end)
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function NormalizeAuraInstanceID(value)
    if type(value) == "table" then
        value = value.auraInstanceID
    end
    if value == nil then
        return nil
    end
    if IsSecretValue(value) then
        return value
    end
    if type(value) == "number" and value > 0 then
        return value
    end
    return nil
end

local function GetSpellIconTexture(spellID)
    if not (C_Spell and C_Spell.GetSpellInfo and spellID) then
        return nil
    end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    return spellInfo and spellInfo.iconID or nil
end

local function GetDefaultIconTexture()
    return GetSpellIconTexture(TRACKED_SPELL_ID)
        or GetSpellIconTexture(FALLBACK_ICON_SPELL_ID)
        or 135848
end

-- =========================================================
-- SECTION 3: CDM 帧辅助（完全复制 VFlow Section 6）
-- =========================================================

local function HasAuraInstanceID(value)
    return NormalizeAuraInstanceID(value) ~= nil
end

local function GetCooldownIDFromFrame(frame)
    local cdID = frame.cooldownID
    if not cdID and frame.cooldownInfo then
        cdID = frame.cooldownInfo.cooldownID
    end
    return cdID
end

local function GetCooldownViewerInfo(cooldownID)
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
        return nil
    end

    return C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
end

local function ResolveSpellID(info)
    if not info then return nil end
    local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
    return linked or info.overrideSpellID or (info.spellID and info.spellID > 0 and info.spellID) or nil
end

-- spellID → cooldownID 映射
local _spellToCooldownID = {}
-- cooldownID → CDM帧 缓存
local _cooldownIDToFrame = {}
-- 重试间隔控制
local _spellMapRetryAt = {}
-- CDM帧 Hook 管理
local _hookedFrames = setmetatable({}, { __mode = "k" })
local _everHookedFrames = setmetatable({}, { __mode = "k" })

local function ForEachViewerFrame(callback)
    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            if viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do
                    if callback(frame, viewer) then
                        return true
                    end
                end
            else
                for _, child in ipairs({ viewer:GetChildren() }) do
                    if callback(child, viewer) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function RegisterSpellMapping(spellID, cooldownID)
    if spellID and spellID > 0 and not _spellToCooldownID[spellID] then
        _spellToCooldownID[spellID] = cooldownID
    end
end

-- 从单个 CDM 帧注册映射（只追加 不覆盖）
local function RegisterCDMFrame(frame)
    local cdID = GetCooldownIDFromFrame(frame)
    if not cdID then return end
    _cooldownIDToFrame[cdID] = frame
    local info = GetCooldownViewerInfo(cdID)
    if not info then return end
    local sid = ResolveSpellID(info)
    RegisterSpellMapping(sid, cdID)
    if info.linkedSpellIDs then
        for _, lid in ipairs(info.linkedSpellIDs) do
            RegisterSpellMapping(lid, cdID)
        end
    end
    RegisterSpellMapping(info.spellID, cdID)
end

-- 全量扫描重建映射（脱战时调用）
local function ScanCDMViewers()
    if InCombatLockdown() then return end
    wipe(_spellToCooldownID)
    wipe(_cooldownIDToFrame)
    wipe(_spellMapRetryAt)

    ForEachViewerFrame(function(frame)
        RegisterCDMFrame(frame)
        return false
    end)
end

-- 战斗中为单个 spellID 补建映射
local function TryMapSpellID(spellID)
    local now = GetTime and GetTime() or 0
    local retryAt = _spellMapRetryAt[spellID]
    if retryAt and now < retryAt then return end

    local found = ForEachViewerFrame(function(frame)
        local cdID = GetCooldownIDFromFrame(frame)
        if not cdID then return false end

        local info = GetCooldownViewerInfo(cdID)
        if not info then return false end

        local sid = ResolveSpellID(info)
        if sid == spellID or info.spellID == spellID then
            RegisterCDMFrame(frame)
            return true
        end

        if info.linkedSpellIDs then
            for _, lid in ipairs(info.linkedSpellIDs) do
                if lid == spellID then
                    RegisterCDMFrame(frame)
                    return true
                end
            end
        end

        return false
    end)

    if found then
        _spellMapRetryAt[spellID] = nil
        return
    end

    _spellMapRetryAt[spellID] = now + MAP_RETRY_INTERVAL
end

local function FindCDMFrame(cooldownID)
    if not cooldownID then return nil end
    local cached = _cooldownIDToFrame[cooldownID]
    if cached then return cached end

    local matchedFrame = nil
    ForEachViewerFrame(function(frame)
        local cdID = GetCooldownIDFromFrame(frame)
        if cdID == cooldownID then
            _cooldownIDToFrame[cdID] = frame
            matchedFrame = frame
            return true
        end

        return false
    end)

    return matchedFrame
end

-- =========================================================
-- SECTION 4: CDM 帧 Hook（复制 VFlow Section 7）
-- =========================================================

-- 当 CDM 帧刷新时的回调（即时触发更新）
local function OnCDMFrameChanged(frame, ...)
    local auraInstanceID = nil
    local auraUnit = nil
    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        if not auraInstanceID then
            auraInstanceID = NormalizeAuraInstanceID(arg)
        end
        if not auraUnit and type(arg) == "string" and arg ~= "" then
            auraUnit = arg
        end
    end

    if ShatterIndicator._active and ShatterIndicator._mainFrame then
        if auraInstanceID then
            ShatterIndicator._lastCDMAuraInstanceID = auraInstanceID
            ShatterIndicator._trackedAuraInstanceID = auraInstanceID
        end
        if auraUnit then
            ShatterIndicator._trackedUnit = auraUnit
        elseif frame and frame.auraDataUnit then
            ShatterIndicator._trackedUnit = frame.auraDataUnit
        end
        ShatterIndicator:UpdateStacks()
    end
end

local function HookCDMFrame(cdmFrame)
    if not cdmFrame or _hookedFrames[cdmFrame] then return end
    _hookedFrames[cdmFrame] = true
    -- Hook RefreshData
    if cdmFrame.RefreshData and not _everHookedFrames[cdmFrame] then
        hooksecurefunc(cdmFrame, "RefreshData", OnCDMFrameChanged)
    end
    -- Hook RefreshApplications
    if cdmFrame.RefreshApplications and not _everHookedFrames[cdmFrame] then
        hooksecurefunc(cdmFrame, "RefreshApplications", OnCDMFrameChanged)
    end
    -- Hook SetAuraInstanceInfo
    if cdmFrame.SetAuraInstanceInfo and not _everHookedFrames[cdmFrame] then
        hooksecurefunc(cdmFrame, "SetAuraInstanceInfo", OnCDMFrameChanged)
    end
    _everHookedFrames[cdmFrame] = true
end

local function ClearAllHooks()
    wipe(_hookedFrames)
end

-- =========================================================
-- SECTION 5: 光环查询（VFlow Section 5 + 12）
-- =========================================================

-- O(1) 查询：根据 auraInstanceID 从指定单位获取光环数据
local function GetAuraDataByInstanceID(auraInstanceID, preferredUnit, secondUnit)
    auraInstanceID = NormalizeAuraInstanceID(auraInstanceID)
    if not auraInstanceID then
        return nil, nil
    end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID then return nil, nil end
    if preferredUnit and UnitExists(preferredUnit) then
        local data = C_UnitAuras.GetAuraDataByAuraInstanceID(preferredUnit, auraInstanceID)
        if data then return data, preferredUnit end
    end
    if secondUnit and secondUnit ~= preferredUnit and UnitExists(secondUnit) then
        local data = C_UnitAuras.GetAuraDataByAuraInstanceID(secondUnit, auraInstanceID)
        if data then return data, secondUnit end
    end
    -- 碎冰总在 target 上
    for _, unit in ipairs({"target", "focus", "mouseover"}) do
        if unit ~= preferredUnit and unit ~= secondUnit and UnitExists(unit) then
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
            if data then return data, unit end
        end
    end
    return nil, nil
end

-- =========================================================
-- SECTION 6: Arc Detector（完全沿用 VFlow stacks 解码方案）
-- =========================================================

local function GetArcDetector(barFrame, threshold)
    barFrame._arcDetectors = barFrame._arcDetectors or {}
    local detector = barFrame._arcDetectors[threshold]
    if detector then
        return detector
    end

    detector = CreateFrame("StatusBar", nil, barFrame)
    detector:SetSize(1, 1)
    detector:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
    detector:SetAlpha(0)
    detector:SetStatusBarTexture(BAR_TEXTURE)
    detector:SetMinMaxValues(threshold - 1, threshold)
    detector:EnableMouse(false)
    ConfigureStatusBar(detector)
    barFrame._arcDetectors[threshold] = detector
    return detector
end

local function FeedArcDetectors(barFrame, secretValue, maxVal)
    for index = 1, maxVal do
        GetArcDetector(barFrame, index):SetValue(secretValue)
    end
end

local function GetExactCount(barFrame, maxVal)
    if not barFrame._arcDetectors then
        return 0
    end

    local count = 0
    for index = 1, maxVal do
        local detector = barFrame._arcDetectors[index]
        local texture = detector and detector:GetStatusBarTexture()
        if texture and texture:IsShown() then
            count = index
        else
            break
        end
    end
    return count
end

local function ResetArcDetectors(barFrame, maxVal)
    if not barFrame or not barFrame._arcDetectors then
        return
    end

    for index = 1, maxVal do
        local detector = barFrame._arcDetectors[index]
        if detector then
            detector:SetValue(0)
        end
    end
end

local function CreateSegmentBorder(holder)
    local borderColor = { 0, 0, 0, 0.95 }

    local top = holder:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(unpack(borderColor))
    top:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    top:SetHeight(1)

    local bottom = holder:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(unpack(borderColor))
    bottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)

    local left = holder:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(unpack(borderColor))
    left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)

    local right = holder:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(unpack(borderColor))
    right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
end

-- =========================================================
-- SECTION 7: 配置方法
-- =========================================================

function ShatterIndicator:GetConfig()
    return Core.db.classAssist.mage.shatterIndicator
end

function ShatterIndicator:IsEnabled()
    return self:GetConfig().enabled
end

function ShatterIndicator:GetTextureChoices()
    local choices = {}
    for name, _ in pairs(BUILTIN_TEXTURES) do choices[name] = name end
    if LSM then
        for _, name in ipairs(LSM:List("statusbar")) do
            if not BUILTIN_TEXTURES[name] then choices[name] = name end
        end
    end
    return choices
end

function ShatterIndicator:GetResolvedTexturePath()
    local textureName = self:GetConfig().texture or "纯色"
    if BUILTIN_TEXTURES[textureName] then return BUILTIN_TEXTURES[textureName] end
    if LSM then
        local path = LSM:Fetch("statusbar", textureName, true)
        if path then return path end
    end
    return BAR_TEXTURE
end

function ShatterIndicator:RefreshRenderedCountText(value)
    if not self._mainFrame then return end

    local isSecret = IsSecretValue(value)

    if isSecret then
        self:SetStackSegmentValue(value)
        FeedArcDetectors(self._mainFrame, value, MAX_STACKS)
    else
        ResetArcDetectors(self._mainFrame, MAX_STACKS)
        self:SetStackSegmentValue(value or 0)
    end

    if not self._countText then return end

    if isSecret then
        self._countText:SetText(value)
        self._countText:Show()
    elseif (value or 0) == 0 then
        self._countText:SetText("")
        self._countText:Hide()
    else
        self._countText:SetText(tostring(value))
        self._countText:Show()
    end
end

-- =========================================================
-- SECTION 8: 状态管理
-- =========================================================

function ShatterIndicator:ResetState()
    self._rawStacks = 0
    self._lastKnownActive = false
    self._auraActive = false
    self._lastCDMAuraInstanceID = nil
    self._trackedAuraInstanceID = nil
    self._trackedUnit = nil
    self._nilGraceCount = 0
    self._iconTexture = nil
end

function ShatterIndicator:IsTesting()
    return self._testing == true
end

function ShatterIndicator:ToggleTestMode()
    if self._testing then
        self._testing = false
        self._testStacks = nil
        self:ResetState()
        if self._active then
            self:StartUpdating()
        end
    else
        self._testing = true
        self._testStacks = 0
        self._testUp = true
        self:StopUpdating()
    end
    self:RefreshDisplay()
end

function ShatterIndicator:StopUpdating()
    if self._updateTicker then
        self._updateTicker:Cancel()
        self._updateTicker = nil
    end
end

function ShatterIndicator:StartUpdating()
    self:StopUpdating()
    self._updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function() self:UpdateStacks() end)
end

-- =========================================================
-- SECTION 9: 核心更新逻辑（VFlow 三级优先路径）
-- =========================================================

function ShatterIndicator:UpdateStacks()
    if self._testing then return end
    if not self._active then return end

    local auraActive = false
    local stacks = 0
    local rawStacks = 0
    local auraData = nil

    -- Path 1: 冷却管理器帧路径（唯一主路径）
    local cooldownID = _spellToCooldownID[TRACKED_SPELL_ID]
    if not cooldownID then
        TryMapSpellID(TRACKED_SPELL_ID)
        cooldownID = _spellToCooldownID[TRACKED_SPELL_ID]
    end

    if cooldownID then
        local cdmFrame = FindCDMFrame(cooldownID)
        if cdmFrame then
            HookCDMFrame(cdmFrame)
            local instID = cdmFrame.auraInstanceID
            if HasAuraInstanceID(instID) then
                local trackedUnit = nil
                auraData, trackedUnit = GetAuraDataByInstanceID(instID, cdmFrame.auraDataUnit or "target", self._trackedUnit)
                if auraData then
                    self._trackedAuraInstanceID = instID
                    self._trackedUnit = trackedUnit or cdmFrame.auraDataUnit or "target"
                    self._iconTexture = (cdmFrame.Icon and cdmFrame.Icon.GetTexture and cdmFrame.Icon:GetTexture())
                        or auraData.icon
                        or self._iconTexture
                    auraActive = true
                    stacks = auraData.applications or 0
                end
            end
        end
    end

    -- Path 2: 缓存的 auraInstanceID（CDM Hook 推送的 或 上一次成功的）
    if not auraActive then
        local cachedInstID = self._lastCDMAuraInstanceID or self._trackedAuraInstanceID
        if HasAuraInstanceID(cachedInstID) then
            local trackedUnit = nil
            auraData, trackedUnit = GetAuraDataByInstanceID(cachedInstID, self._trackedUnit or "target", "target")
            if auraData then
                self._trackedAuraInstanceID = cachedInstID
                self._trackedUnit = trackedUnit or self._trackedUnit or "target"
                self._iconTexture = auraData.icon or self._iconTexture
                auraActive = true
                stacks = auraData.applications or 0
            end
        end
    end

    -- Nil grace（VFlow 的 nil 容忍机制：连续5帧 nil 才清除）
    if not auraActive then
        if self._lastKnownActive then
            self._nilGraceCount = (self._nilGraceCount or 0) + 1
            if self._nilGraceCount <= 5 then
                return  -- 冻结显示，不更新
            end
        end
        stacks = 0
        self._lastKnownActive = false
        self._lastKnownStacks = 0
        self._trackedAuraInstanceID = nil
        self._lastCDMAuraInstanceID = nil
        self._trackedUnit = nil
        self._auraActive = false
    else
        self._nilGraceCount = 0
        self._lastKnownActive = true
        self._auraActive = true
        if not IsSecretValue(stacks) and type(stacks) == "number" then
            self._lastKnownStacks = stacks
        end
    end

    rawStacks = stacks
    self._stacks = stacks
    self._rawStacks = rawStacks
    self:RefreshDisplay()
end

-- =========================================================
-- SECTION 10: 显示状态计算
-- =========================================================

function ShatterIndicator:GetDisplayState()
    if self._testing then return "TESTING" end
    if not self._active then return "HIDDEN" end
    if self._auraActive then return "ACTIVE" end
    if not self:GetConfig().showOutOfCombat and not InCombatLockdown() then
        return "HIDDEN"
    end
    return "IDLE"
end

-- =========================================================
-- SECTION 11: 测试模式更新
-- =========================================================

function ShatterIndicator:UpdateTestMode()
    if not self._testing then return end
    local maxCount = MAX_STACKS

    if self._testUp then
        self._testStacks = (self._testStacks or 0) + 1
        if self._testStacks >= maxCount then self._testUp = false end
    else
        self._testStacks = (self._testStacks or 0) - 1
        if self._testStacks <= 0 then self._testUp = true end
    end
    self._rawStacks = self._testStacks
    self._auraActive = self._testStacks > 0
    self:RefreshDisplay()
end

-- =========================================================
-- SECTION 12: UI 创建
-- =========================================================

function ShatterIndicator:CreateFrame()
    if self._mainFrame then return end
    local config = self:GetConfig()

    local mainFrame = CreateFrame("Frame", "YuXuanShatterIndicator", UIParent)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(100)
    mainFrame:SetClampedToScreen(true)
    self._mainFrame = mainFrame

    -- 图标（默认冻结法术图标）
    local icon = mainFrame:CreateTexture(nil, "ARTWORK")
    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(TRACKED_SPELL_ID)
    if not spellInfo then
        spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(FALLBACK_ICON_SPELL_ID)
    end
    local iconTexture = spellInfo and spellInfo.iconID or 135848
    icon:SetTexture(iconTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self._icon = icon

    local textLayer = CreateFrame("Frame", nil, mainFrame)
    textLayer:SetAllPoints(mainFrame)
    textLayer:SetFrameLevel(mainFrame:GetFrameLevel() + 50)
    textLayer:EnableMouse(false)
    self._textLayer = textLayer

    local countText = textLayer:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("CENTER", textLayer, "CENTER", 0, 0)
    countText:SetJustifyH("CENTER")
    countText:SetJustifyV("MIDDLE")
    countText:SetDrawLayer("OVERLAY", 7)
    countText:SetShadowOffset(1, -1)
    countText:SetShadowColor(0, 0, 0, 0.9)
    ApplyChatLikeFont(countText, 14)
    countText:SetText("")
    countText:Hide()
    self._countText = countText

    -- 条
    self._bars = {}
    self._barBackgrounds = {}
    self._barFrames = {}
    self._thresholdOverlays = {}

    -- 拖拽
    mainFrame:EnableMouse(false)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local offsetX, offsetY = GetCenterOffset(f)
        config.offsetX = RoundOffset(offsetX)
        config.offsetY = RoundOffset(offsetY)
    end)
end

function ShatterIndicator:ReleaseBarWidgets()
    if self._thresholdOverlays then
        for _, overlay in ipairs(self._thresholdOverlays) do
            overlay:Hide()
            overlay:SetParent(nil)
        end
    end
    if self._bars then
        for _, bar in ipairs(self._bars) do
            bar:Hide()
            bar:SetParent(nil)
        end
    end
    if self._barBackgrounds then
        for _, bg in ipairs(self._barBackgrounds) do
            bg:Hide()
            bg:SetParent(nil)
        end
    end
    if self._barFrames then
        for _, frame in ipairs(self._barFrames) do
            frame:Hide()
            frame:SetParent(nil)
        end
    end

    self._bars = {}
    self._barBackgrounds = {}
    self._barFrames = {}
    self._thresholdOverlays = {}
end

function ShatterIndicator:SetStackSegmentValue(value)
    value = value or 0
    for _, bar in ipairs(self._bars or {}) do
        bar:SetValue(value)
    end
    for _, overlay in ipairs(self._thresholdOverlays or {}) do
        overlay:SetValue(value)
    end
end

-- =========================================================
-- SECTION 13: 布局刷新
-- =========================================================

function ShatterIndicator:RefreshLayout()
    if not self._mainFrame then return end
    local config = self:GetConfig()

    local barWidth = Clamp(config.width or 14, 4, 100)
    local barHeight = Clamp(config.height or 18, 4, 200)
    local spacing = Clamp(config.spacing or 2, 0, 20)
    local scale = Clamp(config.scale or 1.0, 0.5, 3.0)
    local showIcon = config.showIcon ~= false
    local showBorders = config.showBorders ~= false
    local texturePath = self:GetResolvedTexturePath()
    local defaultColor = config.defaultColor or { r = 0.3, g = 0.7, b = 1.0, a = 1.0 }

    -- monitorList
    local monitorList = config.monitorList or {}
    SortMonitorList(monitorList)

    local maxStacks = MAX_STACKS

    -- 图标
    local iconWidth = 0
    if showIcon then
        self._icon:Show()
        self._icon:SetSize(barHeight, barHeight)
        self._icon:SetPoint("LEFT", self._mainFrame, "LEFT", 0, 0)
        iconWidth = barHeight + spacing
    else
        self._icon:Hide()
        iconWidth = 0
    end

    -- 总宽度
    local totalWidth = iconWidth + maxStacks * barWidth + math.max(0, maxStacks - 1) * spacing
    local totalHeight = barHeight

    self._mainFrame:SetSize(totalWidth, totalHeight)
    self._mainFrame:SetScale(scale)

    -- 每次配置变化都按当前配置重建一遍分段，和 VFlow 一样让 secret value 直接喂给 StatusBar。
    self:ReleaseBarWidgets()

    for i = 1, maxStacks do
        local offsetX = iconWidth + (i - 1) * (barWidth + spacing)
        local holder = CreateFrame("Frame", nil, self._mainFrame)
        holder:SetSize(barWidth, barHeight)
        holder:SetPoint("LEFT", self._mainFrame, "LEFT", offsetX, 0)
        holder:SetFrameLevel(self._mainFrame:GetFrameLevel() + 1)
        self._barFrames[i] = holder

        local bg = holder:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(holder)
        bg:SetColorTexture(0, 0, 0, 0.6)
        self._barBackgrounds[i] = bg

        if showBorders then
            local borderColor = { 0, 0, 0, 0.95 }

            local top = holder:CreateTexture(nil, "OVERLAY")
            top:SetColorTexture(unpack(borderColor))
            top:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
            top:SetHeight(1)

            local bottom = holder:CreateTexture(nil, "OVERLAY")
            bottom:SetColorTexture(unpack(borderColor))
            bottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
            bottom:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
            bottom:SetHeight(1)

            local left = holder:CreateTexture(nil, "OVERLAY")
            left:SetColorTexture(unpack(borderColor))
            left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            left:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
            left:SetWidth(1)

            local right = holder:CreateTexture(nil, "OVERLAY")
            right:SetColorTexture(unpack(borderColor))
            right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
            right:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
            right:SetWidth(1)
        end

        local bar = CreateFrame("StatusBar", nil, holder)
        bar:SetAllPoints(holder)
        bar:SetStatusBarTexture(texturePath)
        bar:SetStatusBarColor(defaultColor.r or 1, defaultColor.g or 1, defaultColor.b or 1, defaultColor.a or 1)
        bar:SetMinMaxValues(i - 1, i)
        bar:SetValue(0)
        bar:SetFrameLevel(holder:GetFrameLevel() + 1)
        ConfigureStatusBar(bar)
        self._bars[i] = bar

        for monitorIndex, entry in ipairs(monitorList) do
            local threshold = Clamp(entry.count or 0, 1, maxStacks)
            local color = entry.color or defaultColor
            local overlay = CreateFrame("StatusBar", nil, holder)
            overlay:SetAllPoints(holder)
            overlay:SetStatusBarTexture(texturePath)
            overlay:SetStatusBarColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
            overlay:SetFrameLevel(holder:GetFrameLevel() + 1 + monitorIndex)
            overlay:SetMinMaxValues((i < threshold) and (threshold - 1) or (i - 1), (i < threshold) and threshold or i)
            overlay:SetValue(0)
            ConfigureStatusBar(overlay)
            table.insert(self._thresholdOverlays, overlay)
        end
    end

    -- 位置
    self._mainFrame:ClearAllPoints()
    local ox = RoundOffset(config.offsetX or 0)
    local oy = RoundOffset(config.offsetY or 0)
    self._mainFrame:SetPoint("CENTER", UIParent, "CENTER", ox, oy)

    if self._countText then
        local fontSize = Clamp(math.floor(barHeight * scale * 0.85), 10, 32)
        ApplyChatLikeFont(self._countText, fontSize)
        self._countText:ClearAllPoints()
        self._countText:SetPoint("CENTER", self._textLayer or self._mainFrame, "CENTER", 0, 0)
    end
end

-- =========================================================
-- SECTION 14: 显示刷新
-- =========================================================

function ShatterIndicator:RefreshDisplay()
    if not self._mainFrame then return end

    local state = self:GetDisplayState()
    local config = self:GetConfig()

    -- 隐藏/显示判断
    if state == "HIDDEN" then
        if self._countText then
            self._countText:Hide()
        end
        self._mainFrame:Hide()
        return
    end

    self._mainFrame:Show()

    if self._icon then
        local iconTexture = self._iconTexture
        if not iconTexture then
            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(TRACKED_SPELL_ID)
            if not spellInfo then
                spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(FALLBACK_ICON_SPELL_ID)
            end
            iconTexture = spellInfo and spellInfo.iconID or 135848
        end
        self._icon:SetTexture(iconTexture)
    end

    -- 解锁拖拽
    local unlocked = config.unlocked == true
    self._mainFrame:EnableMouse(unlocked)

    local displayValue = self._testing and (self._testStacks or 0) or (self._rawStacks or 0)
    self:RefreshRenderedCountText(displayValue)
end

-- =========================================================
-- SECTION 15: 事件处理
-- =========================================================

function ShatterIndicator:OnEvent(event, ...)
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        self:EvaluateActivation()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 进入战斗：清除 hook 状态以重新绑定
        ClearAllHooks()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 脱战：全量重建 CDM 映射
        ScanCDMViewers()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "target" then
            -- target 光环变化：标记脏状态以加速下一次 UpdateStacks
            if self._active then
                self:UpdateStacks()
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- 切目标：重置缓存
        self._trackedAuraInstanceID = nil
        self._lastCDMAuraInstanceID = nil
        self._trackedUnit = nil
        self._nilGraceCount = 0
        if self._active then
            self:UpdateStacks()
        end
    end
end

-- =========================================================
-- SECTION 16: 激活/停用
-- =========================================================

function ShatterIndicator:EvaluateActivation()
    local _, classFile = UnitClass("player")
    if classFile ~= MAGE_CLASS_FILE then
        self:Deactivate()
        return
    end

    local specIndex = GetSpecialization and GetSpecialization() or 0
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex) or 0

    if specID ~= FROST_SPEC_ID then
        self:Deactivate()
        return
    end

    if not self:IsEnabled() then
        self:Deactivate()
        return
    end

    self:Activate()
end

function ShatterIndicator:Activate()
    if self._active then return end
    self._active = true

    self:CreateFrame()
    self:ResetState()
    self:RefreshLayout()

    -- 初始全量扫描 CDM
    ScanCDMViewers()

    -- 启动轮询
    self:StartUpdating()

    -- 测试模式定时器
    if self._testing then
        self:StopUpdating()
    end
    if not self._testTicker then
        self._testTicker = C_Timer.NewTicker(TEST_INTERVAL, function()
            if self._testing then self:UpdateTestMode() end
        end)
    end

    self:RefreshDisplay()
end

function ShatterIndicator:Deactivate()
    if not self._active then return end
    self._active = false

    self:StopUpdating()
    ClearAllHooks()

    if self._mainFrame then self._mainFrame:Hide() end
    self:ResetState()
end

-- =========================================================
-- SECTION 17: 公开接口
-- =========================================================

function ShatterIndicator:RefreshFromSettings()
    self:EvaluateActivation()
    if self._mainFrame then
        self:RefreshLayout()
        self:RefreshDisplay()
    end
end

function ShatterIndicator:Refresh()
    self:EvaluateActivation()
end

-- =========================================================
-- SECTION 18: 生命周期入口
-- =========================================================

function ShatterIndicator:OnPlayerLogin()
    local _, classFile = UnitClass("player")
    if classFile ~= MAGE_CLASS_FILE then return end

    -- 注册事件
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event, ...) self:OnEvent(event, ...) end)
    self._eventFrame = eventFrame

    -- 延迟初始化（等待 CDM 帧加载完毕）
    C_Timer.After(1.0, function()
        ScanCDMViewers()
        self:EvaluateActivation()
    end)
end
