local _, NS = ...
local Core = NS.Core
local function GetModule()
    return NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.CurrencyDisplay
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "currencyDisplay")
end

local function RefreshModule(notifyOptions)
    local module = GetModule()
    if module and module.RefreshFromSettings then
        module:RefreshFromSettings()
    end

    if notifyOptions and NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function BuildCurrencyToggle(currencyID, label, order)
    return {
        type = "toggle",
        order = order,
        width = "full",
        name = label,
        disabled = function()
            return not GetConfig().enabled
        end,
        get = function()
            return GetConfig().selected[currencyID] == true
        end,
        set = function(_, value)
            GetConfig().selected[currencyID] = value and true or nil
            RefreshModule(true)
        end,
    }
end

local function BuildCurrencyHeaderTabs()
    Core:RefreshCurrencyCatalog()

    local tabs = {}
    local headers = Core:GetCurrencyHeaderList()
    for headerIndex, headerName in ipairs(headers) do
        local currencyIDs = Core:GetCurrenciesByHeader(headerName)
        local args = {}

        if #currencyIDs == 0 then
            args.empty = {
                type = "description",
                order = 1,
                name = "|cFF888888当前分类没有可用货币。|r",
            }
        else
            for index, currencyID in ipairs(currencyIDs) do
                local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
                local label = (info and info.name or ("货币 " .. tostring(currencyID))) .. " (ID:" .. tostring(currencyID) .. ")"
                args["currency" .. tostring(currencyID)] = BuildCurrencyToggle(currencyID, label, index)
            end
        end

        tabs["header" .. tostring(headerIndex)] = {
            type = "group",
            name = headerName,
            order = headerIndex,
            args = args,
        }
    end

    if not next(tabs) then
        tabs.empty = {
            type = "group",
            name = "暂无数据",
            order = 1,
            args = {
                tip = {
                    type = "description",
                    order = 1,
                    name = "|cFF888888当前无法读取货币列表。|r",
                },
            },
        }
    end

    return tabs
end

local function BuildOrderArgs()
    local args = {}
    local orderedIDs = Core:GetOrderedSelectedCurrencyIDs()

    if #orderedIDs == 0 then
        args.empty = {
            type = "description",
            order = 1,
            name = "|cFF888888当前还没有勾选任何货币。|r",
        }
        return args
    end

    for index, currencyID in ipairs(orderedIDs) do
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
        local label = info and info.name or ("货币 " .. tostring(currencyID))

        args["row" .. tostring(currencyID)] = {
            type = "group",
            order = index,
            name = "",
            layout = "row",
            args = {
                title = {
                    type = "description",
                    order = 1,
                    width = 1.5,
                    fontSize = "medium",
                    name = string.format("%d. %s", index, label),
                },
                up = {
                    type = "execute",
                    order = 2,
                    width = 0.6,
                    name = "上移",
                    disabled = function()
                        return index == 1
                    end,
                    func = function()
                        if Core:MoveCurrencyOrder(currencyID, -1) then
                            RefreshModule(true)
                        end
                    end,
                },
                down = {
                    type = "execute",
                    order = 3,
                    width = 0.6,
                    name = "下移",
                    disabled = function()
                        return index == #orderedIDs
                    end,
                    func = function()
                        if Core:MoveCurrencyOrder(currencyID, 1) then
                            RefreshModule(true)
                        end
                    end,
                },
                remove = {
                    type = "execute",
                    order = 4,
                    width = 0.6,
                    name = "移除",
                    func = function()
                        GetConfig().selected[currencyID] = nil
                        RefreshModule(true)
                    end,
                },
            },
        }
    end

    return args
end

