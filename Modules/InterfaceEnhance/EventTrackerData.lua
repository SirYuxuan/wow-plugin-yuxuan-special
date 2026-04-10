local _, NS = ...

--------------------------------------------------------------------------------
-- 事件追踪器 - 数据定义
-- 参考 ElvUI_WindTools EventTracker，独立实现，不依赖 ElvUI
--------------------------------------------------------------------------------

NS.Modules.InterfaceEnhance.EventTrackerData = NS.Modules.InterfaceEnhance.EventTrackerData or {}
NS.EventTrackerData = NS.Modules.InterfaceEnhance.EventTrackerData
local ETD = NS.EventTrackerData

--------------------------------------------------------------------------------
-- 工具函数
--------------------------------------------------------------------------------
local floor, format, pairs, ipairs, type = floor, format, pairs, ipairs, type
local GetServerTime = GetServerTime
local GetCurrentRegion = GetCurrentRegion
local C_QuestLog_IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
local C_Map_GetMapInfo = C_Map.GetMapInfo
local professionProgressScratch = {}
local _secondToTimeCache = {}
local _secondToTimeCacheSize = 0
local _MAX_SECOND_CACHE = 256

-- 格式化秒数为 HH:MM:SS 或 MM:SS (cached)
function ETD.SecondToTime(second)
    local key = floor(second)
    local cached = _secondToTimeCache[key]
    if cached then return cached end

    local hour = floor(second / 3600)
    local min = floor((second - hour * 3600) / 60)
    local sec = floor(second - hour * 3600 - min * 60)
    local result
    if hour == 0 then
        result = format("%02d:%02d", min, sec)
    else
        result = format("%02d:%02d:%02d", hour, min, sec)
    end

    if _secondToTimeCacheSize >= _MAX_SECOND_CACHE then
        for k in pairs(_secondToTimeCache) do _secondToTimeCache[k] = nil end
        _secondToTimeCacheSize = 0
    end
    _secondToTimeCache[key] = result
    _secondToTimeCacheSize = _secondToTimeCacheSize + 1
    return result
end

-- 绿色高亮版本 (cached)
local _coloredTimeCache = {}
local _coloredTimeCacheSize = 0

function ETD.SecondToTimeGreen(second)
    local key = floor(second)
    local cached = _coloredTimeCache[key]
    if cached then return cached end

    local result = "|cFF33FF33" .. ETD.SecondToTime(second) .. "|r"

    if _coloredTimeCacheSize >= _MAX_SECOND_CACHE then
        for k in pairs(_coloredTimeCache) do _coloredTimeCache[k] = nil end
        _coloredTimeCacheSize = 0
    end
    _coloredTimeCache[key] = result
    _coloredTimeCacheSize = _coloredTimeCacheSize + 1
    return result
end

-- 获取安全的地图名称
local function SafeMapName(mapID)
    local info = C_Map_GetMapInfo(mapID)
    return info and info.name or ("地图" .. mapID)
end

--------------------------------------------------------------------------------
-- 元数据
--------------------------------------------------------------------------------
ETD.Meta = {
    -- 专业周常任务数据 (MN/午夜)
    ProfessionsWeeklyMN = {
        [4620669] = 93690,                          -- 炼金术
        [4620670] = 93691,                          -- 锻造
        [4620672] = 93698,                          -- 附魔
        [4620673] = 93692,                          -- 工程学
        [4620675] = { 93700, 93702, 93703, 93704 }, -- 草药学
        [4620676] = 93693,                          -- 铭文
        [4620677] = 93694,                          -- 珠宝
        [4620678] = 93695,                          -- 制皮
        [4620679] = { 93705, 93706, 93708, 93709 }, -- 采矿
        [4620680] = { 93710, 93711, 93714 },        -- 剥皮
        [4620681] = 93696,                          -- 裁缝
    },
}

