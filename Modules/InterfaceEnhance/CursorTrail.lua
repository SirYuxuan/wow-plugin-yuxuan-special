local _, NS = ...
local Core = NS.Core

local CursorTrail = {}
NS.Modules.InterfaceEnhance.CursorTrail = CursorTrail

--[[
鼠标指针 / 鼠标拖尾
1. 参考 FrogskisCursorTrail 的拖尾算法，按鼠标移动路径生成一串点。
2. 支持调色板、职业色覆盖、纹理切换、混合模式、性能节流和右键高亮。
3. 不复制参考插件自己的 profile / 条件切换系统，统一复用当前插件的配置体系。
]]

local abs = math.abs
local sqrt = math.sqrt
local MOUSELOOK_CURSOR_ATLAS = "Cursor_cast_128"

local Anchor
local headTex
local slotTex = {}
local pointsX, pointsY, pointsT = {}, {}, {}
local headIndex = 1
local haveInit = false
local trailDist = 0
local lastX, lastY
local lastSampleX, lastSampleY
local lastUpdateTime
local lastEmitTime = 0
local lastHeadPX, lastHeadPY
local lastHeadOffX, lastHeadOffY
local trailDormant = false
local dormantX, dormantY

local ElementCap = 300
local MaxSpacing = 3
local duration = 0.35
local invDuration = 1 / duration
local onlyInCombat = false
local rainbowByTime = true
local colorSpeed = 0.5
local numPhases = 6
local phaseColors
local blendModeStr = "ADD"
local cursorLayerStrata = "TOOLTIP"
local alphaMul = 1.0
local dotW, dotH = 50, 50
local offX, offY = 20, -18
local shrinkWithTime = true
local shrinkWithDistance = true
local adaptiveUpdate = true
local adaptiveTargetFPS = 90
local posByRank = {}
local sqrtPosByRank = {}
local MAX_STEPS_PER_TICK = 250
local glowBoost = 1

local debugHolder
local debugValue1
local debugValue2
local fpsElapsed = 0
local fpsFrames = 0
local fpsValue = 0
local fpsSampleElapsed = 0
local fpsAutoValue = 120
local FPS_SAMPLE_PERIOD = 0.25

local RMBLook = {
    enabled = false,
    inLook = false,
    wasDown = false,
    lastX = 0,
    lastY = 0,
    threshold = 1,
    thresholdPassed = false,
    moveAccum = 0,
    holdActive = false,
    startedByAddon = false,
    enableLook = false,
    enableIndicator = true,
    enableCombatLook = false,
    cursorFrameSize = 40,
    blockWhileVisible = {
        function()
            return CharacterFrame
        end,
    },
}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function CursorTrail:GetConfig()
    return Core:GetConfig("interfaceEnhance", "cursorTrail")
end

local function GetEffectiveConfig()
    return CursorTrail:GetConfig()
end

local function HideTrailTextures()
    if headTex then
        headTex:Hide()
    end

    for index = 1, ElementCap do
        if slotTex[index] then
            slotTex[index]:Hide()
        end
    end
end

local function EnsureAnchor()
    if Anchor then
        return
    end

    Anchor = CreateFrame("Frame", nil, UIParent)
    Anchor:SetAllPoints(UIParent)
end

local function EnsureDebugHolder()
    if debugHolder then
        return
    end

    debugHolder = CreateFrame("Frame", nil, UIParent)
    debugHolder:SetPoint("TOP", UIParent, "TOP", 0, -40)
    debugHolder:SetSize(900, 90)
    debugHolder:Hide()

    local debugLabel1 = debugHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    debugLabel1:SetPoint("TOP", debugHolder, "TOP", 0, 0)
    debugLabel1:SetJustifyH("RIGHT")
    debugLabel1:SetText("鼠标拖尾纹理数量:")
    debugLabel1:SetScale(1.2)

    debugValue1 = debugHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    debugValue1:SetPoint("LEFT", debugLabel1, "RIGHT", 8, 0)
    debugValue1:SetJustifyH("LEFT")
    debugValue1:SetScale(1.2)

    local debugLabel2 = debugHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    debugLabel2:SetPoint("TOP", debugHolder, "TOP", 0, -28)
    debugLabel2:SetJustifyH("RIGHT")
    debugLabel2:SetText("当前 FPS / 更新频率:")
    debugLabel2:SetScale(1.2)

    debugValue2 = debugHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    debugValue2:SetPoint("LEFT", debugLabel2, "RIGHT", 8, 0)
    debugValue2:SetJustifyH("LEFT")
    debugValue2:SetScale(1.2)
