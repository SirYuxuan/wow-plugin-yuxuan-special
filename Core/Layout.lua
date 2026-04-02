local _, NS = ...
local Core = NS.Core

local C_AddOns = rawget(_G, "C_AddOns")
local C_EditMode = rawget(_G, "C_EditMode")
local C_Timer = rawget(_G, "C_Timer")
local EditModeManagerFrame = rawget(_G, "EditModeManagerFrame")
local Enum = rawget(_G, "Enum")
local InCombatLockdown = rawget(_G, "InCombatLockdown")
local ReloadUI = rawget(_G, "ReloadUI")

NS.CommonLayouts = NS.CommonLayouts or {}
NS.CommonLayouts.Default =
[=[2 50 0 0 0 7 7 UIParent -0.6 0.0 -1 ##$$%/&('%)$+$,$ 0 1 1 7 7 UIParent 0.0 45.0 -1 ##$$%/&('%(#,$ 0 2 0 7 7 UIParent -0.0 92.2 -1 ##$$%/&('%(#,$ 0 3 0 7 7 UIParent 383.9 0.0 -1 ##$&%/&('%(#,# 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,$ 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 0 7 7 UIParent -120.9 142.2 -1 ##$$&('% 0 11 1 7 7 UIParent 0.0 45.0 -1 ##$$&('%,# 0 12 0 7 7 UIParent -247.8 177.2 -1 ##$$&('% 1 -1 0 7 7 UIParent 13.3 246.9 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%( 3 0 1 8 7 UIParent -300.0 250.0 -1 $#3# 3 1 1 6 7 UIParent 300.0 250.0 -1 %#3# 3 2 1 6 7 UIParent 520.0 265.0 -1 %#&#3# 3 3 1 0 2 CompactRaidFrameManager 0.0 -7.0 -1 '#(#)#-#.#/#1$3#5#6(7-7$ 3 4 0 0 0 UIParent 0.0 -1006.0 -1 ,#-#.#/#0#1#2(5#6(7-7$ 3 5 0 2 2 UIParent -114.4 -276.0 -1 &#*$3# 3 6 0 2 2 UIParent -1471.1 -472.9 -1 -#.#/#4$5#6(7-7$ 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 0 1 1 UIParent 65.6 -123.4 -1 # 5 -1 0 7 7 UIParent 337.8 144.5 -1 # 6 0 1 2 2 UIParent -255.0 -10.0 -1 ##$#%#&.(()( 6 1 0 2 2 UIParent -267.8 -150.0 -1 ##$#%#'+(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 0 0 0 UIParent 360.1 -35.6 -1 # 8 -1 0 6 6 UIParent 10.1 30.1 -1 #'$7%%&s 9 -1 0 7 7 UIParent 259.8 181.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 0 5 5 UIParent -0.5 -20.9 -1 #@$#%# 13 -1 0 2 2 UIParent 0.0 -150.6 -1 #$$$%)&' 14 -1 1 2 2 MicroButtonAndBagsBar 0.0 10.0 -1 ##$#%( 15 0 0 1 1 UIParent 20.6 -53.0 -1 # 15 1 0 1 1 UIParent 21.1 -74.3 -1 # 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 0 4 4 UIParent -5.0 -170.7 -1 ##$5%$&&'%(-($)#+$,$-$ 20 1 0 4 4 UIParent -8.3 -229.1 -1 ##$1%$&&'%(-($)#+$,$-$ 20 2 0 4 4 UIParent -13.4 -115.0 -1 ##$$%$&&'((-($)#+$,$-$ 20 3 0 4 4 UIParent -10.0 -110.0 -1 #$$$%#&%'((-($)#*#+$,$-$.-.$ 21 -1 0 7 7 UIParent -420.6 278.3 -1 ##$# 22 0 0 1 1 UIParent -411.5 -26.8 -1 #$$$%$&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 1 0 0 UIParent 0.0 0.0 -1 ##$#%$&-&$'7(%)U+$,$-$.(/U]=]

function Core:ImportEditModeLayout(layoutString, layoutName)
    if type(layoutString) ~= "string" or layoutString == "" then
        return false, "布局字符串为空。"
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, "战斗中无法导入布局。"
    end

    if not (C_EditMode and EditModeManagerFrame) then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_EditMode")
        end
    end

    if not (C_EditMode and EditModeManagerFrame and C_EditMode.ConvertStringToLayoutInfo) then
        return false, "无法加载编辑模式模块。"
    end

    local layoutInfo = C_EditMode.ConvertStringToLayoutInfo(layoutString)
    if not layoutInfo then
        return false, "布局字符串无效。"
    end

    local baseName = tostring(layoutName or "雨轩通用布局")
    local finalName = baseName
    local layouts = (C_EditMode.GetLayouts and C_EditMode.GetLayouts().layouts) or {}
    local nameTaken = false

    for _, info in ipairs(layouts) do
        if info.layoutName == finalName then
            nameTaken = true
            break
        end
    end

    if nameTaken then
        local index = 1
        while true do
            local testName = string.format("%s (%d)", baseName, index)
            local found = false
            for _, info in ipairs(layouts) do
                if info.layoutName == testName then
                    found = true
                    break
                end
            end
            if not found then
                finalName = testName
                break
            end
            index = index + 1
        end
    end

    EditModeManagerFrame:ImportLayout(layoutInfo, Enum.EditModeLayoutType.Character, finalName)

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if InCombatLockdown and InCombatLockdown() then
                return
            end

            local newLayouts = (C_EditMode.GetLayouts and C_EditMode.GetLayouts().layouts) or {}
            for idx, info in ipairs(newLayouts) do
                if info.layoutName == finalName then
                    C_EditMode.SetActiveLayout(idx + 2)
                    if C_Timer.After and ReloadUI then
                        C_Timer.After(0.3, function()
                            if InCombatLockdown and InCombatLockdown() then
                                return
                            end

                            ReloadUI()
                        end)
                    end
                    break
                end
            end
        end)
    end

    return true, finalName
end

function Core:ImportDefaultCommonLayout()
    local ok, result = self:ImportEditModeLayout(NS.CommonLayouts.Default, "雨轩通用布局")
    if ok then
        self:Print("已导入并激活布局：" .. tostring(result))
    else
        self:Print(tostring(result or "导入通用布局失败。"))
    end
    return ok, result
end