--------------------------------------------------------------------------------
-- 颜色配置
--------------------------------------------------------------------------------
ETD.Colors = {
    running    = { 0.2, 0.8, 0.5 },  -- 进行中进度条
    waiting    = { 0.4, 0.4, 0.4 },  -- 等待中进度条
    completed  = { 0.2, 1.0, 0.2 },  -- 已完成
    notDone    = { 1.0, 0.3, 0.3 },  -- 未完成
    inProgress = { 1.0, 0.82, 0.0 }, -- 进行中文本
    label      = { 1.0, 0.84, 0.2 }, -- 标签文本
    timer      = { 0.5, 1.0, 0.5 },  -- 倒计时文本
    purple     = { 0.5, 0.3, 0.9 },  -- 紫色进度条
    blue       = { 0.3, 0.6, 1.0 },  -- 蓝色进度条
    red        = { 0.9, 0.3, 0.3 },  -- 红色进度条
    green      = { 0.3, 0.9, 0.4 },  -- 绿色进度条
    bronze     = { 0.8, 0.65, 0.2 }, -- 铜色进度条
}

--------------------------------------------------------------------------------
-- 获取区域时间戳（根据服务器区域选择起始时间）
--------------------------------------------------------------------------------
local function GetRegionTimestamp(timestampTable)
    local region = GetCurrentRegion()
    return timestampTable[region] or timestampTable[5] or 0
end

--------------------------------------------------------------------------------
-- 事件列表（显示顺序）
--------------------------------------------------------------------------------
ETD.EventList = {
    -- 至暗之夜 (Midnight)
    "WeeklyMN",
    "ProfessionsWeeklyMN",
    "StormarionAssault",
    -- 地心之战 (The War Within)
    "WeeklyTWW",
    "Nightfall",
    "TheaterTroupe",
    "EcologicalSuccession",
    "RingingDeeps",
    "SpreadingTheLight",
    "UnderworldOperative",
}

