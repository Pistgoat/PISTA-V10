-- ══════════════════════════════════════════════════════════════
-- WOLFVXPE REWRITE  —  LOADER.LUA
--
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/Pistgoat/PISTA-V10/main/Loader.lua"
--   ))()
-- ══════════════════════════════════════════════════════════════

local REPO_BASE = "https://raw.githubusercontent.com/Pistgoat/PISTA-V10/main"

-- ══════════════════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════════════════
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService         = game:GetService("TweenService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local Lighting             = game:GetService("Lighting")
local Stats                = game:GetService("Stats")
local CoreGui              = game:GetService("CoreGui")
local UserInputService     = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

local tinsert, tremove, tclone = table.insert, table.remove, table.clone
local mfloor = math.floor
local v3new  = Vector3.new

-- ══════════════════════════════════════════════════════════════
-- CHARACTER HELPERS
-- ══════════════════════════════════════════════════════════════
local function getChar()     return LocalPlayer.Character end
local function getRoot()     local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() local c = getChar(); return c and c:FindFirstChild("Humanoid") end

-- ══════════════════════════════════════════════════════════════
-- ANTI-AFK
-- ══════════════════════════════════════════════════════════════
pcall(function()
    local VU = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        VU:Button2Down(Vector2.zero, Camera.CFrame)
        task.wait(1)
        VU:Button2Up(Vector2.zero, Camera.CFrame)
    end)
end)

-- ══════════════════════════════════════════════════════════════
-- TOGGLE NOTIFICATION
-- 100% self-contained — no UI library, no module dependencies.
-- Works even if every other module fails to load.
-- CoreGui parent (DisplayOrder 99999, IgnoreGuiInset) means it
-- renders on top of every game UI layer without exception.
-- Falls back to PlayerGui if CoreGui write is blocked.
-- ══════════════════════════════════════════════════════════════
local C = {
    BG       = Color3.fromRGB(8,   4,  18),
    BG_MID   = Color3.fromRGB(20,  8,  42),
    PRIMARY  = Color3.fromRGB(168, 85, 247),
    DEEP     = Color3.fromRGB(88,  28, 135),
    GLOW     = Color3.fromRGB(216, 180, 254),
    DIM      = Color3.fromRGB(140, 100, 200),
    GREEN    = Color3.fromRGB(134, 239, 172),
}

