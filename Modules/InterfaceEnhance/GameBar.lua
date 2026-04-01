-- ============================================================
-- Modules/GameBar.lua  (Part 1/4: Header + Icons + Button Defs)
-- ============================================================
local addonName, NS = ...
local Core = NS.Core

local GameBar = {}
NS.Modules.InterfaceEnhance.GameBar = GameBar

local function GB()
    return Core:GetConfig("interfaceEnhance", "gameBar")
end

local C_AddOns = C_AddOns
local C_BattleNet = C_BattleNet
local C_FVar = C_CVar

local ICON_PATH = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Icons\\GameBar\\"
local ICONS = {
    Character        = ICON_PATH .. "Character",
    Talents          = ICON_PATH .. "Talents",
    SpellBook        = ICON_PATH .. "SpellBook",
    Bags             = ICON_PATH .. "Bags",
    Achievements     = ICON_PATH .. "Achievements",
    Collections      = ICON_PATH .. "Collections",
    PetJournal       = ICON_PATH .. "PetJournal",
    ToyBox           = ICON_PATH .. "ToyBox",
    Friends          = ICON_PATH .. "Friends",
    Guild            = ICON_PATH .. "Guild",
    GroupFinder      = ICON_PATH .. "GroupFinder",
    EncounterJournal = ICON_PATH .. "EncounterJournal",
    GameMenu         = ICON_PATH .. "GameMenu",
    ScreenShot       = ICON_PATH .. "ScreenShot",
    Volume           = ICON_PATH .. "Volume",
    Options          = ICON_PATH .. "Options",
    Profession       = ICON_PATH .. "Profession",
    BlizzardShop     = ICON_PATH .. "BlizzardShop",
    Hearthstone      = ICON_PATH .. "Hearthstone",
    MissionReports   = ICON_PATH .. "MissionReports",
    Home             = ICON_PATH .. "Home",
    Notification     = ICON_PATH .. "Notification",
    Timer            = ICON_PATH .. "Achievements",
}

local L_BTN = "|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:230:307|t"
local R_BTN = "|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:333:410|t"
local M_BTN = "|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:13:11:0:-1:512:512:12:66:127:204|t"

local HEARTHSTONE_IDS = {
    6948, 54452, 64488, 93672, 142542, 162973, 163045, 165669, 165670, 165802,
    166746, 166747, 168907, 172179, 180290, 182773, 183716, 184353, 188952, 190196,
    193588, 200630, 206195, 208704, 209035, 210455, 212337, 228940, 235016, 236687,
    245970, 246565, 257736, 263489, 263933, 265100, 110560, 140192, 141605,
    180817, 253629,
}

local function GetPlayerClassColor()
    local classTag = select(2, UnitClass("player"))
    local color = classTag and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]
    if color then
        return color.r, color.g, color.b
    end
    return 0, 0.75, 1
end

local function SetGradientColor(texture, orientation, r, g, b, a1, a2)
    if not texture then return end
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(orientation or "VERTICAL", r, g, b, a1 or 0, r, g, b, a2 or 1)
    else
        texture:SetColorTexture(r, g, b, math.max(a1 or 0, a2 or 1))
    end
end

local function GetGameBarAnimationDuration()
    return math.max(0, tonumber(GB().animationDuration) or 0.2)
end

local function IsActionButtonUseKeyDown()
    if C_FVar and C_FVar.GetCVarBool then
        return C_FVar.GetCVarBool("ActionButtonUseKeyDown")
    end

    local getCVarBool = rawget(_G, "GetCVarBool")
    if getCVarBool then
        return getCVarBool("ActionButtonUseKeyDown")
    end

    local getCVar = rawget(_G, "GetCVar")
    if getCVar then
        local value = getCVar("ActionButtonUseKeyDown")
        return value == "1" or value == 1 or value == true
    end

    return false
end