end

local function ApplyDebugState()
    EnsureDebugHolder()

    local config = GetEffectiveConfig()
    if config and config.enabled and config.debugEnabled then
        debugHolder:Show()
    else
        debugHolder:Hide()
    end
end

local function WrapIndex(index, count)
    if index < 1 then
        index = index % count
        if index == 0 then
            index = count
        end
    elseif index > count then
        index = ((index - 1) % count) + 1
    end
    return index
end

local function EnsurePoints(count, x, y)
    local now = GetTime()
    lastEmitTime = now

    for index = 1, count do
        pointsX[index] = x
        pointsY[index] = y
        pointsT[index] = now
    end

    headIndex = 1
    haveInit = true
end

local SetSlotTexPos
local SetHeadTexPos

local function ResetTrailSilent(x, y, now)
    local deadTime = now - (duration + 1)
    lastEmitTime = deadTime

    for index = 1, ElementCap do
        pointsX[index] = x
        pointsY[index] = y
        pointsT[index] = deadTime
    end

    for slot = 1, ElementCap do
        if slotTex[slot] then
            SetSlotTexPos(slot, x, y)
        end
    end

    headIndex = 1
    haveInit = true
    lastSampleX, lastSampleY = x, y
    lastX, lastY = x, y
    lastHeadPX, lastHeadPY = nil, nil
    lastHeadOffX, lastHeadOffY = nil, nil
end

local function PushPoint(x, y, now)
    headIndex = WrapIndex(headIndex + 1, ElementCap)
    pointsX[headIndex] = x
    pointsY[headIndex] = y
    pointsT[headIndex] = now or GetTime()
    lastEmitTime = pointsT[headIndex]
    SetSlotTexPos(headIndex, x, y)
end

local function GetCursorXY()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return (x or 0) / scale, (y or 0) / scale
end

SetSlotTexPos = function(slot, x, y)
    local texture = slotTex[slot]
    if not texture then
        return
    end

    texture:ClearAllPoints()
    texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + offX, y + offY)
end

SetHeadTexPos = function(x, y)
    if not headTex then
        return
    end

    local px = x + offX
    local py = y + offY

    if lastHeadPX and lastHeadPY and lastHeadOffX == offX and lastHeadOffY == offY then
        if abs(px - lastHeadPX) < 0.05 and abs(py - lastHeadPY) < 0.05 then
            return
        end
    end

    headTex:ClearAllPoints()
    headTex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", px, py)
    lastHeadPX, lastHeadPY = px, py
    lastHeadOffX, lastHeadOffY = offX, offY
end

local function LooksLikeAPath(path)
    if not path or path == "" then
        return false
    end
    if path:find("\\") or path:find("/") then
        return true
    end

    local lowerPath = path:lower()
    return lowerPath:match("%.blp$") or lowerPath:match("%.tga$") or lowerPath:match("%.png$")
        or lowerPath:match("%.jpg$") or lowerPath:match("%.jpeg$")
end

local function TrySetAtlas(texture, atlasName)
    if atlasName and atlasName ~= "" and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlasName) then
        texture:SetAtlas(atlasName, true)
        return true
    end
    return false
end

local function ApplyElementTexture(texture)
    local config = GetEffectiveConfig()
    local input = config and config.textureInput
    if not input or input == "" then
        input = (config and config.fallbackTexture) or "bags-glow-flash"
    end

    if LooksLikeAPath(input) then
        texture:SetTexture(input)
        texture:SetTexCoord(0, 1, 0, 1)
        return
    end

    if TrySetAtlas(texture, input) then
        return
    end

    texture:SetTexture(input)
    texture:SetTexCoord(0, 1, 0, 1)
end

