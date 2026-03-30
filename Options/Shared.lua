local _, NS = ...

local Options = NS.Options

--[[
设置系统共享上下文。

这里不直接渲染任何界面，只做三类事情：
1. 保存整个设置系统都会反复用到的常量。
2. 提供安全调用、文本解析、排序等通用工具。
3. 维护“当前选中了哪一个页面/子页面”这类路径工具。

后面的 Widgets / Layout / Renderer / Main 都会依赖这里的能力，
所以这个文件会最先被 TOC 加载。
]]
Options.Private = Options.Private or {}
local Private = Options.Private

Private.Constants = {
    FRAME_NAME = "YuXuanSpecialOptionsFrame",
    DROPDOWN_HELPER_NAME = "YuXuanSpecialOptionsDropdownHelper",
    CONFIRM_NAME = "YuXuanSpecialOptionsConfirm",
}

Private.Colors = {
    bg = { 0.07, 0.08, 0.10, 0.98 },
    panel = { 0.10, 0.11, 0.14, 0.98 },
    card = { 0.12, 0.13, 0.17, 0.98 },
    cardSoft = { 0.10, 0.11, 0.14, 0.95 },
    border = { 0.22, 0.24, 0.30, 1.00 },
    borderSoft = { 0.18, 0.20, 0.25, 1.00 },
    borderActive = { 0.95, 0.76, 0.18, 1.00 },
    text = { 0.96, 0.96, 0.98, 1.00 },
    muted = { 0.62, 0.65, 0.72, 1.00 },
    accent = { 0.95, 0.76, 0.18, 1.00 },
    accentSoft = { 0.44, 0.33, 0.06, 1.00 },
    accentBg = { 0.24, 0.19, 0.07, 0.88 },
    success = { 0.22, 0.72, 0.44, 1.00 },
    shadow = { 0.00, 0.00, 0.00, 0.45 },
    disabled = { 0.38, 0.40, 0.45, 1.00 },
}

Private.Sizes = {
    frameWidth = 1080,
    frameHeight = 700,
    navWidth = 190,
    headerHeight = 46,
    brandHeight = 58,
    secondNavWidth = 146,
    gap = 10,
    cardGap = 8,
    rowGap = 4,
    sectionGap = 12,
    contentInset = 8,
}

Private.Meta = {
    qqGroup = "1087904677",
}

Private.Assets = {
    qqIcon = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Icons\\qq.png",
}

Private.FontPresets = {
    CHAT = {
        label = "聊天字体",
    },
    DEFAULT = {
        label = "系统默认",
        path = STANDARD_TEXT_FONT,
    },
    FRIZQT = {
        label = "Frizqt",
        path = "Fonts\\FRIZQT__.TTF",
    },
    MORPHEUS = {
        label = "Morpheus",
        path = "Fonts\\MORPHEUS.ttf",
    },
    SKURRI = {
        label = "Skurri",
        path = "Fonts\\skurri.ttf",
    },
}

function Private.UnpackColor(color)
    return color[1], color[2], color[3], color[4] or 1
end

function Private.CopyColor(color, alpha)
    if not color then
        return { 1, 1, 1, alpha or 1 }
    end

    return {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        alpha or color[4] or 1,
    }
end

function Private.MixColor(base, target, factor, alpha)
    local mix = math.max(0, math.min(1, tonumber(factor) or 0))
    local left = base or { 1, 1, 1, 1 }
    local right = target or { 1, 1, 1, 1 }

    return {
        (left[1] or 1) + ((right[1] or 1) - (left[1] or 1)) * mix,
        (left[2] or 1) + ((right[2] or 1) - (left[2] or 1)) * mix,
        (left[3] or 1) + ((right[3] or 1) - (left[3] or 1)) * mix,
        alpha or left[4] or 1,
    }
end

function Private.GetPlayerClassColor()
    local _, classToken = UnitClass("player")
    local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if classColor then
        return { classColor.r, classColor.g, classColor.b, 1 }
    end

    return { 0.95, 0.76, 0.18, 1.00 }
end

function Private.GetAppearanceConfig()
    local core = NS.Core
    if core and core.GetConfig then
        return core:GetConfig("general", "appearance")
    end
    return nil
end

