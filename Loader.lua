--[[
    ██╗    ██╗ ██████╗ ██╗     ███████╗    ██╗   ██╗██╗  ██╗██████╗ ███████╗
    ██║    ██║██╔═══██╗██║     ██╔════╝    ██║   ██║╚██╗██╔╝██╔══██╗██╔════╝
    ██║ █╗ ██║██║   ██║██║     █████╗      ██║   ██║ ╚███╔╝ ██████╔╝█████╗
    ██║███╗██║██║   ██║██║     ██╔══╝      ╚██╗ ██╔╝ ██╔██╗ ██╔═══╝ ██╔══╝
    ╚███╔███╔╝╚██████╔╝███████╗██║          ╚████╔╝ ██╔╝ ██╗██║     ███████╗
     ╚══╝╚══╝  ╚═════╝ ╚══════╝╚═╝           ╚═══╝  ╚═╝  ╚═╝╚═╝     ╚══════╝

    WOLFVXPE  (REWRITE)  —  Ash-Libs Edition
    Originally by pistademon | Rewritten & Enhanced Edition
    Vape Kill Aura Engine  •  KB Reducer  •  Aim Assist  •  ESP  •  FPS

    MODULAR LOADER — loads 9 modules in dependency order:
      Module7_Profile.lua     → Profile save/load, state tables, auto-save
      Module1_GUI.lua         → Splash, Colors, Ash-Libs window, Toast
      Module2_KillAura.lua    → Vape EntityLib, Bedwars, KA Engine, KATab
      Module3_KBReducer.lua   → CombatTab creation, KB Reducer section
      Module4_AimAssist.lua   → Aim Assist logic + AA section on CombatTab
      Module5_FPSBoost.lua    → ESP logic/tab, FPS tab, Ping stabilizer
      Module6_Credits.lua     → Credits tab, Changelog tab
      Module8_KitESP.lua      → Kit ESP section appended to ESPTab
      Module9_Animations.lua  → Animations tab
]]

-- ══════════════════════════════════════════════════════════════
-- SERVICES  (cached once — fastest possible lookup)
-- ══════════════════════════════════════════════════════════════
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

-- Fast local refs to built-ins (micro-optimise hot paths)
local tinsert, tremove, tclone = table.insert, table.remove, table.clone
local mfloor, mcos, mrad, mabs = math.floor, math.cos, math.rad, math.abs
local v3new, cf3new            = Vector3.new, CFrame.new

-- ── cloneref safety wrapper ───────────────────────────────────
local cloneref = cloneref or function(obj) return obj end

-- ── Anti-AFK ─────────────────────────────────────────────────
local ok, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
if ok and VirtualUser then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.zero, Camera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.zero, Camera.CFrame)
    end)
end

-- ══════════════════════════════════════════════════════════════
-- CHARACTER HELPERS
-- ══════════════════════════════════════════════════════════════
local function getChar()     return LocalPlayer.Character end
local function getRoot()     local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() local c=getChar(); return c and c:FindFirstChild("Humanoid") end

-- ══════════════════════════════════════════════════════════════
-- SHARED CONTEXT TABLE
-- ══════════════════════════════════════════════════════════════
local ctx = {
    -- Services
    Players           = Players,
    RunService        = RunService,
    UserInputService  = UserInputService,
    TweenService      = TweenService,
    ReplicatedStorage = ReplicatedStorage,
    Lighting          = Lighting,
    Stats             = Stats,
    CoreGui           = CoreGui,
    -- Player refs
    LocalPlayer = LocalPlayer,
    PlayerGui   = PlayerGui,
    Mouse       = Mouse,
    Camera      = Camera,
    -- Fast refs
    tinsert  = tinsert,
    tremove  = tremove,
    tclone   = tclone,
    mfloor   = mfloor,
    mcos     = mcos,
    mrad     = mrad,
    mabs     = mabs,
    v3new    = v3new,
    cf3new   = cf3new,
    cloneref = cloneref,
    -- Character helpers
    getChar     = getChar,
    getRoot     = getRoot,
    getHumanoid = getHumanoid,
}

-- ══════════════════════════════════════════════════════════════
-- GITHUB RAW BASE URL
-- ══════════════════════════════════════════════════════════════
local REPO = "https://raw.githubusercontent.com/Pistgoat/PISTA-V10/main/"