local function CreateOneTexture()
    EnsureAnchor()

    local texture = Anchor:CreateTexture(nil, "OVERLAY")
    texture:SetSize(dotW, dotH)
    texture:SetBlendMode(blendModeStr)
    texture:SetAlpha(0.9)
    texture:Hide()
    ApplyElementTexture(texture)
    return texture
end

local function EnsureTextures(count)
    EnsureAnchor()

    if not headTex then
        headTex = CreateOneTexture()
    end

    headTex:SetBlendMode(blendModeStr)
    ApplyElementTexture(headTex)

    for slot = 1, count do
        if not slotTex[slot] then
            slotTex[slot] = CreateOneTexture()
        end

        slotTex[slot]:SetBlendMode(blendModeStr)
        ApplyElementTexture(slotTex[slot])
    end

    for slot = count + 1, #slotTex do
        if slotTex[slot] then
            slotTex[slot]:Hide()
        end
    end
end

local function ColorByVisibleRank(rank, total)
    if not phaseColors or not phaseColors[1] then
        return 1, 1, 1
    end

    if not total or total <= 1 then
        local color = phaseColors[1]
        return color[1] or 1, color[2] or 1, color[3] or 1
    end

    local ratio = rank / (total - 1)
    local phases = math.max(1, numPhases or 1)
    if phases == 1 then
        local color = phaseColors[1]
        return color[1] or 1, color[2] or 1, color[3] or 1
    end

    local phasePos = ratio * (phases - 1)
    local index1 = math.floor(phasePos) + 1
    local index2 = math.min(index1 + 1, phases)
    local frac = phasePos - (index1 - 1)
    local color1 = phaseColors[index1] or phaseColors[1]
    local color2 = phaseColors[index2] or color1

    return (color1[1] or 1) + ((color2[1] or 1) - (color1[1] or 1)) * frac,
        (color1[2] or 1) + ((color2[2] or 1) - (color1[2] or 1)) * frac,
        (color1[3] or 1) + ((color2[3] or 1) - (color1[3] or 1)) * frac
end

local function WorldLockedRainbowColor(worldDistPx)
    local phases = math.max(1, numPhases or 1)
    if not phaseColors or not phaseColors[1] or phases == 1 then
        local color = phaseColors and phaseColors[1] or { 1, 1, 1 }
        return color[1] or 1, color[2] or 1, color[3] or 1
    end

    local bandLen = math.max(1e-3, MaxSpacing * (ElementCap / phases)) / math.max(0.1, colorSpeed)
    local position = (worldDistPx / bandLen) % phases
    local index1 = math.floor(position) + 1
    local frac = position - math.floor(position)
    local index2 = (index1 % phases) + 1
    local color1 = phaseColors[index1] or phaseColors[1]
    local color2 = phaseColors[index2] or color1

    return (color1[1] or 1) + ((color2[1] or 1) - (color1[1] or 1)) * frac,
        (color1[2] or 1) + ((color2[2] or 1) - (color1[2] or 1)) * frac,
        (color1[3] or 1) + ((color2[3] or 1) - (color1[3] or 1)) * frac
end

local function GetPlayerClassColorRGB()
    local _, classFile = UnitClass("player")
    if classFile then
        if C_ClassColor and C_ClassColor.GetClassColor then
            local color = C_ClassColor.GetClassColor(classFile)
            if color and color.GetRGB then
                return color:GetRGB()
            end
        end

        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            local color = RAID_CLASS_COLORS[classFile]
            return color.r, color.g, color.b
        end
    end

    return 1, 1, 1
end

local function BuildPhaseColors(config)
    if config.useClassColor then
        local r, g, b = GetPlayerClassColorRGB()
        r = r * 1 / glowBoost
        g = g * 1 / glowBoost
        b = b * 1 / glowBoost
        local color = { r, g, b }
        phaseColors = { color, color, color, color, color, color, color, color, color, color }
        return
    end

    phaseColors = {}
    for index = 1, 10 do
        local color = config["color" .. index]
        phaseColors[index] = type(color) == "table" and color or { 1, 1, 1 }
    end
end

