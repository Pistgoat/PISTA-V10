-- ══════════════════════════════════════════════════════════════
-- MODULE 2: KILL AURA  (Module2_KillAura.lua)
-- Full Vape KA Engine: entitylib, bedwars loader, HitFix,
-- HitBoxes, reach patch, KA tab UI, main KA loop.
-- ctx: services, ka, KATab, collectAndSave, mfloor
--
-- FIXES IN THIS VERSION (zero logic removed):
--  [FIX 1] task.wait() removed from multiHit loop — was stalling
--          one full Heartbeat frame per target (5 targets = 5 frames
--          of freeze + camera snap per stall). All swings now fire
--          in the same tick. Server cooldown limits hits naturally.
--  [FIX 2] entitylib.Wallcheck: pre-allocated ignorelist table that
--          is UPDATED IN PLACE instead of rebuilt on every call.
--          Was: new table + tinsert for every entity every check.
--          Now: cleared + refilled once, FilterDescendantsInstances
--          only set when the list actually changes.
--  [FIX 3] getPingMs() cached once per KA loop cycle into _pingCache.
--          Was called inside HitFix hook (per swing), reach patch,
--          and FireServer fallback — pcall+service traversal each time.
--  [FIX 4] doSwing hoisted outside the hot path — was a fresh closure
--          allocation every loop iteration when targets existed.
--  [FIX 5] Camera savedCF captured immediately before first swing and
--          restored once after all swings complete — no stale CFrame.
--  [FIX 6] table.sort guarded: skipped when 0 or 1 target (no-op).
--  [FIX 7] isVisible fallback uses entitylib.List instead of calling
--          Players:GetPlayers() on every wall check.
--  [FIX 8] lmbHeld declared BEFORE the KA loop task.spawn that reads
--          it — eliminates hidden ordering dependency.
--  [FIX 9] Wallcheck _wallListDirty flag: FilterDescendantsInstances
--          only reassigned when entity list actually changes, not every
--          raycast call.
-- ══════════════════════════════════════════════════════════════

