---@diagnostic disable: undefined-global, undefined-field, inject-field
local _, NS = ...
local Core = NS.Core

local CurrencyDisplay = {}
NS.Modules.InterfaceEnhance.CurrencyDisplay = CurrencyDisplay

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "currencyDisplay")
end
local LibSharedMedia = LibStub("LibSharedMedia-3.0")
local ShowCurrencyTooltip
local HideCurrencyTooltip

local DEFAULT_MONEY_ICON = 133784

-- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
--  Currency catalog: read directly from game API
--  Uses C_CurrencyInfo list headers as natural groups
-- 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?

local function EnsureSelected(cfg)
    cfg.selected = cfg.selected or {}
    return cfg.selected
end

local function GetOptionsPrivate()
    return NS.Options and NS.Options.Private
end

local function GetFontPreset(config)
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.NormalizeFontPreset then
        return optionsPrivate.NormalizeFontPreset(config, "font")
    end

    return (config and config.fontPreset) or "CHAT"
end

local function ApplyConfiguredFont(target, size, outline, config)
    local optionsPrivate = GetOptionsPrivate()
    if optionsPrivate and optionsPrivate.ApplyFont then
        optionsPrivate.ApplyFont(target, size, outline, GetFontPreset(config))
        return
    end

    local fontPath = LibSharedMedia:Fetch("font", config and config.font) or STANDARD_TEXT_FONT
    target:SetFont(fontPath, size or 12, outline or "")
end

---@param currencyID number
---@return CurrencyInfo|nil
local function GetCurrencyInfoByID(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        return C_CurrencyInfo.GetCurrencyInfo(currencyID)
    end
    return nil
end

local function SetCurrencyHeaderExpanded(index, expanded)
    if not (C_CurrencyInfo and C_CurrencyInfo.ExpandCurrencyList) then
        return
    end

    local ok = pcall(C_CurrencyInfo.ExpandCurrencyList, index, expanded and 1 or 0)
    if not ok then
        pcall(C_CurrencyInfo.ExpandCurrencyList, index, expanded and true or false)
    end
end

-- Catalog: group currencies by their list headers

function Core:RefreshCurrencyCatalog()
    self.currencyCatalog = {}
    self.currencyHeaders = {}
    self.currencyHeaderOrder = {}

    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListInfo) then
        return
    end

    local listSize = C_CurrencyInfo.GetCurrencyListSize()
    local currentHeader = nil
    local headerStates = {}

    for i = 1, listSize do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and info.name and info.name ~= "" then
            headerStates[info.name] = info.isHeaderExpanded and true or false
        end
    end

    for i = listSize, 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader then
            SetCurrencyHeaderExpanded(i, true)
        end
    end

    listSize = C_CurrencyInfo.GetCurrencyListSize()

    for i = 1, listSize do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.name and info.name ~= "" then
            if info.isHeader then
                currentHeader = info.name
                if not self.currencyHeaders[currentHeader] then
                    self.currencyHeaders[currentHeader] = {}
                    table.insert(self.currencyHeaderOrder, currentHeader)
                end
            elseif currentHeader and info.currencyID and (not info.isTypeUnused) then
                self.currencyCatalog[info.currencyID] = {
                    name = info.name,
                    header = currentHeader,
                    icon = info.iconFileID,
                    quantity = info.quantity or 0,
                }
                table.insert(self.currencyHeaders[currentHeader], info.currencyID)
            elseif info.currencyID and (not info.isTypeUnused) then
                local fallback = "Other"
                if not self.currencyHeaders[fallback] then
                    self.currencyHeaders[fallback] = {}
                    table.insert(self.currencyHeaderOrder, fallback)
                end
                self.currencyCatalog[info.currencyID] = {
                    name = info.name,
                    header = fallback,
                    icon = info.iconFileID,
                    quantity = info.quantity or 0,
                }
                table.insert(self.currencyHeaders[fallback], info.currencyID)
            end
        end
    end

    for i = listSize, 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and info.name and headerStates[info.name] ~= nil then
            SetCurrencyHeaderExpanded(i, headerStates[info.name])
        end
    end
end

function Core:GetCurrencyHeaderForID(currencyID)
    local catalog = self.currencyCatalog
    if catalog and catalog[currencyID] then
        return catalog[currencyID].header
    end
    return "Other"
end