local function EnsureCursorIndicator()
    if RMBLook.cursorFrame then
        return
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(RMBLook.cursorFrameSize, RMBLook.cursorFrameSize)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(99)
    frame:SetAlpha(0.5)
    frame:Hide()

    local base = frame:CreateTexture(nil, "OVERLAY")
    base:SetAllPoints(frame)
    base:SetAtlas(MOUSELOOK_CURSOR_ATLAS, true)

    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(frame)
    glow:SetAtlas(MOUSELOOK_CURSOR_ATLAS, true)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.8)

    RMBLook.cursorFrame = frame
    RMBLook.cursorTex = base
    RMBLook.cursorGlow = glow
end

local function ShowCursorIndicator()
    EnsureCursorIndicator()
    RMBLook.cursorFrame:Show()
end

local function HideCursorIndicator()
    if RMBLook.cursorFrame then
        RMBLook.cursorFrame:Hide()
    end
end

local function UpdateCursorIndicatorPosition()
    if not (RMBLook.cursorFrame and RMBLook.cursorFrame:IsShown()) then
        return
    end

    local x, y
    if type(GetScaledCursorPosition) == "function" then
        x, y = GetScaledCursorPosition()
    end
    if not x or not y then
        x, y = GetCursorXY()
    end

    RMBLook.cursorFrame:ClearAllPoints()
    RMBLook.cursorFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function SafeGetMouseFocus()
    if type(GetMouseFoci) == "function" then
        local foci = { GetMouseFoci() }
        return foci[1]
    end

    if UIParent and UIParent.GetMouseFocus then
        return UIParent:GetMouseFocus()
    end

    return nil
end

local function IsDragFrameUnderMouse()
    local frame = SafeGetMouseFocus()
    while frame and frame ~= UIParent do
        if frame.IsMovable and frame:IsMovable() then
            return true
        end

        if frame.GetScript and (frame:GetScript("OnDragStart") or frame:GetScript("OnDragStop")) then
            return true
        end

        frame = frame.GetParent and frame:GetParent() or nil
    end

    return false
end

local function IsBlocked()
    for index = 1, #RMBLook.blockWhileVisible do
        local getter = RMBLook.blockWhileVisible[index]
        local frame = (type(getter) == "function") and getter() or getter
        if frame and frame.IsShown and frame:IsShown() then
            return true
        end
    end
    return false
end

local function ForEachMouseFrame(callback)
    if type(GetMouseFoci) == "function" then
        local frames = { GetMouseFoci() }
        for index = 1, #frames do
            if frames[index] and callback(frames[index]) then
                return true
            end
        end
        return false
    end

    if type(GetMouseFocus) == "function" then
        local frame = GetMouseFocus()
        local hops = 0
        while frame and hops < 30 do
            hops = hops + 1
            if callback(frame) then
                return true
            end
            frame = frame.GetParent and frame:GetParent() or nil
        end
    end

    return false
end

local function IsMouseOverStatusBar()
    return ForEachMouseFrame(function(frame)
        if frame.IsObjectType and (frame:IsObjectType("StatusBar") or frame:IsObjectType("UnitFrame")) then
            return true
        end

        return frame.UpdateTextStringWithValues or frame.ShowStatusBarText or frame.HideStatusBarText
    end)
end

local function IsPlayerInCombat()
    return UnitAffectingCombat and UnitAffectingCombat("player") or false
end

local function StopLook()
    if RMBLook.enableLook and RMBLook.startedByAddon then
        pcall(MouselookStop)
    end

    RMBLook.inLook = false
    RMBLook.thresholdPassed = false
    RMBLook.moveAccum = 0
    RMBLook.holdActive = false
    RMBLook.startedByAddon = false
    HideCursorIndicator()
end

local function SyncLookState(down)
    local isLooking = (type(IsMouselooking) == "function") and IsMouselooking() or false
    RMBLook.inLook = isLooking

    if down and isLooking then
        RMBLook.thresholdPassed = true
    end

    if not RMBLook.enableIndicator then
        HideCursorIndicator()
        return isLooking
    end

    if isLooking and RMBLook.thresholdPassed then
        ShowCursorIndicator()
        UpdateCursorIndicatorPosition()
    else
        HideCursorIndicator()
    end

    return isLooking
end

