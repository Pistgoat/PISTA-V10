-- ══════════════════════════════════════════════════════════════
-- MODULE 6: CREDITS  (Module6_Credits.lua)
-- Credits tab and full Changelog tab content.
-- ctx keys: CredTab, CLTab, Window, collectAndSave
-- ══════════════════════════════════════════════════════════════

return function(ctx)

    local CredTab        = ctx.CredTab
    local CLTab          = ctx.CLTab
    local Window         = ctx.Window
    local collectAndSave = ctx.collectAndSave

    -- ══════════════════════════════════════════════════════════
    -- TAB: CREDITS
    -- ══════════════════════════════════════════════════════════
    CredTab:Section({ Title = "WOLFVXPE — REWRITE" })
    CredTab:Code({
        Title = "About",
        Code  = [[-- WOLFVXPE (REWRITE)
-- Originally by : pistademon  (Discord)
-- Rewritten & Enhanced Edition
--
-- Kill Aura  — Vape engine: swingSwordAtMouse + HitFix + HitBoxes
-- KB Reducer — knockback damping
-- Aim Assist — smooth camera lock  [R]  (torso-only)
-- ESP        — highlight hitbox + name/HP/distance
-- Kit ESP    — map item icons (iron, bee, orbs, kits)
-- FPS Boost  — sky / players / nuclear / fullbright
-- Animations — 5 packs + cycle mix mode
-- Profiles   — versioned settings auto-saved & restored
--
-- Keybinds:
--   RightShift  ->  open / close menu
--   Q           ->  toggle Kill Aura
--   R           ->  toggle Aim Assist]],
    })

    CredTab:Button({
        Title    = "Re-show Notice",
        Callback = function()
            Window:Notify({ Title = "WOLFVXPE REWRITE", Desc = "Made by pistademon — Vape KA Engine", Time = 4 })
        end,
    })

    CredTab:Button({
        Title    = "Save Profile Now",
        Desc     = "Force-save current settings to file.",
        Callback = function()
            collectAndSave()
            Window:Notify({ Title = "Profile", Desc = "Settings saved!", Time = 2 })
        end,
    })

    -- ══════════════════════════════════════════════════════════
    -- TAB: CHANGELOG
    -- ══════════════════════════════════════════════════════════
    CLTab:Section({ Title = "Version History" })

    CLTab:Code({
        Title = "v1.0  —  REWRITE  (Current)",
        Code  = [[━━ Combat ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [FIX]  Aim Assist: head targeting removed entirely
         — now locks exclusively to torso (HumanoidRootPart)
  [OPT]  Kill Aura: pre-allocated target table with table.clear()
         removes per-cycle garbage collection pressure
  [OPT]  Kill Aura: rootCF and lpPos cached once per cycle
         instead of being re-read on every entity iteration
  [OPT]  Kill Aura: added early exit when humanoid is dead
         to skip invalid entities faster

━━ Visual & UI ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [NEW]  Full purple premium theme across all custom UI elements
  [NEW]  Splash screen rewritten from scratch:
         slide-in animation with Back easing (springy)
         sequential status text with real timing
         gradient progress bar with purple glow gradient
         version label, staggered text fade-in
         clean slide-up exit — no stuck or fade bugs
  [NEW]  Toast notification rewritten: purple premium,
         slide-up with Back easing, clean slide-down exit

━━ ESP ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [NEW]  Player ESP: Highlight adorns full character model
         (shows around hitbox outline, not just root part)
  [NEW]  Player ESP: full rebuild on LocalPlayer respawn
         — no ghost highlights after death
  [NEW]  Kit ESP: icon billboards for map items
         30-second auto-refresh, death-safe ScreenGui
         toggle, icon size slider, 3 color themes

━━ Animations ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [NEW]  Animations tab: 5 packs (Ninja, Vampire, Toy,
         Levitation, Elder)
  [NEW]  Cycle Mix Mode: random per-slot blend of all packs
  [NEW]  Reset to Default button
  [NEW]  Auto re-apply on respawn

━━ Systems ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [FIX]  Stats.Network ping path corrected in updatePing()
         was: Stats.Network:GetValue() * 1000  (wrong API)
         now: Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
  [FIX]  KB Reducer: Velocity API updated to AssemblyLinearVelocity
         with pcall fallback for compatibility
  [FIX]  diagBlock:SetCode() wrapped in pcall to prevent
         RenderStepped errors if library method is unavailable
  [NEW]  Profile saving: versioned format (version 2)
         stale/mismatched profiles reset cleanly to defaults
  [NEW]  Modular GitHub loader — 9 modules, one loadstring
  [NEW]  Changelog tab added (this screen)]],
    })

    CLTab:Code({
        Title = "v0.5  —  PISTA V5",
        Code  = [[━━ Kill Aura  —  Vape Engine ━━━━━━━━━━━━━━━━━━━━
  [NEW]  swingSwordAtMouse() replaces raw FireServer
         goes through the full game sword pipeline
         passes server-side validation naturally
  [NEW]  HitFix: hookClientGet selfPosition ping compensation
         mirrors Vape hookClientGet exactly on every AttackEntity call
  [NEW]  HitBoxes: debug.setconstant on swingSwordInRegion index 6
         Vape "Sword" mode — expands server-side swing region
  [NEW]  entitylib: full Vape entity tracking integrated
         adds/removes players, health updates, team check, wall check
  [NEW]  hasSwordEquipped: Vape ItemMeta hotbar slot check
  [NEW]  Reach patch: CombatConstant RAYCAST_SWORD_CHARACTER_DISTANCE
         expanded with ping multiplier
  [NEW]  applyDebugPatch: swingSwordAtMouse debug constants patched
  [NEW]  FireServer fallback retained for non-bedwars environments]],
    })

    CLTab:Code({
        Title = "v0.4  —  PISTA V4",
        Code  = [[━━ Initial Feature Set ━━━━━━━━━━━━━━━━━━━━━━━━━
  [NEW]  Kill Aura: basic FireServer hit loop
         range, angle, team check, wall check, multi-hit
  [NEW]  KB Reducer: horizontal knockback damping
  [NEW]  Aim Assist: smooth camera lock with torso target
         keybind R, smoothing slider, range slider
  [NEW]  ESP: Highlight chams, name / HP / distance billboards
         fill transparency, outline by team colour
  [NEW]  FPS Boost suite:
           Grey Sky    — removes skybox + atmosphere
           No Shadows  — disables GlobalShadows
           Grey Players — strips accessories/clothing
           FullBright  — max ambient, persistent
           Nuclear Boost — strips particles, decals,
                           effects, reflections game-wide
  [NEW]  Profile: settings serialised and auto-saved to file
         loaded on next execution
  [NEW]  Anti-AFK: VirtualUser idle prevention
  [NEW]  Live FPS + Ping diagnostics panel (RenderStepped)
  [NEW]  Ping Stabiliser: EMA + median smoothing
  [NEW]  Keybinds: Q = Kill Aura  R = Aim  RightShift = Menu]],
    })

    -- ══════════════════════════════════════════════════════════
    -- PUBLIC API
    -- ══════════════════════════════════════════════════════════
    return {}
end
