local _, NS = ...

--[[
职业辅助先只挂法师分支
保留 职业辅助 这一层 是为了后面继续加别的职业时不用改主树结构
]]

function NS.BuildClassAssistOptions()
    return {
        type = "group",
        name = "职业辅助",
        order = 20,
        args = {
            mage = NS.BuildMageAssistOptions(),
        },
    }
end