local function SafeStartLook()
    if not RMBLook.enableLook then
        return
    end
    if RMBLook.enableCombatLook and not IsPlayerInCombat() then
        return
    end
    if IsBlocked() or IsDragFrameUnderMouse() or IsMouseOverStatusBar() then
        return
    end

    pcall(MouselookStart)
    if type(IsMouselooking) == "function" and IsMouselooking() then
        RMBLook.startedByAddon = true
    end
end

local function UpdateThresholdPassed()
    if RMBLook.thresholdPassed then
        return true
    end

    if type(GetMouseDelta) == "function" then
        local dx, dy = GetMouseDelta()
        RMBLook.moveAccum = RMBLook.moveAccum + abs(dx or 0) + abs(dy or 0)
        if RMBLook.moveAccum >= RMBLook.threshold then
            RMBLook.thresholdPassed = true
            return true
        end
        return false
    end

    local x, y = GetCursorPosition()
    if abs(x - RMBLook.lastX) > RMBLook.threshold or abs(y - RMBLook.lastY) > RMBLook.threshold then
        RMBLook.thresholdPassed = true
        return true
    end
    return false
end

local function RMB_OnUpdate()
    if not RMBLook.enabled then
        HideCursorIndicator()
        return
    end

    local down = IsMouseButtonDown("RightButton")
    if down and not RMBLook.wasDown then
        RMBLook.lastX, RMBLook.lastY = GetCursorPosition()
        RMBLook.thresholdPassed = false
        RMBLook.moveAccum = 0
        RMBLook.holdActive = true
        if RMBLook.enableIndicator then
            EnsureCursorIndicator()
        end
    end

    if not down and RMBLook.wasDown then
        StopLook()
    end

    RMBLook.wasDown = down
    local isLooking = SyncLookState(down)
    if not down then
        return
    end

    if IsBlocked() then
        if RMBLook.startedByAddon then
            StopLook()
        else
            RMBLook.inLook = (type(IsMouselooking) == "function") and IsMouselooking() or false
            RMBLook.thresholdPassed = false
            RMBLook.moveAccum = 0
            RMBLook.holdActive = false
        end

        if RMBLook.enableIndicator and down then
            ShowCursorIndicator()
            UpdateCursorIndicatorPosition()
        else
            HideCursorIndicator()
        end
        return
    end

    local passed = UpdateThresholdPassed()
    if not isLooking and passed then
        SafeStartLook()
        SyncLookState(down)
    end

    if RMBLook.inLook and RMBLook.thresholdPassed then
        UpdateCursorIndicatorPosition()
    end
end

function RMBLook:Init()
    if self.frame then
        return
    end

    self.frame = CreateFrame("Frame", nil, UIParent)
end

function RMBLook:Enable(threshold)
    self:Init()
    self.enabled = true
    self.wasDown = false
    self.inLook = false
    self.thresholdPassed = false
    self.moveAccum = 0
    self.holdActive = false
    self.startedByAddon = false

    if type(threshold) == "number" then
        self.threshold = threshold
    end

    if self.frame then
        self.frame:SetScript("OnUpdate", RMB_OnUpdate)
    end
end

function RMBLook:Disable()
    self.enabled = false
    self.wasDown = false
    self.startedByAddon = false
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
    StopLook()
end

