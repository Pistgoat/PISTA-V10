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


execModule("Module5_FPSBoost.lua")

-- 7. Credits + Changelog
execModule("Module6_Credits.lua")

-- 8. Kit ESP — appends to ctx.ESPTab (needs Module5)
execModule("Module8_KitESP.lua")

-- 9. Animations tab
execModule("Module9_Animations.lua")


local _nGui = Instance.new("ScreenGui")
_nGui.Name           = "WolfVXPE_Notify"
_nGui.ResetOnSpawn   = false
_nGui.DisplayOrder   = 99999
_nGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
_nGui.Parent         = CoreGui

-- Green palette (matches splash)
local NC_BG      = Color3.fromRGB(4,   12,  8)
local NC_BG_MID  = Color3.fromRGB(8,   24,  14)
local NC_PRIMARY = Color3.fromRGB(34,  197, 94)
local NC_GLOW    = Color3.fromRGB(187, 247, 208)
local NC_DIM     = Color3.fromRGB(74,  222, 128)
local NC_MUTED   = Color3.fromRGB(52,  120, 80)
local NC_DEEP    = Color3.fromRGB(20,  83,  45)

local _nQueue   = {}
local _nBusy    = false

local function _showNextNotify()
    if _nBusy or #_nQueue == 0 then return end
    _nBusy = true

    local item     = table.remove(_nQueue, 1)
    local title    = item.title    or ""
    local body     = item.body     or ""
    local duration = item.duration or 3

    -- Card frame
    local card = Instance.new("Frame", _nGui)
    card.Name                   = "NotifyCard"
    card.Size                   = UDim2.new(0, 340, 0, 70)
    card.AnchorPoint            = Vector2.new(0.5, 1)
    card.Position               = UDim2.new(0.5, 0, 1, 90)   -- off-screen
    card.BackgroundColor3       = NC_BG
    card.BackgroundTransparency = 0.04
    card.BorderSizePixel        = 0
    card.ClipsDescendants       = false

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

    -- Border stroke
    local stroke = Instance.new("UIStroke", card)
    stroke.Color        = NC_PRIMARY
    stroke.Thickness    = 1.4
    stroke.Transparency = 0.2

    -- Background gradient
    local grad = Instance.new("UIGradient", card)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, NC_BG),
        ColorSequenceKeypoint.new(1, NC_BG_MID),
    })
    grad.Rotation = 90

    -- Left accent bar
    local accent = Instance.new("Frame", card)
    accent.Size             = UDim2.new(0, 3, 1, -16)
    accent.Position         = UDim2.new(0, 8, 0, 8)
    accent.BackgroundColor3 = NC_PRIMARY
    accent.BorderSizePixel  = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)
    local accentGrad = Instance.new("UIGradient", accent)
    accentGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, NC_PRIMARY),
        ColorSequenceKeypoint.new(1, NC_DEEP),
    })
    accentGrad.Rotation = 90

    -- Title label
    local titleLbl = Instance.new("TextLabel", card)
    titleLbl.Size                   = UDim2.new(1, -26, 0, 22)
    titleLbl.Position               = UDim2.new(0, 18, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = title
    titleLbl.TextColor3             = NC_GLOW
    titleLbl.TextStrokeColor3       = NC_DEEP
    titleLbl.TextStrokeTransparency = 0.5
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextSize               = 13
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.ZIndex                 = 3

    -- Body label
    local bodyLbl = Instance.new("TextLabel", card)
    bodyLbl.Size                   = UDim2.new(1, -26, 0, 14)
    bodyLbl.Position               = UDim2.new(0, 18, 0, 31)
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Text                   = body
    bodyLbl.TextColor3             = NC_DIM
    bodyLbl.Font                   = Enum.Font.Gotham
    bodyLbl.TextSize               = 11
    bodyLbl.TextXAlignment         = Enum.TextXAlignment.Left
    bodyLbl.ZIndex                 = 3

    -- Progress bar background
    local barBg = Instance.new("Frame", card)
    barBg.Size             = UDim2.new(1, -16, 0, 3)
    barBg.Position         = UDim2.new(0, 8, 1, -7)
    barBg.BackgroundColor3 = Color3.fromRGB(8, 28, 14)
    barBg.BorderSizePixel  = 0
    barBg.ClipsDescendants = true
    barBg.ZIndex           = 3
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)

    local bar = Instance.new("Frame", barBg)
    bar.Size             = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = NC_PRIMARY
    bar.BorderSizePixel  = 0
    bar.ZIndex           = 4
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local barGrad = Instance.new("UIGradient", bar)
    barGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    NC_DEEP),
        ColorSequenceKeypoint.new(0.6,  NC_PRIMARY),
        ColorSequenceKeypoint.new(1,    NC_GLOW),
    })

    task.spawn(function()
        -- SLIDE UP
        TweenService:Create(card,
            TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 1, -16),
            }):Play()
        task.wait(0.45)

        -- PROGRESS BAR depletes over duration
        TweenService:Create(bar,
            TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                Size = UDim2.new(0, 0, 1, 0),
            }):Play()

        task.wait(duration)

        -- FADE OUT + SLIDE DOWN
        local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(card,     fadeInfo, { Position = UDim2.new(0.5, 0, 1, 90), BackgroundTransparency = 1 }):Play()
        TweenService:Create(titleLbl, fadeInfo, { TextTransparency = 1 }):Play()
        TweenService:Create(bodyLbl,  fadeInfo, { TextTransparency = 1 }):Play()
        TweenService:Create(accent,   fadeInfo, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(barBg,    fadeInfo, { BackgroundTransparency = 1 }):Play()
        task.wait(0.38)

        pcall(function() card:Destroy() end)
        _nBusy = false
        _showNextNotify()   -- show next queued notification
    end)
end

local function wolfNotify(title, body, duration)
    table.insert(_nQueue, { title = title, body = body, duration = duration or 3 })
    _showNextNotify()
end

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


UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then
        ctx.ka.enabled = not ctx.ka.enabled
        ctx.collectAndSave()
        if ctx.ka.enabled then
            wolfNotify("⚔  Kill Aura  ON",  "Vape Engine active — targeting enemies", 2.5)
        else
            wolfNotify("✗  Kill Aura  OFF", "Kill Aura disabled", 2.5)
        end
    elseif input.KeyCode == Enum.KeyCode.R then
        ctx.aim.enabled = not ctx.aim.enabled
        if not ctx.aim.enabled then ctx.aim.target = nil end
        ctx.collectAndSave()
        if ctx.aim.enabled then
            wolfNotify("🎯  Aim Assist  ON",  "Locking onto nearest enemy torso", 2.5)
        else
            wolfNotify("✗  Aim Assist  OFF", "Aim Assist disabled", 2.5)
        end
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


wolfNotify("✓  WOLFVXPE LOADED", "Q = Kill Aura  •  R = Aim  •  RShift = Menu", 5)
print("[ WOLFVXPE REWRITE ] Loaded — pistademon | Vape KA Engine | Q=KA  R=Aim  RightShift=Menu")