--------------------------------------------------------------------------------
-- 事件数据定义
--------------------------------------------------------------------------------
ETD.EventData = {
    ---------------------------------------------------------------------------
    -- ████ 至暗之夜 (Midnight) ████
    ---------------------------------------------------------------------------

    -- 至暗之夜周常任务
    WeeklyMN = {
        dbKey = "weeklyMN",
        type = "weekly",
        icon = 236681,
        label = "周常(至暗之夜)",
        eventName = "周常任务 (至暗之夜)",
        location = SafeMapName(2537),
        mapID = 2537,
        questGroups = {
            {
                name = "莉亚德琳 4选1",
                location = SafeMapName(2393),
                quests = { 93767, 93889, 93909, 93911 },
            },
            {
                name = "地下城周常",
                location = SafeMapName(2393),
                quests = { 93753 },
            },
            {
                name = "聚会周常",
                location = SafeMapName(2395),
                quests = { 90573, 90574, 90575, 90576 },
            },
            {
                name = "传奇周常",
                location = SafeMapName(2413),
                quests = { 88993, 88994, 88995, 88996, 88997 },
            },
            {
                name = "丰饶贡品",
                location = SafeMapName(2437),
                quests = { 89507 },
            },
        },
    },

    -- 至暗之夜专业周常
    ProfessionsWeeklyMN = {
        dbKey = "professionsWeeklyMN",
        type = "weekly",
        icon = 1392955,
        label = "专业周常(至暗之夜)",
        eventName = "专业周常 (至暗之夜)",
        location = SafeMapName(2393),
        mapID = 2393,
        useProfessionQuests = true, -- 标记使用专业匹配逻辑
    },

    -- 斯托玛兰突袭战 (Stormarion Assault)
    StormarionAssault = {
        dbKey = "stormarionAssault",
        type = "loopTimer",
        icon = 7431083,
        label = "斯托玛兰突袭战",
        eventName = "斯托玛兰突袭战",
        location = SafeMapName(2405),
        mapID = 2405,
        questIDs = { 90962 },
        hasWeeklyReward = true,
        duration = 15 * 60,
        interval = 30 * 60,
        flash = true,
        barColor = ETD.Colors.purple,
        runningText = "进行中",
        startTimestamp = GetRegionTimestamp({
            [1] = 1772728200, -- NA
            [2] = 1772728200, -- KR
            [3] = 1772728200, -- EU
            [4] = 1772728200, -- TW
            [5] = 1772728200, -- CN
        }),
    },

    ---------------------------------------------------------------------------
    -- ████ 地心之战 (The War Within) ████
    ---------------------------------------------------------------------------

    -- TWW 周常任务
    WeeklyTWW = {
        dbKey = "weeklyTWW",
        type = "weekly",
        icon = 236681,
        label = "周常(地心之战)",
        eventName = "周常任务 (地心之战)",
        location = SafeMapName(2339),
        mapID = 2339,
        questGroups = {
            {
                name = "探究周常",
                quests = { 82706, 82708, 82709, 82710, 82711, 82712, 82746 },
            },
            {
                name = "文库周常",
                quests = { 82678, 82679 },
            },
            {
                name = "周末活动",
                quests = { 83345, 83347, 83357, 83358, 83359, 83360, 83362, 83363, 83364, 83365, 83366, 84776 },
            },
            {
                name = "地下城周常",
                quests = { 83432, 83436, 83443, 83457, 83458, 83459, 83465, 83469, 86203 },
            },
        },
    },

    -- 夜幕激斗 (Nightfall)
    Nightfall = {
        dbKey = "nightfall",
        type = "loopTimer",
        icon = 6694198,
        label = "夜幕激斗",
        eventName = "夜幕激斗",
        location = SafeMapName(2215),
        mapID = 2215,
        questIDs = { 91173 },
        hasWeeklyReward = true,
        duration = 15 * 60,
        interval = 60 * 60,
        flash = true,
        barColor = ETD.Colors.purple,
        runningText = "进行中",
        startTimestamp = GetRegionTimestamp({
            [1] = 1757134800,
            [2] = 1757134800,
            [3] = 1757134800,
            [4] = 1757134800,
            [5] = 1757134800,
        }),
    },

    -- 剧团演出 (Theater Troupe)
    TheaterTroupe = {
        dbKey = "theaterTroupe",
        type = "loopTimer",
        icon = 5788303,
        label = "剧团演出",
        eventName = "剧团演出",
        location = SafeMapName(2248),
        mapID = 2248,
        questIDs = { 83240 },
        hasWeeklyReward = true,
        duration = 15 * 60,
        interval = 60 * 60,
        flash = true,
        barColor = ETD.Colors.bronze,
        runningText = "演出中",
        startTimestamp = GetRegionTimestamp({
            [1] = 1757134800,
            [2] = 1757134800,
            [3] = 1757134800,
            [4] = 1757134800,
            [5] = 1757134800,
        }),
    },

    -- 生态重构 (Ecological Succession)
    EcologicalSuccession = {
        dbKey = "ecologicalSuccession",
        type = "weekly",
        icon = 6921877,
        label = "生态重构",
        eventName = "生态重构",
        location = SafeMapName(2371),
        mapID = 2371,
        questIDs = { 85460 },
        hasWeeklyReward = true,
    },

    -- 回响深渊 (Ringing Deeps)
    RingingDeeps = {
        dbKey = "ringingDeeps",
        type = "weekly",
        icon = 2120036,
        label = "回响深渊",
        eventName = "回响深渊",
        location = SafeMapName(2214),
        mapID = 2214,
        questIDs = { 83333 },
        hasWeeklyReward = true,
    },

    -- 散布光芒 (Spreading The Light)
    SpreadingTheLight = {
        dbKey = "spreadingTheLight",
        type = "weekly",
        icon = 5927633,
        label = "散布光芒",
        eventName = "散布光芒",
        location = SafeMapName(2215),
        mapID = 2215,
        questIDs = { 76586 },
        hasWeeklyReward = true,
    },

    -- 暗影行动 (Underworld Operative)
    UnderworldOperative = {
        dbKey = "underworldOperative",
        type = "weekly",
        icon = 5309857,
        label = "暗影行动",
        eventName = "暗影行动",
        location = SafeMapName(2255),
        mapID = 2255,
        questIDs = { 80670, 80671, 80672 },
        hasWeeklyReward = true,
    },
}