function Core:GetCurrencyHeaderList()
    return self.currencyHeaderOrder or {}
end

function Core:GetCurrenciesByHeader(headerName)
    local headers = self.currencyHeaders
    if not headers then
        return {}
    end
    return headers[headerName] or {}
end

-- Values for options UI

function Core:GetAvailableCurrencyValues()
    self:RefreshCurrencyCatalog()
    local values = {}
    local catalog = self.currencyCatalog or {}

    for cid, row in pairs(catalog) do
        local key = tostring(cid)
        local label = (row.name or key) .. " (ID:" .. key .. ")"
        values[key] = label
    end

    local cfg = GetConfig()
    if cfg and cfg.selected then
        for cid, enabled in pairs(cfg.selected) do
            local key = tostring(cid)
            if enabled and not values[key] then
                local info = GetCurrencyInfoByID(cid)
                local cname = info and info.name or ("ID " .. key)
                values[key] = cname .. " (ID:" .. key .. ")"
            end
        end
    end

    return values
end

function Core:GetAvailableCurrencyValuesByHeader(headerName)
    self:RefreshCurrencyCatalog()
    local ids = self:GetCurrenciesByHeader(headerName)
    local values = {}
    local catalog = self.currencyCatalog

    for _, cid in ipairs(ids) do
        local row = catalog[cid]
        if row then
            local key = tostring(cid)
            values[key] = (row.name or key) .. " (ID:" .. key .. ")"
        end
    end

    return values
end

-- Order management

local function EnsureOrder(cfg)
    cfg.order = cfg.order or {}
    local selected = EnsureSelected(cfg)

    local seen = {}
    local normalized = {}
    for _, cid in ipairs(cfg.order) do
        if type(cid) == "number" and selected[cid] and not seen[cid] then
            table.insert(normalized, cid)
            seen[cid] = true
        end
    end

    local missing = {}
    for cid, enabled in pairs(selected) do
        if enabled and not seen[cid] then
            table.insert(missing, cid)
        end
    end

    table.sort(missing, function(a, b)
        local ia = GetCurrencyInfoByID(a)
        local ib = GetCurrencyInfoByID(b)
        local na = ia and ia.name or tostring(a)
        local nb = ib and ib.name or tostring(b)
        return na < nb
    end)

    for _, cid in ipairs(missing) do
        table.insert(normalized, cid)
    end

    cfg.order = normalized
    return cfg.order
end

function Core:GetOrderedSelectedCurrencyIDs()
    local cfg = GetConfig()
    if not cfg then
        return {}
    end
    local selected = EnsureSelected(cfg)
    local order = EnsureOrder(cfg)

    local list = {}
    for _, cid in ipairs(order) do
        if selected[cid] then
            table.insert(list, cid)
        end
    end
    return list
end

function Core:MoveCurrencyOrder(currencyID, direction)
    local cfg = GetConfig()
    if not cfg then
        return false
    end
    local order = EnsureOrder(cfg)

    local idx = nil
    for i, id in ipairs(order) do
        if id == currencyID then
            idx = i
            break
        end
    end
    if not idx then
        return false
    end

    local target = idx + direction
    if target < 1 or target > #order then
        return false
    end

    order[idx], order[target] = order[target], order[idx]
    return true
end

-- Frame creation

local function FormatMoneyShort(copper)
    local gold = math.floor((copper or 0) / 10000)
    return tostring(gold) .. "G"
end

local function SaveCurrencyFramePosition(frame)
    local cfg = GetConfig()
    if not (cfg and frame) then
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    cfg.pos = {
        point = point,
        relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function StartCurrencyFrameDrag(frame)
    local cfg = GetConfig()
    if frame and cfg and not cfg.locked then
        frame:StartMoving()
    end
end

local function StopCurrencyFrameDrag(frame)
    if not frame then
        return
    end

    frame:StopMovingOrSizing()
    SaveCurrencyFramePosition(frame)
end

function Core:CreateCurrencyFrame()
    if self.currencyFrame then
        return
    end

    local frame = CreateFrame("Frame", "YuXuanCurrencyFrame", UIParent)
    frame:SetSize(200, 24)
    frame:SetPoint("CENTER", 0, -220)
    frame:SetFrameStrata("LOW")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(false)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        StartCurrencyFrameDrag(self)
    end)

    frame:SetScript("OnDragStop", function(self)
        StopCurrencyFrameDrag(self)
    end)

    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    frame:SetScript("OnEvent", function()
        Core:UpdateCurrencyDisplay()
    end)
    frame:SetScript("OnEnter", function(self)
        ShowCurrencyTooltip(self)
    end)
    frame:SetScript("OnLeave", function(self)
        HideCurrencyTooltip(self)
    end)

    self.currencyFrame = frame