return function(ctx)

    local services       = ctx.services
    local ka             = ctx.ka
    local KATab          = ctx.KATab
    local collectAndSave = ctx.collectAndSave
    local mfloor         = ctx.mfloor

    local Players           = services.Players
    local UserInputService  = services.UserInputService
    local ReplicatedStorage = services.ReplicatedStorage
    local Camera            = services.Camera
    local LocalPlayer       = services.LocalPlayer

    local tinsert, tremove, tclone = table.insert, table.remove, table.clone
    local mcos, mrad               = math.cos, math.rad
    local v3new                    = Vector3.new

    -- ══════════════════════════════════════════════════════════
    -- VAPE ENTITY LIB
    -- ══════════════════════════════════════════════════════════
    local cloneref = cloneref or function(obj) return obj end

    local vapeEvents = setmetatable({}, {
        __index = function(self, index)
            self[index] = Instance.new("BindableEvent")
            return self[index]
        end
    })

    local playersService = cloneref(game:GetService("Players"))
    local lplr           = playersService.LocalPlayer
    local gameCamera     = workspace.CurrentCamera

    local entitylib = {
        isAlive           = false,
        character         = {},
        List              = {},
        Connections       = {},
        PlayerConnections = {},
        EntityThreads     = {},
        Running           = false,
        Events            = setmetatable({}, {
            __index = function(self, ind)
                self[ind] = {
                    Connections = {},
                    Connect = function(rself, func)
                        tinsert(rself.Connections, func)
                        return { Disconnect = function()
                            local i = table.find(rself.Connections, func)
                            if i then tremove(rself.Connections, i) end
                        end }
                    end,
                    Fire = function(rself, ...)
                        for _, v in rself.Connections do task.spawn(v, ...) end
                    end,
                    Destroy = function(rself)
                        table.clear(rself.Connections)
                        table.clear(rself)
                    end
                }
                return self[ind]
            end
        })
    }

    local function _waitForChildOfType(obj, name, timeout, prop)
        local deadline = tick() + timeout
        local returned
        repeat
            returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
            if returned or deadline < tick() then break end
            task.wait()
        until false
        return returned
    end

    entitylib.isVulnerable = function(ent)
        return ent.Health > 0 and not ent.Character:FindFirstChildWhichIsA("ForceField")
    end

    entitylib.targetCheck = function(ent)
        if ent.TeamCheck then return ent:TeamCheck() end
        if ent.NPC then return true end
        if not lplr.Team then return true end
        if not ent.Player.Team then return true end
        if ent.Player.Team ~= lplr.Team then return true end
        return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
    end

    -- FIX 2 + FIX 9: Pre-allocate ignorelist. Dirty flag ensures
    -- FilterDescendantsInstances is only updated when list changes,
    -- not rebuilt from scratch on every single raycast call.
    local _wallIgnoreList  = {}
    local _wallListDirty   = true
    local _wallRayParams   = RaycastParams.new()
    _wallRayParams.RespectCanCollide = true

    entitylib.IgnoreObject = _wallRayParams  -- keep original API

    local function _rebuildWallIgnoreList()
        table.clear(_wallIgnoreList)
        _wallIgnoreList[1] = gameCamera
        _wallIgnoreList[2] = lplr.Character
        local n = 2
        for _, v in entitylib.List do
            if v.Targetable then
                n = n + 1
                _wallIgnoreList[n] = v.Character
            end
        end
        _wallRayParams.FilterDescendantsInstances = _wallIgnoreList
        _wallListDirty = false
    end

    entitylib.Wallcheck = function(origin, position, ignoreobject)
        if typeof(ignoreobject) ~= "Instance" then
            -- Rebuild only when something changed (entity added/removed)
            if _wallListDirty then _rebuildWallIgnoreList() end
            if typeof(ignoreobject) == "table" then
                -- Caller passed extra objects — merge without mutating the base list
                local merged = tclone(_wallIgnoreList)
                for _, v in ignoreobject do tinsert(merged, v) end
                local tempParams = RaycastParams.new()
                tempParams.RespectCanCollide = true
                tempParams.FilterDescendantsInstances = merged
                return workspace:Raycast(origin, position - origin, tempParams)
            end
            ignoreobject = _wallRayParams
        end
        return workspace:Raycast(origin, (position - origin), ignoreobject)
    end

    -- Mark wall list dirty when entities change
    local function _markWallDirty() _wallListDirty = true end

    entitylib.getUpdateConnections = function(ent)
        local hum = ent.Humanoid
        return {
            hum:GetPropertyChangedSignal("Health"),
            hum:GetPropertyChangedSignal("MaxHealth"),
        }
    end

    entitylib.getEntity = function(char)
        for i, v in entitylib.List do
            if v.Player == char or v.Character == char then return v, i end
        end
    end

    entitylib.addEntity = function(char, plr, teamfunc)
        if not char then return end
        entitylib.EntityThreads[char] = task.spawn(function()
            local hum         = _waitForChildOfType(char, "Humanoid", 10)
            local humrootpart = hum and _waitForChildOfType(hum, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true)
            local head        = char:WaitForChild("Head", 10) or humrootpart

            if hum and humrootpart then
                local entity = {
                    Connections      = {},
                    Character        = char,
                    Health           = hum.Health,
                    Head             = head,
                    Humanoid         = hum,
                    HumanoidRootPart = humrootpart,
                    HipHeight        = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                    MaxHealth        = hum.MaxHealth,
                    NPC              = plr == nil,
                    Player           = plr,
                    RootPart         = humrootpart,
                    TeamCheck        = teamfunc,
                }

                if plr == lplr then
                    entitylib.character = entity
                    entitylib.isAlive   = true
                    entitylib.Events.LocalAdded:Fire(entity)
                else
                    entity.Targetable = entitylib.targetCheck(entity)
                    for _, v in entitylib.getUpdateConnections(entity) do
                        tinsert(entity.Connections, v:Connect(function()
                            entity.Health    = hum.Health
                            entity.MaxHealth = hum.MaxHealth
                            entitylib.Events.EntityUpdated:Fire(entity)
                        end))
                    end
                    tinsert(entitylib.List, entity)
                    _markWallDirty()  -- FIX 9: entity added — rebuild wall list next check
                    entitylib.Events.EntityAdded:Fire(entity)
                end
            end
            entitylib.EntityThreads[char] = nil
        end)
    end

    entitylib.removeEntity = function(char, localcheck)
        if localcheck then
            if entitylib.isAlive then
                entitylib.isAlive = false
                for _, v in entitylib.character.Connections do v:Disconnect() end
                table.clear(entitylib.character.Connections)
                entitylib.Events.LocalRemoved:Fire(entitylib.character)
            end
            return
        end
        if char then
            if entitylib.EntityThreads[char] then
                task.cancel(entitylib.EntityThreads[char])
                entitylib.EntityThreads[char] = nil
            end
            local entity, ind = entitylib.getEntity(char)
            if ind then
                for _, v in entity.Connections do v:Disconnect() end
                table.clear(entity.Connections)
                tremove(entitylib.List, ind)
                _markWallDirty()  -- FIX 9: entity removed — rebuild wall list next check
                entitylib.Events.EntityRemoved:Fire(entity)
            end
        end
    end

    entitylib.refreshEntity = function(char, plr)
        entitylib.removeEntity(char)
        entitylib.addEntity(char, plr)
    end

    entitylib.addPlayer = function(plr)
        if plr.Character then entitylib.refreshEntity(plr.Character, plr) end
        entitylib.PlayerConnections[plr] = {
            plr.CharacterAdded:Connect(function(char) entitylib.refreshEntity(char, plr) end),
            plr.CharacterRemoving:Connect(function(char) entitylib.removeEntity(char, plr == lplr) end),
            plr:GetPropertyChangedSignal("Team"):Connect(function()
                for _, v in entitylib.List do
                    if v.Targetable ~= entitylib.targetCheck(v) then
                        entitylib.refreshEntity(v.Character, v.Player)
                    end
                end
                if plr == lplr then entitylib.start()
                else entitylib.refreshEntity(plr.Character, plr) end
            end),
        }
    end

    entitylib.removePlayer = function(plr)
        if entitylib.PlayerConnections[plr] then
            for _, v in entitylib.PlayerConnections[plr] do v:Disconnect() end
            table.clear(entitylib.PlayerConnections[plr])
            entitylib.PlayerConnections[plr] = nil
        end
        entitylib.removeEntity(plr)
    end

    entitylib.start = function()
        if entitylib.Running then entitylib.stop() end
        tinsert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v) entitylib.addPlayer(v) end))
        tinsert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v) entitylib.removePlayer(v) end))
        for _, v in playersService:GetPlayers() do entitylib.addPlayer(v) end
        tinsert(entitylib.Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
            _markWallDirty()  -- camera changed — rebuild ignore list
        end))
        entitylib.Running = true
    end

    entitylib.stop = function()
        for _, v in entitylib.Connections do v:Disconnect() end
        for _, v in entitylib.PlayerConnections do
            for _, v2 in v do v2:Disconnect() end
            table.clear(v)
        end
        entitylib.removeEntity(nil, true)
        local cloned = tclone(entitylib.List)
        for _, v in cloned do entitylib.removeEntity(v.Character) end
        for _, v in entitylib.EntityThreads do task.cancel(v) end
        table.clear(entitylib.PlayerConnections)
        table.clear(entitylib.EntityThreads)
        table.clear(entitylib.Connections)
        table.clear(cloned)
        entitylib.Running = false
    end

    entitylib.kill = function()
        if entitylib.Running then entitylib.stop() end
        for _, v in entitylib.Events do v:Destroy() end
    end

    -- ══════════════════════════════════════════════════════════
    -- VAPE: waitForBedwars
    -- ══════════════════════════════════════════════════════════
    local function waitForBedwars()
        local attempts = 0
        while attempts < 100 do
            attempts = attempts + 1
            local success, knit = pcall(function()
                return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
            end)
            if success and knit then
                local startAttempts = 0
                while not debug.getupvalue(knit.Start, 1) and startAttempts < 50 do
                    startAttempts = startAttempts + 1
                    task.wait(0.1)
                end
                if debug.getupvalue(knit.Start, 1) then
                    print("[PISTAV5] Bedwars loaded after " .. attempts .. " attempts")
                    return knit
                end
            end
            task.wait(0.1)
        end
        warn("[PISTAV5] Bedwars failed to load")
        return nil
    end

    -- ══════════════════════════════════════════════════════════
    -- VAPE: bedwars store + ItemMeta
    -- ══════════════════════════════════════════════════════════
    local bedwars      = {}
    local bedwarsReady = false

    local vapeStore = {
        hand        = { toolType = "", tool = nil, amount = 0 },
        inventory   = { inventory = { items = {}, armor = {} }, hotbar = {}, hotbarSlot = 0 },
        equippedKit = "",
    }

    local function getItemMeta(itemType)
        if bedwars.ItemMeta and bedwars.ItemMeta[itemType] then
            return bedwars.ItemMeta[itemType]
        end
        return nil
    end

    local function hasSwordEquipped()
        local inv = vapeStore.inventory
        if not inv or not inv.hotbar then return false end
        local hotbarSlot = inv.hotbarSlot
        if hotbarSlot == nil then return false end
        local slotItem = inv.hotbar[hotbarSlot + 1]
        if not slotItem or not slotItem.item then return false end
        local meta = getItemMeta(slotItem.item.itemType)
        return meta and meta.sword ~= nil
    end

    local function vapeUpdateStore(new, old)
        if new.Bedwars ~= old.Bedwars then
            vapeStore.equippedKit = (new.Bedwars and new.Bedwars.kit ~= "none") and new.Bedwars.kit or ""
        end
        if new.Inventory ~= old.Inventory then
            local newinv = (new.Inventory and new.Inventory.observedInventory) or { inventory = {} }
            local oldinv = (old.Inventory and old.Inventory.observedInventory) or { inventory = {} }
            vapeStore.inventory = newinv
            if newinv.inventory and oldinv.inventory and newinv.inventory.hand ~= oldinv.inventory.hand then
                local currentHand = newinv.inventory.hand
                local toolType = ""
                if currentHand then
                    local handData = getItemMeta(currentHand.itemType)
                    if handData then
                        toolType = handData.sword and "sword"
                               or handData.block and "block"
                               or (currentHand.itemType:find("bow") and "bow" or "")
                    end
                end
                vapeStore.hand = {
                    tool     = currentHand and currentHand.tool,
                    amount   = currentHand and currentHand.amount or 0,
                    toolType = toolType,
                }
            end
        end
    end

    -- ══════════════════════════════════════════════════════════
    -- VAPE: HitFix — hookClientGet
    -- ══════════════════════════════════════════════════════════
    local OldGet        = nil
    local remotes       = {}
    local HitFixEnabled = ka.hitfix

    -- FIX 3: Ping cached per KA loop cycle (_pingCache).
    -- HitFix hook and FireServer fallback both READ _pingCache
    -- instead of calling getPingMs() themselves.
    local _pingCache    = 0
    local _pingTimer    = 0

    local function refreshPingCache()
        -- Called once per KA tick — not inside the hot per-target loop
        pcall(function()
            _pingCache = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
    end

    -- Kept for reach patch (called once on setup, not per tick)
    local function getPingMs()
        return _pingCache
    end

    local function hookClientGet()
        if not bedwars.Client or OldGet then return end
        OldGet = bedwars.Client.Get
        bedwars.Client.Get = function(self, remoteName)
            local call = OldGet(self, remoteName)
            if remoteName == (remotes.AttackEntity or "AttackEntity") then
                return {
                    instance = call.instance,
                    SendToServer = function(_, attackTable, ...)
                        if attackTable and attackTable.validate and HitFixEnabled then
                            local selfpos   = attackTable.validate.selfPosition   and attackTable.validate.selfPosition.value
                            local targetpos = attackTable.validate.targetPosition and attackTable.validate.targetPosition.value
                            if selfpos and targetpos then
                                -- FIX 3: uses _pingCache instead of calling getPingMs() here
                                local distance         = (selfpos - targetpos).Magnitude
                                local pingCompensation = math.min(_pingCache / 1000 * 50, 8)
                                local adjustmentDist   = math.max(distance - 12, 0) + pingCompensation
                                if adjustmentDist > 0 then
                                    local direction = CFrame.lookAt(selfpos, targetpos).LookVector
                                    attackTable.validate.selfPosition.value = selfpos + (direction * adjustmentDist)
                                    if pingCompensation > 2 then
                                        attackTable.validate.targetPosition.value = targetpos - (direction * math.min(pingCompensation * 0.3, 2))
                                    end
                                end
                            end
                        end
                        return call:SendToServer(attackTable, ...)
                    end,
                }
            end
            return call
        end
    end

    -- ══════════════════════════════════════════════════════════
    -- VAPE: HitBoxes
    -- ══════════════════════════════════════════════════════════
    local HITBOX_DEFAULT_CONSTANT = 3.8

    local function applySwordHitbox(enabled, expandAmount)
        if not bedwars.SwordController or not bedwars.SwordController.swingSwordInRegion then return false end
        local success = pcall(function()
            if enabled then
                debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (expandAmount or 38) / 3)
            else
                debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, HITBOX_DEFAULT_CONSTANT)
            end
        end)
        return success
    end

    -- ══════════════════════════════════════════════════════════
    -- VAPE: Reach + Debug patches
    -- ══════════════════════════════════════════════════════════
    local originalReachDistance = nil

    local function applyReachPatch(enabled)
        pcall(function()
            if bedwars.CombatConstant then
                if enabled then
                    if originalReachDistance == nil then
                        originalReachDistance = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
                    end
                    -- FIX 3: uses cached ping
                    local pingMult = _pingCache < 50 and 1.0 or _pingCache < 100 and 1.2 or _pingCache < 200 and 1.5 or 2.0
                    bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = 18 + math.min(2 * pingMult, 6)
                else
                    if originalReachDistance ~= nil then
                        bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = originalReachDistance
                    end
                end
            end
        end)
    end

    local function applyDebugPatch(enabled)
        pcall(function()
            if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, enabled and "raycast" or "Raycast")
                debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, enabled and (bedwars.QueryUtil or workspace) or workspace)
            end
        end)
    end

    -- ══════════════════════════════════════════════════════════
    -- VAPE: setupBedwars
    -- ══════════════════════════════════════════════════════════
    task.spawn(function()
        local knit = waitForBedwars()
        if not knit then return end

        local ok = pcall(function()
            bedwars.SwordController = knit.Controllers.SwordController
            bedwars.ItemMeta = debug.getupvalue(
                require(ReplicatedStorage.TS.item["item-meta"]).getItemMeta, 1
            )
            bedwars.Store  = require(lplr.PlayerScripts.TS.ui.store).ClientStore
            bedwars.Client = require(ReplicatedStorage.TS.remotes).default.Client

            pcall(function()
                bedwars.QueryUtil = require(
                    ReplicatedStorage["rbxts_include"]["node_modules"]["@easy-games"]["game-core"].out
                ).GameQueryUtil
            end)

            local comboPaths = {
                function() return require(ReplicatedStorage.TS.combat["combat-constant"]).CombatConstant end,
                function() return require(ReplicatedStorage.TS.combat.CombatConstant) end,
                function() return knit.Controllers.SwordController.CombatConstant end,
            }
            for _, fn in ipairs(comboPaths) do
                local s, r = pcall(fn)
                if s and r and r.RAYCAST_SWORD_CHARACTER_DISTANCE then
                    bedwars.CombatConstant = r; break
                end
            end

            pcall(function()
                local function dumpRemote(tab)
                    for i, v in tab do
                        if v == "Client" then return tab[i + 1] end
                    end
                    return ""
                end
                local r = dumpRemote(debug.getconstants(bedwars.SwordController.sendServerRequest or function() end))
                if r and r ~= "" then remotes.AttackEntity = r end
            end)

            pcall(function()
                bedwars.Store.changed:connect(vapeUpdateStore)
                vapeUpdateStore(bedwars.Store:getState(), {})
            end)
        end)

        if ok then
            bedwarsReady = true
            refreshPingCache()  -- seed ping cache before first reach patch
            applyReachPatch(true)
            applyDebugPatch(true)
            hookClientGet()
            print("[PISTAV5] Vape KA Engine ready")
        else
            warn("[PISTAV5] Bedwars setup failed — FireServer fallback will be used")
        end
    end)

    -- ══════════════════════════════════════════════════════════
    -- KA TAB UI
    -- ══════════════════════════════════════════════════════════
    KATab:Section({ Title = "Kill Aura  [Q to toggle]  —  Vape Engine" })

    KATab:Toggle({
        Title    = "Enable Kill Aura",
        Desc     = "Vape swingSwordAtMouse engine. Toggle with Q.",
        Value    = ka.enabled,
        Callback = function(v) ka.enabled = v; collectAndSave() end,
    })

    KATab:Toggle({
        Title    = "Team Check",
        Desc     = "Only attack players on the opposing team.",
        Value    = ka.teamCheck,
        Callback = function(v) ka.teamCheck = v; collectAndSave() end,
    })

    KATab:Toggle({
        Title    = "Multi-Hit (all in range)",
        Desc     = "Hit every valid enemy per tick instead of just the closest.",
        Value    = ka.multiHit,
        Callback = function(v) ka.multiHit = v; collectAndSave() end,
    })

    KATab:Section({ Title = "Fire Method" })

    KATab:Toggle({
        Title    = "Vape SwingMode (swingSwordAtMouse)",
        Desc     = "ON = Vape native swingSwordAtMouse — most legit.\nOFF = raw FireServer AttackEntity fallback.",
        Value    = ka.useSwingMode,
        Callback = function(v) ka.useSwingMode = v; collectAndSave() end,
    })

    KATab:Section({ Title = "HitFix  (Vape AttackEntity Hook)" })

    KATab:Toggle({
        Title    = "Enable HitFix",
        Desc     = "Adjusts selfPosition toward target with ping compensation.",
        Value    = ka.hitfix,
        Callback = function(v)
            ka.hitfix     = v
            HitFixEnabled = v
            collectAndSave()
        end,
    })

    KATab:Section({ Title = "HitBoxes  (Vape swingSwordInRegion)" })

    KATab:Toggle({
        Title    = "Enable HitBoxes",
        Desc     = "Expands the sword swing region constant. Exact Vape Sword mode.",
        Value    = ka.hitboxes,
        Callback = function(v)
            ka.hitboxes = v
            if bedwarsReady then applySwordHitbox(v, ka.hitboxExpand) end
            collectAndSave()
        end,
    })

    KATab:Slider({
        Title    = "HitBox Expand Amount",
        Desc     = "Vape default is 38.",
        Min = 5, Max = 80, Rounding = 0, Value = ka.hitboxExpand,
        Callback = function(v)
            ka.hitboxExpand = v
            if ka.hitboxes and bedwarsReady then applySwordHitbox(true, v) end
            collectAndSave()
        end,
    })

    KATab:Section({ Title = "Range & Angle" })

    KATab:Slider({
        Title    = "Range (studs)",
        Desc     = "Vape default is ~16 studs.",
        Min = 4, Max = 30, Rounding = 0, Value = ka.range,
        Callback = function(v) ka.range = v; collectAndSave() end,
    })

    KATab:Slider({
        Title    = "Angle (degrees)",
        Desc     = "FOV cone. 45 = narrow  360 = all-around.",
        Min = 45, Max = 360, Rounding = 0, Value = ka.angleDeg,
        Callback = function(v) ka.angleDeg = v; collectAndSave() end,
    })

    KATab:Section({ Title = "Timing" })

    KATab:Slider({
        Title    = "Hitreg Delay (ms)",
        Min = 20, Max = 500, Rounding = 0, Value = ka.delay * 1000,
        Callback = function(v) ka.delay = v / 1000; collectAndSave() end,
    })

    KATab:Section({ Title = "Conditions" })

    KATab:Toggle({
        Title    = "Require LMB (Left Click)",
        Value    = ka.requireMouse,
        Callback = function(v) ka.requireMouse = v; collectAndSave() end,
    })

    KATab:Toggle({
        Title    = "Limit to Sword Items",
        Value    = ka.limitToItems,
        Callback = function(v) ka.limitToItems = v; collectAndSave() end,
    })

    KATab:Toggle({
        Title    = "Ignore Behind Walls",
        Value    = ka.ignoreWalls,
        Callback = function(v) ka.ignoreWalls = v; collectAndSave() end,
    })

    KATab:Section({ Title = "Info" })
    KATab:Code({
        Title = "Vape KA Engine Notes",
        Code  = [[-- Q                -> toggle Kill Aura on/off
-- SwingMode ON  : swingSwordAtMouse() — Vape pipeline
-- SwingMode OFF : raw FireServer AttackEntity fallback
-- HitFix        : selfPosition ping compensation
-- HitBoxes      : debug.setconstant swingSwordInRegion
-- RightShift    : open/close menu]],
    })

    -- ══════════════════════════════════════════════════════════
    -- FIX 8: lmbHeld declared BEFORE the KA loop task.spawn.
    -- Previously declared at line ~636, after spawn at ~756.
    -- Worked only because spawn defers — now explicit and safe.
    -- ══════════════════════════════════════════════════════════
    local lmbHeld = false
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then lmbHeld = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then lmbHeld = false end
    end)

    -- ══════════════════════════════════════════════════════════
    -- ANGLE COSINE CACHE
    -- ══════════════════════════════════════════════════════════
    local _cachedAngleDeg, _cachedCos = -1, 0
    local function getAngleCos()
        if ka.angleDeg ~= _cachedAngleDeg then
            _cachedAngleDeg = ka.angleDeg
            _cachedCos = mcos(mrad(ka.angleDeg / 2))
        end
        return _cachedCos
    end

    local function inAngleCone(rootCF, targetPos)
        if ka.angleDeg >= 360 then return true end
        local toTarget = targetPos - rootCF.Position
        toTarget = v3new(toTarget.X, 0, toTarget.Z).Unit
        local forward = v3new(rootCF.LookVector.X, 0, rootCF.LookVector.Z).Unit
        return forward:Dot(toTarget) >= getAngleCos()
    end

    -- ══════════════════════════════════════════════════════════
    -- WALL RAYCAST  (separate from entitylib.Wallcheck above)
    -- Used by isVisible() in the KA loop.
    -- ══════════════════════════════════════════════════════════
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local _rayFilterDirty = true
    local function refreshRayFilter()
        if not _rayFilterDirty then return end
        _rayFilterDirty = false
        local char = LocalPlayer.Character
        rayParams.FilterDescendantsInstances = char and { char } or {}
    end

    local function isVisible(fromPos, toPos)
        if not ka.ignoreWalls then return true end
        refreshRayFilter()
        local result = workspace:Raycast(fromPos, toPos - fromPos, rayParams)
        if not result then return true end
        local hit = result.Instance
        -- FIX 7: use entitylib.List instead of Players:GetPlayers()
        -- entitylib.List is already maintained — no new allocation needed
        for _, ent in ipairs(entitylib.List) do
            if ent.Character and hit:IsDescendantOf(ent.Character) then return true end
        end
        return false
    end

    -- ══════════════════════════════════════════════════════════
    -- SWORD CHECK
    -- ══════════════════════════════════════════════════════════
    local function holdingSwordGeneric()
        local char = LocalPlayer.Character; if not char then return false end
        local handItem = char:FindFirstChild("HandInvItem")
        if handItem and handItem.Value then
            local n = handItem.Value.Name:lower()
            if n:find("sword") or n:find("blade") then return true end
        end
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then
                local n = obj.Name:lower()
                if n:find("sword") or n:find("blade") then return true end
            end
        end
        return false
    end

    local function checkSwordEquipped()
        if bedwarsReady and bedwars.ItemMeta then return hasSwordEquipped() end
        return holdingSwordGeneric()
    end

    -- ══════════════════════════════════════════════════════════
    -- FIRESERVER FALLBACK HELPERS
    -- ══════════════════════════════════════════════════════════
    local _net, _inv
    local function getKANet()
        if _net then return _net end
        local ok2, v = pcall(function()
            return ReplicatedStorage.rbxts_include.node_modules
                :FindFirstChild("@rbxts").net.out._NetManaged.SwordHit
        end)
        if ok2 and v then _net = v end
        return _net
    end

    local function getKAInv()
        if _inv and _inv.Parent then return _inv end
        local invRoot = ReplicatedStorage:FindFirstChild("Inventories")
        _inv = invRoot and invRoot:FindFirstChild(LocalPlayer.Name)
        return _inv
    end

    local SWORD_NAMES = {
        "wood_sword","stone_sword","iron_sword",
        "diamond_sword","emerald_sword","netherite_sword",
    }
    local function getSwordItem()
        local inv = getKAInv(); if not inv then return nil end
        for _, name in ipairs(SWORD_NAMES) do
            local found = inv:FindFirstChild(name)
            if found then return found end
        end
        for _, child in ipairs(inv:GetChildren()) do
            if child.Name:lower():find("sword") then return child end
        end
        return nil
    end

    -- ══════════════════════════════════════════════════════════
    -- FIX 4: doSwing hoisted here — declared ONCE at module level.
    -- Previously a fresh closure was allocated every loop iteration
    -- inside the `if #_kaTargets > 0` block.
    -- ══════════════════════════════════════════════════════════
    local function doSwing(targetPos)
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        pcall(function() bedwars.SwordController:swingSwordAtMouse() end)
    end

    -- ══════════════════════════════════════════════════════════
    -- MAIN KILL AURA LOOP
    -- ══════════════════════════════════════════════════════════
    local _kaTargets = {}

    task.spawn(function()
        while true do
            task.wait(ka.delay)
            if not ka.enabled then continue end
            if ka.requireMouse and not lmbHeld then continue end
            if ka.limitToItems and not checkSwordEquipped() then continue end

            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local rootCF   = root.CFrame
            local lpPos    = rootCF.Position
            local localHum = char:FindFirstChild("Humanoid")
            if not localHum or localHum.Health <= 0 then continue end

            -- FIX 3: refresh ping cache once per tick here
            refreshPingCache()

            -- ── METHOD 1: swingSwordAtMouse (Vape native) ──────────
            if ka.useSwingMode and bedwarsReady
            and bedwars.SwordController
            and bedwars.SwordController.swingSwordAtMouse then

                table.clear(_kaTargets)

                for _, ent in ipairs(entitylib.List) do
                    if not ent.Targetable then continue end
                    if not entitylib.isVulnerable(ent) then continue end
                    if ka.teamCheck and ent.Player then
                        local localTeam = LocalPlayer.Team
                        local entTeam   = ent.Player.Team
                        if localTeam and entTeam and entTeam == localTeam then continue end
                    end
                    local pRoot = ent.RootPart
                    if not pRoot then continue end
                    local pPos = pRoot.Position
                    local dist = (lpPos - pPos).Magnitude
                    if dist > ka.range then continue end
                    if not inAngleCone(rootCF, pPos) then continue end
                    if not isVisible(lpPos, pPos) then continue end
                    tinsert(_kaTargets, { ent = ent, pPos = pPos, dist = dist })
                end

                -- FIX 6: skip sort when 0 or 1 target — table.sort on 1 element is a no-op waste
                if #_kaTargets > 1 then
                    table.sort(_kaTargets, function(a, b) return a.dist < b.dist end)
                end

                if #_kaTargets > 0 then
                    -- FIX 5: capture CFrame ONCE right before first swing
                    local savedCF = Camera.CFrame

                    if ka.multiHit then
                        -- FIX 1: removed task.wait() between swings.
                        -- Was stalling 1 full Heartbeat frame per target —
                        -- with 5 targets that was 5 frames of freeze + visual
                        -- camera snap per stall. All swings now fire this tick.
                        -- The server's own swing cooldown limits actual hitreg.
                        for _, t in ipairs(_kaTargets) do
                            doSwing(t.pPos)
                        end
                    else
                        doSwing(_kaTargets[1].pPos)
                    end

                    -- FIX 5: restore camera once after ALL swings, not after each wait
                    Camera.CFrame = savedCF
                end

            -- ── METHOD 2: FireServer fallback ──────────────────────
            else
                local net   = getKANet()
                local sword = getSwordItem()
                if not net or not sword then continue end
                _rayFilterDirty = true

                for _, p in ipairs(Players:GetPlayers()) do
                    if p == LocalPlayer then continue end
                    if ka.teamCheck and p.Team == LocalPlayer.Team and LocalPlayer.Team ~= nil then continue end

                    local pChar = p.Character
                    local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                    local hum   = pChar and pChar:FindFirstChild("Humanoid")
                    if not pChar or not pRoot or not hum or hum.Health <= 0 then continue end

                    local pPos = pRoot.Position
                    if (lpPos - pPos).Magnitude > ka.range then continue end
                    if not inAngleCone(rootCF, pPos) then continue end
                    if not isVisible(lpPos, pPos) then continue end

                    local fireSelfPos = lpPos
                    if ka.hitfix then
                        -- FIX 3: reads _pingCache (already refreshed above this frame)
                        local distance         = (lpPos - pPos).Magnitude
                        local pingCompensation = math.min(_pingCache / 1000 * 50, 8)
                        local adjustmentDist   = math.max(distance - 12, 0) + pingCompensation
                        if adjustmentDist > 0 then
                            local direction = CFrame.lookAt(lpPos, pPos).LookVector
                            fireSelfPos = lpPos + (direction * adjustmentDist)
                        end
                    end

                    local args = {{
                        entityInstance = pChar,
                        chargedAttack  = { chargeRatio = 0 },
                        validate = {
                            targetPosition = { value = pPos },
                            selfPosition   = { value = fireSelfPos },
                        },
                        weapon = sword,
                    }}
                    pcall(net.FireServer, net, unpack(args))
                    if not ka.multiHit then break end
                end
            end
        end
    end)

    -- ══════════════════════════════════════════════════════════
    -- PUBLIC API
    -- ══════════════════════════════════════════════════════════
    return {
        entitylib         = entitylib,
        getBedwarsReady   = function() return bedwarsReady end,
        setRayFilterDirty = function(v) _rayFilterDirty = v end,
    }
end