--------------------------------------------------------------------------------
-- 检查任务完成状态
--------------------------------------------------------------------------------

-- 检查单个任务组是否完成（任意一个完成即可）
function ETD.IsQuestGroupCompleted(quests)
    if not quests or type(quests) ~= "table" then return false end
    for _, questID in ipairs(quests) do
        if C_QuestLog_IsQuestFlaggedCompleted(questID) then
            return true
        end
    end
    return false
end

-- 检查任务组列表的完成进度
function ETD.GetQuestGroupsProgress(questGroups)
    if not questGroups then return 0, 0 end
    local completed, total = 0, #questGroups
    for _, group in ipairs(questGroups) do
        if ETD.IsQuestGroupCompleted(group.quests) then
            completed = completed + 1
        end
    end
    return completed, total
end

-- 检查简单任务列表的完成状态
function ETD.IsAnyQuestCompleted(questIDs)
    if not questIDs or type(questIDs) ~= "table" then return false end
    for _, questID in ipairs(questIDs) do
        if C_QuestLog_IsQuestFlaggedCompleted(questID) then
            return true
        end
    end
    return false
end

-- 检查专业周常完成状态
function ETD.GetProfessionWeeklyProgress()
    local GetProfessions = GetProfessions
    local GetProfessionInfo = GetProfessionInfo
    if not GetProfessions or not GetProfessionInfo then return {} end

    local prof1, prof2 = GetProfessions()
    local results = professionProgressScratch
    for index = #results, 1, -1 do
        results[index] = nil
    end

    local function AddProfession(profIndex)
        if profIndex then
            local name, iconID = GetProfessionInfo(profIndex)
            local questData = ETD.Meta.ProfessionsWeeklyMN[iconID]
            if questData then
                local isCompleted = false
                if type(questData) == "table" then
                    for _, qid in ipairs(questData) do
                        if C_QuestLog_IsQuestFlaggedCompleted(qid) then
                            isCompleted = true
                            break
                        end
                    end
                else
                    isCompleted = C_QuestLog_IsQuestFlaggedCompleted(questData)
                end
                results[#results + 1] = {
                    name = name,
                    iconID = iconID,
                    isCompleted = isCompleted,
                }
            end
        end
    end

    AddProfession(prof1)
    AddProfession(prof2)

    return results
end

-- 获取事件的完成状态
function ETD.GetEventCompletionStatus(eventKey)
    local data = ETD.EventData[eventKey]
    if not data then return false end

    if data.useProfessionQuests then
        local profProgress = ETD.GetProfessionWeeklyProgress()
        if #profProgress == 0 then return false end
        for _, prof in ipairs(profProgress) do
            if not prof.isCompleted then return false end
        end
        return true
    end

    if data.questGroups then
        local completed, total = ETD.GetQuestGroupsProgress(data.questGroups)
        return completed == total and total > 0
    end

    if data.questIDs then
        return ETD.IsAnyQuestCompleted(data.questIDs)
    end

    return false
end

-- 获取循环计时事件的时间状态
function ETD.GetLoopTimerStatus(eventKey)
    local data = ETD.EventData[eventKey]
    if not data or data.type ~= "loopTimer" then return nil end

    local now = GetServerTime()
    local elapsed = now - data.startTimestamp
    local timeInCycle = elapsed % data.interval
    local isRunning = timeInCycle < data.duration

    local timeLeft
    if isRunning then
        timeLeft = data.duration - timeInCycle
    else
        timeLeft = data.interval - timeInCycle
    end

    local nextEventTimestamp = data.startTimestamp + (floor(elapsed / data.interval) + 1) * data.interval

    data._loopStatus = data._loopStatus or {}
    data._loopStatus.isRunning = isRunning
    data._loopStatus.timeLeft = timeLeft
    data._loopStatus.timeInCycle = timeInCycle
    data._loopStatus.nextEventTimestamp = nextEventTimestamp
    data._loopStatus.duration = data.duration
    data._loopStatus.interval = data.interval
    return data._loopStatus
end