function Private.RefreshThemeColors()
    local config = Private.GetAppearanceConfig()
    local accent = Private.GetPlayerClassColor()
    local borderBase = { 0.22, 0.24, 0.30, 1.00 }
    local panelBase = { 0.10, 0.11, 0.14, 0.98 }
    local successBase = { 0.22, 0.72, 0.44, 1.00 }

    if config and config.colorMode == "CUSTOM" and config.customColor then
        accent = {
            config.customColor.r or accent[1],
            config.customColor.g or accent[2],
            config.customColor.b or accent[3],
            config.customColor.a or 1,
        }
    end

    Private.Colors.accent = accent
    Private.Colors.borderActive = Private.MixColor(borderBase, accent, 0.78, 1.00)
    Private.Colors.accentSoft = Private.MixColor(panelBase, accent, 0.28, 1.00)
    Private.Colors.accentBg = Private.MixColor(panelBase, accent, 0.18, 0.90)
    Private.Colors.success = Private.MixColor(successBase, accent, 0.22, 1.00)
end

function Private.GetFontOptions()
    local values = {}
    for key, info in pairs(Private.FontPresets) do
        values[key] = info.label
    end
    return values
end

function Private.GetFontPathAndFlags(outline, fontPresetKey)
    local config = Private.GetAppearanceConfig()
    local presetKey = fontPresetKey or ((config and config.fontPreset) or "CHAT")
    local preset = Private.FontPresets[presetKey] or Private.FontPresets.CHAT
    local fontPath = preset.path
    local fontFlags = outline or ""

    if not fontPath and ChatFontNormal and ChatFontNormal.GetFont then
        local chatPath, _, chatFlags = ChatFontNormal:GetFont()
        fontPath = chatPath
        if fontFlags == "" then
            fontFlags = chatFlags or ""
        end
    end

    if not fontPath then
        fontPath = STANDARD_TEXT_FONT
    end

    return fontPath, fontFlags
end

function Private.ApplyFont(target, size, outline, fontPresetKey)
    if not (target and target.SetFont) then
        return
    end

    local fontPath, fontFlags = Private.GetFontPathAndFlags(outline, fontPresetKey)
    target:SetFont(fontPath, size or 12, fontFlags or "")
end

function Private.ApplyStoredFont(target)
    if not target then
        return
    end

    local size = target._yxsFontSize
    if not size then
        return
    end

    Private.ApplyFont(target, size, target._yxsFontOutline or "")
end

function Private.RefreshFonts(root)
    if not root then
        return
    end

    Private.ApplyStoredFont(root)

    if root.GetRegions then
        local regions = { root:GetRegions() }
        for _, region in ipairs(regions) do
            Private.ApplyStoredFont(region)
        end
    end

    if root.GetChildren then
        local children = { root:GetChildren() }
        for _, child in ipairs(children) do
            Private.RefreshFonts(child)
        end
    end
end

--[[
安全调用包装：
有些选项的 get/set/disabled/values 来自动态函数，
这里统一用 pcall 包一层，避免某一个选项报错时把整个设置窗体卡死。
]]
function Private.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end

    return a, b, c, d
end

function Private.Evaluate(value, ...)
    if type(value) == "function" then
        return Private.SafeCall(value, ...)
    end
    return value
end

function Private.ResolveText(value, fallback)
    local resolved = Private.Evaluate(value)
    if resolved == nil then
        return fallback or ""
    end
    return tostring(resolved)
end

function Private.TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function Private.IsTruthy(value)
    return value and true or false
end

function Private.IsDisabled(option)
    return Private.IsTruthy(Private.Evaluate(option and option.disabled))
end

function Private.IsHidden(option)
    return Private.IsTruthy(Private.Evaluate(option and option.hidden))
end

function Private.GetOptionValue(option)
    if type(option.get) ~= "function" then
        return nil
    end

    return Private.SafeCall(option.get)
end

function Private.SetOptionValue(option, ...)
    if type(option.set) == "function" then
        Private.SafeCall(option.set, nil, ...)
    end
end

function Private.RunOption(option)
    if type(option.func) == "function" then
        Private.SafeCall(option.func)
    end
end

