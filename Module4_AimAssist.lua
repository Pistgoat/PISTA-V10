-- ══════════════════════════════════════════════════════════════
-- MODULE 4 : AIM ASSIST
--   • Self-contained RenderStepped — does NOT rely on Loader calling doAimAssist
--   • workspace.CurrentCamera read LIVE every frame (never stale)
--   • Targets HumanoidRootPart → UpperTorso → Torso (never head)
--   • Smooth lerp or instant snap
--   • Own tab in menu
-- ══════════════════════════════════════════════════════════════
return function(ctx)
    local Players        = ctx.Players
    local RunService     = ctx.RunService
    local mfloor         = ctx.mfloor
    local LocalPlayer    = ctx.LocalPlayer
    local getRoot        = ctx.getRoot
    local aim            = ctx.aim
    local collectAndSave = ctx.collectAndSave
    local Window         = ctx.Window

    -- ══════════════════════════════════════════════════════════════
    -- TAB + CONTROLS
    -- ══════════════════════════════════════════════════════════════
    local AimTab = Window:Tab({ Title = "Aim Assist", Icon = "crosshair" })

    AimTab:Section({ Title = "Aim Assist  [R = toggle on/off]" })

    AimTab:Toggle({
        Title    = "Enable Aim Assist",
        Desc     = "Locks camera onto nearest enemy torso. Press R to toggle.",
        Value    = aim.enabled,
        Callback = function(v)
            aim.enabled = v
            if not v then aim.target = nil end
            collectAndSave()
        end,
    })

    AimTab:Toggle({
        Title    = "Team Check",
        Desc     = "Only target enemies — skip teammates.",
        Value    = aim.teamCheck,
        Callback = function(v) aim.teamCheck = v; collectAndSave() end,
    })

    AimTab:Slider({
        Title    = "Aim Range (studs)",
        Desc     = "Max distance aim assist will reach.",
        Min = 10, Max = 500, Rounding = 0,
        Value    = aim.range,
        Callback = function(v) aim.range = v; collectAndSave() end,
    })

    AimTab:Slider({
        Title    = "Camera Smoothing",
        Desc     = "0 = instant snap.  100 = very slow follow.",
        Min = 0, Max = 100, Rounding = 0,
        Value    = mfloor(aim.smoothing * 100),
        Callback = function(v) aim.smoothing = v / 100; collectAndSave() end,
    })

    -- ══════════════════════════════════════════════════════════════
    -- LOGIC
    -- ══════════════════════════════════════════════════════════════
    local function isEnemy(p)
        if not aim.teamCheck then return true end
        local lTeam = LocalPlayer.Team
        if not lTeam then return true end
        if not p.Team then return true end
        return p.Team ~= lTeam
    end

    local function getAimTarget()
        local root = getRoot()
        if not root then return nil end
        local bestDist = aim.range
        local best     = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if not isEnemy(p) then continue end
            local char  = p.Character
            local hum   = char and char:FindFirstChild("Humanoid")
            local pRoot = char and char:FindFirstChild("HumanoidRootPart")
            if not char or not hum or hum.Health <= 0 or not pRoot then continue end
            local d = (root.Position - pRoot.Position).Magnitude
            if d < bestDist then bestDist = d; best = p end
        end
        return best
    end

    -- ── SELF-CONTAINED RENDERSTEPPED ─────────────────────────────
    -- Runs every frame on its own — does NOT depend on Loader calling
    -- ctx.doAimAssist(). This way the aim works even if ctx hookup fails.
    RunService.RenderStepped:Connect(function()
        if not aim.enabled then
            aim.target = nil
            return
        end

        -- Validate current target still alive
        if aim.target then
            local char = aim.target.Character
            local hum  = char and char:FindFirstChild("Humanoid")
            if not aim.target.Parent or not char or not hum or hum.Health <= 0 then
                aim.target = nil
            end
        end

        -- Find new target
        if not aim.target then aim.target = getAimTarget() end
        if not aim.target then return end

        local char = aim.target.Character
        if not char then aim.target = nil; return end

        local bone = char:FindFirstChild("HumanoidRootPart")
                  or char:FindFirstChild("UpperTorso")
                  or char:FindFirstChild("Torso")
        if not bone then return end

        -- LIVE camera — never use ctx.Camera (stale snapshot)
        local cam = workspace.CurrentCamera
        if not cam then return end

        local tgt = CFrame.new(cam.CFrame.Position, bone.Position)
        if aim.smoothing < 0.01 then
            cam.CFrame = tgt
        else
            cam.CFrame = cam.CFrame:Lerp(tgt, 1 - aim.smoothing)
        end
    end)

    -- ctx.doAimAssist = no-op stub so Loader's call doesn't error
    ctx.doAimAssist  = function() end
    ctx.getAimTarget = getAimTarget
    ctx.AimTab       = AimTab
end
