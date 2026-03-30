local _, NS = ...

local Options = NS.Options
local Private = Options.Private

--[[
设置系统主入口。

这个文件只做“总控”工作：
1. 确保主窗口已经创建。
2. 对外暴露 Open / Close / Toggle 这些公共接口。
3. 把斜杠命令需要的快捷入口统一收口在这里。
4. 在专精变化、世界进入时刷新当前打开的设置页。

真正的界面搭建和选项渲染已经拆到其他文件里了，
这样 Main.lua 会保持很短，也更适合以后维护。
]]

function Options:EnsureRegistered()
    self.selectedChildren = self.selectedChildren or {}
    self.navButtons = self.navButtons or {}
    if Private and Private.RefreshThemeColors then
        Private.RefreshThemeColors()
    end
    self:CreateMainFrame()
    self.frame:SetScale(1)
    return self.frame ~= nil
end

function Options:ApplyWindowScale()
    if self.frame then
        self.frame:SetScale(1)
    end
end

function Options:RefreshAppearance()
    if Private and Private.RefreshThemeColors then
        Private.RefreshThemeColors()
    end

    if self.frame and Private and Private.RefreshFonts then
        Private.RefreshFonts(self.frame)
    end

    if self.frame and self.frame.header and self.frame.header.qqButton and self.frame.header.qqButton.label then
        Private.ApplyStoredFont(self.frame.header.qqButton.label)
    end

    if self:IsOpen() then
        self:Render()
    elseif self.frame then
        self:RefreshNavigation()
    end
end

function Options:IsOpen()
    return self.frame and self.frame:IsShown() or false
end

function Options:Open(...)
    if not self:EnsureRegistered() then
        return false
    end

    local path = { ... }
    self:GetRootOptions()
    self:ApplyPathSelection(path)
    self:RefreshAppearance()
    self.frame:Show()
    self:RestoreWindowPlacement()
    self:Render()

    -- 某些尺寸依赖需要等到 Show 之后下一帧才稳定，再补一次刷新更保险。
    C_Timer.After(0, function()
        if Options and Options.IsOpen and Options:IsOpen() then
            Options:Render()
        end
    end)

    return true
end

function Options:Close()
    if self.frame then
        self:CaptureWindowPlacement()
        self.frame:Hide()
    end
end

function Options:Toggle(...)
    if select("#", ...) > 0 then
        return self:Open(...)
    end

    if self:IsOpen() then
        self:Close()
        return true
    end

    return self:Open()
end

--[[
下面这些方法是给斜杠命令和模块内部快速跳页用的。
这样以后如果页面路径有调整，只需要改这一处映射关系。
]]
function Options:OpenMapAssist()
    return self:Open("mapAssist")
end

function Options:OpenQuickWaypoint()
    return self:Open("mapAssist", "quickWaypoint")
end

function Options:OpenMageAssist()
    return self:Open("classAssist", "mage")
end

function Options:OpenMageFrostAssist()
    return self:Open("classAssist", "mage", "frost")
end

function Options:OpenCombatAssist()
    return self:Open("combatAssist")
end

function Options:OpenTrinketMonitor()
    return self:Open("combatAssist", "trinketMonitor")
end

local optionEventFrame = CreateFrame("Frame")
optionEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
optionEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
optionEventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
optionEventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return
    end

    if Options and Options.IsOpen and Options:IsOpen() then
        Options:NotifyChanged()
    end
end)
