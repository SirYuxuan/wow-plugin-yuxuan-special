--[[
共享工具模块

这个文件提供模块间共享的工具函数，避免代码重复：
1. 边框创建 (CreateSimpleOutline)
2. 字体应用 (ApplyConfiguredFont)
3. 兼容性 API 包装
4. 表复用工具
5. 颜色工具
]]

local _, NS = ...
local Core = NS.Core

NS.Utils = NS.Utils or {}
local Utils = NS.Utils

-- ============================================================
-- 兼容性 API 包装
-- ============================================================

function Utils.GetNumAddOns()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return C_AddOns.GetNumAddOns()
    end
    return GetNumAddOns and GetNumAddOns() or 0
end

function Utils.GetAddOnInfo(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local a, b = C_AddOns.GetAddOnInfo(index)
        if type(a) == "table" then
            return a.name or a.Name, a.title or a.Title
        end
        return a, b
    end

    if GetAddOnInfo then
        local name, title = GetAddOnInfo(index)
        return name, title
    end
end

function Utils.IsAddOnLoaded(indexOrName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(indexOrName)
    end
    return IsAddOnLoaded and IsAddOnLoaded(indexOrName) or false
end

-- ============================================================
-- 表复用工具
-- ============================================================

function Utils.WipeArray(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

function Utils.WipeDictionary(dict)
    for key in pairs(dict) do
        dict[key] = nil
    end
end

function Utils.AcquireEntry(list, index)
    local entry = list[index]
    if not entry then
        entry = {}
        list[index] = entry
    end
    return entry
end

-- ============================================================
-- 边框创建工具
-- ============================================================

function Utils.CreateSimpleOutline(parent, layer, thickness)
    local border = {}
    local size = thickness or 1

    border.top = parent:CreateTexture(nil, layer or "BORDER")
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.top:SetHeight(size)

    border.bottom = parent:CreateTexture(nil, layer or "BORDER")
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.bottom:SetHeight(size)

    border.left = parent:CreateTexture(nil, layer or "BORDER")
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size, -size)
    border.left:SetWidth(size)

    border.right = parent:CreateTexture(nil, layer or "BORDER")
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size, size)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border.right:SetWidth(size)

    return border
end

function Utils.SetSimpleOutlineColor(border, r, g, b, a)
    if type(border) ~= "table" then
        return
    end

    for _, edge in pairs(border) do
        edge:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
    end
end

-- ============================================================
-- 字体工具
-- ============================================================

function Utils.GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

function Utils.GetFontPreset(config)
    local optionsPrivate = Utils.GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.NormalizeFontPreset then
        return optionsPrivate.NormalizeFontPreset(config, "font")
    end

    return (config and config.fontPreset) or "CHAT"
end

function Utils.ApplyConfiguredFont(fontString, size, outline, config)
    if not fontString then
        return
    end

    local optionsPrivate = Utils.GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(fontString, size or 12, outline or "", Utils.GetFontPreset(config))
        return
    end

    fontString:SetFont(STANDARD_TEXT_FONT, size or 12, outline or "")
end

-- ============================================================
-- 颜色工具
-- ============================================================

function Utils.UnpackColor(color)
    if not color then
        return 1, 1, 1, 1
    end
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

function Utils.GetColorFromConfig(config, prefix)
    if not config or not prefix then
        return { r = 1, g = 1, b = 1, a = 1 }
    end

    local colorKey = "color" .. prefix:sub(1, 1):upper() .. prefix:sub(2)
    local color = config[colorKey]
    if not color then
        return { r = 1, g = 1, b = 1, a = 1 }
    end

    return {
        r = color.r or color[1] or 1,
        g = color.g or color[2] or 1,
        b = color.b or color[3] or 1,
        a = color.a or color[4] or 1,
    }
end

-- ============================================================
-- 数值工具
-- ============================================================

function Utils.RoundToPlaces(value, places)
    local multiplier = 10 ^ (places or 0)
    return math.floor(((tonumber(value) or 0) * multiplier) + 0.5) / multiplier
end

function Utils.Clamp(value, minVal, maxVal)
    return math.max(minVal, math.min(maxVal, tonumber(value) or minVal))
end

function Utils.FormatMemoryKB(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then
        return string.format("%.2f MB", kb / 1024)
    end
    return string.format("%.0f KB", kb)
end

-- ============================================================
-- 位置保存工具
-- ============================================================

function Utils.SaveFramePosition(frame, config, key)
    if not frame or not config then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local pos = config[key or "point"]
    if not pos then
        pos = {}
        config[key or "point"] = pos
    end

    pos.point = point or "CENTER"
    pos.relativePoint = relativePoint or "CENTER"
    pos.x = math.floor((x or 0) + 0.5)
    pos.y = math.floor((y or 0) + 0.5)
end

-- ============================================================
-- 框架背景/边框应用工具
-- ============================================================

function Utils.ApplyFrameBackground(frame, config, bgKey)
    if not frame or not frame.bg then
        return
    end

    local showBg = config[bgKey or "showBackground"]
    if showBg then
        local bg = config.backgroundColor or { r = 0, g = 0, b = 0, a = 0.32 }
        frame.bg:SetColorTexture(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.32)
    else
        frame.bg:SetColorTexture(0, 0, 0, 0)
    end
end

function Utils.ApplyFrameBorder(frame, config, borderKey)
    if not frame or not frame.border then
        return
    end

    local showBorder = config[borderKey or "showBorder"]
    if showBorder then
        local border = config.borderColor or { r = 0, g = 0.6, b = 1, a = 0.45 }
        Utils.SetSimpleOutlineColor(frame.border, border.r or 0, border.g or 0.6, border.b or 1, border.a or 0.45)
    else
        Utils.SetSimpleOutlineColor(frame.border, 0, 0, 0, 0)
    end
end

function Utils.ApplyFrameBackgroundAndBorder(frame, config)
    Utils.ApplyFrameBackground(frame, config)
    Utils.ApplyFrameBorder(frame, config)
end