function NS.BuildCurrencyDisplayOptions()
    return {
        type = "group",
        name = "货币展示",
        order = 9,
        childGroups = "tab",
        args = {
            basic = {
                type = "group",
                name = "基础设置",
                order = 10,
                args = {
                    stateRow = {
                        type = "group",
                        order = 10,
                        name = "",
                        layout = "row",
                        args = {
                            enabled = {
                                type = "toggle",
                                order = 1,
                                width = 1.0,
                                name = "启用货币展示",
                                get = function()
                                    return GetConfig().enabled
                                end,
                                set = function(_, value)
                                    GetConfig().enabled = value and true or false
                                    RefreshModule(true)
                                end,
                            },
                            locked = {
                                type = "toggle",
                                order = 2,
                                width = 1.0,
                                name = "锁定位置",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().locked
                                end,
                                set = function(_, value)
                                    GetConfig().locked = value and true or false
                                    RefreshModule(false)
                                end,
                            },
                            showMoney = {
                                type = "toggle",
                                order = 3,
                                width = 1.0,
                                name = "显示金币",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().showMoney
                                end,
                                set = function(_, value)
                                    GetConfig().showMoney = value and true or false
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    layoutRow = {
                        type = "group",
                        order = 20,
                        name = "",
                        layout = "row",
                        args = {
                            orientation = {
                                type = "select",
                                order = 1,
                                width = 1.0,
                                name = "排列方向",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    HORIZONTAL = "横向",
                                    VERTICAL = "纵向",
                                },
                                get = function()
                                    return GetConfig().orientation
                                end,
                                set = function(_, value)
                                    GetConfig().orientation = value
                                    RefreshModule(false)
                                end,
                            },
                            displayMode = {
                                type = "select",
                                order = 2,
                                width = 1.0,
                                name = "显示模式",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = {
                                    ICON = "图标 + 数量",
                                    TEXT = "仅文字",
                                    ICON_TEXT = "图标 + 文本",
                                },
                                get = function()
                                    return GetConfig().displayMode
                                end,
                                set = function(_, value)
                                    GetConfig().displayMode = value
                                    RefreshModule(false)
                                end,
                            },
                            spacing = {
                                type = "range",
                                order = 3,
                                width = 1.0,
                                name = "项目间距",
                                min = 0,
                                max = 40,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().spacing
                                end,
                                set = function(_, value)
                                    GetConfig().spacing = value
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    styleRow = {
                        type = "group",
                        order = 30,
                        name = "",
                        layout = "row",
                        args = {
                            iconSize = {
                                type = "range",
                                order = 1,
                                width = 1.0,
                                name = "图标大小",
                                min = 10,
                                max = 40,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().iconSize
                                end,
                                set = function(_, value)
                                    GetConfig().iconSize = value
                                    RefreshModule(false)
                                end,
                            },
                            fontSize = {
                                type = "range",
                                order = 2,
                                width = 1.0,
                                name = "字体大小",
                                min = 8,
                                max = 30,
                                step = 1,
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().fontSize
                                end,
                                set = function(_, value)
                                    GetConfig().fontSize = value
                                    RefreshModule(false)
                                end,
                            },
                            fontOutline = {
                                type = "toggle",
                                order = 3,
                                width = 1.0,
                                name = "字体描边",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                get = function()
                                    return GetConfig().fontOutline
                                end,
                                set = function(_, value)
                                    GetConfig().fontOutline = value and true or false
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    fontRow = {
                        type = "group",
                        order = 40,
                        name = "",
                        layout = "row",
                        args = {
                            font = {
                                type = "select",
                                order = 1,
                                width = 1.2,
                                name = "字体",
                                disabled = function()
                                    return not GetConfig().enabled
                                end,
                                values = function()
                                    return NS.Options.Private.GetFontOptions()
                                end,
                                get = function()
                                    return NS.Options.Private.NormalizeFontPreset(GetConfig(), "font")
                                end,
                                set = function(_, value)
                                    GetConfig().fontPreset = value
                                    RefreshModule(false)
                                end,
                            },
                        },
                    },
                    reset = {
                        type = "execute",
                        order = 90,
                        width = 1.0,
                        name = "恢复默认设置",
                        func = function()
                            Core:ResetCurrencyDisplayConfig()
                            RefreshModule(true)
                        end,
                    },
                },
            },
            currencies = {
                type = "group",
                name = "货币类型",
                order = 20,
                childGroups = "tab",
                args = BuildCurrencyHeaderTabs(),
            },
            ordering = {
                type = "group",
                name = "排序管理",
                order = 30,
                args = BuildOrderArgs(),
            },
        },
    }
end
