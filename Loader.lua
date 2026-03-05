
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Lighting         = game:GetService("Lighting")
local Stats            = game:GetService("Stats")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Mouse       = LocalPlayer:GetMouse()
local Camera      = workspace.CurrentCamera


local tinsert, tremove, tclone = table.insert, table.remove, table.clone
local mfloor, mcos, mrad, mabs = math.floor, math.cos, math.rad, math.abs
local v3new, cf3new = Vector3.new, CFrame.new


local cloneref = cloneref or function(obj) return obj end


local ok, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
if ok and VirtualUser then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.zero, Camera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.zero, Camera.CFrame)
    end)
end


local function getChar()     return LocalPlayer.Character end
local function getRoot()     local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() local c=getChar(); return c and c:FindFirstChild("Humanoid") end


-- Every module receives this table and populates it with its
-- own exports so downstream modules can reference them.
-- ══════════════════════════════════════════════════════════════
local ctx = {
    -- Services
    Players          = Players,
    RunService       = RunService,
    UserInputService = UserInputService,
    TweenService     = TweenService,
    ReplicatedStorage= ReplicatedStorage,
    Lighting         = Lighting,
    Stats            = Stats,
    CoreGui          = CoreGui,
    -- Player refs
    LocalPlayer = LocalPlayer,
    PlayerGui   = PlayerGui,
    Mouse       = Mouse,
    Camera      = Camera,
    -- Fast refs
    tinsert = tinsert,
    tremove = tremove,
    tclone  = tclone,
    mfloor  = mfloor,
    mcos    = mcos,
    mrad    = mrad,
    mabs    = mabs,
    v3new   = v3new,
    cf3new  = cf3new,
    cloneref= cloneref,
    -- Character helpers
    getChar    = getChar,
    getRoot    = getRoot,
    getHumanoid= getHumanoid,
}


local REPO = "https://raw.githubusercontent.com/Pistgoat/PISTA-V10/main/"


local function execModule(name)
    local source, err
    local ok = pcall(function()
        source = game:HttpGet(REPO .. name, true)
    end)
    if not ok or not source or source == "" then
        warn("[WolfVXPE Loader] Failed to fetch " .. name .. ": " .. tostring(err or "empty response"))
        return
    end
    local fn, compErr = loadstring(source)
    if not fn then
        warn("[WolfVXPE Loader] Failed to compile " .. name .. ": " .. tostring(compErr))
        return
    end
    local mod = fn()
    if type(mod) == "function" then
        local ok2, runErr = pcall(mod, ctx)
        if not ok2 then
            warn("[WolfVXPE Loader] Error in " .. name .. ": " .. tostring(runErr))
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

-- ══════════════════════════════════════════════════════════════
-- PLAYER / CHARACTER EVENTS  (NN ASS SHI )
-- ══════════════════════════════════════════════════════════════
local function onNewChar(player, char)
    task.wait(0.5)
    if player == LocalPlayer then
        ctx.kb.lastVelocity = Vector3.zero
        ctx.aim.target      = nil
        return
    end
    if ctx.fpsState.greyplayers then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.BrickColor  = BrickColor.new("Medium stone grey")
                p.Material    = Enum.Material.SmoothPlastic
                p.Reflectance = 0
            end
            if p:IsA("Shirt") or p:IsA("Pants") or p:IsA("ShirtGraphic")
            or p:IsA("Accessory") or p:IsA("Hat") or p:IsA("Hair") then
                p:Destroy()
            end
        end
    end
    if ctx.esp.enabled then
        task.wait(0.2)
        ctx.createESPFor(player)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then task.spawn(onNewChar, p, p.Character) end
    p.CharacterAdded:Connect(function(c) task.spawn(onNewChar, p, c) end)
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c) task.spawn(onNewChar, p, c) end)
end)

Players.PlayerRemoving:Connect(function(p)
    ctx.removeESPFor(p)
    if ctx.aim.target == p then ctx.aim.target = nil end
end)