end

-- Item pool

function Core:AcquireCurrencyItem(index)
    self.currencyItems = self.currencyItems or {}
    if self.currencyItems[index] then
        return self.currencyItems[index]
    end

    local item = CreateFrame("Frame", nil, self.currencyFrame)
    item:SetSize(1, 1)
    item:EnableMouse(true)
    item:RegisterForDrag("LeftButton")

    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetPoint("LEFT", item, "LEFT", 0, 0)
    item.icon:SetSize(16, 16)

    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    item.text:SetPoint("LEFT", item, "LEFT", 0, 0)
    item.text:SetJustifyH("LEFT")

    item:SetScript("OnEnter", function()
        ShowCurrencyTooltip(Core.currencyFrame)
    end)
    item:SetScript("OnLeave", function()
        HideCurrencyTooltip(Core.currencyFrame)
    end)
    item:SetScript("OnDragStart", function()
        StartCurrencyFrameDrag(Core.currencyFrame)
    end)
    item:SetScript("OnDragStop", function()
        StopCurrencyFrameDrag(Core.currencyFrame)
    end)

    self.currencyItems[index] = item
    return item
end

-- Text formatters

local function BuildDisplayText(data)
    if data.kind == "money" then
        if GetMoneyString then
            return GetMoneyString(data.quantity or 0, false)
        end
        return FormatMoneyShort(data.quantity or 0)
    end

    local quantity = data.quantity or 0
    local qText = tostring(quantity)
    if BreakUpLargeNumbers then
        qText = BreakUpLargeNumbers(quantity)
    end
    return (data.name or ("ID " .. tostring(data.id))) .. ": " .. qText
end

local function BuildCountText(data)
    if data.kind == "money" then
        return FormatMoneyShort(data.quantity or 0)
    end
    local quantity = data.quantity or 0
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(quantity)
    end
    return tostring(quantity)
end

function Core:GetCurrencyDisplayEntries()
    if not self.db then
        return {}
    end

    local cfg = GetConfig()
    local entries = {}

    if cfg.showMoney then
        local moneyAmount = 0
        if GetMoney then
            moneyAmount = GetMoney()
        end
        table.insert(entries, {
            kind = "money",
            name = GOLD_AMOUNT_SYMBOL or "金币",
            quantity = moneyAmount,
            icon = DEFAULT_MONEY_ICON,
        })
    end

    local selected = EnsureSelected(cfg)
    local orderedIDs = self:GetOrderedSelectedCurrencyIDs()
    for _, cid in ipairs(orderedIDs) do
        if selected[cid] then
            local info = GetCurrencyInfoByID(cid)
            if info and info.name then
                table.insert(entries, {
                    kind = "currency",
                    id = cid,
                    name = info.name,
                    quantity = info.quantity or 0,
                    icon = info.iconFileID,
                })
            end
        end
    end

    if #entries == 0 then
        entries[1] = {
            kind = "empty",
            name = "未选择货币",
            quantity = 0,
            icon = DEFAULT_MONEY_ICON,
        }
    end

    return entries
end

local function BuildTooltipLabel(data)
    local icon = data.icon or DEFAULT_MONEY_ICON
    local iconMarkup = string.format("|T%d:14:14:0:0|t", icon)
    if data.kind == "money" then
        return iconMarkup .. " 金币",
            GetMoneyString and GetMoneyString(data.quantity or 0, false) or FormatMoneyShort(data.quantity or 0)
    end
    if data.kind == "empty" then
        return iconMarkup .. " " .. (data.name or "未选择货币"), "-"
    end

    local countText = BreakUpLargeNumbers and BreakUpLargeNumbers(data.quantity or 0) or tostring(data.quantity or 0)
    return iconMarkup .. " " .. (data.name or ("ID " .. tostring(data.id or ""))), countText
end