-- ══════════════════════════════════════════════════════════════
-- MODULE LOADER HELPER
-- ══════════════════════════════════════════════════════════════
local function execModule(name)
    local source
    local ok1 = pcall(function()
        source = game:HttpGet(REPO .. name, true)
    end)
    if not ok1 or not source or source == "" then
        warn("[WolfVXPE Loader] Failed to fetch " .. name)
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

-- ══════════════════════════════════════════════════════════════
-- LOAD ALL 9 MODULES  (strict dependency order)
-- ══════════════════════════════════════════════════════════════
-- 1. Profile first — provides ctx.ka/kb/aim/esp/fpsState/collectAndSave
execModule("Module7_Profile.lua")

-- 2. GUI — provides ctx.GUI, ctx.Window (Ash-Libs wrapper), colors
execModule("Module1_GUI.lua")

-- 3. Kill Aura — provides ctx.entitylib, ctx.bedwars
execModule("Module2_KillAura.lua")

-- 4. KB Reducer — creates CombatTab, provides ctx.CombatTab
execModule("Module3_KBReducer.lua")

-- 5. Aim Assist — appends to CombatTab, provides ctx.doAimAssist
execModule("Module4_AimAssist.lua")

-- 6. FPS + ESP — provides ctx.ESPTab, ctx.diagBlock, ctx.updateESP,
--    ctx.refreshESP, ctx.createESPFor, ctx.removeESPFor,
--    ctx.pingData, ctx.updatePing, ctx.fpsSamples, ctx.diagTimer
execModule("Module5_FPSBoost.lua")

-- 7. Credits + Changelog
execModule("Module6_Credits.lua")

-- 8. Kit ESP — appends to ctx.ESPTab (needs Module5)
execModule("Module8_KitESP.lua")

-- 9. Animations tab
execModule("Module9_Animations.lua")

-- ══════════════════════════════════════════════════════════════
-- NOTIFY HELPER  —  Ash-Libs: GUI:CreateNotify
-- ══════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════
-- STANDALONE NOTIFICATION SYSTEM
-- Lives entirely in the Loader — zero module dependency.
-- Works from the first line. Never fails silently.
-- ══════════════════════════════════════════════════════════════
local _notifGui = Instance.new("ScreenGui")
_notifGui.Name           = "WolfVXPE_Notifs"
_notifGui.ResetOnSpawn   = false
_notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
_notifGui.DisplayOrder   = 10000
_notifGui.Parent         = CoreGui

local _notifQueue   = {}
local _notifBusy    = false

local _NP  = Color3.fromRGB(138, 43,  226)
local _ND  = Color3.fromRGB(60,  10,  100)
local _NG  = Color3.fromRGB(220, 180, 255)
local _NDm = Color3.fromRGB(180, 100, 255)
local _NB  = Color3.fromRGB(8,   4,   14)
local _NBM = Color3.fromRGB(16,  8,   28)

local function _showNotif(title, body, duration)
    duration = duration or 2.5
    local card = Instance.new("Frame", _notifGui)
    card.Size             = UDim2.new(0, 320, 0, 60)
    card.AnchorPoint      = Vector2.new(1, 1)
    card.Position         = UDim2.new(1, -14, 1, 80)
    card.BackgroundColor3 = _NB
    card.BorderSizePixel  = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 9)
    local sk = Instance.new("UIStroke", card)
    sk.Color = _NP; sk.Thickness = 1.2; sk.Transparency = 0.15
    local bg = Instance.new("UIGradient", card)
    bg.Color    = ColorSequence.new({ ColorSequenceKeypoint.new(0,_NB), ColorSequenceKeypoint.new(1,_NBM) })
    bg.Rotation = 90
    local accent = Instance.new("Frame", card)
    accent.Size = UDim2.new(0,3,1,-12); accent.Position = UDim2.new(0,6,0,6)
    accent.BackgroundColor3 = _NP; accent.BorderSizePixel = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1,0)
    local tl = Instance.new("TextLabel", card)
    tl.Size = UDim2.new(1,-20,0,20); tl.Position = UDim2.new(0,15,0,7)
    tl.BackgroundTransparency = 1; tl.Text = title
    tl.TextColor3 = _NG; tl.Font = Enum.Font.GothamBold
    tl.TextSize = 13; tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.TextTransparency = 0
    local bl = Instance.new("TextLabel", card)
    bl.Size = UDim2.new(1,-20,0,13); bl.Position = UDim2.new(0,15,0,31)
    bl.BackgroundTransparency = 1; bl.Text = body
    bl.TextColor3 = _NDm; bl.Font = Enum.Font.Gotham
    bl.TextSize = 11; bl.TextXAlignment = Enum.TextXAlignment.Left
    bl.TextTransparency = 0
    local prog = Instance.new("Frame", card)
    prog.Size = UDim2.new(1,0,0,2); prog.Position = UDim2.new(0,0,1,-2)
    prog.BackgroundColor3 = _NP; prog.BorderSizePixel = 0
    TweenService:Create(card,
        TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(1,-14,1,-14) }):Play()
    TweenService:Create(prog,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0,0,0,2) }):Play()
    task.wait(duration)
    local fo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(card, fo, { Position = UDim2.new(1,-14,1,80), BackgroundTransparency=1 }):Play()
    TweenService:Create(tl,   fo, { TextTransparency = 1 }):Play()
    TweenService:Create(bl,   fo, { TextTransparency = 1 }):Play()
    task.wait(0.27)
    pcall(function() card:Destroy() end)