local function showToggleNotif(title, message, isOn)
    task.spawn(function()
        -- Find safest parent — CoreGui beats PlayerGui
        local guiParent = PlayerGui
        pcall(function()
            local probe = Instance.new("Folder")
            probe.Parent = CoreGui
            probe:Destroy()
            guiParent = CoreGui
        end)

        -- Unique name so multiple notifications stack without collision
        local uid = tostring(mfloor(tick() * 10000))

        local sg = Instance.new("ScreenGui")
        sg.Name           = "PISTA_Notif_" .. uid
        sg.ResetOnSpawn   = false
        sg.DisplayOrder   = 99999
        sg.IgnoreGuiInset = true   -- renders over ALL Bedwars UI
        sg.Parent         = guiParent

        local accent = isOn and C.GREEN or C.PRIMARY

        -- ── outer frame ───────────────────────────────────────
        local frame = Instance.new("Frame", sg)
        frame.Name                   = "Toast"
        frame.Size                   = UDim2.new(0, 320, 0, 58)
        frame.AnchorPoint            = Vector2.new(1, 1)
        frame.Position               = UDim2.new(1, -14, 1, 80) -- starts off-screen
        frame.BackgroundColor3       = C.BG
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel        = 0
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

        -- gradient background
        local grad = Instance.new("UIGradient", frame)
        grad.Color    = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.BG),
            ColorSequenceKeypoint.new(1, C.BG_MID),
        })
        grad.Rotation = 90

        -- border stroke
        local stroke = Instance.new("UIStroke", frame)
        stroke.Color        = accent
        stroke.Thickness    = 1.4
        stroke.Transparency = 0.18

        -- left accent bar
        local bar = Instance.new("Frame", frame)
        bar.Size             = UDim2.new(0, 3, 1, -14)
        bar.Position         = UDim2.new(0, 8, 0, 7)
        bar.BackgroundColor3 = accent
        bar.BorderSizePixel  = 0
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        -- title row
        local lblTitle = Instance.new("TextLabel", frame)
        lblTitle.Size                   = UDim2.new(1, -24, 0, 20)
        lblTitle.Position               = UDim2.new(0, 17, 0, 8)
        lblTitle.BackgroundTransparency = 1
        lblTitle.Text                   = title .. "   " .. (isOn and "[ ON ]" or "[ OFF ]")
        lblTitle.TextColor3             = isOn and C.GREEN or C.GLOW
        lblTitle.TextStrokeColor3       = C.DEEP
        lblTitle.TextStrokeTransparency = 0.45
        lblTitle.Font                   = Enum.Font.GothamBold
        lblTitle.TextSize               = 13
        lblTitle.TextXAlignment         = Enum.TextXAlignment.Left
        lblTitle.RichText               = false

        -- subtitle row
        local lblSub = Instance.new("TextLabel", frame)
        lblSub.Size                   = UDim2.new(1, -24, 0, 13)
        lblSub.Position               = UDim2.new(0, 17, 0, 32)
        lblSub.BackgroundTransparency = 1
        lblSub.Text                   = message
        lblSub.TextColor3             = C.DIM
        lblSub.Font                   = Enum.Font.Gotham
        lblSub.TextSize               = 11
        lblSub.TextXAlignment         = Enum.TextXAlignment.Left
        lblSub.RichText               = false

        -- ── slide IN from below ───────────────────────────────
        TweenService:Create(frame,
            TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(1, -14, 1, -14) }
        ):Play()

        task.wait(2.6)

        -- ── slide OUT + fade ──────────────────────────────────
        local outTI = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(frame, outTI,
            { Position = UDim2.new(1, -14, 1, 80), BackgroundTransparency = 1 }):Play()
        TweenService:Create(stroke,   outTI, { Transparency = 1 }):Play()
        TweenService:Create(bar,      outTI, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(lblTitle, outTI, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
        TweenService:Create(lblSub,   outTI, { TextTransparency = 1 }):Play()

        task.wait(0.32)
        pcall(function() sg:Destroy() end)
    end)
end

-- ══════════════════════════════════════════════════════════════
-- PARALLEL MODULE PREFETCH
-- All 9 files downloaded simultaneously — load time = slowest
-- single fetch, not the sum of all fetches.
-- ══════════════════════════════════════════════════════════════
local MODULE_NAMES = {
    "Module7_Profile.lua",
    "Module1_GUI.lua",
    "Module2_KillAura.lua",
    "Module3_KBReducer.lua",
    "Module4_AimAssist.lua",
    "Module5_FPSBoost.lua",
    "Module6_Credits.lua",
    "Module8_KitESP.lua",
    "Module9_Animations.lua",
}

local _cache = {}
local _ready = {}

for _, name in ipairs(MODULE_NAMES) do
    _ready[name] = false
    task.spawn(function()
        local ok, src = pcall(game.HttpGet, game, REPO_BASE .. "/" .. name, true)
        _cache[name] = ok and src or nil
        if not ok then
            warn("[WolfVXPE] Fetch failed: " .. name .. " — " .. tostring(src))
        end
        _ready[name] = true
    end)
end

for _, name in ipairs(MODULE_NAMES) do
    while not _ready[name] do task.wait() end
    if not _cache[name] then
        error("[WolfVXPE] Cannot boot — missing: " .. name)
    end
end

print("[WolfVXPE] All modules fetched. Booting...")

local function loadMod(filename, ctx)
    local fn, err = loadstring(_cache[filename])
    assert(fn, "[WolfVXPE] Compile error in " .. filename .. ":\n" .. tostring(err))
    local factory = fn()
    assert(type(factory) == "function",
        "[WolfVXPE] " .. filename .. " must return function(ctx)")
    return factory(ctx)
end

-- ══════════════════════════════════════════════════════════════
-- MODULE 7: PROFILE  (no deps — always first)
-- ══════════════════════════════════════════════════════════════
local Profile     = loadMod("Module7_Profile.lua", nil)
local P           = Profile.P
local saveProfile = Profile.saveProfile

-- ══════════════════════════════════════════════════════════════
-- STATE TABLES
-- ══════════════════════════════════════════════════════════════
local ka = {
    enabled      = P("ka_enabled",      false),
    range        = P("ka_range",        16),
    teamCheck    = P("ka_teamCheck",    true),
    delay        = P("ka_delay",        0.05),
    angleDeg     = P("ka_angle",        180),
    requireMouse = P("ka_requireMouse", false),
    limitToItems = P("ka_limitToItems", false),
    ignoreWalls  = P("ka_ignoreWalls",  false),
    multiHit     = P("ka_multiHit",     true),
    hitfix       = P("ka_hitfix",       true),
    hitboxes     = P("ka_hitboxes",     false),
    hitboxExpand = P("ka_hitboxExpand", 38),
    useSwingMode = P("ka_useSwingMode", true),
}

local kb = {
    enabled      = P("kb_enabled",  false),
    strength     = P("kb_strength", 0.25),
    lastVelocity = Vector3.zero,
}

local aim = {
    enabled   = P("aim_enabled",   false),
    teamCheck = P("aim_teamCheck", false),
    range     = P("aim_range",     60),
    smoothing = P("aim_smoothing", 0.08),
    target    = nil,
}

local esp = {
    enabled   = P("esp_enabled",   true),
    chams     = P("esp_chams",     true),
    names     = P("esp_names",     true),
    health    = P("esp_health",    true),
    distance  = P("esp_distance",  true),
    fillAlpha = P("esp_fillAlpha", 0.6),
    objects   = {},
}

local fpsState = {
    greysky     = P("fps_greysky",     false),
    greyplayers = P("fps_greyplayers", false),
    noshadows   = P("fps_noshadows",   false),
}

local kitESP = {
    enabled    = P("kitESP_enabled",    true),
    iconSize   = P("kitESP_iconSize",   32),
    colorTheme = P("kitESP_colorTheme", "Default"),
}

local anims = {
    enabled      = P("anim_enabled",      false),
    selectedPack = P("anim_selectedPack", "Vampire"),
    cycleMode    = P("anim_cycleMode",    false),
}

-- ══════════════════════════════════════════════════════════════
-- COLLECT + SAVE
-- ══════════════════════════════════════════════════════════════
local function collectAndSave()
    saveProfile({
        ka_enabled        = ka.enabled,
        ka_range          = ka.range,
        ka_teamCheck      = ka.teamCheck,
        ka_delay          = ka.delay,
        ka_angle          = ka.angleDeg,
        ka_requireMouse   = ka.requireMouse,
        ka_limitToItems   = ka.limitToItems,
        ka_ignoreWalls    = ka.ignoreWalls,
        ka_multiHit       = ka.multiHit,
        ka_hitfix         = ka.hitfix,
        ka_hitboxes       = ka.hitboxes,
        ka_hitboxExpand   = ka.hitboxExpand,
        ka_useSwingMode   = ka.useSwingMode,
        kb_enabled        = kb.enabled,
        kb_strength       = kb.strength,
        aim_enabled       = aim.enabled,
        aim_teamCheck     = aim.teamCheck,
        aim_range         = aim.range,
        aim_smoothing     = aim.smoothing,
        esp_enabled       = esp.enabled,
        esp_chams         = esp.chams,
        esp_names         = esp.names,
        esp_health        = esp.health,
        esp_distance      = esp.distance,
        esp_fillAlpha     = esp.fillAlpha,
        fps_greysky       = fpsState.greysky,
        fps_greyplayers   = fpsState.greyplayers,
        fps_noshadows     = fpsState.noshadows,
        kitESP_enabled    = kitESP.enabled,
        kitESP_iconSize   = kitESP.iconSize,
        kitESP_colorTheme = kitESP.colorTheme,
        anim_enabled      = anims.enabled,
        anim_selectedPack = anims.selectedPack,
        anim_cycleMode    = anims.cycleMode,
    })
end

-- Auto-save every 10s
task.spawn(function()
    while true do task.wait(10); collectAndSave() end
end)

-- ══════════════════════════════════════════════════════════════
-- SERVICES BUNDLE  (passed to modules)
-- ══════════════════════════════════════════════════════════════
local services = {
    Players           = Players,
    RunService        = RunService,
    UserInputService  = UserInputService,
    TweenService      = TweenService,
    ReplicatedStorage = ReplicatedStorage,
    Lighting          = Lighting,
    Stats             = Stats,
    CoreGui           = CoreGui,
    LocalPlayer       = LocalPlayer,
    PlayerGui         = PlayerGui,
    Camera            = Camera,
}

-- ══════════════════════════════════════════════════════════════
-- MODULE 1: GUI
-- ══════════════════════════════════════════════════════════════
local GUI = loadMod("Module1_GUI.lua", {
    services       = services,
    esp            = esp,
    collectAndSave = collectAndSave,
    mfloor         = mfloor,
})

local Window       = GUI.Window
local KATab        = GUI.KATab
local CombatTab    = GUI.CombatTab
local ESPTab       = GUI.ESPTab
local FPSTab       = GUI.FPSTab
local CredTab      = GUI.CredTab
local CLTab        = GUI.CLTab
local updateESP    = GUI.updateESP
local refreshESP   = GUI.refreshESP
local createESPFor = GUI.createESPFor
local removeESPFor = GUI.removeESPFor

-- ══════════════════════════════════════════════════════════════
-- MODULE 2: KILL AURA
-- ctx matches exactly what Module2_KillAura.lua expects:
--   ctx.services, ctx.ka, ctx.KATab, ctx.collectAndSave, ctx.mfloor
-- Returns: { entitylib, getBedwarsReady, setRayFilterDirty }
-- ══════════════════════════════════════════════════════════════
local KillAura = loadMod("Module2_KillAura.lua", {
    services       = services,
    ka             = ka,
    KATab          = KATab,
    collectAndSave = collectAndSave,
    mfloor         = mfloor,
})

local entitylib         = KillAura.entitylib
local getBedwarsReady   = KillAura.getBedwarsReady
local setRayFilterDirty = KillAura.setRayFilterDirty

-- ══════════════════════════════════════════════════════════════
-- MODULE 3: KB REDUCER
-- ══════════════════════════════════════════════════════════════
loadMod("Module3_KBReducer.lua", {
    CombatTab      = CombatTab,
    kb             = kb,
    collectAndSave = collectAndSave,
    mfloor         = mfloor,
})

-- ══════════════════════════════════════════════════════════════
-- MODULE 4: AIM ASSIST
-- Self-managed BindToRenderStep at Last+1 — runs after Bedwars
-- camera code every frame so the CFrame change sticks.
-- ══════════════════════════════════════════════════════════════
loadMod("Module4_AimAssist.lua", {
    CombatTab      = CombatTab,
    aim            = aim,
    collectAndSave = collectAndSave,
    services       = services,
    mfloor         = mfloor,
})

-- ══════════════════════════════════════════════════════════════
-- MODULE 5: FPS BOOST
-- ══════════════════════════════════════════════════════════════
local FPSBoost = loadMod("Module5_FPSBoost.lua", {
    FPSTab         = FPSTab,
    fpsState       = fpsState,
    collectAndSave = collectAndSave,
    Window         = Window,
    services       = services,
    mfloor         = mfloor,
    tremove        = tremove,
    tclone         = tclone,
})

local diagBlock  = FPSBoost.diagBlock
local updatePing = FPSBoost.updatePing
local pingData   = FPSBoost.pingData

-- ══════════════════════════════════════════════════════════════
-- MODULE 6: CREDITS
-- ══════════════════════════════════════════════════════════════
loadMod("Module6_Credits.lua", {
    CredTab        = CredTab,
    CLTab          = CLTab,
    Window         = Window,
    collectAndSave = collectAndSave,
})

-- ══════════════════════════════════════════════════════════════
-- MODULE 8: KIT ESP
-- ══════════════════════════════════════════════════════════════
local KitESP = loadMod("Module8_KitESP.lua", {
    ESPTab         = ESPTab,
    services       = services,
    kitESP         = kitESP,
    collectAndSave = collectAndSave,
    P              = P,
})

local kitTick = KitESP.kitTick

-- ══════════════════════════════════════════════════════════════
-- MODULE 9: ANIMATIONS
-- ══════════════════════════════════════════════════════════════
loadMod("Module9_Animations.lua", {
    Window         = Window,
    services       = services,
    anims          = anims,
    collectAndSave = collectAndSave,
    P              = P,
})

-- ══════════════════════════════════════════════════════════════
-- KEYBINDS — ContextActionService
--
-- WHY NOT UserInputService.InputBegan:
--   Bedwars sets gameProcessedEvent = true on nearly every key.
--   InputBegan's `gp` param becomes true and `if gp then return end`
--   silently swallows the press. ContextActionService fires BEFORE
--   the game's input pipeline — gp is irrelevant here.
--   Returning Pass means Bedwars still receives the key too.
-- ══════════════════════════════════════════════════════════════
ContextActionService:BindAction(
    "PISTA_ToggleKA",
    function(_, state, _)
        if state ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end
        ka.enabled = not ka.enabled
        collectAndSave()
        showToggleNotif(
            "Kill Aura",
            ka.enabled
                and "Vape Engine  •  " .. (getBedwarsReady() and "SwingMode" or "FireServer")
                or  "Disabled",
            ka.enabled
        )
        return Enum.ContextActionResult.Pass
    end,
    false,
    Enum.KeyCode.Q
)

ContextActionService:BindAction(
    "PISTA_ToggleAim",
    function(_, state, _)
        if state ~= Enum.UserInputState.Begin then
            return Enum.ContextActionResult.Pass
        end
        aim.enabled = not aim.enabled
        if not aim.enabled then aim.target = nil end
        collectAndSave()
        showToggleNotif(
            "Aim Assist",
            aim.enabled and "Locking to nearest enemy torso" or "Disabled",
            aim.enabled
        )
        return Enum.ContextActionResult.Pass
    end,
    false,
    Enum.KeyCode.R
)

-- ══════════════════════════════════════════════════════════════
-- RENDERSTEPPED — ESP + FPS diag
-- (aim assist is NOT called here — Module4 owns its own loop)
-- ══════════════════════════════════════════════════════════════
local fpsSamples = {}
local diagTimer  = 0

RunService.RenderStepped:Connect(function(dt)
    updateESP()
    refreshESP(dt)

    fpsSamples[#fpsSamples + 1] = dt > 0 and 1 / dt or 60
    if #fpsSamples > 30 then tremove(fpsSamples, 1) end

    diagTimer = diagTimer + dt
    if diagTimer >= 1 then
        diagTimer = 0
        local sum = 0
        for _, v in ipairs(fpsSamples) do sum = sum + v end
        local avgFps = mfloor(sum / #fpsSamples)
        updatePing()
        local pm  = mfloor(pingData.smooth)
        local pc  = pm < 50 and "LOW" or pm < 100 and "MID" or "HIGH"
        local ft  = avgFps >= 60 and "GREAT" or avgFps >= 30 and "OK" or "LOW"
        local kaS = ka.enabled  and "ON (" .. (getBedwarsReady() and "Vape" or "FS") .. ")" or "OFF"
        local aaS = aim.enabled and "ON" or "OFF"
        pcall(function()
            diagBlock:SetCode(string.format(
                "FPS        : %d  [%s]\nPING       : %dms  [%s]\nKill Aura  : %s  |  Aim: %s",
                avgFps, ft, pm, pc, kaS, aaS
            ))
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════
-- HEARTBEAT — KB Reducer + Kit ESP tick + GC
-- ══════════════════════════════════════════════════════════════
local gcTimer = 0

RunService.Heartbeat:Connect(function(dt)
    -- KB Reducer
    local root = getRoot()
    local hum  = getHumanoid()
    if root and hum and hum.Health > 0 and kb.enabled and kb.strength > 0 then
        local cur   = root.AssemblyLinearVelocity
        local delta = (cur - kb.lastVelocity).Magnitude
        if delta > 10 then
            local m       = 1 - kb.strength
            local reduced = v3new(cur.X * m, cur.Y, cur.Z * m)
            pcall(function() root.AssemblyLinearVelocity = reduced end)
            kb.lastVelocity = reduced
        else
            kb.lastVelocity = cur
        end
    end

    -- Kit ESP 30s prune tick
    if kitTick then kitTick(dt) end

    -- GC every 60s
    gcTimer = gcTimer + dt
    if gcTimer >= 60 then gcTimer = 0; collectgarbage() end
end)

-- ══════════════════════════════════════════════════════════════
-- PLAYER / CHARACTER EVENTS
-- ══════════════════════════════════════════════════════════════
local function onNewChar(player, char)
    task.wait(0.5)
    if player == LocalPlayer then
        kb.lastVelocity = Vector3.zero
        aim.target      = nil
        return
    end
    if fpsState.greyplayers then
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
    if esp.enabled then
        task.wait(0.2)
        createESPFor(player)
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
    removeESPFor(p)
    if aim.target == p then aim.target = nil end
end)

LocalPlayer.CharacterAdded:Connect(function()
    kb.lastVelocity = Vector3.zero
    aim.target      = nil
    setRayFilterDirty(true)
end)

-- ══════════════════════════════════════════════════════════════
-- START ENTITY LIB  (after all hooks are wired)
-- ══════════════════════════════════════════════════════════════
entitylib.start()

-- ══════════════════════════════════════════════════════════════
-- DONE — show startup notification
-- ══════════════════════════════════════════════════════════════
pcall(function()
    Window:Notify({
        Title = "WOLFVXPE REWRITE",
        Desc  = "Ready — Q = Kill Aura  •  R = Aim Assist  •  RightShift = Menu",
        Time  = 5,
    })
end)

-- Also show our own notif so it appears even if library Notify fails
showToggleNotif("WOLFVXPE REWRITE", "Q = KA   R = Aim   RShift = Menu", true)

print("[ WOLFVXPE REWRITE ] Loaded — Q=KA  R=Aim  RightShift=Menu")
