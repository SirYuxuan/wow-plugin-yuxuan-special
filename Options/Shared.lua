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
    card = { 0.13, 0.14, 0.18, 0.98 },
    cardSoft = { 0.11, 0.12, 0.15, 0.95 },
    border = { 0.22, 0.24, 0.30, 1.00 },
    borderActive = { 0.95, 0.76, 0.18, 1.00 },
    text = { 0.96, 0.96, 0.98, 1.00 },
    muted = { 0.62, 0.65, 0.72, 1.00 },
    accent = { 0.95, 0.76, 0.18, 1.00 },
    accentSoft = { 0.44, 0.33, 0.06, 1.00 },
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
    cardGap = 10,
    rowGap = 8,
}

Private.Meta = {
    qqGroup = "1087904677",
}

Private.Assets = {
    qqIcon = "Interface\\AddOns\\YuXuanSpecial\\Assets\\Icons\\qq.png",
}

function Private.UnpackColor(color)
    return color[1], color[2], color[3], color[4] or 1
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