LocalPlayer.CharacterAdded:Connect(function()
    ctx.kb.lastVelocity = Vector3.zero
    ctx.aim.target      = nil
end)


ctx.entitylib.start()

-- ══════════════════════════════════════════════════════════════
-- KEYBINDS  (no skid)
-- ══════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then
        ctx.ka.enabled = not ctx.ka.enabled
        ctx.collectAndSave()
        ctx.Window:Notify({
            Title = "Kill Aura",
            Desc  = ctx.ka.enabled and "Kill Aura  ON  (Vape Engine)" or "Kill Aura  OFF",
            Time  = 2,
        })
    elseif input.KeyCode == Enum.KeyCode.R then
        ctx.aim.enabled = not ctx.aim.enabled
        if not ctx.aim.enabled then ctx.aim.target = nil end
        ctx.collectAndSave()
        ctx.Window:Notify({
            Title = "Aim Assist",
            Desc  = ctx.aim.enabled and "Aim Assist  ON" or "Aim Assist  OFF",
            Time  = 2,
        })
    end
end)

-- ══════════════════════════════════════════════════════════════
-- MAIN LOOPS — RENDERSTEPPED + HEARTBEAT
-- ══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    ctx.doAimAssist()
    ctx.updateESP()
    ctx.refreshESP(dt)

    ctx.fpsSamples[#ctx.fpsSamples + 1] = dt > 0 and 1 / dt or 60
    if #ctx.fpsSamples > 30 then tremove(ctx.fpsSamples, 1) end

    ctx.diagTimer += dt
    if ctx.diagTimer >= 1 then
        ctx.diagTimer = 0

        local sum = 0
        for _, v in ipairs(ctx.fpsSamples) do sum += v end
        local avgFps = mfloor(sum / #ctx.fpsSamples)

        ctx.updatePing()
        local pm  = mfloor(ctx.pingData.smooth)
        local pc  = pm < 50 and "LOW" or pm < 100 and "MID" or "HIGH"
        local ft  = avgFps >= 60 and "GREAT" or avgFps >= 30 and "OK" or "LOW"
        local kaS = ctx.ka.enabled  and "ON (" .. (ctx._getBedwarsReady() and "Vape" or "FS") .. ")" or "OFF"
        local aaS = ctx.aim.enabled and "ON" or "OFF"

        -- BUGFIX: wrapped in pcall — SetCode may not exist on all library versions
        pcall(function()
            ctx.diagBlock:SetCode(string.format(
                "FPS        : %d  [%s]\nPING       : %dms  [%s]\nKill Aura  : %s  |  Aim: %s",
                avgFps, ft, pm, pc, kaS, aaS
            ))
        end)
    end
end)

local gcTimer = 0
RunService.Heartbeat:Connect(function(dt)
    local root = getRoot()
    local hum  = getHumanoid()
    if root and hum and hum.Health > 0 and ctx.kb.enabled and ctx.kb.strength > 0 then
        -- BUGFIX: use AssemblyLinearVelocity (Velocity is deprecated)
        local cur = root.AssemblyLinearVelocity
        local delta = (cur - ctx.kb.lastVelocity).Magnitude
        if delta > 10 then
            local m = 1 - ctx.kb.strength
            local reduced = v3new(cur.X * m, cur.Y, cur.Z * m)
            pcall(function() root.AssemblyLinearVelocity = reduced end)
            ctx.kb.lastVelocity = reduced
        else
            ctx.kb.lastVelocity = cur
        end
    end

    gcTimer += dt
    if gcTimer >= 60 then
        gcTimer = 0
        collectgarbage()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- FINAL NOTIFICATIONS
-- ══════════════════════════════════════════════════════════════
ctx.Window:Notify({ Title = "WOLFVXPE REWRITE", Desc = "Loaded — Vape KA Engine | Q=KA  R=Aim  RightShift=Menu", Time = 5 })
print("[ WOLFVXPE REWRITE ] Loaded — pistademon | Vape KA Engine | Q=KA  R=Aim  RightShift=Menu")