--[[
数值滑条既要显示整数，也要显示 0.1 / 0.05 这类小数。
根据 step 自动推断小数位数，可以避免界面上出现很丑的长小数。
]]
function Private.FormatNumber(value, step)
    local number = tonumber(value) or 0
    local precision = 0
    local stepValue = tonumber(step) or 1

    if stepValue < 1 then
        local text = tostring(stepValue)
        local decimals = text:match("%.(%d+)")
        if decimals then
            precision = #decimals
        else
            precision = 2
        end
    end

    return string.format("%." .. precision .. "f", number)
end

function Private.FormatHexColor(r, g, b)
    local red = math.floor(math.max(0, math.min(255, (tonumber(r) or 0) * 255)) + 0.5)
    local green = math.floor(math.max(0, math.min(255, (tonumber(g) or 0) * 255)) + 0.5)
    local blue = math.floor(math.max(0, math.min(255, (tonumber(b) or 0) * 255)) + 0.5)
    return string.format("#%02X%02X%02X", red, green, blue)
end

function Private.GetDisabledTip(option, fallback)
    local tip = Private.Evaluate(option and option.disabledTip)
    if tip == nil or tostring(tip) == "" then
        return fallback or ""
    end
    return tostring(tip)
end

--[[
AceConfig 风格的 options 表是无序字典。
这里统一把 args 按 order 排好，渲染时就不需要在每个地方重复排序。
]]
function Private.SortArgs(args)
    local list = {}
    for key, value in pairs(args or {}) do
        list[#list + 1] = {
            key = key,
            value = value,
        }
    end

    table.sort(list, function(left, right)
        local leftOrder = tonumber(left.value.order) or 1000
        local rightOrder = tonumber(right.value.order) or 1000
        if leftOrder == rightOrder then
            return tostring(left.key) < tostring(right.key)
        end
        return leftOrder < rightOrder
    end)

    return list
end

function Private.ClonePath(path)
    local copy = {}
    for index, value in ipairs(path or {}) do
        copy[index] = value
    end
    return copy
end