end

local function _runQueue()
    if _notifBusy then return end
    _notifBusy = true
    task.spawn(function()
        while #_notifQueue > 0 do
            local item = table.remove(_notifQueue, 1)
            _showNotif(item.t, item.b, item.d)
            task.wait(0.08)
        end
        _notifBusy = false
    end)
end

local function notify(title, body, duration)
    table.insert(_notifQueue, { t = title or "", b = body or "", d = duration or 2.5 })
    _runQueue()
end
-- Also push onto ctx so modules can call ctx.notify(...)
ctx.notify = notify

-- ══════════════════════════════════════════════════════════════
-- PLAYER / CHARACTER EVENTS
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

-- ══════════════════════════════════════════════════════════════
-- START ENTITY LIB  (Vape — after all connections set up)
-- ══════════════════════════════════════════════════════════════
ctx.entitylib.start()

-- ══════════════════════════════════════════════════════════════
-- KEYBINDS  —  Q = Kill Aura  •  R = Aim Assist
-- ══════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then
        ctx.ka.enabled = not ctx.ka.enabled
        ctx.collectAndSave()
        notify("Kill Aura",
            ctx.ka.enabled and "Kill Aura  ON  (Vape Engine)" or "Kill Aura  OFF")
    elseif input.KeyCode == Enum.KeyCode.R then
        ctx.aim.enabled = not ctx.aim.enabled
        if not ctx.aim.enabled then
            ctx.aim.target = nil
            pcall(function() ctx.onAimToggle() end)
        end
        ctx.collectAndSave()
        notify("Aim Assist",
            ctx.aim.enabled and "Aim Assist  ON" or "Aim Assist  OFF")
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

    ctx.diagTimer = ctx.diagTimer + dt
    if ctx.diagTimer >= 1 then
        ctx.diagTimer = 0

        local sum = 0
        for _, v in ipairs(ctx.fpsSamples) do sum = sum + v end
        local avgFps = mfloor(sum / #ctx.fpsSamples)

        ctx.updatePing()
        local pm  = mfloor(ctx.pingData.smooth)
        local pc  = pm < 50 and "LOW" or pm < 100 and "MID" or "HIGH"
        local ft  = avgFps >= 60 and "GREAT" or avgFps >= 30 and "OK" or "LOW"
        local kaS = ctx.ka.enabled
                    and "ON (" .. (ctx._getBedwarsReady() and "Vape" or "FS") .. ")"
                    or  "OFF"
        local aaS = ctx.aim.enabled and "ON" or "OFF"

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
        local cur   = root.AssemblyLinearVelocity
        local delta = (cur - ctx.kb.lastVelocity).Magnitude
        if delta > 10 then
            local m       = 1 - ctx.kb.strength
            local reduced = v3new(cur.X * m, cur.Y, cur.Z * m)
            pcall(function() root.AssemblyLinearVelocity = reduced end)
            ctx.kb.lastVelocity = reduced
        else
            ctx.kb.lastVelocity = cur
        end
    end

    gcTimer = gcTimer + dt
    if gcTimer >= 60 then
        gcTimer = 0
        collectgarbage()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- FINAL NOTIFICATION
-- ══════════════════════════════════════════════════════════════
task.wait(0.5)  -- let GUI settle first
notify("WOLFVXPE REWRITE", "Loaded  |  Q = Kill Aura  •  R = Aim  •  RShift = Menu", 4)
print("[ WOLFVXPE REWRITE ] Loaded — pistademon | Vape KA Engine | Q=KA  R=Aim  RightShift=Menu")