local function RegisterButtonClicks(button)
    if not button or not button.RegisterForClicks then return end
    if IsActionButtonUseKeyDown() then
        button:RegisterForClicks("AnyDown")
    else
        button:RegisterForClicks("AnyUp")
    end
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function StartRegionColorAnimation(owner, key, applyFunc, targetR, targetG, targetB)
    if not owner or not applyFunc then return end

    local anim = owner[key] or {}
    owner[key] = anim

    anim.fromR = anim.currentR or 1
    anim.fromG = anim.currentG or 1
    anim.fromB = anim.currentB or 1
    anim.toR = targetR
    anim.toG = targetG
    anim.toB = targetB
    anim.elapsed = 0
    anim.duration = GetGameBarAnimationDuration()
    anim.applyFunc = applyFunc

    if anim.duration <= 0 then
        anim.currentR, anim.currentG, anim.currentB = targetR, targetG, targetB
        applyFunc(targetR, targetG, targetB)
        return
    end

    owner:SetScript("OnUpdate", function(self, elapsed)
        local active = false

        for _, state in pairs({ self._iconColorAnim, self._timeColorAnim }) do
            if state and state.elapsed ~= nil and state.applyFunc then
                state.elapsed = math.min(state.elapsed + elapsed, state.duration)
                local progress = state.duration > 0 and (state.elapsed / state.duration) or 1
                local r = Lerp(state.fromR, state.toR, progress)
                local g = Lerp(state.fromG, state.toG, progress)
                local b = Lerp(state.fromB, state.toB, progress)
                state.currentR, state.currentG, state.currentB = r, g, b
                state.applyFunc(r, g, b)
                if progress < 1 then
                    active = true
                end
            end
        end

        if not active then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function FormatMemoryUsage(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then
        return string.format("%.2f MB", kb / 1024)
    end
    return string.format("%.0f KB", kb)
end

local function GetPerformanceSummaryText()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, home, world = GetNetStats()
    local latency = math.max(tonumber(world) or 0, tonumber(home) or 0)
    return string.format("%d FPS  %d MS", fps, latency)
end

local function GetAddOnInfoCompat(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local info = C_AddOns.GetAddOnInfo(index)
        if type(info) == "table" then
            return info.name or info.Name, info.title or info.Title
        end
        return info
    end
    local getAddOnInfo = rawget(_G, "GetAddOnInfo")
    if getAddOnInfo then
        local name, title = getAddOnInfo(index)
        return name, title
    end
end

local function IsAddOnLoadedCompat(indexOrName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(indexOrName)
    end
    local isAddOnLoaded = rawget(_G, "IsAddOnLoaded")
    if isAddOnLoaded then
        return isAddOnLoaded(indexOrName)
    end
    return false
end

local function CollectAddOnMemoryRows()
    local rows = {}
    local total = 0
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end
    local getNumAddOns = rawget(_G, "GetNumAddOns")
    local count = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or (getNumAddOns and getNumAddOns()) or
        0
    for i = 1, count do
        local name, title = GetAddOnInfoCompat(i)
        if name and IsAddOnLoadedCompat(i) then
            local memory = (GetAddOnMemoryUsage and GetAddOnMemoryUsage(i)) or 0
            total = total + memory
            table.insert(rows, {
                name = title and title ~= "" and title or name,
                memory = memory,
            })
        end
    end
    table.sort(rows, function(a, b)
        if a.memory == b.memory then
            return a.name < b.name
        end
        return a.memory > b.memory
    end)
    return total, rows
end

local function ShowAddOnMemoryTooltip(owner, title)
    local total, rows = CollectAddOnMemoryRows()
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local _, _, home, world = GetNetStats()

    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM", 0, -8)
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title or "系统信息", 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("FPS", tostring(fps), 1, 1, 1, 0.3, 1, 0.3)
    GameTooltip:AddDoubleLine("本地延迟", string.format("%d ms", tonumber(home) or 0), 1, 1, 1, 0.3, 0.8, 1)
    GameTooltip:AddDoubleLine("世界延迟", string.format("%d ms", tonumber(world) or 0), 1, 1, 1, 0.3, 0.8, 1)
    GameTooltip:AddDoubleLine("插件总内存", FormatMemoryUsage(total), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    for _, entry in ipairs(rows) do
        GameTooltip:AddDoubleLine(entry.name, FormatMemoryUsage(entry.memory), 1, 1, 1, 0.75, 0.9, 1)
    end

    GameTooltip:Show()
end

local ELVUI_VIRTUAL_DT_EVENT = {
    Time = "UPDATE_INSTANCE_INFO",
}

local ELVUI_VIRTUAL_DT = {
    Time = {
        name = "Time",
        text = {
            SetFormattedText = function() end,
        },
    },
}

local function GetElvUITimeTooltipModules()
    local elvUI = rawget(_G, "ElvUI")
    if type(elvUI) ~= "table" then
        return nil
    end

    local unpackFunc = rawget(_G, "unpack") or table.unpack
    if type(unpackFunc) ~= "function" then
        return nil
    end

    local ok, E = pcall(unpackFunc, elvUI)
    if not ok or type(E) ~= "table" or type(E.GetModule) ~= "function" then
        return nil
    end

    local okDT, DT = pcall(E.GetModule, E, "DataTexts")
    if not okDT or type(DT) ~= "table" or type(DT.RegisteredDataTexts) ~= "table" or not DT.tooltip then
        return nil
    end

    local timeDT = DT.RegisteredDataTexts.Time
    local systemDT = DT.RegisteredDataTexts.System
    if type(timeDT) ~= "table" or type(timeDT.onEnter) ~= "function" then
        return nil
    end

    return DT, timeDT, systemDT
end

local function ShowElvUITimeTooltip(owner)
    local DT, timeDT, systemDT = GetElvUITimeTooltipModules()
    if not DT then
        return false
    end

    local anchorOwner = (owner and owner.text) or owner
    if RequestRaidInfo then
        RequestRaidInfo()
    end

    DT.tooltip:SetOwner(anchorOwner, "ANCHOR_BOTTOM", 0, -10)

    if IsModifierKeyDown and IsModifierKeyDown() and type(systemDT) == "table" and type(systemDT.eventFunc) == "function" and type(systemDT.onEnter) == "function" then
        systemDT.eventFunc()
        systemDT.onEnter()
        return true
    end

    if type(timeDT.eventFunc) == "function" then
        timeDT.eventFunc(ELVUI_VIRTUAL_DT.Time, ELVUI_VIRTUAL_DT_EVENT.Time)
    end
    timeDT.onEnter()
    if type(timeDT.onLeave) == "function" then
        timeDT.onLeave()
    end

    if type(systemDT) == "table" and type(systemDT.onUpdate) == "function" then
        systemDT.onUpdate(owner, 10)
    end

    DT.tooltip:AddLine("\n")
    DT.tooltip:AddDoubleLine(L_BTN .. " 左键", "日历", 1, 1, 1, 1, 1, 1)
    DT.tooltip:AddDoubleLine(R_BTN .. " 右键", "时间管理器", 1, 1, 1, 1, 1, 1)
    DT.tooltip:AddDoubleLine(M_BTN .. " 中键", "重载界面", 1, 1, 1, 1, 1, 1)
    DT.tooltip:AddDoubleLine("Shift + 任意键", "整理内存", 1, 1, 1, 1, 1, 1)
    DT.tooltip:AddDoubleLine("Ctrl + Shift + 任意键", "切换脚本分析", 1, 1, 1, 1, 1, 1)
    DT.tooltip:Show()
    return true
end

local function HideElvUITimeTooltip()
    local DT, _, systemDT = GetElvUITimeTooltipModules()
    if type(systemDT) == "table" and type(systemDT.onLeave) == "function" then
        systemDT.onLeave()
    end
    if DT and DT.tooltip then
        DT.tooltip:Hide()
    end
end

local function GetBattleNetOnlineCounts()
    local total = 0
    local wowOnly = 0
    if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then
        return total, wowOnly
    end
    for i = 1, BNGetNumFriends() do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
            total = total + 1
            if info.gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
                wowOnly = wowOnly + 1
            end
        end
    end
    return total, wowOnly
end

local function GetClassColoredName(name, classFile)
    if not name or name == "" then
        return "未知"
    end

    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        if color.colorStr then
            return "|c" .. color.colorStr .. name .. "|r"
        end
    end

    return name
end

local function SetContactTooltipOwner(tooltip, btn)
    if not tooltip or not btn then return end
    tooltip:SetOwner(btn, "ANCHOR_BOTTOM", 0, -12)
end

local function SplitFullName(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return "", ""
    end

    local name, realm = strsplit("-", fullName, 2)
    return name or fullName, realm or ""
end

local function GetWoWFriendRows()
    local rows = {}
    local seen = {}
    local getNumOnlineFriends = C_FriendList and C_FriendList.GetNumOnlineFriends
    local getFriendInfoByIndex = C_FriendList and C_FriendList.GetFriendInfoByIndex

    if not (getNumOnlineFriends and getFriendInfoByIndex) then
        return rows
    end

    local totalOnline = getNumOnlineFriends() or 0
    for index = 1, totalOnline do
        local info = getFriendInfoByIndex(index)
        if info and info.connected then
            local name, realm = SplitFullName(info.name)
            local key = (name or "") .. "-" .. (realm or "")
            if not seen[key] then
                seen[key] = true
                table.insert(rows, {
                    name = name,
                    realm = realm,
                    classFile = info.className,
                    level = info.level,
                    area = info.area,
                    status = "好友",
                })
            end
        end
    end

    table.sort(rows, function(a, b)
        if (a.level or 0) == (b.level or 0) then
            return (a.name or "") < (b.name or "")
        end
        return (a.level or 0) > (b.level or 0)
    end)

    return rows
end

local function GetBattleNetFriendRows()
    local rows = {}
    local seen = {}

    if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then
        return rows
    end

    for friendIndex = 1, BNGetNumFriends() do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(friendIndex)
        if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
            local accountName = accountInfo.accountName or accountInfo.battleTag or "战网好友"
            local gameAccounts = accountInfo.gameAccountInfo and { accountInfo.gameAccountInfo } or {}

            if C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
                local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(friendIndex) or 0
                if numGameAccounts > 0 then
                    gameAccounts = {}
                    for gameIndex = 1, numGameAccounts do
                        local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(friendIndex, gameIndex)
                        if gameAccountInfo then
                            table.insert(gameAccounts, gameAccountInfo)
                        end
                    end
                end
            end

            for _, gameAccountInfo in ipairs(gameAccounts) do
                if gameAccountInfo.isOnline and gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
                    local characterName = gameAccountInfo.characterName or accountName
                    local realmName = gameAccountInfo.realmName or ""
                    local key = characterName .. "-" .. realmName
                    if not seen[key] then
                        seen[key] = true
                        table.insert(rows, {
                            name = characterName,
                            realm = realmName,
                            classFile = gameAccountInfo.className,
                            level = gameAccountInfo.characterLevel,
                            area = gameAccountInfo.areaName,
                            accountName = accountName,
                            status = "战网",
                        })
                    end
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if (a.level or 0) == (b.level or 0) then
            return (a.name or "") < (b.name or "")
        end
        return (a.level or 0) > (b.level or 0)
    end)

    return rows
end

local function GetGuildMemberRows()
    local rows = {}
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then
        return rows
    end

    if GuildRoster then
        GuildRoster()
    end

    local totalMembers = GetNumGuildMembers() or 0
    for index = 1, totalMembers do
        local fullName, _, _, level, _, zone, _, _, online, _, classFile = GetGuildRosterInfo(index)
        if online then
            local name, realm = SplitFullName(fullName)
            table.insert(rows, {
                name = name,
                realm = realm,
                classFile = classFile,
                level = level,
                area = zone,
            })
        end
    end

    table.sort(rows, function(a, b)
        local areaA = a.area or ""
        local areaB = b.area or ""
        if areaA == areaB then
            return (a.name or "") < (b.name or "")
        end
        return areaA < areaB
    end)

    return rows
end

local function AddContactRowsToTooltip(tooltip, rows, opts)
    opts = opts or {}
    local maxLines = opts.maxLines or 12
    if not rows or #rows == 0 then
        tooltip:AddLine(opts.emptyText or "暂无在线成员", 0.65, 0.65, 0.65)
        return
    end

    local shown = math.min(#rows, maxLines)
    for index = 1, shown do
        local row = rows[index]
        local left = GetClassColoredName(row.name, row.classFile)
        if row.level and row.level > 0 then
            left = string.format("[%d] %s", row.level, left)
        end
        if row.realm and row.realm ~= "" then
            left = left .. string.format(" |cFF888888-%s|r", row.realm)
        end

        local right = row.area or ""
        if row.accountName and row.accountName ~= "" then
            right = right ~= "" and (right .. " | ") or ""
            right = right .. row.accountName
        end

        tooltip:AddDoubleLine(left, right, 1, 1, 1, 0.75, 0.85, 1)
    end

    if #rows > shown then
        tooltip:AddLine(string.format("还有 %d 位未显示", #rows - shown), 0.75, 0.75, 0.75)
    end
end

local function StartContactTooltipTicker(btn, refreshFunc)
    if not btn or not refreshFunc then return end

    if btn.tooltipTicker then
        btn.tooltipTicker:Cancel()
        btn.tooltipTicker = nil
    end

    btn.tooltipTicker = C_Timer.NewTicker(2, function()
        if GameTooltip:IsOwned(btn) then
            refreshFunc(btn, true)
        else
            if btn.tooltipTicker then
                btn.tooltipTicker:Cancel()
                btn.tooltipTicker = nil
            end
        end
    end)
end

local function ShowFriendsTooltip(btn, skipTicker)
    SetContactTooltipOwner(GameTooltip, btn)
    GameTooltip:ClearLines()
    GameTooltip:AddLine("好友", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    local totalFriends = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0
    local onlineFriends = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
    local bnTotal, bnWow = GetBattleNetOnlineCounts()
    local bnRows = GetBattleNetFriendRows()
    local wowRows = GetWoWFriendRows()

    GameTooltip:AddDoubleLine("战网在线", tostring(bnTotal), 1, 1, 1, 0.3, 0.8, 1)
    GameTooltip:AddDoubleLine("魔兽战网在线", tostring(bnWow), 1, 1, 1, 0.3, 1, 0.6)
    GameTooltip:AddDoubleLine("角色好友在线", string.format("%d/%d", onlineFriends, totalFriends), 1, 1, 1, 0.2, 1, 0.2)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("战网好友", 1, 0.82, 0)
    AddContactRowsToTooltip(GameTooltip, bnRows, { emptyText = "暂无在线战网好友", maxLines = 8 })

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("角色好友", 1, 0.82, 0)
    AddContactRowsToTooltip(GameTooltip, wowRows, { emptyText = "暂无在线角色好友", maxLines = 8 })

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L_BTN .. " 打开好友列表", 1, 1, 1)
    GameTooltip:Show()

    if not skipTicker then
        StartContactTooltipTicker(btn, ShowFriendsTooltip)
    end
end

local function OpenFriendsList()
    if ToggleFriendsFrame then
        if FRIENDS_TAB then
            ToggleFriendsFrame(FRIENDS_TAB)
        else
            ToggleFriendsFrame()
        end
        if FriendsFrame_ShowSubFrame then
            FriendsFrame_ShowSubFrame("FriendsListFrame")
        end
        return true
    end

    local toggleFriendsPanel = rawget(_G, "ToggleFriendsPanel")
    if toggleFriendsPanel then
        toggleFriendsPanel()
        return true
    end

    if ClickNamedFrame("FriendsMicroButton") then
        if FriendsFrame_ShowSubFrame then
            FriendsFrame_ShowSubFrame("FriendsListFrame")
        end
        return true
    end

    return false
end

local function ShowGuildTooltip(btn, skipTicker)
    SetContactTooltipOwner(GameTooltip, btn)
    GameTooltip:ClearLines()
    GameTooltip:AddLine("公会", 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    if IsInGuild and IsInGuild() then
        local total, online = GetNumGuildMembers()
        local rows = GetGuildMemberRows()
        GameTooltip:AddDoubleLine("在线成员", string.format("%d/%d", tonumber(online) or 0, tonumber(total) or 0), 1, 1, 1,
            0.2, 1, 0.2)
        GameTooltip:AddLine(" ")
        AddContactRowsToTooltip(GameTooltip, rows, { emptyText = "暂无在线公会成员", maxLines = 12 })
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L_BTN .. " 公会界面", 1, 1, 1)
        GameTooltip:AddLine(R_BTN .. " 公会名单", 1, 1, 1)
    else
        GameTooltip:AddLine("当前未加入公会", 1, 0.3, 0.3)
    end

    GameTooltip:Show()

    if not skipTicker then
        StartContactTooltipTicker(btn, ShowGuildTooltip)
    end
end

local function GetAvailableHearthstones()
    local result = {}
    local activeCovenantID = C_Covenants and C_Covenants.GetActiveCovenantID and C_Covenants.GetActiveCovenantID() or nil
    local _, raceFile = UnitRace("player")

    local covenantHearthstones = {
        [184353] = Enum and Enum.CovenantType and Enum.CovenantType.Kyrian,
        [183716] = Enum and Enum.CovenantType and Enum.CovenantType.Venthyr,
        [180290] = Enum and Enum.CovenantType and Enum.CovenantType.NightFae,
        [182773] = Enum and Enum.CovenantType and Enum.CovenantType.Necrolord,
    }

    local raceLockedHearthstones = {
        [210455] = {
            Draenei = true,
            LightforgedDraenei = true,
        },
    }

    for _, itemID in ipairs(HEARTHSTONE_IDS) do
        local hasItem = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID, false, false, true) or 0
        local hasToy = PlayerHasToy and PlayerHasToy(itemID)
        local toyUsable = not hasToy or (C_ToyBox and C_ToyBox.IsToyUsable and C_ToyBox.IsToyUsable(itemID))
        local covenantID = covenantHearthstones[itemID]
        local raceRules = raceLockedHearthstones[itemID]
        local allowedByCovenant = covenantID == nil or activeCovenantID == covenantID
        local allowedByRace = raceRules == nil or raceRules[raceFile] == true

        if ((hasItem and hasItem > 0) or (hasToy and toyUsable)) and allowedByCovenant and allowedByRace then
            table.insert(result, itemID)
        end
    end

    if #result == 0 and select(2, UnitClass("player")) == "SHAMAN" and C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(556) then
        table.insert(result, "SPELL:556")
    end

    return result
end

local function IsHearthstoneAction(action)
    if type(action) == "string" and action:match("^SPELL:") then
        return true
    end

    local actionID = tonumber(action)
    if not actionID then
        return false
    end

    for _, itemID in ipairs(HEARTHSTONE_IDS) do
        if itemID == actionID then
            return true
        end
    end

    return false
end

local function GetAllConfiguredHearthstoneActions()
    local result = { "AUTO", "RANDOM" }
    local seen = {
        AUTO = true,
        RANDOM = true,
    }

    for _, itemID in ipairs(HEARTHSTONE_IDS) do
        local key = tostring(itemID)
        if not seen[key] then
            seen[key] = true
            table.insert(result, itemID)
        end
    end

    local spellKey = "SPELL:556"
    if not seen[spellKey] then
        table.insert(result, spellKey)
    end

    return result
end

local function ClickNamedFrame(frameName)
    local frame = type(frameName) == "string" and rawget(_G, frameName) or frameName
    if frame and frame.Click then
        frame:Click()
        return true
    end
    return false
end

local function OpenCollectionsTab(tabIndex)
    ClickNamedFrame("CollectionsJournalCloseButton")
    if not ClickNamedFrame("CollectionsMicroButton") then
        return false
    end

    local tabButton = rawget(_G, "CollectionsJournalTab" .. tostring(tabIndex))
    if tabButton and tabButton.Click then
        tabButton:Click()
        return true
    end

    if CollectionsJournal_SetTab then
        CollectionsJournal_SetTab(tabIndex)
        return true
    end

    return true
end

local GetHearthstoneSettings
local ResolveConfiguredHearthstoneAction

local function BuildHearthstoneMacroForAction(action)
    if not action then
        return "/run UIErrorsFrame:AddMessage(\"未找到可用炉石\", 1, 0.1, 0.1)"
    end
    if type(action) == "string" and action:match("^SPELL:") then
        local spellID = action:match("SPELL:(%d+)")
        return "/cast " .. tostring(spellID)
    end
    return "/use item:" .. tostring(action)
end

local function RunMacroTextCompat(text)
    local runMacroText = rawget(_G, "RunMacroText")
    if runMacroText and text and text ~= "" then
        runMacroText(text)
        return true
    end
    return false
end

local function BuildHearthstoneMacroForSide(button, side)
    local action = ResolveConfiguredHearthstoneAction(button, side)
    return BuildHearthstoneMacroForAction(action)
end

local function GetDefaultHearthstoneAction()
    local list = GetAvailableHearthstones()
    return list[1], #list
end

local function GetRandomHearthstoneAction(button)
    local list = GetAvailableHearthstones()
    if #list == 0 then
        return nil, 0
    end
    if #list == 1 then
        button._randomHearthstoneAction = list[1]
        return list[1], 1
    end
    local current = button._randomHearthstoneAction
    local choice = list[math.random(1, #list)]
    if current and #list > 1 then
        local safety = 0
        while choice == current and safety < 8 do
            choice = list[math.random(1, #list)]
            safety = safety + 1
        end
    end
    button._randomHearthstoneAction = choice
    return choice, #list
end

local function GetActionDisplayName(action)
    if not action then return "未找到" end
    if type(action) == "string" and action:match("^SPELL:") then
        local spellID = tonumber(action:match("SPELL:(%d+)"))
        local spellName = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        return spellName or "星界传送"
    end
    local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(action)
    if not itemName and C_ToyBox and C_ToyBox.GetToyInfo then
        local toyName = select(1, C_ToyBox.GetToyInfo(action))
        if type(toyName) == "string" then
            itemName = toyName
        end
    end
    local getItemInfo = rawget(_G, "GetItemInfo")
    if not itemName and getItemInfo then
        itemName = getItemInfo(action)
    end
    if not itemName and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(action)
    end
    return itemName or tostring(action)
end

local function GetActionIcon(action)
    if not action then return nil end
    if action == "AUTO" or action == "RANDOM" then
        return ICONS.Hearthstone
    end
    if type(action) == "string" and action:match("^SPELL:") then
        local spellID = tonumber(action:match("SPELL:(%d+)"))
        return spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or nil
    end
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(action) or nil
    if not icon and C_ToyBox and C_ToyBox.GetToyInfo then
        local _, toyIcon = C_ToyBox.GetToyInfo(action)
        if type(toyIcon) == "number" then
            icon = toyIcon
        end
    end
    local getItemInfoInstant = rawget(_G, "GetItemInfoInstant")
    if not icon and getItemInfoInstant then
        local _, _, _, _, iconFile = getItemInfoInstant(action)
        if type(iconFile) == "number" then
            icon = iconFile
        end
    end
    return icon
end

local function GetActionCooldownInfo(action)
    if not action then return true, nil end

    if type(action) == "string" and action:match("^SPELL:") then
        local spellID = tonumber(action:match("SPELL:(%d+)"))
        if C_Spell and C_Spell.GetSpellCooldown and spellID then
            local info = C_Spell.GetSpellCooldown(spellID)
            if type(info) == "table" then
                local startTime = info.startTime or 0
                local duration = info.duration or 0
                local remain = (startTime + duration) - GetTime()
                if remain > 0 then
                    return false, string.format("%02d:%02d", math.floor(remain / 60), math.floor(remain % 60))
                end
                return true, READY or "就绪"
            end
        end
        return true, READY or "就绪"
    end

    local itemID = tonumber(action)
    if not itemID then
        return true, READY or "就绪"
    end

    local startTime, duration = 0, 0
    if C_Item and C_Item.GetItemCooldown then
        local info = C_Item.GetItemCooldown(itemID)
        if type(info) == "table" then
            startTime = info.startTime or 0
            duration = info.duration or 0
        end
    else
        local getItemCooldown = rawget(_G, "GetItemCooldown")
        if getItemCooldown then
            startTime, duration = getItemCooldown(itemID)
        end
    end

    local remain = ((startTime or 0) + (duration or 0)) - GetTime()
    if remain > 0 then
        return false, string.format("%02d:%02d", math.floor(remain / 60), math.floor(remain % 60))
    end

    return true, READY or "就绪"
end

local function AddHearthstoneTooltipLine(tooltip, prefix, action, showBindLocation)
    local icon = GetActionIcon(action)
    local name = GetActionDisplayName(action)

    if action == nil then
        name = "未找到"
    elseif showBindLocation and IsHearthstoneAction(action) then
        local bindLocation = GetBindLocation and GetBindLocation()
        if bindLocation and bindLocation ~= "" then
            name = name .. " > " .. bindLocation
        end
    end

    if icon then
        name = "|T" .. tostring(icon) .. ":14:14:0:0|t " .. name
    end

    local ready, status = GetActionCooldownInfo(action)
    tooltip:AddDoubleLine(
        prefix .. " " .. name,
        status,
        1, 1, 1,
        ready and 0 or 1,
        ready and 1 or 0,
        0
    )
end

GetHearthstoneSettings = function()
    local cfg = GB()
    cfg.hearthstone = cfg.hearthstone or {}
    local hs = cfg.hearthstone
    if hs.showBindLocation == nil then hs.showBindLocation = true end
    if not hs.left or hs.left == "" then hs.left = "AUTO" end
    if not hs.middle or hs.middle == "" then hs.middle = "RANDOM" end
    if not hs.right or hs.right == "" then hs.right = "AUTO" end
    return hs
end

local function IsSpecificHearthstoneUsable(action)
    if not action or action == "AUTO" or action == "RANDOM" then return true end
    if type(action) == "string" and action:match("^SPELL:") then
        local spellID = tonumber(action:match("SPELL:(%d+)"))
        return spellID and C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID)
    end
    for _, available in ipairs(GetAvailableHearthstones()) do
        if tostring(available) == tostring(action) then
            return true
        end
    end
    return false
end

local function GetRandomHearthstoneActionForSide(button, side)
    local list = GetAvailableHearthstones()
    if #list == 0 then return nil, 0 end

    local key = "_randomHearthstoneAction_" .. tostring(side or "default")
    local current = button and button[key] or nil
    local choice = list[math.random(1, #list)]

    if current and #list > 1 then
        local safety = 0
        while tostring(choice) == tostring(current) and safety < 8 do
            choice = list[math.random(1, #list)]
            safety = safety + 1
        end
    end

    if button then
        button[key] = choice
    end
    return choice, #list
end

ResolveConfiguredHearthstoneAction = function(button, side)
    local hs = GetHearthstoneSettings()
    local primary = hs[side] or "AUTO"

    local function resolve(action)
        if not action or action == "AUTO" then
            return GetDefaultHearthstoneAction()
        elseif action == "RANDOM" then
            return GetRandomHearthstoneActionForSide(button, side)
        elseif IsSpecificHearthstoneUsable(action) then
            return action, #GetAvailableHearthstones()
        end
        return nil, 0
    end

    local resolved, count = resolve(primary)
    if resolved then return resolved, count end

    return GetDefaultHearthstoneAction()
end

local function GetHearthstoneChoiceValues()
    local values = {
        AUTO = "自动选择",
        RANDOM = "随机炉石",
    }

    for _, action in ipairs(GetAllConfiguredHearthstoneActions()) do
        if action ~= "AUTO" and action ~= "RANDOM" then
            local name = GetActionDisplayName(action)
            local icon = GetActionIcon(action)
            values[tostring(action)] = (icon and ("|T" .. tostring(icon) .. ":14:14:0:0|t ") or "") .. name
        end
    end

    return values
end

NS.GetGameBarHearthstoneChoices = GetHearthstoneChoiceValues

local function GetMissionReportCount()
    local total = 0
    if C_Garrison and C_Garrison.GetCompleteMissions and Enum and Enum.GarrisonFollowerType then
        local types = {
            Enum.GarrisonFollowerType.FollowerType_8_0_GarrisonFollower,
            Enum.GarrisonFollowerType.FollowerType_9_0_GarrisonFollower,
        }
        for _, followerType in ipairs(types) do
            local missions = C_Garrison.GetCompleteMissions(followerType)
            total = total + (missions and #missions or 0)
        end
    end
    return total
end

local function OpenMissionReport()
    local garrisonButton = rawget(_G, "GarrisonLandingPageMinimapButton")
    if garrisonButton and garrisonButton:IsShown() then
        garrisonButton:Click()
        return
    end
    local toggleGarrisonLandingPage = rawget(_G, "ToggleGarrisonLandingPage")
    if toggleGarrisonLandingPage then
        toggleGarrisonLandingPage()
    end
end

local function ApplyButtonHoverVisual(btn, hovered)
    if not btn then return end
    local r, g, b = GetPlayerClassColor()
    if btn.hoverFill then btn.hoverFill:Hide() end
    if btn.accent then btn.accent:Hide() end
    if btn.icon and btn.icon:GetTexture() then
        if hovered then
            StartRegionColorAnimation(btn, "_iconColorAnim", function(rr, gg, bb)
                btn.icon:SetVertexColor(rr, gg, bb, 1)
            end, r, g, b)
        else
            StartRegionColorAnimation(btn, "_iconColorAnim", function(rr, gg, bb)
                btn.icon:SetVertexColor(rr, gg, bb, 1)
            end, 1, 1, 1)
        end
    end
    if btn.badge then
        local defaultR, defaultG, defaultB = 1, 0.9, 0.1
        if btn._defID == "FRIENDS" then
            defaultR, defaultG, defaultB = GetPlayerClassColor()
        end
        btn.badge:SetTextColor(hovered and r or defaultR, hovered and g or defaultG, hovered and b or defaultB, 1)
    end
end

local BUTTON_DEFS = {
    NONE = { id = "NONE", label = "（空）", icon = nil },
    CHARACTER = {
        id = "CHARACTER",
        label = "角色面板",
        icon = ICONS.Character,
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    ToggleCharacter("PaperDollFrame")
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "角色面板" },
    },
    TALENTS = {
        id = "TALENTS",
        label = "天赋",
        icon = ICONS.Talents,
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    if PlayerSpellsUtil then PlayerSpellsUtil.ToggleClassTalentFrame() end
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "天赋" },
    },
    SPELLBOOK = {
        id = "SPELLBOOK",
        label = "技能书",
        icon = ICONS.SpellBook,
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    if PlayerSpellsUtil then PlayerSpellsUtil.ToggleSpellBookFrame() end
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "技能书" },
    },
    QUESTLOG = {
        id = "QUESTLOG",
        label = "任务日志",
        icon = "Interface\\Icons\\INV_Misc_Book_17",
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    ToggleQuestLog()
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "任务日志" },
    },
    ACHIEVEMENTS = {
        id = "ACHIEVEMENTS",
        label = "成就",
        icon = ICONS.Achievements,
        click = {
            LeftButton = function()
                if not ClickNamedFrame("AchievementMicroButton") and ToggleAchievementFrame then
                    ToggleAchievementFrame()
                end
            end,
        },
        tooltips = { "成就" },
    },
    COLLECTIONS = {
        id = "COLLECTIONS",
        label = "收藏夹",
        icon = ICONS.Collections,
        click = {
            LeftButton = function()
                OpenCollectionsTab(1)
            end,
            RightButton = function()
                if C_MountJournal and C_MountJournal.SummonByID then
                    C_MountJournal.SummonByID(0)
                end
            end,
        },
        tooltips = { "收藏夹", "\n", L_BTN .. " 打开坐骑收藏", R_BTN .. " 随机最爱坐骑" },
    },
    PETS = {
        id = "PETS",
        label = "宠物日志",
        icon = ICONS.PetJournal,
        click = {
            LeftButton = function()
                OpenCollectionsTab(2)
            end,
            RightButton = function()
                if C_PetJournal and C_PetJournal.SummonRandomPet then
                    C_PetJournal.SummonRandomPet(C_PetJournal.HasFavoritePets and C_PetJournal.HasFavoritePets())
                end
            end,
        },
        tooltips = { "宠物日志", "\n", L_BTN .. " 打开宠物日志", R_BTN .. " 随机最爱宠物" },
    },
    TOYS = {
        id = "TOYS",
        label = "玩具箱",
        icon = ICONS.ToyBox,
        click = {
            LeftButton = function()
                OpenCollectionsTab(3)
            end,
        },
        tooltips = { "玩具箱" },
    },
    FRIENDS = {
        id = "FRIENDS",
        label = "好友",
        icon = ICONS.Friends,
        click = {
            LeftButton = OpenFriendsList,
            RightButton = OpenFriendsList,
        },
        additionalText = function()
            local totalBN, wowBN = GetBattleNetOnlineCounts()
            local wowFriends = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or
                0
            local n = math.max(wowBN, wowFriends)
            if totalBN > n then
                n = totalBN
            end
            return n > 0 and tostring(n) or ""
        end,
        tooltips = ShowFriendsTooltip,
    },
    GUILD = {
        id = "GUILD",
        label = "公会",
        icon = ICONS.Guild,
        macro = {
            LeftButton  = "/click GuildMicroButton",
            RightButton = "/script if not InCombatLockdown() then ToggleGuildFrame() end",
        },
        additionalText = function()
            if not IsInGuild or not IsInGuild() then return "" end
            local _, on = GetNumGuildMembers()
            return on and on > 0 and tostring(on) or ""
        end,
        tooltips = ShowGuildTooltip,
    },
    LFD = {
        id = "LFD",
        label = "副本查找",
        icon = ICONS.GroupFinder,
        click = {
            LeftButton = function()
                if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MeetingStone") and SlashCmdList and SlashCmdList.MEETINGSTONE then
                    SlashCmdList.MEETINGSTONE("")
                    return
                end
                if LFDMicroButton then LFDMicroButton:Click() end
            end,
            RightButton = function()
                if LFDMicroButton then LFDMicroButton:Click() end
            end,
        },
        tooltips = {
            "副本查找",
            "\n",
            L_BTN .. " 集合石（已安装时优先）",
            R_BTN .. " 随机队伍查找",
        },
    },
    ENCOUNTER = {
        id = "ENCOUNTER",
        label = "地下城手册",
        icon = ICONS.EncounterJournal,
        click = {
            LeftButton = function()
                ClickNamedFrame("EJMicroButton")
            end,
            RightButton = function()
                if WeeklyRewards_ShowUI then
                    WeeklyRewards_ShowUI()
                end
            end,
        },
        tooltips = { "地下城手册", "\n", L_BTN .. " 打开地下城手册", R_BTN .. " 打开宝库" },
    },
    BAGS = {
        id = "BAGS",
        label = "背包",
        icon = ICONS.Bags,
        click = { LeftButton = function() ToggleAllBags() end },
        tooltips = { "背包" },
    },
    PROFESSION = {
        id = "PROFESSION",
        label = "专业技能",
        icon = ICONS.Profession,
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    if ToggleProfessionsBook then ToggleProfessionsBook() end
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "专业技能" },
    },
    VOLUME = {
        id = "VOLUME",
        label = "音量",
        icon = ICONS.Volume,
        click = {
            LeftButton   = function()
                local v = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0; C_CVar.SetCVar("Sound_MasterVolume",
                    math.min(v + 0.1, 1))
            end,
            MiddleButton = function()
                local e = tonumber(C_CVar.GetCVar("Sound_EnableAllSound")) == 1; C_CVar.SetCVar("Sound_EnableAllSound",
                    e and 0 or 1)
            end,
            RightButton  = function()
                local v = tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0; C_CVar.SetCVar("Sound_MasterVolume",
                    math.max(v - 0.1, 0))
            end,
        },
        tooltips = function(btn)
            local vol = math.floor((tonumber(C_CVar.GetCVar("Sound_MasterVolume")) or 0) * 100)
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(string.format("音量：%d%%", vol), 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L_BTN .. " 增加音量 (+10%)", 1, 1, 1)
            GameTooltip:AddLine(R_BTN .. " 减少音量 (-10%)", 1, 1, 1)
            GameTooltip:AddLine(M_BTN .. " 音效开/关", 1, 1, 1)
            GameTooltip:Show()
        end,
        tooltipsLeave = function() GameTooltip:Hide() end,
    },
    SCREENSHOT = {
        id = "SCREENSHOT",
        label = "截图",
        icon = ICONS.ScreenShot,
        click = {
            LeftButton  = function()
                GameTooltip:Hide(); Screenshot()
            end,
            RightButton = function() C_Timer.After(2, Screenshot) end,
        },
        tooltips = { "截图", "\n", L_BTN .. " 立即截图", R_BTN .. " 2秒后截图" },
    },
    GAMEMENU = {
        id = "GAMEMENU",
        label = "游戏菜单",
        icon = ICONS.GameMenu,
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    if not GameMenuFrame:IsShown() then
                        CloseMenus(); CloseAllWindows(); PlaySound(850); ShowUIPanel(GameMenuFrame)
                    else
                        PlaySound(854); HideUIPanel(GameMenuFrame)
                    end
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "游戏菜单" },
    },
    BLIZZARDSHOP = {
        id = "BLIZZARDSHOP",
        label = "暴雪商城",
        icon = ICONS.BlizzardShop,
        click = { LeftButton = function() StoreMicroButton:Click() end },
        tooltips = { "暴雪商城" },
    },
    HEARTHSTONE = {
        id = "HEARTHSTONE",
        label = "炉石",
        icon = ICONS.Hearthstone,
        tooltips = function(btn)
            local leftAction, count = ResolveConfiguredHearthstoneAction(btn, "left")
            local middleAction = ResolveConfiguredHearthstoneAction(btn, "middle")
            local rightAction = ResolveConfiguredHearthstoneAction(btn, "right")
            local hs = GetHearthstoneSettings()
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM", 0, -8)
            GameTooltip:ClearLines()
            GameTooltip:AddLine("炉石", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            AddHearthstoneTooltipLine(GameTooltip, L_BTN, leftAction, hs.showBindLocation ~= false)
            AddHearthstoneTooltipLine(GameTooltip, M_BTN, middleAction, hs.showBindLocation ~= false)
            AddHearthstoneTooltipLine(GameTooltip, R_BTN, rightAction, hs.showBindLocation ~= false)
            GameTooltip:AddDoubleLine("可用数量", tostring(count), 1, 1, 1, 1, 0.82, 0)
            GameTooltip:Show()
        end,
        getMacro = function(btn)
            return {
                LeftButton = BuildHearthstoneMacroForSide(btn, "left"),
                MiddleButton = BuildHearthstoneMacroForSide(btn, "middle"),
                RightButton = BuildHearthstoneMacroForSide(btn, "right"),
            }
        end,
    },
    MISSIONREPORTS = {
        id = "MISSIONREPORTS",
        label = "任务报告",
        icon = ICONS.MissionReports,
        click = { LeftButton = OpenMissionReport },
        additionalText = function()
            local count = GetMissionReportCount()
            return count > 0 and tostring(count) or ""
        end,
        tooltips = function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("任务报告", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("可领取任务", tostring(GetMissionReportCount()), 1, 1, 1, 0.2, 1, 0.2)
            GameTooltip:AddLine(L_BTN .. " 打开指挥台/任务报告", 1, 1, 1)
            GameTooltip:Show()
        end,
    },
    HOME = {
        id = "HOME",
        label = "家园",
        icon = ICONS.Home,
        click = {
            LeftButton = function()
                local housingFramesUtil = rawget(_G, "HousingFramesUtil")
                if C_Housing and C_Housing.GetPlayerOwnedHouses and housingFramesUtil and housingFramesUtil.TeleportHome then
                    housingFramesUtil.TeleportHome()
                else
                    UIErrorsFrame:AddMessage("当前客户端不支持家园功能", 1, 0.1, 0.1)
                end
            end,
            RightButton = function()
                local housingFramesUtil = rawget(_G, "HousingFramesUtil")
                if C_Housing and housingFramesUtil and housingFramesUtil.ToggleHousingDashboard then
                    housingFramesUtil.ToggleHousingDashboard()
                else
                    UIErrorsFrame:AddMessage("当前客户端不支持家园功能", 1, 0.1, 0.1)
                end
            end,
        },
        tooltips = function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM", 0, -8)
            GameTooltip:ClearLines()
            GameTooltip:AddLine("家园", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L_BTN .. " 返回家园", 1, 1, 1)
            GameTooltip:AddLine(R_BTN .. " 打开家宅面板", 1, 1, 1)
            GameTooltip:Show()
        end,
    },
    TIMER = {
        id = "TIMER",
        label = "收益计时器",
        icon = ICONS.Timer,
        click = {
            LeftButton = function()
                if Core.ToggleTimerWindow then Core:ToggleTimerWindow() end
            end
        },
        tooltips = { "收益计时器" },
    },
    SETTINGS = {
        id = "SETTINGS",
        label = "插件设置",
        icon = ICONS.Options,
        click = {
            LeftButton = function()
                if NS.Options and NS.Options.Open then
                    NS.Options:Open("interfaceEnhance", "gameBar")
                end
            end
        },
        tooltips = { "插件设置" },
    },
    RELOAD = {
        id = "RELOAD",
        label = "重载界面",
        icon = "Interface\\Icons\\Spell_ChargePositive",
        click = {
            LeftButton = function()
                if not InCombatLockdown() then
                    if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
                else
                    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, .3, .3)
                end
            end
        },
        tooltips = { "重载界面" },
    },
}

NS.GameBarButtonDefs = BUTTON_DEFS
NS.GameBarButtonIDs = {}
for k in pairs(BUTTON_DEFS) do table.insert(NS.GameBarButtonIDs, k) end
table.sort(NS.GameBarButtonIDs, function(a, b)
    if a == "NONE" then return true end
    if b == "NONE" then return false end
    return (BUTTON_DEFS[a].label or a) < (BUTTON_DEFS[b].label or b)
end)

-- Part 2/4: Bar frame + buttons + time panel

local bar         -- 主框体
local leftPanel   -- 左面板
local rightPanel  -- 右面板
local middlePanel -- 中间时间面板
local leftButtons        = {}
local rightButtons       = {}
local timeTicker
local infoTicker
local hearthstoneButtons = {}
local gameBarEventFrame
local playerHouseList
local UpdateHearthstoneButtonMacros

local function GetDef(id) return BUTTON_DEFS[id] or BUTTON_DEFS["NONE"] end

local function UpdateHomeButtonAttributes(button)
    if not button or button._defID ~= "HOME" or InCombatLockdown and InCombatLockdown() then
        return
    end

    button:SetAttribute("house-neighborhood-guid", nil)
    button:SetAttribute("house-guid", nil)
    button:SetAttribute("house-plot-id", nil)

    local house = type(playerHouseList) == "table" and playerHouseList[1] or nil
    if house and house.neighborhoodGUID and house.houseGUID and house.plotID then
        button:SetAttribute("house-neighborhood-guid", house.neighborhoodGUID)
        button:SetAttribute("house-guid", house.houseGUID)
        button:SetAttribute("house-plot-id", house.plotID)
        button:SetAttribute("type1", "teleporthome")
    else
        button:SetAttribute("type1", nil)
    end
end

local function RefreshHomeButtonAttributes()
    for _, button in ipairs(leftButtons) do
        UpdateHomeButtonAttributes(button)
    end
    for _, button in ipairs(rightButtons) do
        UpdateHomeButtonAttributes(button)
    end
end

local function EnsureGameBarEvents()
    if gameBarEventFrame then
        return
    end

    gameBarEventFrame = CreateFrame("Frame")
    gameBarEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    gameBarEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    gameBarEventFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
    gameBarEventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_HOUSE_LIST_UPDATED" then
            playerHouseList = ...
            RefreshHomeButtonAttributes()
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            RefreshHomeButtonAttributes()
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            if C_Housing and C_Housing.GetPlayerOwnedHouses then
                C_Housing.GetPlayerOwnedHouses()
            end
            C_Timer.After(1, function()
                RefreshHomeButtonAttributes()
            end)
        end
    end)
end

local function IsTwentyFourHourTime()
    return true
end

local function FormatDisplayHour(hour)
    if IsTwentyFourHourTime() then
        return string.format("%02d", tonumber(hour) or 0)
    end

    hour = tonumber(hour) or 0
    hour = hour % 12
    if hour == 0 then
        hour = 12
    end
    return string.format("%02d", hour)
end

local function GetLocalClockParts()
    return tonumber(date("%H")) or 0, tonumber(date("%M")) or 0
end

local function FormatClockText(hour, minute)
    return FormatDisplayHour(hour) .. ":" .. string.format("%02d", tonumber(minute) or 0)
end

local function GetSecondsUntilDailyResetCompat()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        return C_DateAndTime.GetSecondsUntilDailyReset()
    end
    if GetQuestResetTime then
        return GetQuestResetTime()
    end
    return nil
end

local function GetSecondsUntilWeeklyResetCompat()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        return C_DateAndTime.GetSecondsUntilWeeklyReset()
    end
    return nil
end

local function FormatResetTime(seconds)
    if not seconds or seconds < 0 then
        return UNKNOWN or "未知"
    end

    local totalSeconds = math.floor(seconds)
    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local minutes = math.floor((totalSeconds % 3600) / 60)

    if days > 0 then
        return string.format("%d天 %d小时 %d分钟", days, hours, minutes)
    end
    if hours > 0 then
        return string.format("%d小时 %d分钟", hours, minutes)
    end
    return string.format("%d分钟", minutes)
end

-- ── 副本进度信息 ──────────────────────────────────
local DIFFICULTY_TAG = { "N", "H", "M", "LFR" }

local function GetDifficultyTag(difficultyID)
    if not GetDifficultyInfo then return "N" end
    local _, _, isHeroic, _, displayHeroic, displayMythic = GetDifficultyInfo(difficultyID)
    if displayMythic then return DIFFICULTY_TAG[3] end
    if isHeroic or displayHeroic then return DIFFICULTY_TAG[2] end
    -- LFR difficulties: 7, 17
    if difficultyID == 7 or difficultyID == 17 then return DIFFICULTY_TAG[4] end
    return DIFFICULTY_TAG[1]
end

-- 副本图标缓存（名称 → 按钮图标路径）
local instanceIconByName = {}
local instanceIconsCollected = false

local function CollectInstanceIcons()
    if instanceIconsCollected then return end
    if not EJ_GetInstanceByIndex or not EJ_GetNumTiers or not EJ_SelectTier or not EJ_GetCurrentTier then return end

    local currentTier = EJ_GetCurrentTier()
    local numTiers = EJ_GetNumTiers() or 0
    if numTiers == 0 then return end

    for tier = 1, numTiers do
        EJ_SelectTier(tier)
        for _, isRaid in ipairs({ false, true }) do
            local index = 1
            local instanceID, name, _, _, buttonImage = EJ_GetInstanceByIndex(index, isRaid)
            while instanceID do
                if name and buttonImage then
                    instanceIconByName[name] = buttonImage
                end
                index = index + 1
                instanceID, name, _, _, buttonImage = EJ_GetInstanceByIndex(index, isRaid)
            end
        end
    end

    if currentTier then
        EJ_SelectTier(currentTier)
    end

    instanceIconsCollected = true
end

local function GetInstanceIcon(name)
    if not instanceIconsCollected then
        CollectInstanceIcons()
    end
    local icon = instanceIconByName[name]
    if icon then
        return string.format("|T%s:16:16:0:0:96:96:0:64:0:64|t ", icon)
    end
    return ""
end

local function AddSavedInstanceLines(tooltip)
    if not GetNumSavedInstances then return end

    if RequestRaidInfo then
        RequestRaidInfo()
    end

    CollectInstanceIcons()

    local raids, dungeons = {}, {}

    for i = 1, GetNumSavedInstances() do
        local name, _, reset, difficulty, locked, extended, _, isRaid, maxPlayers, _, numEncounters, encounterProgress =
            GetSavedInstanceInfo(i)
        if name and (locked or extended) then
            local tag = GetDifficultyTag(difficulty)
            local entry = {
                name = name,
                tag = tag,
                reset = reset,
                maxPlayers = maxPlayers or 0,
                numEncounters = numEncounters or 0,
                encounterProgress = encounterProgress or 0,
                extended = extended,
            }
            if isRaid then
                table.insert(raids, entry)
            else
                table.insert(dungeons, entry)
            end
        end
    end

    table.sort(raids, function(a, b) return a.name < b.name end)
    table.sort(dungeons, function(a, b) return a.name < b.name end)

    if #raids > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("已保存的团队副本", 1, 0.82, 0)
        for _, info in ipairs(raids) do
            local icon = GetInstanceIcon(info.name)
            local left = string.format("%s%s %s |cffaaaaaa(%d/%d)", icon, info.tag, info.name, info.encounterProgress,
                info.numEncounters)
            local right = FormatResetTime(info.reset)
            local lr, lg, lb = 1, 1, 1
            if info.extended then lr, lg, lb = 0.3, 1, 0.3 end
            tooltip:AddDoubleLine(left, right, lr, lg, lb, 0.8, 0.8, 0.8)
        end
    end

    if #dungeons > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("已保存的地下城", 1, 0.82, 0)
        for _, info in ipairs(dungeons) do
            local icon = GetInstanceIcon(info.name)
            local left = string.format("%s%s %s |cffaaaaaa(%d/%d)", icon, info.tag, info.name, info.encounterProgress,
                info.numEncounters)
            local right = FormatResetTime(info.reset)
            local lr, lg, lb = 1, 1, 1
            if info.extended then lr, lg, lb = 0.3, 1, 0.3 end
            tooltip:AddDoubleLine(left, right, lr, lg, lb, 0.8, 0.8, 0.8)
        end
    end

    -- 世界首领
    if GetNumSavedWorldBosses then
        local bosses = {}
        for i = 1, GetNumSavedWorldBosses() do
            local name, _, reset = GetSavedWorldBossInfo(i)
            if name and reset then
                table.insert(bosses, { name = name, reset = reset })
            end
        end
        if #bosses > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("世界首领", 1, 0.82, 0)
            for _, info in ipairs(bosses) do
                tooltip:AddDoubleLine(info.name, FormatResetTime(info.reset), 1, 1, 1, 0.8, 0.8, 0.8)
            end
        end
    end
end

UpdateHearthstoneButtonMacros = function(button)
    if not button then return end
    button:SetAttribute("type*", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("type2", "macro")
    button:SetAttribute("type3", "macro")
    button:SetAttribute("macrotext1", BuildHearthstoneMacroForSide(button, "left"))
    button:SetAttribute("macrotext2", BuildHearthstoneMacroForSide(button, "right"))
    button:SetAttribute("macrotext3", BuildHearthstoneMacroForSide(button, "middle"))
end

_G[addonName .. "_UpdateHearthstoneButtons"] = function()
    for _, button in ipairs(hearthstoneButtons) do
        if button and button:IsShown() then
            UpdateHearthstoneButtonMacros(button)
        end
    end
end

-- ── 位置保存 ──────────────────────────────────────
function Core:SaveGameBarPosition()
    if not bar then return end
    local point, _, relPoint, x, y = bar:GetPoint(1)
    local cfg = GB()
    cfg.point = point or "TOP"
    cfg.relativePoint = relPoint or "TOP"
    cfg.x = math.floor((x or 0) + 0.5)
    cfg.y = math.floor((y or 0) + 0.5)
end

-- ── Tooltip 显示 ──────────────────────────────────
local function ShowBtnTooltip(btn)
    local def = GetDef(btn._defID)
    if not def or def.id == "NONE" then return end
    if type(def.tooltips) == "function" then
        def.tooltips(btn)
    elseif type(def.tooltips) == "table" then
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM", 0, -8)
        for i, line in ipairs(def.tooltips) do
            if i == 1 then
                GameTooltip:AddLine(line, 1, 0.82, 0)
            else
                GameTooltip:AddLine(line, 1, 1, 1)
            end
        end
        GameTooltip:Show()
    end
end

local function HideBtnTooltip(btn)
    if btn and btn.tooltipTicker then
        btn.tooltipTicker:Cancel()
        btn.tooltipTicker = nil
    end
    local def = GetDef(btn._defID)
    if def and def.tooltipsLeave then def.tooltipsLeave() end
    GameTooltip:Hide()
end

-- ── 创建单个按钮 ──────────────────────────────────
local function CreateBarButton(parent, index, side)
    local btnName = addonName .. "GameBar_" .. side .. index
    local btn = CreateFrame("Button", btnName, parent, "SecureActionButtonTemplate")
    RegisterButtonClicks(btn)
    btn:RegisterForDrag("LeftButton")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetVertexColor(1, 1, 1, 1)
    btn.icon = icon

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetColorTexture(0, 0, 0, 0)
    btn.bg = bg

    local r, g, b = GetPlayerClassColor()

    local hoverFill = btn:CreateTexture(nil, "BORDER")
    hoverFill:SetAllPoints(btn)
    SetGradientColor(hoverFill, "VERTICAL", r, g, b, 0.02, 0.38)
    hoverFill:Hide()
    btn.hoverFill = hoverFill

    local accent = btn:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    accent:SetHeight(2)
    accent:SetColorTexture(r, g, b, 0.95)
    accent:Hide()
    btn.accent = accent

    -- 高亮
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn)
    hl:SetColorTexture(1, 1, 1, 0.04)

    -- 角落数字标签（好友在线数、公会人数等）
    local badge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
    badge:SetTextColor(1, 0.9, 0.1, 1)
    btn.badge          = badge

    btn._defID         = "NONE"
    btn._index         = index
    btn._side          = side
    btn._badgeTicker   = nil
    btn._iconColorAnim = { currentR = 1, currentG = 1, currentB = 1 }

    btn:SetScript("PostClick", function(self, mouseButton)
        if self._defID == "HOME" and mouseButton == "LeftButton" and self:GetAttribute("type1") == "teleporthome" then
            return
        end

        local def = GetDef(self._defID)
        if def.click then
            local fn = def.click[mouseButton] or def.click.LeftButton
            if fn then
                local ok = pcall(fn, self)
                if not ok then
                    pcall(fn)
                end
            end
        end
        if self._defID == "HEARTHSTONE" and self._isHearthstoneButton and not InCombatLockdown() then
            C_Timer.After(0, function()
                if self and self._isHearthstoneButton then
                    UpdateHearthstoneButtonMacros(self)
                end
            end)
        end
    end)
    btn:SetScript("OnEnter", function(self)
        if GB().mouseOver and bar then UIFrameFadeIn(bar, 0.2, bar:GetAlpha(), 1) end
        ApplyButtonHoverVisual(self, true)
        ShowBtnTooltip(self)
    end)
    btn:SetScript("OnLeave", function(self)
        ApplyButtonHoverVisual(self, false)
        if GB().mouseOver and bar then
            -- 只有鼠标真正离开整个条才淡出
            C_Timer.After(0.1, function()
                if bar and not bar:IsMouseOver() then
                    UIFrameFadeOut(bar, 0.4, bar:GetAlpha(), 0)
                end
            end)
        end
        HideBtnTooltip(self)
    end)
    btn:SetScript("OnDragStart", function()
        if GB().locked then return end
        bar:StartMoving()
    end)
    btn:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        Core:SaveGameBarPosition()
    end)

    return btn
end

-- ── 刷新单个按钮 ──────────────────────────────────
local function RefreshButton(btn, defID, size)
    btn._defID = defID or "NONE"
    local def  = GetDef(btn._defID)
    btn:SetSize(size, size)
    RegisterButtonClicks(btn)
    local badgeFontSize = math.max(10, math.floor((tonumber(size) or 28) * 0.42))
    btn.badge:SetFont(STANDARD_TEXT_FONT, badgeFontSize, "OUTLINE")
    if btn._defID == "FRIENDS" then
        local r, g, b = GetPlayerClassColor()
        btn.badge:SetTextColor(r, g, b, 1)
    else
        btn.badge:SetTextColor(1, 0.9, 0.1, 1)
    end

    -- 清除旧的 macro 属性
    if btn.ClearAttributes then
        btn:ClearAttributes()
    else
        btn:SetAttribute("type*", nil)
        btn:SetAttribute("type1", nil)
        btn:SetAttribute("type2", nil)
        btn:SetAttribute("type3", nil)
        btn:SetAttribute("macrotext1", nil)
        btn:SetAttribute("macrotext2", nil)
        btn:SetAttribute("macrotext3", nil)
    end
    btn._isHearthstoneButton = false

    ApplyButtonHoverVisual(btn, false)

    if def.icon then
        btn.icon:SetTexture(def.icon)
        btn.icon:SetSize(size, size)
        btn.icon:Show()
        btn.bg:Show()
    else
        btn.icon:SetTexture(nil)
        btn.icon:Hide()
        btn.bg:Show()
    end

    -- macro 模式：使用 SecureActionButton
    local macro = def.macro
    if def.getMacro then
        macro = def.getMacro(btn)
    end
    if macro then
        btn:SetAttribute("type*", "macro")
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("type2", "macro")
        btn:SetAttribute("type3", "macro")
        btn:SetAttribute("macrotext1", macro.LeftButton or "")
        btn:SetAttribute("macrotext2", macro.RightButton or macro.LeftButton or "")
        btn:SetAttribute("macrotext3", macro.MiddleButton or macro.LeftButton or "")

        if btn._defID == "HEARTHSTONE" then
            btn._isHearthstoneButton = true
            UpdateHearthstoneButtonMacros(btn)
            table.insert(hearthstoneButtons, btn)
        end
    elseif btn._defID == "HOME" then
        UpdateHomeButtonAttributes(btn)
    end

    -- 角落数字（additionalText）
    if btn._badgeTicker then
        btn._badgeTicker:Cancel(); btn._badgeTicker = nil
    end
    if def.additionalText then
        local function UpdateBadge()
            local txt = def.additionalText()
            btn.badge:SetText(txt or "")
        end
        UpdateBadge()
        btn._badgeTicker = C_Timer.NewTicker(1, UpdateBadge)
        btn.badge:Show()
    else
        btn.badge:SetText("")
        btn.badge:Hide()
    end
end

-- ── 创建中间时间面板 ──────────────────────────────
local function CreateMiddlePanel(parent)
    local panel = CreateFrame("Button", addonName .. "GameBarMiddle", parent, "SecureActionButtonTemplate")
    RegisterButtonClicks(panel)
    panel:RegisterForDrag("LeftButton")

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    bg:SetColorTexture(0, 0, 0, 0)
    panel.bg = bg

    local r, g, b = GetPlayerClassColor()

    local hoverFill = panel:CreateTexture(nil, "BORDER")
    hoverFill:SetAllPoints(panel)
    SetGradientColor(hoverFill, "VERTICAL", r, g, b, 0.04, 0.3)
    hoverFill:Hide()
    panel.hoverFill = hoverFill

    -- 时:分 文字
    local hour = panel:CreateFontString(nil, "OVERLAY")
    hour:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    hour:SetTextColor(1, 1, 1, 1)
    panel.hour = hour

    local colon = panel:CreateFontString(nil, "OVERLAY")
    colon:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    colon:SetTextColor(1, 1, 0.6, 1)
    colon:SetText(":")
    panel.colon = colon

    local mins = panel:CreateFontString(nil, "OVERLAY")
    mins:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    mins:SetTextColor(1, 1, 1, 1)
    panel.mins = mins
    panel._timeColorAnim = { currentR = 1, currentG = 1, currentB = 1 }

    -- 布局：colon 居中，hour 在左，mins 在右
    colon:SetPoint("CENTER", panel, "CENTER", 0, 0)
    hour:SetPoint("RIGHT", colon, "LEFT", 0, 0)
    mins:SetPoint("LEFT", colon, "RIGHT", 0, 0)

    -- 更新时间
    local function UpdateTime()
        local h, m = GetLocalClockParts()
        panel.hour:SetText(FormatDisplayHour(h))
        panel.mins:SetFormattedText("%02d", m)
    end

    local function RefreshTimeTooltip(self)
        if ShowElvUITimeTooltip(self) then
            return
        end

        if IsModifierKeyDown and IsModifierKeyDown() then
            ShowAddOnMemoryTooltip(self, "系统信息")
            return
        end

        local gameHour, gameMinute = GetGameTime()
        local localHour, localMinute = GetLocalClockParts()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -8)
        GameTooltip:ClearLines()
        GameTooltip:AddLine("时间", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME or "本地时间", FormatClockText(localHour, localMinute), 1, 1,
            1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME or "服务器时间", FormatClockText(gameHour, gameMinute), 1, 1,
            1, 0.3, 1, 0.3)
        GameTooltip:AddDoubleLine("日常重置", FormatResetTime(GetSecondsUntilDailyResetCompat()), 1, 1, 1, 1, 0.82, 0)
        GameTooltip:AddDoubleLine("每周重置", FormatResetTime(GetSecondsUntilWeeklyResetCompat()), 1, 1, 1, 1, 0.82, 0)
        AddSavedInstanceLines(GameTooltip)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L_BTN .. " 左键", "日历", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(R_BTN .. " 右键", "时间管理器", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(M_BTN .. " 中键", "重载界面", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Shift + 任意键", "系统信息", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Ctrl + Shift + 任意键", "脚本分析并重载", 1, 1, 1, 1, 1, 1)
        GameTooltip:Show()
    end

    UpdateTime()
    if timeTicker then timeTicker:Cancel() end
    timeTicker = C_Timer.NewTicker(30, UpdateTime)

    panel.RefreshTooltip = RefreshTimeTooltip

    -- 悬停 Tooltip
    panel:SetScript("OnEnter", function(self)
        if GB().mouseOver and bar then UIFrameFadeIn(bar, 0.2, bar:GetAlpha(), 1) end
        local rr, gg, bb = GetPlayerClassColor()
        StartRegionColorAnimation(self, "_timeColorAnim", function(r, g, b)
            self.hour:SetTextColor(r, g, b, 1)
            self.mins:SetTextColor(r, g, b, 1)
            self.colon:SetTextColor(r, g, b, 1)
        end, rr, gg, bb)
        self:RefreshTooltip()
        if self.tooltipTicker then self.tooltipTicker:Cancel() end
        self.tooltipTicker = C_Timer.NewTicker(1, function()
            local DT = GetElvUITimeTooltipModules()
            local anchorOwner = self.text or self
            if (DT and DT.tooltip and DT.tooltip:IsOwned(anchorOwner)) or GameTooltip:IsOwned(self) then
                self:RefreshTooltip()
            end
        end)
    end)
    panel:SetScript("OnLeave", function(self)
        StartRegionColorAnimation(self, "_timeColorAnim", function(r, g, b)
            self.hour:SetTextColor(r, g, b, 1)
            self.mins:SetTextColor(r, g, b, 1)
            self.colon:SetTextColor(r, g, b, 1)
        end, 1, 1, 1)
        if GB().mouseOver and bar then
            C_Timer.After(0.1, function()
                if bar and not bar:IsMouseOver() then
                    UIFrameFadeOut(bar, 0.4, bar:GetAlpha(), 0)
                end
            end)
        end
        if self.tooltipTicker then
            self.tooltipTicker:Cancel(); self.tooltipTicker = nil
        end
        HideElvUITimeTooltip()
        GameTooltip:Hide()
    end)
    panel:SetScript("OnClick", function(_, mouseButton)
        if IsShiftKeyDown() then
            if IsControlKeyDown() then
                C_CVar.SetCVar("scriptProfile", tonumber(C_CVar.GetCVar("scriptProfile")) == 1 and 0 or 1)
                if not InCombatLockdown() then
                    if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
                end
            else
                collectgarbage("collect")
                if UpdateAddOnMemoryUsage then
                    UpdateAddOnMemoryUsage()
                end
            end
            return
        elseif mouseButton == "LeftButton" then
            if not InCombatLockdown() then
                local gameTimeFrame = rawget(_G, "GameTimeFrame")
                if gameTimeFrame and gameTimeFrame.Click then
                    gameTimeFrame:Click()
                else
                    ToggleCalendar()
                end
            end
        elseif mouseButton == "RightButton" then
            local timeManagerFrame = rawget(_G, "TimeManagerFrame")
            if ToggleFrame and timeManagerFrame then
                ToggleFrame(timeManagerFrame)
            elseif ToggleTimeManager then
                ToggleTimeManager()
            end
        elseif mouseButton == "MiddleButton" then
            if not InCombatLockdown() then
                if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
            end
        end
    end)
    panel:SetScript("OnDragStart", function()
        if GB().locked then return end
        bar:StartMoving()
    end)
    panel:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        Core:SaveGameBarPosition()
    end)

    return panel
end

-- Part 3/4: CreateGameBar + UpdateLayout + Visibility

-- ── 创建游戏条主体 ───────────────────────────────
function Core:CreateGameBar()
    if bar then return end

    EnsureGameBarEvents()

    -- 主框体（不可见容器，用于整体拖动）
    bar = CreateFrame("Frame", addonName .. "GameBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetSize(600, 50)

    -- 主背景
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetColorTexture(0, 0, 0, 0)

    bar:SetScript("OnDragStart", function(self)
        if GB().locked then return end
        self:StartMoving()
    end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Core:SaveGameBarPosition()
    end)

    -- 三个子面板
    middlePanel = CreateMiddlePanel(bar)
    middlePanel:SetPoint("CENTER", bar, "CENTER", 0, 0)

    leftPanel = CreateFrame("Frame", addonName .. "GameBarLeft", bar)
    leftPanel:SetPoint("RIGHT", middlePanel, "LEFT", -6, 0)

    leftPanel.bg = leftPanel:CreateTexture(nil, "BACKGROUND")
    leftPanel.bg:SetAllPoints(leftPanel)
    leftPanel.bg:SetColorTexture(0, 0, 0, 0)

    leftPanel.accent = leftPanel:CreateTexture(nil, "OVERLAY")
    leftPanel.accent:SetPoint("BOTTOMLEFT", leftPanel, "BOTTOMLEFT", 0, 0)
    leftPanel.accent:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", 0, 0)
    leftPanel.accent:SetHeight(2)

    rightPanel = CreateFrame("Frame", addonName .. "GameBarRight", bar)
    rightPanel:SetPoint("LEFT", middlePanel, "RIGHT", 6, 0)

    rightPanel.bg = rightPanel:CreateTexture(nil, "BACKGROUND")
    rightPanel.bg:SetAllPoints(rightPanel)
    rightPanel.bg:SetColorTexture(0, 0, 0, 0)

    rightPanel.accent = rightPanel:CreateTexture(nil, "OVERLAY")
    rightPanel.accent:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 0, 0)
    rightPanel.accent:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", 0, 0)
    rightPanel.accent:SetHeight(2)

    -- 恢复位置
    local cfg = GB()
    bar:SetPoint(
        cfg.point or "TOP",
        UIParent,
        cfg.relativePoint or "TOP",
        cfg.x or 0,
        cfg.y or -20
    )

    if C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses()
    end
end

-- ── 刷新整条布局 ──────────────────────────────────
function Core:UpdateGameBarLayout()
    if not bar then return end
    local cfg      = GB()
    local size     = math.max(16, math.min(64, tonumber(cfg.buttonSize) or 28))
    local gap      = math.max(0, math.min(20, tonumber(cfg.spacing) or 4))
    local midW     = math.max(60, tonumber(cfg.middleWidth) or 80)
    local midH     = size

    -- 时间面板字体大小随高度缩放
    local fontSize = math.max(10, tonumber(cfg.timeFontSize) or math.floor(size * 0.7))
    middlePanel.hour:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    middlePanel.colon:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    middlePanel.mins:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    middlePanel:SetSize(midW, midH)

    local leftSlot  = cfg.leftButtons or { "CHARACTER", "TALENTS", "SPELLBOOK", "QUESTLOG" }
    local rightSlot = cfg.rightButtons or { "BAGS", "FRIENDS", "GUILD", "SETTINGS" }

    wipe(hearthstoneButtons)

    -- 确保按钮池足够
    while #leftButtons < #leftSlot do
        table.insert(leftButtons, CreateBarButton(leftPanel, #leftButtons + 1, "L"))
    end
    while #rightButtons < #rightSlot do
        table.insert(rightButtons, CreateBarButton(rightPanel, #rightButtons + 1, "R"))
    end

    -- 布局左面板
    local lw = 0
    for i, defID in ipairs(leftSlot) do
        local btn = leftButtons[i]
        RefreshButton(btn, defID, size)
        btn:ClearAllPoints()
        if i == 1 then
            btn:SetPoint("LEFT", leftPanel, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", leftButtons[i - 1], "RIGHT", gap, 0)
        end
        btn:Show()
        lw = lw + size + (i > 1 and gap or 0)
    end
    for i = #leftSlot + 1, #leftButtons do leftButtons[i]:Hide() end
    leftPanel:SetSize(math.max(lw, 1), size)

    -- 布局右面板
    local rw = 0
    for i, defID in ipairs(rightSlot) do
        local btn = rightButtons[i]
        RefreshButton(btn, defID, size)
        btn:ClearAllPoints()
        if i == 1 then
            btn:SetPoint("LEFT", rightPanel, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", rightButtons[i - 1], "RIGHT", gap, 0)
        end
        btn:Show()
        rw = rw + size + (i > 1 and gap or 0)
    end
    for i = #rightSlot + 1, #rightButtons do rightButtons[i]:Hide() end
    rightPanel:SetSize(math.max(rw, 1), size)

    -- 整体框体大小
    local totalW = lw + midW + rw + 12 -- 12 = 两侧各6的间距
    local totalH = math.max(size, midH)
    bar:SetSize(math.max(totalW, 60), totalH)

    -- 背景
    local showBg = cfg.showBackground
    local bc = cfg.backgroundColor or { r = 0, g = 0, b = 0, a = 0.45 }
    local r, g, b = GetPlayerClassColor()
    if showBg then
        SetGradientColor(leftPanel.bg, "HORIZONTAL", r, g, b, 0.05, math.max(0.12, bc.a or 0.25))
        SetGradientColor(rightPanel.bg, "HORIZONTAL", r, g, b, math.max(0.12, bc.a or 0.25), 0.05)
        SetGradientColor(middlePanel.bg, "VERTICAL", r, g, b, 0.04, math.min((bc.a or 0.45) + 0.08, 0.38))
    else
        leftPanel.bg:SetColorTexture(0, 0, 0, 0)
        rightPanel.bg:SetColorTexture(0, 0, 0, 0)
        middlePanel.bg:SetColorTexture(0, 0, 0, 0)
    end
    if leftPanel.accent then leftPanel.accent:SetColorTexture(r, g, b, showBg and 0.85 or 0) end
    if rightPanel.accent then rightPanel.accent:SetColorTexture(r, g, b, showBg and 0.85 or 0) end
    if middlePanel.accent then middlePanel.accent:SetColorTexture(r, g, b, 0) end

    RefreshHomeButtonAttributes()

    -- mouseOver
    if cfg.mouseOver then bar:SetAlpha(0) else bar:SetAlpha(1) end
end

-- ── 显示/隐藏 ─────────────────────────────────────
function Core:UpdateGameBarVisibility()
    if not bar then return end
    if GB().enabled then bar:Show() else bar:Hide() end
end

-- ── 全量应用 ──────────────────────────────────────
function Core:ApplyGameBarSettings()
    local cfg = GB()
    if not cfg or not cfg.enabled then
        if bar then bar:Hide() end
        return
    end
    self:CreateGameBar()
    self:UpdateGameBarLayout()
    self:UpdateGameBarVisibility()
end

function GameBar:OnPlayerLogin()
    Core:ApplyGameBarSettings()
end

function GameBar:RefreshFromSettings()
    Core:ApplyGameBarSettings()
end