function Private.AppendPath(path, key)
    local result = Private.ClonePath(path)
    result[#result + 1] = key
    return result
end

--[[
把页面路径转成稳定字符串。
这样就可以把“某个 group 当前选中了哪个 tab”缓存到 selectedChildren 里。
]]
function Private.PathKey(path)
    return table.concat(path or {}, "\001")
end

function Private.CollectGroupChildren(group)
    local groups = {}
    local nonGroups = {}

    for _, entry in ipairs(Private.SortArgs(group and group.args or {})) do
        if not Private.IsHidden(entry.value) then
            if entry.value.type == "group" then
                groups[#groups + 1] = entry
            else
                nonGroups[#nonGroups + 1] = entry
            end
        end
    end

    return groups, nonGroups
end

--[[
如果一个页面只有一层“纯中转 group”，就自动折叠掉，
这样右侧标题和正文会更干净，不会出现多余的一层空壳分组。
]]
function Private.CollapseSingleGroup(group, path)
    local current = group
    local currentPath = Private.ClonePath(path)

    while current and current.type == "group" and current.childGroups ~= "tab" do
        local groups, nonGroups = Private.CollectGroupChildren(current)
        if #nonGroups > 0 or #groups ~= 1 or groups[1].value.inline then
            break
        end

        current = groups[1].value
        currentPath[#currentPath + 1] = groups[1].key
    end

    return current, currentPath
end

function Private.NormalizeDropdownValues(values)
    local resolved = Private.Evaluate(values) or {}
    local list = {}

    -- 支持按顺序传入数组，避免下拉项被字母排序打乱。
    -- 例如：
    -- {
    --     { value = "shift", label = "Shift" },
    --     { value = "alt", label = "Alt" },
    -- }
    if type(resolved[1]) == "table" then
        for _, entry in ipairs(resolved) do
            if entry.value ~= nil then
                list[#list + 1] = {
                    value = entry.value,
                    label = tostring(entry.label or entry.text or entry.value),
                }
            end
        end
        return list
    end

    for key, label in pairs(resolved) do
        list[#list + 1] = {
            value = key,
            label = tostring(label),
        }
    end

    table.sort(list, function(left, right)
        return left.label < right.label
    end)

    return list
end

--[[
EasyMenu 需要一个全局 dropdown helper frame。
这里延迟创建，避免在插件刚加载时就生成不必要的 UI 对象。
]]
function Private.EnsureDropdownHelper()
    if Options.dropdownHelper then
        return Options.dropdownHelper
    end

    Options.dropdownHelper = CreateFrame(
        "Frame",
        Private.Constants.DROPDOWN_HELPER_NAME,
        UIParent,
        "UIDropDownMenuTemplate"
    )
    return Options.dropdownHelper
end

--[[
当前客户端里 EasyMenu 可能不存在，但 UIDropDownMenu 依然可用。
这里统一封装成一个稳定的弹出接口，渲染层只需要传入按钮和菜单项即可。
]]
function Private.ShowDropdownMenu(anchor, items)
    if not (
        anchor
        and UIDropDownMenu_Initialize
        and UIDropDownMenu_CreateInfo
        and UIDropDownMenu_AddButton
        and ToggleDropDownMenu
    ) then
        return false
    end

    local dropdown = Private.EnsureDropdownHelper()
    dropdown.displayMode = "MENU"
    if UIDropDownMenu_SetWidth and anchor.GetWidth then
        UIDropDownMenu_SetWidth(dropdown, math.max(120, anchor:GetWidth()))
    end
    dropdown.initialize = function(_, level)
        if level and level ~= 1 then
            return
        end

        for _, item in ipairs(items or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = tostring(item.text or "")
            info.checked = item.checked and true or false
            info.func = item.func
            info.disabled = item.disabled and true or false
            info.keepShownOnClick = item.keepShownOnClick and true or false
            info.isNotRadio = true
            info.notCheckable = item.notCheckable and true or false
            UIDropDownMenu_AddButton(info, level)
        end
    end

    CloseDropDownMenus()
    ToggleDropDownMenu(1, nil, dropdown, anchor, 0, 2)

    for level = 1, 2 do
        local backdrop = _G["DropDownList" .. level .. "Backdrop"]
        local menuBackdrop = _G["DropDownList" .. level .. "MenuBackdrop"]
        if backdrop and backdrop.SetBackdropColor then
            backdrop:SetBackdropColor(Private.UnpackColor(Private.MixColor(Private.Colors.card, Private.Colors.bg, 0.35, 0.98)))
            backdrop:SetBackdropBorderColor(Private.UnpackColor(Private.Colors.borderActive))
        end
        if menuBackdrop then
            menuBackdrop:SetAlpha(1)
            if not menuBackdrop._yxsFill then
                local fill = menuBackdrop:CreateTexture(nil, "BACKGROUND")
                fill:SetAllPoints(menuBackdrop)
                menuBackdrop._yxsFill = fill
            end
            menuBackdrop._yxsFill:SetColorTexture(
                Private.UnpackColor(Private.MixColor(Private.Colors.cardSoft, Private.Colors.bg, 0.25, 0.98))
            )
        end

        local buttonCount = UIDROPDOWNMENU_MAXBUTTONS or 32
        for index = 1, buttonCount do
            local button = _G["DropDownList" .. level .. "Button" .. index]
            if button and button:IsShown() then
                if not button._yxsHighlight then
                    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
                    highlight:SetPoint("TOPLEFT", 4, -1)
                    highlight:SetPoint("BOTTOMRIGHT", -4, 1)
                    button:SetHighlightTexture(highlight)
                    button._yxsHighlight = highlight
                end

                button._yxsHighlight:SetColorTexture(Private.UnpackColor(Private.Colors.accentBg))

                local check = _G[button:GetName() .. "Check"]
                local uncheck = _G[button:GetName() .. "UnCheck"]
                local fontString = _G[button:GetName() .. "NormalText"] or button:GetFontString()

                if check then
                    check:ClearAllPoints()
                    check:SetPoint("LEFT", button, "LEFT", 10, 0)
                end
                if uncheck then
                    uncheck:ClearAllPoints()
                    uncheck:SetPoint("LEFT", button, "LEFT", 10, 0)
                end
                if fontString then
                    fontString:ClearAllPoints()
                    fontString:SetPoint("LEFT", button, "LEFT", 30, 0)
                    fontString:SetJustifyH("LEFT")
                end
            end
        end
    end

    return true
end
