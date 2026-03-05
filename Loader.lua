local REPO = "https://raw.githubusercontent.com/Pistgoat/PISTA-V10/main/"

local function execModule(name)
    local ok, source = pcall(game.HttpGet, game, REPO .. name, true)
    if not ok or not source or source == "" then
        warn("[WolfVXPE Loader] Failed to fetch " .. name)
        return
    end
    local fn, err = loadstring(source)
    if not fn then
        warn("[WolfVXPE Loader] Failed to compile " .. name .. ": " .. tostring(err))
        return
    end
    local mod = fn()
    if type(mod) == "function" then
        local ok2, err2 = pcall(mod, ctx)
        if not ok2 then
            warn("[WolfVXPE Loader] Error in " .. name .. ": " .. tostring(err2))
        end
    else
        warn("[WolfVXPE Loader] " .. name .. " did not return a function.")
    end
end

execModule("Module7_Profile.lua")
execModule("Module1_GUI.lua")
execModule("Module2_KillAura.lua")
execModule("Module3_KBReducer.lua")
execModule("Module4_AimAssist.lua")
execModule("Module5_FPSBoost.lua")
execModule("Module6_Credits.lua")
execModule("Module8_KitESP.lua")
execModule("Module9_Animations.lua")