local function ApplyConfig()
    local config = GetEffectiveConfig()
    if type(config) ~= "table" then
        return
    end

    EnsureAnchor()
    shrinkWithTime = (config.shrinkWithTime ~= false)
    shrinkWithDistance = (config.shrinkWithDistance ~= false)
    MaxSpacing = math.max(1, tonumber(config.dotDistance) or 3)
    duration = math.max(0.05, tonumber(config.lifetime) or 0.35)
    invDuration = 1 / duration
    ElementCap = math.floor(Clamp(tonumber(config.maxDots) or 300, 1, 800))
    onlyInCombat = (config.combatOnly == true)
    rainbowByTime = (config.changeWithTime == true)
    colorSpeed = tonumber(config.colorSpeed) or 0.5
    if colorSpeed <= 0 then
        colorSpeed = 0.1
    end

    numPhases = math.max(1, math.min(10, math.floor(tonumber(config.phaseCount) or 6)))
    alphaMul = Clamp(tonumber(config.alpha) or 1, 0, 1)
    dotW = Clamp(tonumber(config.dotWidth) or 50, 1, 256)
    dotH = Clamp(tonumber(config.dotHeight) or 50, 1, 256)
    offX = tonumber(config.offsetX) or 20
    offY = tonumber(config.offsetY) or -18
    adaptiveUpdate = (config.adaptiveUpdate == true)
    adaptiveTargetFPS = math.floor(Clamp(tonumber(config.adaptiveTargetFPS) or 90, 1, 240))

    if config.blendMode == 2 then
        blendModeStr = "BLEND"
    else
        blendModeStr = "ADD"
    end

    if config.cursorLayer == 2 then
        cursorLayerStrata = "BACKGROUND"
    else
        cursorLayerStrata = "TOOLTIP"
    end
    Anchor:SetFrameStrata(cursorLayerStrata)

    wipe(posByRank)
    wipe(sqrtPosByRank)
    if ElementCap <= 1 then
        posByRank[1] = 1
        sqrtPosByRank[1] = 1
    else
        local denominator = ElementCap - 1
        for rank = 1, ElementCap do
            local pos = 1 - ((rank - 1) / denominator)
            posByRank[rank] = pos
            sqrtPosByRank[rank] = sqrt(pos)
        end
    end

    BuildPhaseColors(config)

    RMBLook.enableLook = (config.enableLook == true)
    RMBLook.enableIndicator = (config.enableIndicator ~= false)
    RMBLook.enableCombatLook = (config.enableCombatLook == true)
    RMBLook.cursorFrameSize = math.floor(Clamp(tonumber(config.cursorFrameSize) or 40, 10, 128))
    if RMBLook.cursorFrame then
        RMBLook.cursorFrame:SetSize(RMBLook.cursorFrameSize, RMBLook.cursorFrameSize)
        if not RMBLook.enableIndicator then
            RMBLook.cursorFrame:Hide()
        end
    end

    ApplyDebugState()
end

function CursorTrail:Refresh()
    local config = self:GetConfig()
    if not config then
        return
    end

    ApplyConfig()
    EnsureTextures(ElementCap)

    for slot = 1, ElementCap do
        if slotTex[slot] and pointsX[slot] and pointsY[slot] then
            SetSlotTexPos(slot, pointsX[slot], pointsY[slot])
        end
    end

    if not haveInit then
        local x, y = GetCursorXY()
        ResetTrailSilent(x, y, GetTime())
        lastUpdateTime = GetTime()
        return
    end

    if #pointsX ~= ElementCap then
        local x = lastX or 0
        local y = lastY or 0
        local now = GetTime()
        ResetTrailSilent(x, y, now)
        lastSampleX, lastSampleY = x, y
        lastX, lastY = x, y
    end
end

local function CountVisibleDots(now, shouldGenerate, headFade)
    if not shouldGenerate or headFade <= 0.01 then
        return 0
    end

    local count = 1
    local index = headIndex
    for _ = 2, ElementCap do
        index = index - 1
        if index <= 0 then
            index = ElementCap
        end

        local born = pointsT[index]
        if not born or (now - born) >= duration then
            break
        end

        count = count + 1
    end

    return count
end

local function AddCursorPathPoint(x, y, now)
    now = now or GetTime()

    if not haveInit then
        ResetTrailSilent(x, y, now)
        PushPoint(x, y, now)
        lastX, lastY = x, y
        lastSampleX, lastSampleY = x, y
        return
    end

    if not lastSampleX or not lastSampleY then
        lastSampleX, lastSampleY = x, y
    end

    local dx = x - lastSampleX
    local dy = y - lastSampleY
    local dist = sqrt(dx * dx + dy * dy)
    if dist <= 0.0001 then
        lastX, lastY = x, y
        return
    end

    local step = math.max(1, MaxSpacing)
    if dist < step then
        lastX, lastY = x, y
        return
    end

    local count = math.floor(dist / step)
    if count > MAX_STEPS_PER_TICK then
        ResetTrailSilent(x, y, now)
        return
    end

    trailDist = trailDist + (count * step)
    local ux = dx / dist
    local uy = dy / dist
    for stepIndex = 1, count do
        local px = lastSampleX + ux * step * stepIndex
        local py = lastSampleY + uy * step * stepIndex
        PushPoint(px, py, now)
        lastSampleX, lastSampleY = px, py
    end

    lastX, lastY = x, y
