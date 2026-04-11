local _, NS = ...

--[[
职业辅助先只挂法师分支
保留 职业辅助 这一层 是为了后面继续加别的职业时不用改主树结构
]]

local function IsCurrentClass(classFile)
    local _, playerClass = UnitClass("player")
    return playerClass == classFile
end

function NS.BuildClassAssistOptions()
    return {
        type = "group",
        name = "职业辅助",
        order = 20,
        args = {
            utilityAnnouncer = NS.BuildClassUtilityAnnouncerOptions(),
            mage = (function()
                local group = NS.BuildMageAssistOptions()
                group.disabled = function()
                    return not IsCurrentClass("MAGE")
                end
                group.disabledTip = "当前角色不是法师"
                return group
            end)(),
        },
    }
end
