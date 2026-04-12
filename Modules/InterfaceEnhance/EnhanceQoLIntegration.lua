local _, NS = ...
local Core = NS.Core

local EnhanceQoLIntegration = {}
NS.Modules.InterfaceEnhance.EnhanceQoLIntegration = EnhanceQoLIntegration

local TARGET_ADDON_NAME = "EnhanceQoL"

local function IsAddOnLoadedCompat(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    end


    return _G[addonName] ~= nil
end

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetConfig()
    return Core:GetConfig("interfaceEnhance", "enhanceQoLIntegration")
end

local function GetCustomText(config, inCombat)
    if not config then
        return ""
    end

    return TrimText(inCombat and config.enterText or config.leaveText)
end

local function CallOriginalMethod(target, key, ...)
    local original = target and target[key]
    if type(original) == "function" then
        return original(target, ...)
    end
end

local function OverrideShowCombatText(combatText, inCombat)
    local config = GetConfig()
    if not (config and config.enabled and config.combatTextEnabled) then
        return CallOriginalMethod(combatText, "__YuXuanOriginalShowCombatText", inCombat)
    end

    if combatText.previewing then
        return
    end

    if not inCombat
        and combatText.IsAlwaysVisible
        and combatText.GetAlwaysVisibleMode
        and combatText:IsAlwaysVisible()
        and combatText:GetAlwaysVisibleMode() == combatText.ALWAYS_VISIBLE_MODE_COMBAT_ONLY then
        if combatText.HideText then
            combatText:HideText()
        end
        return
    end

    local text = GetCustomText(config, inCombat)
    if text == "" then
        return CallOriginalMethod(combatText, "__YuXuanOriginalShowCombatText", inCombat)
    end

    local r, g, b, a
    if inCombat and combatText.GetEnterColor then
        r, g, b, a = combatText:GetEnterColor()
    elseif combatText.GetLeaveColor then
        r, g, b, a = combatText:GetLeaveColor()
    end

    if combatText.ShowText then
        combatText:ShowText(text, r, g, b, a)
        return
    end

    return CallOriginalMethod(combatText, "__YuXuanOriginalShowCombatText", inCombat)
end

local function OverrideShowEditModeHint(combatText, show)
    local config = GetConfig()
    if not (config and config.enabled and config.combatTextEnabled) then
        return CallOriginalMethod(combatText, "__YuXuanOriginalShowEditModeHint", show)
    end

    if GetCustomText(config, true) == "" then
        return CallOriginalMethod(combatText, "__YuXuanOriginalShowEditModeHint", show)
    end

    if show then
        if combatText.EnsureFrame then
            combatText:EnsureFrame()
        end
        combatText.previewing = true
        if combatText.CancelHideTimer then
            combatText:CancelHideTimer()
        end
        if combatText.frame and combatText.frame.bg then
            combatText.frame.bg:Show()
        end

        local text = GetCustomText(config, true)

        local r, g, b, a
        if combatText.GetEnterColor then
            r, g, b, a = combatText:GetEnterColor()
        end
        if combatText.ApplyStyle then
            combatText:ApplyStyle(r, g, b, a)
        end
        if combatText.SetText then
            combatText:SetText(text)
        end
        if combatText.frame then
            combatText.frame:Show()
        end
        return
    end

    combatText.previewing = nil
    if combatText.frame and combatText.frame.bg then
        combatText.frame.bg:Hide()
    end

    local targetAddon = _G[TARGET_ADDON_NAME]
    if targetAddon and targetAddon.db and targetAddon.db.combatTextEnabled then
        if C_Timer and C_Timer.After and combatText.RefreshDisplayMode then
            C_Timer.After(0, function()
                combatText:RefreshDisplayMode()
            end)
        elseif combatText.RefreshDisplayMode then
            combatText:RefreshDisplayMode()
        end
    elseif combatText.HideText then
        combatText:HideText()
    end
end

function EnhanceQoLIntegration:IsTargetLoaded()
    return IsAddOnLoadedCompat(TARGET_ADDON_NAME) and _G[TARGET_ADDON_NAME] ~= nil
end

function EnhanceQoLIntegration:GetTargetCombatText()
    local targetAddon = _G[TARGET_ADDON_NAME]
    return targetAddon and targetAddon.CombatText or nil
end

function EnhanceQoLIntegration:ApplyOverrides()
    local combatText = self:GetTargetCombatText()
    if not combatText then
        return false
    end

    if combatText.__YuXuanOriginalShowCombatText == nil then
        combatText.__YuXuanOriginalShowCombatText = combatText.ShowCombatText
    end
    combatText.ShowCombatText = OverrideShowCombatText

    if combatText.ShowEditModeHint then
        if combatText.__YuXuanOriginalShowEditModeHint == nil then
            combatText.__YuXuanOriginalShowEditModeHint = combatText.ShowEditModeHint
        end
        combatText.ShowEditModeHint = OverrideShowEditModeHint
    end

    if combatText.RefreshDisplayMode then
        combatText:RefreshDisplayMode()
    end

    return true
end

function EnhanceQoLIntegration:RestoreOverrides()
    local combatText = self:GetTargetCombatText()
    if not combatText then
        return
    end

    if combatText.__YuXuanOriginalShowCombatText then
        combatText.ShowCombatText = combatText.__YuXuanOriginalShowCombatText
    end

    if combatText.__YuXuanOriginalShowEditModeHint then
        combatText.ShowEditModeHint = combatText.__YuXuanOriginalShowEditModeHint
    end

    if combatText.RefreshDisplayMode then
        combatText:RefreshDisplayMode()
    end
end

function EnhanceQoLIntegration:RefreshFromSettings()
    if not self:IsTargetLoaded() then
        return
    end

    local config = GetConfig()
    if config and config.enabled and config.combatTextEnabled then
        self:ApplyOverrides()
    else
        self:RestoreOverrides()
    end
end

function EnhanceQoLIntegration:EnsureEventFrame()
    if self.eventFrame then
        return self.eventFrame
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, _, loadedAddonName)
        if loadedAddonName == TARGET_ADDON_NAME then
            EnhanceQoLIntegration:RefreshFromSettings()
            if NS.Options and NS.Options.NotifyChanged then
                NS.Options:NotifyChanged()
            end
        end
    end)

    self.eventFrame = frame
    return frame
end

function EnhanceQoLIntegration:OnPlayerLogin()
    self:EnsureEventFrame()
    self:RefreshFromSettings()
end



