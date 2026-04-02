local _, NS = ...

local Media = NS.Media or {}
NS.Media = Media

local LibStub = _G.LibStub

local DEFAULT_STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local ADDON_PREFIX = "Interface\\AddOns\\YuXuanSpecial\\"

Media.StatusBars = Media.StatusBars or {
    Yuxuan = ADDON_PREFIX .. "Assets\\Tga\\Yuxuan.tga",
    ["Gradient-Line"] = ADDON_PREFIX .. "Assets\\Tga\\Gradient-Line.tga",
    ["Gradient-Circle"] = ADDON_PREFIX .. "Assets\\Tga\\Gradient-Circle.tga",
}

local function SortKeys(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function GetLSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function Media:EnsureRegistered()
    local libSharedMedia = GetLSM()
    if not libSharedMedia then
        return
    end

    if self.registered then
        return
    end

    self.registered = true

    for name, path in pairs(self.StatusBars) do
        pcall(libSharedMedia.Register, libSharedMedia, "statusbar", name, path)
    end
end

function Media:GetStatusBarDropdownValues()
    self:EnsureRegistered()
    local libSharedMedia = GetLSM()

    local values = {}
    for name in pairs(self.StatusBars) do
        values[name] = name
    end

    if libSharedMedia and libSharedMedia.HashTable then
        local ok, mediaValues = pcall(libSharedMedia.HashTable, libSharedMedia, "statusbar")
        if ok and type(mediaValues) == "table" then
            for name in pairs(mediaValues) do
                values[name] = name
            end
        end
    end

    local sortedValues = {}
    for _, name in ipairs(SortKeys(values)) do
        sortedValues[name] = values[name]
    end
    return sortedValues
end

function Media:FetchStatusBar(name, silent)
    self:EnsureRegistered()
    local libSharedMedia = GetLSM()

    if type(name) == "string" and self.StatusBars[name] then
        return self.StatusBars[name]
    end

    if libSharedMedia and libSharedMedia.Fetch then
        local ok, path = pcall(libSharedMedia.Fetch, libSharedMedia, "statusbar", name, silent)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end

    if type(name) == "string" and name ~= "" and (name:find("\\", 1, true) or name:find("/", 1, true)) then
        return name
    end

    return DEFAULT_STATUSBAR
end

Media:EnsureRegistered()
