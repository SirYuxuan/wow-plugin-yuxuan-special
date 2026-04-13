local _, NS = ...

local unpack = unpack or table.unpack
local WEEKLY_REWARD_TYPE = Enum and Enum.WeeklyRewardChestThresholdType

local function U(bytes)
    return string.char(unpack(bytes))
end

local STR = {
    query = U({ 228, 189, 142, 228, 191, 157, 230, 159, 165, 232, 175, 162 }),
    vault = U({ 229, 174, 143, 228, 188, 159, 229, 174, 157, 229, 186, 147 }),
    summary = U({ 230, 156, 172, 229, 145, 168, 229, 174, 143, 228, 188, 159, 229, 174, 157, 229, 186, 147, 232, 191, 155, 229, 186, 166 }),
    unsupported = U({ 229, 189, 147, 229, 137, 141, 229, 174, 162, 230, 136, 183, 231, 171, 175, 228, 184, 141, 230, 148, 175, 230, 140, 129, 229, 174, 143, 228, 188, 159, 229, 174, 157, 229, 186, 147, 230, 142, 165, 229, 143, 163, 227, 128, 130 }),
    unavailable = U({ 230, 154, 130, 230, 151, 182, 230, 178, 161, 230, 156, 137, 229, 143, 175, 232, 175, 187, 229, 143, 150, 231, 154, 132, 229, 174, 143, 228, 188, 159, 229, 174, 157, 229, 186, 147, 232, 191, 155, 229, 186, 166, 227, 128, 130 }),
    waitHint = U({ 229, 166, 130, 230, 158, 156, 229, 136, 154, 228, 184, 138, 231, 186, 191, 239, 188, 140, 229, 143, 175, 228, 187, 165, 231, 168, 141, 231, 173, 137, 231, 137, 135, 229, 136, 187, 229, 144, 142, 231, 130, 185, 226, 128, 156, 229, 136, 183, 230, 150, 176, 232, 191, 155, 229, 186, 166, 226, 128, 157, 227, 128, 130 }),
    notOpen = U({ 230, 156, 170, 229, 188, 128, 229, 144, 175 }),
    unlocked = U({ 229, 183, 178, 232, 167, 163, 233, 148, 129 }),
    incomplete = U({ 230, 156, 170, 229, 174, 140, 230, 136, 144 }),
    level = U({ 229, 177, 130, 230, 149, 176 }),
    slotFormat = U({ 226, 128, 162, 32, 231, 172, 172, 37, 100, 230, 160, 188, 32, 37, 115 }),
    openVault = U({ 230, 137, 147, 229, 188, 128, 229, 174, 143, 228, 188, 159, 229, 174, 157, 229, 186, 147 }),
    refresh = U({ 229, 136, 183, 230, 150, 176, 232, 191, 155, 229, 186, 166 }),
    command = U({ 229, 145, 189, 228, 187, 164, 239, 188, 154, 47, 121, 120, 115, 32, 100, 98 }),
    activities = U({ 229, 143, 178, 232, 175, 151, 233, 146, 165, 231, 159, 179 }),
    raid = U({ 229, 155, 162, 230, 156, 172 }),
    world = U({ 228, 184, 150, 231, 149, 140, 229, 134, 133, 229, 174, 185 }),
    other = U({ 229, 133, 182, 228, 187, 150 }),
    noRewardData = U({ 230, 154, 130, 230, 151, 160, 229, 165, 150, 229, 138, 177, 230, 149, 176, 230, 141, 174 }),
    retrieving = U({ 230, 173, 163, 229, 156, 168, 232, 142, 183, 229, 143, 150, 231, 137, 169, 229, 147, 129, 228, 191, 161, 230, 129, 175 }),
}

local pendingItemLoads = {}

local function NotifyGreatVaultChanged()
    if NS.Options and NS.Options.NotifyChanged then
        NS.Options:NotifyChanged()
    end
end