end

local function UpdateTrail()
    local now = GetTime()
    local x, y = GetCursorXY()

    if trailDormant and dormantX and dormantY then
        if abs(x - dormantX) < 0.5 and abs(y - dormantY) < 0.5 then
            HideTrailTextures()
            return
        end
    end

    if lastUpdateTime and (now - lastUpdateTime) > 0.25 then
        ResetTrailSilent(x, y, now)
        lastUpdateTime = now
        return
    end
    lastUpdateTime = now

    local shouldGenerate = not onlyInCombat or IsPlayerInCombat()
    if shouldGenerate then
        AddCursorPathPoint(x, y, now)
    else
        lastX, lastY = x, y
        lastSampleX, lastSampleY = x, y
    end

    local idle = now - (lastEmitTime or now)
    local headFade = 1 - Clamp(idle / duration, 0, 1)
    if not shouldGenerate then
        headFade = 0
    end

    local visibleCount = CountVisibleDots(now, shouldGenerate, headFade)
    if visibleCount == 0 and headFade <= 0.01 then
        if not trailDormant then
            haveInit = false
            lastSampleX, lastSampleY = nil, nil
            lastX, lastY = nil, nil
            trailDist = 0
            trailDormant = true
            dormantX, dormantY = x, y
        end
    else
        trailDormant = false
        dormantX, dormantY = nil, nil
    end

    if headTex then
        if headFade <= 0.01 or visibleCount == 0 then
            headTex:Hide()
        else
            local pos = (shrinkWithDistance and (posByRank[1] or 1)) or 1
            local sqrtPos = (shrinkWithDistance and (sqrtPosByRank[1] or 1)) or 1
            local timeScale = shrinkWithTime and headFade or 1
            local timeAlpha = shrinkWithTime and headFade or 1

            local alpha
            local scale
            if shrinkWithTime and shrinkWithDistance then
                local sTime = sqrt(timeAlpha)
                alpha = alphaMul * sTime * sqrtPos
                scale = sTime * sqrtPos
            else
                alpha = alphaMul * timeAlpha * pos
                scale = timeScale * pos
            end

            if alpha <= 0.01 or scale <= 0.01 then
                headTex:Hide()
            else
                local r, g, b
                if rainbowByTime then
                    r, g, b = WorldLockedRainbowColor(trailDist)
                else
                    r, g, b = ColorByVisibleRank(1, visibleCount)
                end

                headTex:Show()
                headTex:SetSize(dotW * scale, dotH * scale)
                headTex:SetVertexColor(r * glowBoost, g * glowBoost, b * glowBoost, alpha)
                SetHeadTexPos(x, y)
            end
        end
    end

    local slot = headIndex
    for rank = 2, visibleCount do
        slot = slot - 1
        if slot <= 0 then
            slot = ElementCap
        end

        local texture = slotTex[slot]
        if texture then
            local born = pointsT[slot]
            if not born or (now - born) >= duration then
                texture:Hide()
            else
                local progress = Clamp((now - born) * invDuration, 0, 1)
                local timeFade = shrinkWithTime and (1 - progress) or 1
                local timeScale = shrinkWithTime and (1 - progress) or 1
                local pos = (shrinkWithDistance and (posByRank[rank] or 1)) or 1
                local sqrtPos = (shrinkWithDistance and (sqrtPosByRank[rank] or 1)) or 1

                local alpha
                local scale
                if shrinkWithTime and shrinkWithDistance then
                    local sTime = sqrt(timeFade)
                    alpha = alphaMul * sTime * sqrtPos
                    scale = sTime * sqrtPos
                else
                    alpha = alphaMul * timeFade * pos
                    scale = timeScale * pos
                end

                if alpha <= 0.01 or scale <= 0.01 then
                    texture:Hide()
                else
                    local r, g, b
                    if rainbowByTime then
                        r, g, b = WorldLockedRainbowColor(trailDist - ((rank - 1) * MaxSpacing))
                    else
                        r, g, b = ColorByVisibleRank(rank, visibleCount)
                    end

                    texture:Show()
                    texture:SetSize(dotW * scale, dotH * scale)
                    texture:SetVertexColor(r * glowBoost, g * glowBoost, b * glowBoost, alpha)
                end
            end
        end
    end

    local hideSlot = slot
    for _ = visibleCount + 1, ElementCap do
        hideSlot = hideSlot - 1
        if hideSlot <= 0 then
            hideSlot = ElementCap
        end

        local texture = slotTex[hideSlot]
        if texture then
            texture:Hide()
        end
    end

    if debugHolder and debugHolder:IsShown() and debugValue1 and debugValue2 then
        local shown = 0
        for index = 1, ElementCap do
            local texture = slotTex[index]
            if texture and texture:IsShown() then
                shown = shown + 1
            end
        end

        local hzText = adaptiveUpdate and (("%d Hz"):format(adaptiveTargetFPS or 0)) or "每帧"
        debugValue1:SetText(("%d / %d"):format(shown, ElementCap))
        debugValue2:SetText(("%d / %s"):format(fpsValue or 0, hzText))
    end
