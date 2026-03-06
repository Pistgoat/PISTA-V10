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
-- CUSTOM NOTIFICATION SYSTEM  —  zero dependency on any UI lib
-- Queued slide-in toasts built entirely with TweenService + CoreGui.
-- Works from the moment the Loader runs — no GUI lib needed.
-- ══════════════════════════════════════════════════════════════
local _nQueue = {}
local _nBusy  = false

local N_BG     = Color3.fromRGB(4,   12,  8)
local N_BG_MID = Color3.fromRGB(8,   24,  14)
local N_GREEN  = Color3.fromRGB(34,  197, 94)
local N_GLOW   = Color3.fromRGB(187, 247, 208)
local N_DIM    = Color3.fromRGB(74,  222, 128)
local N_DEEP   = Color3.fromRGB(20,  83,  45)

local function notify(title, body)
    table.insert(_nQueue, { title = tostring(title or ""), body = tostring(body or "") })
    if _nBusy then return end
    _nBusy = true
    task.spawn(function()
        while #_nQueue > 0 do
            local n = table.remove(_nQueue, 1)

            local nGui = Instance.new("ScreenGui")
            nGui.Name           = "WolfVXPE_Notify"
            nGui.ResetOnSpawn   = false
            nGui.DisplayOrder   = 9997
            nGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            nGui.Parent         = CoreGui

            local frame = Instance.new("Frame", nGui)
            frame.Size                   = UDim2.new(0, 300, 0, 58)
            frame.AnchorPoint            = Vector2.new(1, 0)
            frame.Position               = UDim2.new(1, 320, 0, 16)
            frame.BackgroundColor3       = N_BG
            frame.BackgroundTransparency = 0.05
            frame.BorderSizePixel        = 0
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = N_GREEN; stroke.Thickness = 1.2; stroke.Transparency = 0.2

            local grad = Instance.new("UIGradient", frame)
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, N_BG),
                ColorSequenceKeypoint.new(1, N_BG_MID),
            })
            grad.Rotation = 90

            local accent = Instance.new("Frame", frame)
            accent.Size             = UDim2.new(0, 3, 1, -14)
            accent.Position         = UDim2.new(0, 7, 0, 7)
            accent.BackgroundColor3 = N_GREEN
            accent.BorderSizePixel  = 0
            Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)
            local aGrad = Instance.new("UIGradient", accent)
            aGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, N_GREEN),
                ColorSequenceKeypoint.new(1, N_DEEP),
            })
            aGrad.Rotation = 90

            local tTitle = Instance.new("TextLabel", frame)
            tTitle.Size                   = UDim2.new(1, -20, 0, 22)
            tTitle.Position               = UDim2.new(0, 16, 0, 5)
            tTitle.BackgroundTransparency = 1
            tTitle.Text                   = n.title
            tTitle.TextColor3             = N_GLOW
            tTitle.TextStrokeColor3       = N_DEEP
            tTitle.TextStrokeTransparency = 0.5
            tTitle.Font                   = Enum.Font.GothamBold
            tTitle.TextSize               = 12
            tTitle.TextXAlignment         = Enum.TextXAlignment.Left
            tTitle.ZIndex                 = 3

            local tBody = Instance.new("TextLabel", frame)
            tBody.Size                   = UDim2.new(1, -20, 0, 18)
            tBody.Position               = UDim2.new(0, 16, 0, 30)
            tBody.BackgroundTransparency = 1
            tBody.Text                   = n.body
            tBody.TextColor3             = N_DIM
            tBody.Font                   = Enum.Font.Gotham
            tBody.TextSize               = 10
            tBody.TextXAlignment         = Enum.TextXAlignment.Left
            tBody.TextTruncate           = Enum.TextTruncate.AtEnd
            tBody.ZIndex                 = 3

            -- Slide in from right
            TweenService:Create(frame,
                TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Position = UDim2.new(1, -10, 0, 16) }):Play()

            task.wait(3.0)

            -- Slide out to right
            local fo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            TweenService:Create(frame,  fo, { Position = UDim2.new(1, 320, 0, 16) }):Play()
            TweenService:Create(tTitle, fo, { TextTransparency = 1 }):Play()
            TweenService:Create(tBody,  fo, { TextTransparency = 1 }):Play()
            task.wait(0.28)
            pcall(function() nGui:Destroy() end)
            task.wait(0.08)
        end
        _nBusy = false
    end)
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
        if not ctx.aim.enabled then ctx.aim.target = nil end
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
notify("WOLFVXPE REWRITE", "Loaded — Vape KA Engine | Q=KA  R=Aim  RightShift=Menu")
print("[ WOLFVXPE REWRITE ] Loaded — pistademon | Vape KA Engine | Q=KA  R=Aim  RightShift=Menu")