ShowCurrencyTooltip = function(frame)
    if not frame or not Core.db or not GetConfig().enabled then
        return
    end

    local entries = Core:GetCurrencyDisplayEntries()
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOM", frame, "TOP", 0, 8)
    GameTooltip:ClearLines()
    GameTooltip:AddLine("货币状态条", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, data in ipairs(entries) do
        local left, right = BuildTooltipLabel(data)
        GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 0.3, 1, 0.6)
    end

    GameTooltip:Show()
end

HideCurrencyTooltip = function(frame)
    if GameTooltip:IsOwned(frame) then
        GameTooltip:Hide()
    end
end

-- Display update

function Core:UpdateCurrencyDisplay()
    if not self.db or not self.currencyFrame then
        return
    end

    local cfg = GetConfig()
    if not cfg.enabled then
        self.currencyFrame:Hide()
        return
    end

    local frame = self.currencyFrame
    local entries = self:GetCurrencyDisplayEntries()

    local isVertical = (cfg.orientation == "VERTICAL")
    local x, y = 0, 0
    local maxW, maxH = 1, 1

    for i, data in ipairs(entries) do
        local item = self:AcquireCurrencyItem(i)
        local mode = cfg.displayMode or "ICON_TEXT"
        local showIcon = (mode ~= "TEXT")
        local textToShow

        if mode == "ICON" then
            textToShow = BuildCountText(data)
        else
            textToShow = BuildDisplayText(data)
        end

        item:ClearAllPoints()
        item.icon:ClearAllPoints()
        item.text:ClearAllPoints()

        ApplyConfiguredFont(item.text, cfg.fontSize, cfg.fontOutline and "OUTLINE" or "", cfg)
        item.text:SetText(textToShow)

        local iconSize = cfg.iconSize or 16
        item.icon:SetSize(iconSize, iconSize)
        item.icon:SetTexture(data.icon or DEFAULT_MONEY_ICON)

        local textW = item.text:GetStringWidth() or 0
        local textH = item.text:GetStringHeight() or cfg.fontSize
        local itemW, itemH = 1, 1

        if showIcon then
            item.icon:SetPoint("LEFT", item, "LEFT", 0, 0)
            item.text:SetPoint("LEFT", item.icon, "RIGHT", 4, 0)
            itemW = iconSize + 4 + textW
            itemH = math.max(iconSize, textH)
            item.icon:Show()
            item.text:Show()
        else
            item.text:SetPoint("LEFT", item, "LEFT", 0, 0)
            itemW = textW
            itemH = textH
            item.icon:Hide()
            item.text:Show()
        end

        itemW = math.max(1, itemW)
        itemH = math.max(1, itemH)
        item:SetSize(itemW, itemH)

        if isVertical then
            item:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
            y = y + itemH + cfg.spacing
            maxW = math.max(maxW, itemW)
        else
            item:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
            x = x + itemW + cfg.spacing
            maxH = math.max(maxH, itemH)
        end

        item:Show()
    end

    local itemPool = self.currencyItems or {}
    for i = #entries + 1, #itemPool do
        itemPool[i]:Hide()
    end

    if isVertical then
        frame:SetSize(maxW, math.max(1, y - cfg.spacing))
    else
        frame:SetSize(math.max(1, x - cfg.spacing), maxH)
    end

    frame:Show()
end

-- Apply settings

function Core:ApplyCurrencySettings()
    if not self.db or not self.currencyFrame then
        return
    end

    local cfg = GetConfig()
    local pos = cfg.pos or {
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = -220,
    }
    local relative = _G[pos.relativeTo] or UIParent

    self.currencyFrame:ClearAllPoints()
    self.currencyFrame:SetPoint(pos.point, relative, pos.relativePoint, pos.x, pos.y)

    if cfg.locked then
        self.currencyFrame:EnableMouse(false)
        self.currencyFrame:RegisterForDrag()
    else
        self.currencyFrame:EnableMouse(true)
        self.currencyFrame:RegisterForDrag("LeftButton")
    end

    self:UpdateCurrencyDisplay()
end

function CurrencyDisplay:OnPlayerLogin()
    Core.currencyItems = Core.currencyItems or {}
    Core:RefreshCurrencyCatalog()
    Core:CreateCurrencyFrame()
    Core:ApplyCurrencySettings()
end

function CurrencyDisplay:RefreshFromSettings()
    if not Core.currencyFrame then
        self:OnPlayerLogin()
        return
    end

    Core:RefreshCurrencyCatalog()
    Core:ApplyCurrencySettings()
end