end

function CursorTrail:Stop()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end

    self.started = false
    HideTrailTextures()
    ApplyDebugState()
    RMBLook:Disable()
    haveInit = false
    trailDormant = false
    lastSampleX, lastSampleY = nil, nil
    lastX, lastY = nil, nil
    lastUpdateTime = nil
end

local function UpdateAutoFPS(dt)
    fpsSampleElapsed = fpsSampleElapsed + (dt or 0)
    if fpsSampleElapsed < FPS_SAMPLE_PERIOD then
        return
    end
    fpsSampleElapsed = 0

    local fpsNow
    if type(GetFramerate) == "function" then
        fpsNow = GetFramerate()
    end
    if not fpsNow or fpsNow <= 0 then
        if fpsElapsed > 0 then
            fpsNow = fpsFrames / fpsElapsed
        else
            fpsNow = fpsAutoValue
        end
    end
    fpsAutoValue = fpsAutoValue * 0.8 + fpsNow * 0.2
end

function CursorTrail:Start()
    if self.started then
        self:Refresh()
        return
    end

    self:EnsureRuntime()
    self:Refresh()
    self.started = true

    local x, y = GetCursorXY()
    lastX, lastY = x, y
    lastSampleX, lastSampleY = x, y
    EnsurePoints(ElementCap, x, y)
    RMBLook:Enable(1)

    local accumulated = 0
    self.frame:SetScript("OnUpdate", function(_, dt)
        fpsElapsed = fpsElapsed + dt
        fpsFrames = fpsFrames + 1
        if fpsElapsed >= 1 then
            fpsValue = math.floor(fpsFrames / fpsElapsed + 0.5)
            fpsElapsed = 0
            fpsFrames = 0
        end

        UpdateAutoFPS(dt)

        if not adaptiveUpdate then
            accumulated = 0
            UpdateTrail()
            return
        end

        local interval = 1 / math.max(1, adaptiveTargetFPS)
        accumulated = accumulated + dt
        if accumulated < interval then
            return
        end

        local steps = math.floor(accumulated / interval)
        if steps > 3 then
            steps = 3
        end

        for _ = 1, steps do
            UpdateTrail()
        end

        accumulated = accumulated - (steps * interval)
    end)
end

function CursorTrail:EnsureRuntime()
    if self.runtimeReady then
        return
    end

    self.runtimeReady = true
    EnsureAnchor()
    EnsureDebugHolder()
    self.frame = CreateFrame("Frame", nil, UIParent)
end

function CursorTrail:RefreshFromSettings()
    local config = self:GetConfig()
    if not config then
        return
    end

    if not config.enabled then
        if self.runtimeReady then
            self:Stop()
        end
        return
    end

    if self.started then
        self:Refresh()
    else
        self:Start()
    end
end

function CursorTrail:OnPlayerLogin()
    self:RefreshFromSettings()
end