local function NormalizeItemLink(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    if itemLink == "" or itemLink:match("^%s*$") then
        return nil
    end
    return itemLink
end

local function QueueItemLoad(itemLink)
    itemLink = NormalizeItemLink(itemLink)
    if not itemLink or pendingItemLoads[itemLink] then
        return
    end

    if Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(itemLink)
        if item then
            pendingItemLoads[itemLink] = true
            item:ContinueOnItemLoad(function()
                pendingItemLoads[itemLink] = nil
                NotifyGreatVaultChanged()
            end)
        end
    end
end

local function ExtractItemLevel(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return nil
end

local function GetDetailedItemLevelInfoCompat(itemLink)
    itemLink = NormalizeItemLink(itemLink)
    if not itemLink then
        return nil
    end

    if C_Item and C_Item.GetDetailedItemLevelInfo then
        return ExtractItemLevel(C_Item.GetDetailedItemLevelInfo(itemLink))
    end
    if GetDetailedItemLevelInfo then
        return ExtractItemLevel(GetDetailedItemLevelInfo(itemLink))
    end
    return nil
end

local function GetItemUpgradeTrackInfoCompat(itemLink)
    local planner = NS.Modules and NS.Modules.InterfaceEnhance and NS.Modules.InterfaceEnhance.ItemLevelPlanner
    if planner and planner.GetItemUpgradeTrackInfo then
        return planner.GetItemUpgradeTrackInfo(itemLink)
    end
    return nil
end

local function GetChestTypeName(chestType)
    if WEEKLY_REWARD_TYPE then
        if chestType == WEEKLY_REWARD_TYPE.Activities then
            return STR.activities
        end
        if chestType == WEEKLY_REWARD_TYPE.RankedPvP then
            return "PvP"
        end
        if chestType == WEEKLY_REWARD_TYPE.Raid then
            return STR.raid
        end
        if chestType == WEEKLY_REWARD_TYPE.World then
            return STR.world
        end
    end

    if chestType == 1 then
        return STR.activities
    end
    if chestType == 2 then
        return "PvP"
    end
    if chestType == 3 then
        return STR.raid
    end
    if chestType == 6 then
        return STR.world
    end

    return STR.other
end

local function GetActivityLevelText(info)
    local chestType = tonumber(info and info.type) or 0
    local level = tonumber(info and info.level) or 0
    if level <= 0 then
        return nil
    end

    if WEEKLY_REWARD_TYPE and chestType == WEEKLY_REWARD_TYPE.Raid then
        if DifficultyUtil and DifficultyUtil.GetDifficultyName then
            return DifficultyUtil.GetDifficultyName(level)
        end
        return tostring(level)
    end

    if WEEKLY_REWARD_TYPE and chestType == WEEKLY_REWARD_TYPE.RankedPvP then
        if PVPUtil and PVPUtil.GetTierName then
            return PVPUtil.GetTierName(level)
        end
        return tostring(level)
    end

    return tostring(level)
end

local function GetRewardLabel(info, itemLink)
    local chestType = tonumber(info and info.type) or 0
    local levelText = GetActivityLevelText(info)

    if WEEKLY_REWARD_TYPE and chestType == WEEKLY_REWARD_TYPE.Raid then
        return levelText
    end

    if WEEKLY_REWARD_TYPE and chestType == WEEKLY_REWARD_TYPE.RankedPvP then
        return levelText
    end

    if WEEKLY_REWARD_TYPE and chestType == WEEKLY_REWARD_TYPE.World then
        return (STR.level .. " " .. (levelText or "")):gsub("%s+$", "")
    end

    local trackInfo = itemLink and GetItemUpgradeTrackInfoCompat(itemLink) or nil
    if trackInfo and trackInfo.name and trackInfo.name ~= "" then
        return trackInfo.name
    end

    if levelText and levelText ~= "" then
        return levelText
    end

    return nil
end

local function GetPreviewRewardLink(info)
    if not (C_WeeklyRewards and C_WeeklyRewards.GetExampleRewardItemHyperlinks and info and info.id) then
        return nil
    end

    local itemLink, upgradeLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(info.id)
    itemLink = NormalizeItemLink(itemLink)
    upgradeLink = NormalizeItemLink(upgradeLink)

    local chestType = tonumber(info and info.type) or 0
    if WEEKLY_REWARD_TYPE and chestType == WEEKLY_REWARD_TYPE.Raid then
        return itemLink or upgradeLink
    end

    return upgradeLink or itemLink
end

local function BuildRewardLine(itemLink, info)
    itemLink = NormalizeItemLink(itemLink)
    local rewardText = GetRewardLabel(info, itemLink)
    local itemLevel = itemLink and tonumber(GetDetailedItemLevelInfoCompat(itemLink)) or 0

    if itemLevel and itemLevel > 0 then
        if rewardText and rewardText ~= "" then
            return string.format("%s %d", rewardText, itemLevel)
        end
        return tostring(itemLevel)
    end

    if itemLink then
        QueueItemLoad(itemLink)
        if rewardText and rewardText ~= "" then
            return string.format("%s %s", rewardText, RETRIEVING_ITEM_INFO or STR.retrieving)
        end
        return RETRIEVING_ITEM_INFO or STR.retrieving
    end

    if rewardText and rewardText ~= "" then
        return string.format("%s %s", rewardText, STR.noRewardData)
    end
    return STR.noRewardData
end

local function GetActivityRewardSummary(info)
    local rewards = info and info.rewards
    if type(rewards) == "table" and #rewards > 0 and C_WeeklyRewards.GetItemHyperlink then
        for _, rewardInfo in ipairs(rewards) do
            local itemLink = rewardInfo and rewardInfo.itemDBID and C_WeeklyRewards.GetItemHyperlink(rewardInfo.itemDBID)
            local displayText = BuildRewardLine(itemLink, info)
            if displayText and displayText ~= "" and displayText ~= STR.noRewardData then
                return displayText
            end
        end
    end

    if C_WeeklyRewards.GetExampleRewardItemHyperlinks and info and info.id then
        local displayLink = GetPreviewRewardLink(info)
        if displayLink then
            return BuildRewardLine(displayLink, info)
        end
    end

    return nil
end

local function BuildProgressLines()
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then
        return {
            "|cFFFF6B6B" .. STR.unsupported .. "|r",
        }
    end

    local activities = C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" or #activities == 0 then
        return {
            "|cFFFFD200" .. STR.unavailable .. "|r",
            "|cFF888888" .. STR.waitHint .. "|r",
        }
    end

    table.sort(activities, function(a, b)
        local typeA = tonumber(a and a.type) or 0
        local typeB = tonumber(b and b.type) or 0
        if typeA ~= typeB then
            return typeA < typeB
        end

        local indexA = tonumber(a and a.index) or 0
        local indexB = tonumber(b and b.index) or 0
        if indexA ~= indexB then
            return indexA < indexB
        end

        return (tonumber(a and a.threshold) or 0) < (tonumber(b and b.threshold) or 0)
    end)

    local lines = {
        "|cFFFFD200" .. STR.summary .. "|r",
    }

    local lastType
    for _, info in ipairs(activities) do
        local chestType = tonumber(info.type) or 0
        local threshold = tonumber(info.threshold) or 0
        local progress = tonumber(info.progress) or 0
        local unlocked = threshold > 0 and progress >= threshold

        if chestType ~= lastType then
            if lastType ~= nil then
                lines[#lines + 1] = " "
            end
            lines[#lines + 1] = string.format("|cFF33FF99%s|r", GetChestTypeName(chestType))
            lastType = chestType
        end

        local detail = string.format("%d / %d", progress, threshold)
        if unlocked then
            local rewardText = GetActivityRewardSummary(info)
            if rewardText and rewardText ~= "" then
                detail = detail .. " " .. rewardText
            else
                detail = detail .. " " .. STR.noRewardData
            end
        else
            detail = detail .. " " .. STR.incomplete
        end

        lines[#lines + 1] = string.format(STR.slotFormat, tonumber(info.index) or 0, detail)
    end

    return lines
end

NS.GetGreatVaultProgressLines = BuildProgressLines

function NS.GetGreatVaultDisplayName()
    return STR.vault
end

function NS.GetGreatVaultQueryName()
    return STR.query
end

function NS.BuildGreatVaultOptions()
    return {
        type = "group",
        name = STR.query,
        order = 18,
        args = {
            summary = {
                type = "description",
                order = 10,
                fontSize = "medium",
                name = function()
                    return table.concat(BuildProgressLines(), "\n")
                end,
            },
            actions = {
                type = "group",
                order = 20,
                name = "",
                layout = "row",
                args = {
                    openVault = {
                        type = "execute",
                        order = 1,
                        width = 1.0,
                        name = STR.openVault,
                        func = function()
                            if WeeklyRewards_ShowUI then
                                WeeklyRewards_ShowUI()
                            end
                        end,
                    },
                    refresh = {
                        type = "execute",
                        order = 2,
                        width = 1.0,
                        name = STR.refresh,
                        func = function()
                            NotifyGreatVaultChanged()
                        end,
                    },
                },
            },
            tips = {
                type = "description",
                order = 30,
                fontSize = "medium",
                name = "|cFF888888" .. STR.command .. "|r",
            },
        },
    }
end
