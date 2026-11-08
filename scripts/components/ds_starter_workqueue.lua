-- Shift + left double-click work queue.
-- The queue lives on the player, picks the nearest visible target, walks there
-- and repeats the matching action until nothing valid is left.  Any manual
-- movement, click, control or UI action cancels it (see modmain hooks).

local TICK_INTERVAL = 0.2
-- Roughly two screens, so the queue can continue to nearby off-screen targets.
local VIEW_RADIUS = 70
local WATER_RADIUS = 90
local INTERACT_RANGE = 3.5
local WATER_RANGE = 8
local WATER_ACTION_RANGE = 1.3
local NPC_RANGE = 6
local PICKUP_RADIUS = 12
local DOUBLE_CLICK_TIME = 0.3
local ACTION_COOLDOWN = 0.35
local MAX_JOBS = 48
local ACTION_WAIT = 18
local BLINK_RANGE = 20
local BLINK_COOLDOWN = 0.35
local BLINK_MAX_FAILURES = 3
local IsWaterTileAt

local function L(en, zh)
    local f = rawget(_G, "DSStarterL")
    if f ~= nil then
        return f(en, zh)
    end
    return en
end

local function CopyList(list)
    local copy = {}
    for i = 1, #(list or {}) do
        copy[i] = list[i]
    end
    return copy
end

local function FlatDistSq(a, b)
    local ax, _, az = a:GetPosition():Get()
    local bx, _, bz = b:GetPosition():Get()
    local dx = ax - bx
    local dz = az - bz
    return dx * dx + dz * dz
end

local function GetTeamBag(inventory)
    if inventory == nil then
        return nil
    end
    local bag = nil
    if EQUIPSLOTS.BACK ~= nil then
        bag = inventory:GetEquippedItem(EQUIPSLOTS.BACK)
    end
    if bag == nil then
        bag = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    end
    if bag ~= nil and bag.components.container ~= nil then
        return bag
    end
end

local function IsOnBoat(player)
    local driver = player.components.driver
    return driver ~= nil
        and driver.GetIsDriving ~= nil
        and driver:GetIsDriving()
end

local function IsWallNear(x, z)
    local ents = TheSim:FindEntities(
        x, 0, z, 1.0, nil, { "INLIMBO", "FX", "NOCLICK" }
    )
    for i = 1, #ents do
        if ents[i]:HasTag("wall") then
            return true
        end
    end
    return false
end

-- Optional Blood-Drinking Sword shortcut: equip the sword and blink toward
-- the target instead of only walking. Blink is skipped in water, on boats and
-- for water targets, and each job gives up after a few failures.
local function TryBlinkToward(self, target, range, job)
    local blink = rawget(_G, "DSStarterBlink")
    if blink == nil or target == nil or job == nil or job.blink_disabled then
        return false
    end
    local player = self.inst
    if player == nil or player:HasTag("playerghost") then
        return false
    end
    if target.Transform == nil then
        return false
    end

    local tx, ty, tz = target.Transform:GetWorldPosition()
    local target_is_water = IsWaterTileAt(tx, ty, tz) == true
    if IsOnBoat(player) then
        -- A boat may only blink to water; blinking onto land is not allowed.
        if not target_is_water then
            return false
        end
    elseif target_is_water then
        return false
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    local dx = tx - px
    local dz = tz - pz
    local distance = math.sqrt(dx * dx + dz * dz)
    range = range or INTERACT_RANGE
    if distance <= range + 0.1 then
        return false
    end

    local sword = self:FindPrefab("ds_starter_yinxue_sword", true)
    local inventory = player.components.inventory
    if sword == nil or inventory == nil then
        return false
    end

    local now = GetTime()
    if job.next_blink_time ~= nil and now < job.next_blink_time then
        -- Wait for the blink cooldown instead of walking into obstacles.
        return true
    end

    if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= sword then
        inventory:Equip(sword)
    end

    local travel = math.min(BLINK_RANGE, distance - range)
    if travel < 1 then
        return false
    end
    local x = px + (dx / distance) * travel
    local z = pz + (dz / distance) * travel
    if blink(x, z) then
        job.next_blink_time = now + BLINK_COOLDOWN + 0.05
        job.blink_failures = 0
        job.last_progress_time = now
        job.last_progress_pos = player:GetPosition()
        return true
    end

    job.blink_failures = (job.blink_failures or 0) + 1
    job.next_blink_time = now + 0.5
    if job.blink_failures >= BLINK_MAX_FAILURES then
        job.blink_disabled = true
    end
    return false
end

IsWaterTileAt = function(x, y, z)
    local map = GetWorld() ~= nil and GetWorld().Map or nil
    if map == nil or map.GetTileAtPoint == nil or map.IsWater == nil then
        return nil
    end
    local tile = map:GetTileAtPoint(x, y, z)
    return map:IsWater(tile)
end

-- In the Shipwrecked world, do not pick targets on other islands while on
-- foot; pathing would otherwise keep pushing against the shoreline.
local function IsSameIsland(player, target)
    if IsOnBoat(player) then
        return true
    end
    local map = GetWorld() ~= nil and GetWorld().Map or nil
    if map == nil or map.GetIslandAtPoint == nil then
        return true
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local ok1, player_island = pcall(map.GetIslandAtPoint, map, px, py, pz)
    local ok2, target_island = pcall(map.GetIslandAtPoint, map, tx, ty, tz)
    if not ok1 or not ok2
        or player_island == nil or target_island == nil
    then
        return true
    end
    -- 127 is NO_ISLAND; do not block when the map cannot classify a point.
    if player_island == 127 or target_island == 127 then
        return true
    end
    return player_island == target_island
end

local function IsInView(player, target)
    if target == nil
        or not target:IsValid()
        or target:IsInLimbo()
        or target.Transform == nil
    then
        return false
    end
    if not IsSameIsland(player, target) then
        return false
    end
    local px, py, pz = player.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local dx = tx - px
    local dz = tz - pz
    local radius = VIEW_RADIUS
    if target.components.flotsamfisher ~= nil then
        radius = WATER_RADIUS
    end
    if dx * dx + dz * dz > radius * radius then
        return false
    end

    -- The search radius is intentionally larger than the visible screen, so
    -- off-screen targets are included; no screen-space check is needed.
    return true
end

local function IsToolUsable(tool)
    if tool == nil or not tool:IsValid() then
        return false
    end
    local uses = tool.components.finiteuses
    if uses ~= nil and uses.GetUses ~= nil and uses:GetUses() <= 0 then
        return false
    end
    return true
end

local function ToolCanDo(tool, action)
    return IsToolUsable(tool)
        and tool.components.tool ~= nil
        and tool.components.tool:CanDoAction(action)
end

-- Only loot-bearing hammerables are safe to repeat automatically. Other
-- hammerable structures (walls, houses, chests, campfires, ...) must be
-- handled with a normal click so the queue cannot demolish them by accident.
local QUEUE_HAMMER_PREFABS = {
    smashingpot = true, -- Hamlet pig ruins pot
    crate = true,       -- Shipwrecked crate washed up on the beach
}

local function IsAllowedHammerTarget(target)
    return target ~= nil
        and target.prefab ~= nil
        and QUEUE_HAMMER_PREFABS[target.prefab] == true
end

local function IsAllowedWorkAction(target, action)
    return action ~= ACTIONS.HAMMER or IsAllowedHammerTarget(target)
end

local function HasRoomForItem(player, item)
    local inventory = player.components.inventory
    if inventory == nil then
        return false
    end
    if inventory:GetNextAvailableSlot(item) ~= nil then
        return true
    end
    local overflow = inventory.overflow
    if overflow ~= nil and overflow.components.container ~= nil then
        local slots = overflow.components.container.slots or {}
        for _, existing in pairs(slots) do
            if existing == nil then
                return true
            end
            if item.components.stackable ~= nil
                and existing.prefab == item.prefab
                and existing.components.stackable ~= nil
                and not existing.components.stackable:IsFull()
            then
                return true
            end
        end
    end
    return false
end

local function TakeOne(player, item)
    if item == nil or not item:IsValid() then
        return nil
    end
    local inventory = player.components.inventory
    if inventory ~= nil then
        local owner = item.components.inventoryitem ~= nil
            and item.components.inventoryitem.owner
            or nil
        if owner == inventory.inst then
            return inventory:RemoveItem(item)
        end
        if owner ~= nil and owner.components.container ~= nil then
            return owner.components.container:RemoveItem(item)
        end
    end
    return item
end

local function GiveBack(player, item)
    if item == nil or not item:IsValid() then
        return
    end
    local inventory = player.components.inventory
    if inventory ~= nil then
        inventory:GiveItem(item)
    end
end

local function CanLooseItemBePicked(item, player)
    if item == nil
        or not item:IsValid()
        or item:IsInLimbo()
        or item.Transform == nil
    then
        return false
    end
    local item_comp = item.components.inventoryitem
    if item_comp == nil
        or not item_comp.canbepickedup
        or not item_comp.cangoincontainer
        or item_comp:IsHeld()
    then
        return false
    end
    if item:HasTag("ds_starter_manual_drop")
        or item:HasTag("INLIMBO")
        or item:HasTag("NOCLICK")
        or item:HasTag("fire")
    then
        return false
    end
    local x, y, z = item.Transform:GetWorldPosition()
    local water = IsWaterTileAt(x, y, z)
    local on_boat = IsOnBoat(player)
    if water == true and not on_boat then
        return false
    end
    if water == false and on_boat then
        return false
    end
    return true
end

local WorkQueue = Class(function(self, inst)
    self.inst = inst
    self.pending = {}
    self.queued = {}
    self.current = nil
    self.task = nil
    self.cooldown = 0
    self.last_click_target = nil
    self.last_click_time = 0
    self.last_finish_pos = nil
    self.pickup_scan = 0
    self.last_progress_time = 0
    self.last_progress_pos = nil
    self.last_block_time = 0

    self.inst:ListenForEvent("actionfailed", function(_, data)
        self:OnActionFailed(data)
    end)
end)

function WorkQueue:OnActionFailed(data)
    local job = self.current
    if job == nil or data == nil or data.action == nil then
        return
    end
    if data.action.target ~= job.target then
        return
    end
    job.failed = (job.failed or 0) + 1
    if job.failed >= 3 then
        self:FinishJob("blocked")
    end
end

function WorkQueue:IsRunning()
    return self.task ~= nil
end

function WorkQueue:Start()
    if self.task ~= nil then
        return
    end
    self.last_progress_pos = self.inst:GetPosition()
    self.task = self.inst:DoPeriodicTask(TICK_INTERVAL, function()
        self:Tick()
    end)
end

function WorkQueue:StopRunning()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
    local locomotor = self.inst.components.locomotor
    if locomotor ~= nil then
        locomotor:Stop()
    end
end

function WorkQueue:Say(en, zh)
    local talker = self.inst.components.talker
    if talker ~= nil and talker.Say ~= nil then
        talker:Say(L(en, zh))
    end
end

function WorkQueue:NoteClick(target)
    local now = GetTime()
    if target ~= nil
        and self.last_click_target == target
        and now - self.last_click_time <= DOUBLE_CLICK_TIME
    then
        self.last_click_target = nil
        self.last_click_time = 0
        return true
    end
    self.last_click_target = target
    self.last_click_time = now
    return false
end

-- Giving is only meaningful for NPCs and production structures such as the
-- bird cage. Other structures with a trader component (teleportato, lava
-- pool, fountains, wormholes, ...) must not enter the "give" queue.
local function CanGiveTo(target)
    if target == nil or target.components.trader == nil then
        return false
    end
    if target.prefab == "birdcage" or target.prefab == "sunken_boat" then
        return true
    end
    return target.HasTag ~= nil and not target:HasTag("structure")
end

function WorkQueue:Classify(target)
    if target == nil or not target:IsValid() or target:IsInLimbo() then
        return nil
    end
    if target.components.stewer ~= nil then
        return "cook"
    end
    if target.components.dryer ~= nil then
        return "dry"
    end
    if target.components.grower ~= nil then
        local grower = target.components.grower
        if not grower:IsEmpty()
            or target._ds_starter_last_seed ~= nil
        then
            return "plant"
        end
        if target._ds_starter_last_fertilizer ~= nil then
            return "fertilize"
        end
        return nil
    end
    if target.components.shopped ~= nil
        and target.components.shopdispenser ~= nil
    then
        return "shop"
    end
    if target.components.trader ~= nil then
        if CanGiveTo(target) then
            return "give"
        end
        return nil
    end
    if target.components.crop ~= nil then
        if target.components.crop:IsReadyForHarvest() then
            return "harvest"
        end
        if target._ds_starter_last_fertilizer ~= nil then
            return "fertilize"
        end
        return nil
    end
    if target.components.flotsamfisher ~= nil then
        if IsOnBoat(self.inst) then
            return "fish"
        end
        return nil
    end
    if target.components.fishable ~= nil then
        local x, y, z = target.Transform:GetWorldPosition()
        local water = IsWaterTileAt(x, y, z)
        if water == nil or water == IsOnBoat(self.inst) then
            return "fish"
        end
        return nil
    end
    if target.components.trap ~= nil then
        if target.components.trap:IsSprung() then
            return "trap"
        end
        return nil
    end
    if target.components.mine ~= nil and target.components.mine.issprung then
        return "trap"
    end
    -- Plain grass and saplings are pickable even though they also expose a
    -- shearable component; always pick them by hand first.
    if target.components.pickable ~= nil then
        if target.components.pickable.canbepicked then
            return "pick"
        end
        if target._ds_starter_last_fertilizer ~= nil then
            return "fertilize"
        end
        -- Do not return: a picked flippable/limpet rock can still be mined
        -- by an explicit second click.
    end
    local hackable = target.components.hackable
    local shearable = target.components.shearable
    if target.components.health == nil
        and ((hackable ~= nil and hackable:CanBeHacked())
            or (shearable ~= nil and shearable:CanShear()))
    then
        local action = self:ChooseHarvestAction(target)
        if ACTIONS.SHEAR ~= nil and action == ACTIONS.SHEAR then
            return "shear"
        end
        if ACTIONS.HACK ~= nil and action == ACTIONS.HACK then
            return "hack"
        end
        -- No tool: remember which kind of harvest this is so the queue can
        -- report the missing tool instead of falling through to DIG/MINE.
        if hackable ~= nil and hackable:CanBeHacked() then
            return "hack"
        end
        return "shear"
    end
    if target.components.workable ~= nil then
        local action = target.components.workable:GetWorkAction()
        if action == ACTIONS.NET then
            return "net"
        end
        if not IsAllowedWorkAction(target, action) then
            return nil
        end
        return "work"
    end
    if target.components.harvestable ~= nil then
        if target.components.harvestable:CanBeHarvested() then
            return "harvest"
        end
        return nil
    end
    if target.components.inventoryitem ~= nil
        and CanLooseItemBePicked(target, self.inst)
    then
        return "pickup"
    end
    return nil
end

function WorkQueue:GetBackpack()
    return GetTeamBag(self.inst.components.inventory)
end

function WorkQueue:EachItem(fn, include_equipped)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return
    end
    local seen = {}
    local function visit(item)
        if item ~= nil and item:IsValid() and not seen[item] then
            seen[item] = true
            return fn(item)
        end
    end
    -- The item held on the cursor is removed from itemslots, so it must be
    -- included explicitly or give/use actions cannot find it.
    local active = inventory.activeitem
    if active ~= nil then
        local ret = visit(active)
        if ret ~= nil then return ret end
    end
    for _, item in pairs(inventory.itemslots or {}) do
        local ret = visit(item)
        if ret ~= nil then return ret end
    end
    if include_equipped then
        for _, item in pairs(inventory.equipslots or {}) do
            local ret = visit(item)
            if ret ~= nil then return ret end
        end
    end
    local backpack = GetTeamBag(inventory)
    if backpack ~= nil and backpack.components.container ~= nil then
        for _, item in pairs(backpack.components.container.slots or {}) do
            local ret = visit(item)
            if ret ~= nil then return ret end
        end
    end
    local overflow = inventory.overflow
    if overflow ~= nil and overflow.components.container ~= nil then
        for _, item in pairs(overflow.components.container.slots or {}) do
            local ret = visit(item)
            if ret ~= nil then return ret end
        end
    end
end

function WorkQueue:CountPrefab(prefab)
    local count = 0
    self:EachItem(function(item)
        if item.prefab == prefab then
            if item.components.stackable ~= nil then
                count = count + item.components.stackable:StackSize()
            else
                count = count + 1
            end
        end
    end, false)
    return count
end

function WorkQueue:FindPrefab(prefab, include_equipped)
    return self:EachItem(function(item)
        if item.prefab == prefab then
            return item
        end
    end, include_equipped)
end

function WorkQueue:FindTool(action)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return nil
    end
    local hand = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if ToolCanDo(hand, action) then
        return hand
    end
    return self:EachItem(function(item)
        if ToolCanDo(item, action) then
            return item
        end
    end, false)
end

function WorkQueue:EnsureTool(action)
    local tool = self:FindTool(action)
    if tool == nil then
        return nil
    end
    local inventory = self.inst.components.inventory
    if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= tool then
        inventory:Equip(tool)
    end
    return tool
end

function WorkQueue:ChooseHarvestAction(target)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return nil
    end
    local hand = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    local hackable = target.components.hackable
    local shearable = target.components.shearable
    local can_hack = hackable ~= nil and hackable:CanBeHacked()
    local can_shear = shearable ~= nil and shearable:CanShear()
    if not can_hack and not can_shear then
        return nil
    end
    -- Tall grass: shears first, then machete / golden machete.
    if can_shear and self:FindTool(ACTIONS.SHEAR) ~= nil then
        return ACTIONS.SHEAR
    end
    if can_hack and self:FindTool(ACTIONS.HACK) ~= nil then
        return ACTIONS.HACK
    end
    return nil
end

function WorkQueue:EnsureRod()
    local inventory = self.inst.components.inventory
    local hand = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if hand ~= nil and hand.components.fishingrod ~= nil then
        return hand
    end
    local rod = self:EachItem(function(item)
        if item.components.fishingrod ~= nil then
            return item
        end
    end, false)
    if rod ~= nil then
        inventory:Equip(rod)
        return rod
    end
    return nil
end

function WorkQueue:HasRecipe(recipe)
    if recipe == nil or #recipe == 0 then
        return false
    end
    local wanted = {}
    for i = 1, #recipe do
        wanted[recipe[i]] = (wanted[recipe[i]] or 0) + 1
    end
    for prefab, count in pairs(wanted) do
        if self:CountPrefab(prefab) < count then
            return false
        end
    end
    return true
end

function WorkQueue:MakeJob(kind, target, extra)
    extra = extra or {}
    if kind == "cook" then
        local stewer = target.components.stewer
        if stewer ~= nil and stewer.done then
            return { kind = kind, target = target }
        end
        local recipe = extra.recipe or target._ds_starter_last_recipe
        local container = target.components.container
        local in_pot = 0
        if container ~= nil and container.slots ~= nil then
            for _, item in pairs(container.slots) do
                if item ~= nil then
                    in_pot = in_pot + 1
                end
            end
        end
        if in_pot >= 4 then
            return { kind = kind, target = target, recipe = {} }
        end
        if in_pot < 4 and (recipe == nil or #recipe == 0) then
            if not extra.silent then
                self:Say("This pot has no previous recipe.", "这个锅还没有上次配方。")
            end
            return nil
        end
        if in_pot < 4 and not self:HasRecipe(recipe) then
            if not extra.silent then
                self:Say("Missing ingredients for the last recipe.", "缺少上次配方的食材。")
            end
            return nil
        end
        return {
            kind = kind,
            target = target,
            recipe = CopyList(recipe),
        }
    elseif kind == "dry" then
        local dryer = target.components.dryer
        if dryer ~= nil and dryer:IsDone() then
            return { kind = kind, target = target }
        end
        local material = extra.material or target._ds_starter_last_dry
        if material == nil then
            if not extra.silent then
                self:Say("This dryer has no previous material.", "这个晾肉架还没有上次材料。")
            end
            return nil
        end
        if self:FindPrefab(material, false) == nil then
            if not extra.silent then
                self:Say("Missing the last dried material.", "缺少上次晾晒的材料。")
            end
            return nil
        end
        return { kind = kind, target = target, material = material }
    elseif kind == "plant" then
        local seed = extra.seed or target._ds_starter_last_seed
        local has_crop = false
        if target.components.grower ~= nil then
            for crop in pairs(target.components.grower.crops or {}) do
                if crop:IsValid() and crop.components.crop ~= nil then
                    has_crop = true
                    if crop.components.crop:IsReadyForHarvest() then
                        return { kind = kind, target = target, seed = seed }
                    end
                end
            end
        end
        if seed == nil then
            if has_crop then
                return { kind = kind, target = target }
            end
            if not extra.silent then
                self:Say("This plot has no previous seed.", "这块地还没有上次种子。")
            end
            return nil
        end
        if self:FindPrefab(seed, false) == nil and not has_crop then
            if not extra.silent then
                self:Say("Missing the last seed.", "缺少上次使用的种子。")
            end
            return nil
        end
        return { kind = kind, target = target, seed = seed }
    elseif kind == "fertilize" then
        local fertilizer = extra.fertilizer or target._ds_starter_last_fertilizer
        if fertilizer == nil then
            if not extra.silent then
                self:Say("No previous fertilizer is remembered.", "还没有上次使用的肥料记录。")
            end
            return nil
        end
        if self:FindPrefab(fertilizer, false) == nil then
            if not extra.silent then
                self:Say("Missing the last fertilizer.", "缺少上次使用的肥料。")
            end
            return nil
        end
        return { kind = kind, target = target, fertilizer = fertilizer }
    elseif kind == "give" then
        local gift = extra.gift
        if gift == nil then
            local inventory = self.inst.components.inventory
            local active = inventory ~= nil
                and inventory:GetActiveItem()
                or nil
            if active ~= nil then
                gift = active.prefab
            end
        end
        if gift == nil then
            gift = target._ds_starter_last_gift
        end
        if gift == nil then
            if not extra.silent then
                self:Say(
                    "Hold the item to give, or give this NPC an item once first.",
                    "请先拿起要给的物品，或先手动给这个 NPC 一次。"
                )
            end
            return nil
        end
        if self:FindPrefab(gift, false) == nil then
            if not extra.silent then
                self:Say("Missing the last gift item.", "缺少上次给予的物品。")
            end
            return nil
        end
        local trader = target.components.trader
        if trader ~= nil and trader.enabled == false then
            self:Say("This trader is not available.", "这个 NPC 现在不能交易。")
            return nil
        end
        return { kind = kind, target = target, gift = gift }
    elseif kind == "fish" then
        if self:EnsureRod() == nil then
            if not extra.silent then
                self:Say("No fishing rod available.", "没有可用的鱼竿。")
            end
            return nil
        end
        if target.components.flotsamfisher ~= nil and not IsOnBoat(self.inst) then
            self:Say("Get on a boat first.", "需要先上船。")
            return nil
        end
        return { kind = kind, target = target, cast_time = 0 }
    elseif kind == "shop" then
        local dispenser = target.components.shopdispenser
        if target:HasTag("justsellonce")
            and (dispenser == nil or dispenser:GetItem() == nil)
        then
            if not extra.silent then
                self:Say("This shop item is sold out.", "这个商品已经卖完了。")
            end
            return nil
        end
        return { kind = kind, target = target }
    elseif kind == "hack" or kind == "shear" then
        local action = self:ChooseHarvestAction(target)
        if action == nil then
            action = kind == "shear" and ACTIONS.SHEAR or ACTIONS.HACK
        end
        if action == nil or self:FindTool(action) == nil then
            if not extra.silent then
                self:Say("No usable tool for this job.", "没有可用的工具。")
            end
            return nil
        end
        return {
            kind = action == ACTIONS.SHEAR and "shear" or "hack",
            target = target,
            action = action,
        }
    elseif kind == "work" or kind == "net" then
        local workable = target.components.workable
        if workable == nil then
            return nil
        end
        local action = workable:GetWorkAction() or ACTIONS.CHOP
        if not IsAllowedWorkAction(target, action) then
            if not extra.silent then
                self:Say("This structure cannot be hammered by the queue.", "工作队列不能锤击这个建筑。")
            end
            return nil
        end
        if self:FindTool(action) == nil then
            if not extra.silent then
                self:Say("No usable tool for this job.", "没有可用的工具。")
            end
            return nil
        end
        return { kind = kind, target = target, action = action }
    end
    return { kind = kind, target = target }
end

function WorkQueue:Enqueue(target, extra)
    local kind = self:Classify(target)
    if kind == nil then
        return false
    end
    if not IsSameIsland(self.inst, target) then
        return false
    end

    if self.current ~= nil and self.current.target == target then
        self:CancelQueue()
        return true
    end
    for i = #self.pending, 1, -1 do
        if self.pending[i].target == target then
            self.queued[target] = nil
            table.remove(self.pending, i)
            if #self.pending == 0 and self.current == nil then
                self:StopRunning()
            end
            return true
        end
    end

    if #self.pending + (self.current ~= nil and 1 or 0) >= MAX_JOBS then
        self:Say("Work queue is full.", "工作队列已满。")
        return false
    end

    local job = self:MakeJob(kind, target, extra)
    if job == nil then
        return false
    end
    self.pending[#self.pending + 1] = job
    self.queued[target] = true
    if kind == "cook" then
        -- Queue nearby crock pots immediately instead of waiting for the
        -- first pot to finish.
        self:AddContinuation(job)
    end
    self:Start()
    return true
end

function WorkQueue:CancelQueue(quiet)
    local had_jobs = self.current ~= nil or #self.pending > 0
    self.pending = {}
    self.queued = {}
    self.current = nil
    self.cooldown = 0
    self.last_progress_pos = nil
    self:StopRunning()
    if had_jobs and not quiet then
        -- The queue is intentionally silent on manual cancellation.
    end
end

function WorkQueue:IsBusy()
    local player = self.inst
    if player.bufferedaction ~= nil then
        return true
    end
    local locomotor = player.components.locomotor
    if locomotor ~= nil and locomotor.bufferedaction ~= nil then
        return true
    end
    if player.sg ~= nil and player.sg:HasStateTag("busy") then
        return true
    end
    return false
end

function WorkQueue:DoAction(target, action, invobject)
    local pc = self.inst.components.playercontroller
    if pc == nil or action == nil then
        return false
    end
    local act = BufferedAction(self.inst, target, action, invobject)
    pc:DoAction(act)
    if self.current ~= nil then
        self.current.attempts = (self.current.attempts or 0) + 1
    end
    self.cooldown = GetTime() + ACTION_COOLDOWN
    return true
end

function WorkQueue:WalkTo(target, range, job)
    local player = self.inst
    local locomotor = player.components.locomotor
    if target == nil or not target:IsValid() then
        return false
    end
    local target_x, _, target_z = target.Transform:GetWorldPosition()
    local dist_sq = FlatDistSq(player, target)
    if dist_sq <= range * range then
        if locomotor:HasDestination() then
            locomotor:Stop()
        end
        if job ~= nil then
            job.walk_start = nil
            job.walk_dist = nil
            job.sidestep_until = nil
            job.walk_check_time = nil
        end
        return true
    end
    local now = GetTime()
    if job ~= nil and job.sidestep_until ~= nil then
        if now < job.sidestep_until then
            return false
        end
        job.sidestep_until = nil
    end
    local sg = player.sg
    local can_walk = sg == nil
        or ((sg:HasStateTag("idle") or sg:HasStateTag("moving"))
            and not sg:HasStateTag("busy")
            and not sg:HasStateTag("fishing")
            and not sg:HasStateTag("prefish"))
    if not locomotor:HasDestination() and can_walk then
        if job == nil
            or job.walk_retry_time == nil
            or now >= job.walk_retry_time
        then
            locomotor:GoToEntity(target, nil, false)
            if job ~= nil then
                job.walk_retry_time = now + 0.5
            end
        end
    end
    if job ~= nil then
        -- If the direct path is blocked (for example by a fence), try a
        -- short sidestep instead of continuing to push into the obstacle.
        if job.walk_check_time == nil then
            local px, _, pz = player.Transform:GetWorldPosition()
            job.walk_check_time = now
            job.walk_check_x, job.walk_check_z = px, pz
        elseif now - job.walk_check_time >= 1.0 then
            local px, _, pz = player.Transform:GetWorldPosition()
            local dx = px - (job.walk_check_x or px)
            local dz = pz - (job.walk_check_z or pz)
            if dx * dx + dz * dz < 0.25 and can_walk then
                local base_angle =
                    player:GetAngleToPoint(target_x, 0, target_z) * DEGREES
                local offsets = { 45, -45, 90, -90, 135, -135 }
                for i = 1, #offsets do
                    local angle = base_angle + offsets[i] * DEGREES
                    local offset = FindWalkableOffset(
                        Vector3(px, 0, pz),
                        angle,
                        3.5,
                        6,
                        true,
                        false
                    )
                    if offset ~= nil
                        and not IsWallNear(px + offset.x, pz + offset.z)
                    then
                        locomotor:Stop()
                        locomotor:GoToPoint(
                            Vector3(px + offset.x, 0, pz + offset.z),
                            nil,
                            false
                        )
                        job.sidestep_until = now + 0.9
                        break
                    end
                end
            end
            job.walk_check_time = now
            job.walk_check_x, job.walk_check_z = px, pz
        end
        if job.sidestep_until ~= nil then
            return false
        end
        local dist = math.sqrt(dist_sq)
        job.walk_start = job.walk_start or GetTime()
        job.walk_dist = job.walk_dist or dist
        if GetTime() - job.walk_start > 9 then
            if dist >= job.walk_dist - 0.4 then
                self:Say("Cannot reach the target.", "无法到达目标。")
                self:FinishJob("blocked")
                return false
            end
            job.walk_start = GetTime()
            job.walk_dist = dist
        end
    end
    return false
end

function WorkQueue:SailTo(target, job, stop_range)
    local player = self.inst
    stop_range = stop_range or WATER_RANGE
    if not IsOnBoat(player) then
        self:FinishJob("invalid")
        return false
    end
    local driver = player.components.driver
    local boat = driver ~= nil and driver.vehicle or nil
    if boat == nil or not boat:IsValid() then
        self:FinishJob("invalid")
        return false
    end
    if boat.components.container ~= nil
        and boat.components.container:IsOpen()
    then
        boat.components.container:Close(player)
    end

    local dist_sq = FlatDistSq(player, target)
    local locomotor = player.components.locomotor
    if dist_sq <= stop_range * stop_range then
        locomotor:Stop()
        if job ~= nil then
            job.sail_start = nil
            job.sail_dist = nil
        end
        return true
    end

    if job ~= nil then
        local dist = math.sqrt(dist_sq)
        job.sail_start = job.sail_start or GetTime()
        job.sail_dist = job.sail_dist or dist
        if GetTime() - job.sail_start > 5 then
            if dist >= job.sail_dist - 0.4 then
                self:Say("The boat cannot make progress.", "船无法继续前进。")
                self:FinishJob("blocked")
                return false
            end
            job.sail_start = GetTime()
            job.sail_dist = dist
        end
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local angle = player:GetAngleToPoint(tx, ty, tz)

    local map = GetWorld() ~= nil and GetWorld().Map or nil
    if map ~= nil and map.GetTileAtPoint ~= nil and map.IsWater ~= nil then
        local best = nil
        local offsets = { 0, 25, -25, 50, -50, 75, -75, 100, -100 }
        for i = 1, #offsets do
            local test_angle = angle + offsets[i]
            local rad = test_angle * DEGREES
            local dx = math.cos(rad)
            local dz = math.sin(rad)
            local clear = true
            for _, step in ipairs({ 3, 5.5 }) do
                local x = px + dx * step
                local z = pz + dz * step
                local tile = map:GetTileAtPoint(x, py, z)
                if not map:IsWater(tile) then
                    clear = false
                    break
                end
            end
            if clear then
                best = test_angle
                break
            end
        end
        if best == nil then
            locomotor:Stop()
            self:Say("The boat is blocked by land.", "船被陆地挡住了。")
            self:FinishJob("blocked")
            return false
        end
        angle = best
    end

    locomotor:RunInDirection(angle)
    self.cooldown = GetTime() + 0.15
    return false
end

function WorkQueue:IsJobValid(job)
    local target = job.target
    if target == nil or not target:IsValid() or target:IsInLimbo() then
        return false
    end
    if not IsSameIsland(self.inst, target) then
        return false
    end
    if job.kind == "work" then
        return target.components.workable ~= nil
            and target.components.workable:CanBeWorked()
    elseif job.kind == "net" then
        return target.components.workable ~= nil
            and target.components.workable:CanBeWorked()
    elseif job.kind == "hack" or job.kind == "shear" then
        local hackable = target.components.hackable
        local shearable = target.components.shearable
        return (hackable ~= nil and hackable:CanBeHacked())
            or (shearable ~= nil and shearable:CanShear())
    elseif job.kind == "pick" then
        return target.components.pickable ~= nil
            and target.components.pickable.canbepicked
    elseif job.kind == "harvest" then
        if target.components.crop ~= nil then
            return target.components.crop:IsReadyForHarvest()
        end
        return target.components.harvestable ~= nil
            and target.components.harvestable:CanBeHarvested()
    elseif job.kind == "trap" then
        if target.components.trap ~= nil then
            return target.components.trap:IsSprung()
        end
        return target.components.mine ~= nil
            and target.components.mine.issprung == true
    elseif job.kind == "fish" then
        local x, y, z = target.Transform:GetWorldPosition()
        local water = IsWaterTileAt(x, y, z)
        if water ~= nil then
            if IsOnBoat(self.inst) and water ~= true then
                return false
            end
            if not IsOnBoat(self.inst) and water == true then
                return false
            end
        end
        if target.components.fishable ~= nil then
            return target.components.fishable.fishleft > 0
                and not target.components.fishable:IsFrozenOver()
        end
        return target.components.flotsamfisher ~= nil
    elseif job.kind == "cook" then
        return target.components.stewer ~= nil
    elseif job.kind == "dry" then
        return target.components.dryer ~= nil
    elseif job.kind == "plant" then
        return target.components.grower ~= nil
            or target.components.crop ~= nil
    elseif job.kind == "fertilize" then
        return target.components.crop ~= nil
            or target.components.grower ~= nil
            or target.components.pickable ~= nil
    elseif job.kind == "give" then
        return target.components.trader ~= nil
    elseif job.kind == "shop" then
        return target.components.shopped ~= nil
            and target.components.shopdispenser ~= nil
    elseif job.kind == "pickup" then
        return CanLooseItemBePicked(target, self.inst)
    end
    return false
end

function WorkQueue:IsJobReady(job)
    local target = job.target
    if job.kind == "shop" then
        local dispenser = target.components.shopdispenser
        if dispenser == nil or dispenser:GetItem() == nil then
            return false
        end
        if target:HasTag("shopclosed") then
            return false
        end
        local clock = GetClock()
        if clock ~= nil and clock:IsNight() then
            return false
        end
        return true
    elseif job.kind == "cook" then
        local stewer = target.components.stewer
        return stewer ~= nil and (stewer.done or not stewer.cooking)
    elseif job.kind == "dry" then
        local dryer = target.components.dryer
        return dryer ~= nil and (dryer:IsDone() or not dryer:IsDrying())
    elseif job.kind == "plant" then
        local grower = target.components.grower
        if grower == nil then
            return false
        end
        if grower:IsEmpty() then
            return true
        end
        for crop in pairs(grower.crops or {}) do
            if crop:IsValid()
                and crop.components.crop ~= nil
                and crop.components.crop:IsReadyForHarvest()
            then
                return true
            end
        end
        return false
    end
    return true
end

function WorkQueue:DeferJob(job)
    self.current = nil
    self.pending[#self.pending + 1] = job
    self.cooldown = GetTime() + 0.5
end

function WorkQueue:PickNext()
    local player = self.inst
    local best = nil
    local best_sq = nil
    local i = 1
    while i <= #self.pending do
        local job = self.pending[i]
        local valid = self:IsJobValid(job)
        if valid and job.kind == "fish"
            and job.target.components.flotsamfisher ~= nil
            and not IsOnBoat(player)
        then
            valid = false
        end
        if not valid then
            self.queued[job.target] = nil
            table.remove(self.pending, i)
        elseif not self:IsJobReady(job) then
            i = i + 1
        else
            local dist_sq = FlatDistSq(player, job.target)
            if best == nil or dist_sq < best_sq then
                best = job
                best_sq = dist_sq
            end
            i = i + 1
        end
    end
    if best == nil then
        return nil
    end
    for i = 1, #self.pending do
        if self.pending[i] == best then
            table.remove(self.pending, i)
            break
        end
    end
    return best
end

function WorkQueue:AddContinuation(job)
    local player = self.inst
    local x, y, z = player.Transform:GetWorldPosition()
    local radius = VIEW_RADIUS
    if job.kind == "fish" and job.target.components.flotsamfisher ~= nil then
        radius = WATER_RADIUS
    end
    local allow_same = (job.kind == "cook"
        or job.kind == "dry"
        or job.kind == "plant")
        and not job.no_same
    local ents = TheSim:FindEntities(x, y, z, radius)
    for i = 1, #ents do
        local ent = ents[i]
        if (ent ~= job.target or allow_same)
            and not self.queued[ent]
            and ent ~= player
            and not ent:IsInLimbo()
            and IsInView(player, ent)
        then
            local kind = self:Classify(ent)
            if IsOnBoat(player) and kind ~= nil then
                local ex, ey, ez = ent.Transform:GetWorldPosition()
                local water = IsWaterTileAt(ex, ey, ez)
                if kind == "fish" then
                    if water ~= true
                        and ent.components.flotsamfisher == nil
                    then
                        kind = nil
                    end
                elseif water ~= true then
                    kind = nil
                end
            end
            local same = false
            if job.kind == "hack" or job.kind == "shear" then
                same = (kind == "hack" or kind == "shear")
                    and ent.prefab == job.target.prefab
            elseif kind ~= nil and kind == job.kind then
                if job.kind == "work" or job.kind == "net" then
                    same = ent.components.workable ~= nil
                        and ent.components.workable:GetWorkAction() == job.action
                        and ent.prefab == job.target.prefab
                    -- Digging grass roots / mining flippable rocks is a
                    -- deliberate follow-up click, not a queue-wide action.
                    if same and job.action == ACTIONS.DIG
                        and ent.components.hackable ~= nil
                    then
                        same = false
                    end
                    if same and job.action == ACTIONS.MINE
                        and ent.components.pickable ~= nil
                    then
                        same = false
                    end
                elseif job.kind == "pick" or job.kind == "harvest" then
                    same = ent.prefab == job.target.prefab
                elseif job.kind == "trap" then
                    same = ent.prefab == job.target.prefab
                elseif job.kind == "fish" then
                    same = true
                elseif job.kind == "cook" then
                    local stewer = ent.components.stewer
                    same = stewer ~= nil
                        and (stewer.done or not stewer.cooking)
                elseif job.kind == "dry" then
                    local dryer = ent.components.dryer
                    same = dryer ~= nil
                        and (dryer:IsDone() or not dryer:IsDrying())
                        and ent._ds_starter_last_dry ~= nil
                elseif job.kind == "plant" then
                    same = ent.components.grower ~= nil
                        and (ent._ds_starter_last_seed ~= nil
                            or next(ent.components.grower.crops or {}) ~= nil)
                elseif job.kind == "fertilize" then
                    same = ent._ds_starter_last_fertilizer ~= nil
                end
            end
            if same then
                local extra = { silent = true }
                if kind == "cook" then
                    extra.recipe = ent._ds_starter_last_recipe
                        or job.recipe
                end
                local new_job = self:MakeJob(kind, ent, extra)
                if new_job ~= nil then
                    self.pending[#self.pending + 1] = new_job
                    self.queued[ent] = true
                end
            end
        end
    end
end

function WorkQueue:FinishJob(reason)
    local job = self.current
    if job ~= nil then
        self.queued[job.target] = nil
        if reason == "blocked" or reason == "stuck" then
            job.no_same = true
        end
    end
    self.current = nil
    self.cooldown = GetTime() + 0.2
    if job ~= nil and reason ~= "cancel" then
        self.last_finish_pos = job.target
        if job.kind == "fertilize"
            and job.target:IsValid()
            and job.target.components.crop ~= nil
            and job.target.components.crop:IsReadyForHarvest()
            and not self.queued[job.target]
        then
            local harvest = self:MakeJob("harvest", job.target)
            if harvest ~= nil then
                self.pending[#self.pending + 1] = harvest
                self.queued[job.target] = true
            end
        end
        self:AddContinuation(job)
    end
end

function WorkQueue:ApproachForAction(job, range)
    local player = self.inst
    local target = job.target
    local x, y, z = target.Transform:GetWorldPosition()
    local water = IsWaterTileAt(x, y, z)
    if IsOnBoat(player) then
        if water == true then
            return self:SailTo(target, job, range or WATER_ACTION_RANGE)
        end
        -- Land targets can still be picked from a boat when the boat is
        -- already close enough; never sail onto land.
        if FlatDistSq(player, target) <= INTERACT_RANGE * INTERACT_RANGE then
            return true
        end
        self:FinishJob("invalid")
        return false
    end
    -- On foot, let the vanilla action system handle the target.  It will
    -- fail naturally for water-only targets; do not filter saplings/twigs
    -- by a possibly misleading water-tile check.
    return true
end

function WorkQueue:ExecuteWork(job)
    local target = job.target
    local workable = target.components.workable
    if workable == nil or not workable:CanBeWorked() then
        self:FinishJob("done")
        return
    end
    local action = workable:GetWorkAction() or job.action
    if action == ACTIONS.NET then
        job.kind = "net"
    end
    if not IsAllowedWorkAction(target, action) then
        self:Say("This structure cannot be hammered by the queue.", "工作队列不能锤击这个建筑。")
        self:FinishJob("invalid")
        return
    end
    if not self:ApproachForAction(job) then
        return
    end
    local tool = self:EnsureTool(action)
    if tool == nil then
        self:Say("No usable tool left.", "没有可用的工具了。")
        self:CancelQueue(true)
        return
    end
    self:DoAction(target, action, tool)
end

function WorkQueue:ExecutePick(job)
    local pickable = job.target.components.pickable
    if pickable == nil or not pickable.canbepicked then
        self:FinishJob("done")
        return
    end
    if not self:ApproachForAction(job) then
        return
    end
    self:DoAction(job.target, ACTIONS.PICK)
end

function WorkQueue:ExecuteHarvest(job)
    local target = job.target
    if target.components.crop ~= nil then
        if not target.components.crop:IsReadyForHarvest() then
            self:FinishJob("done")
            return
        end
    elseif target.components.harvestable ~= nil then
        if not target.components.harvestable:CanBeHarvested() then
            self:FinishJob("done")
            return
        end
    else
        self:FinishJob("done")
        return
    end
    if not self:ApproachForAction(job) then
        return
    end
    self:DoAction(target, ACTIONS.HARVEST)
end

function WorkQueue:ExecuteHarvestWithTool(job)
    local target = job.target
    local action = self:ChooseHarvestAction(target)
    if action == nil then
        self:Say("No usable tool left.", "没有可用的工具了。")
        self:CancelQueue(true)
        return
    end
    job.action = action
    job.kind = action == ACTIONS.SHEAR and "shear" or "hack"
    if not self:ApproachForAction(job) then
        return
    end
    local tool = self:EnsureTool(action)
    if tool == nil then
        self:Say("No usable tool left.", "没有可用的工具了。")
        self:CancelQueue(true)
        return
    end
    self:DoAction(target, action, tool)
end

function WorkQueue:ExecuteTrap(job)
    local target = job.target
    if not self:ApproachForAction(job) then
        return
    end
    if target.components.trap ~= nil and target.components.trap:IsSprung() then
        self:DoAction(target, ACTIONS.CHECKTRAP)
        return
    end
    if target.components.mine ~= nil and target.components.mine.issprung then
        self:DoAction(target, ACTIONS.RESETMINE)
        return
    end
    self:FinishJob("done")
end

function WorkQueue:ExecutePickup(job)
    local item = job.target
    if not CanLooseItemBePicked(item, self.inst) then
        self:FinishJob("done")
        return
    end
    local x, y, z = item.Transform:GetWorldPosition()
    local water = IsWaterTileAt(x, y, z)
    if IsOnBoat(self.inst) then
        if water == true then
            if not self:SailTo(item, job, WATER_ACTION_RANGE) then
                return
            end
        else
            self:FinishJob("invalid")
            return
        end
    elseif water == true then
        self:FinishJob("invalid")
        return
    end
    self:DoAction(item, ACTIONS.PICKUP)
end

function WorkQueue:ExecuteFish(job)
    local target = job.target
    local rod = self:EnsureRod()
    if rod == nil then
        self:Say("No fishing rod left.", "没有可用的鱼竿了。")
        self:CancelQueue(true)
        return
    end
    local fishingrod = rod.components.fishingrod
    if fishingrod == nil then
        self:FinishJob("invalid")
        return
    end
    if fishingrod:IsFishing() then
        if fishingrod.target ~= target then
            fishingrod:StopFishing()
            return
        end
        if fishingrod:HasHookedFish() or fishingrod:FishIsBiting() then
            self:DoAction(target, ACTIONS.REEL, rod)
        elseif (job.cast_time or 0) > 0
            and GetTime() - job.cast_time > ACTION_WAIT
        then
            self:DoAction(target, ACTIONS.REEL, rod)
            job.cast_time = GetTime()
        end
        return
    end

    if target.components.flotsamfisher ~= nil and not IsOnBoat(self.inst) then
        self:FinishJob("invalid")
        return
    end
    if not IsOnBoat(self.inst) and target.components.fishable ~= nil then
        if not self:WalkTo(target, INTERACT_RANGE, job) then
            return
        end
    elseif IsOnBoat(self.inst) then
        if not self:SailTo(target, job) then
            return
        end
    end

    if target.components.fishable ~= nil
        and target.components.fishable.fishleft <= 0
    then
        self:FinishJob("done")
        return
    end
    if target.components.flotsamfisher ~= nil
        and target.components.flotsamfisher.lootleft <= 0
    then
        self:FinishJob("done")
        return
    end

    local action = target.components.flotsamfisher ~= nil
        and ACTIONS.FISHOCEAN
        or ACTIONS.FISH
    self:DoAction(target, action, rod)
    job.cast_time = GetTime()
end

function WorkQueue:ExecuteCook(job)
    local pot = job.target
    local stewer = pot.components.stewer
    if stewer == nil then
        self:FinishJob("invalid")
        return
    end

    if stewer.done then
        if not self:WalkTo(pot, INTERACT_RANGE, job) then
            return
        end
        job.phase = "harvest"
        self:DoAction(pot, ACTIONS.HARVEST)
        return
    end
    if job.phase == "harvest" then
        self:FinishJob("done")
        return
    end
    if stewer.cooking then
        self:DeferJob(job)
        return
    end
    if pot:HasTag("burnt") then
        self:FinishJob("invalid")
        return
    end

    local container = pot.components.container
    if container == nil then
        self:FinishJob("invalid")
        return
    end
    if not self:WalkTo(pot, INTERACT_RANGE, job) then
        return
    end

    local recipe = job.recipe
    if recipe == nil then
        recipe = pot._ds_starter_last_recipe
    end

    local in_pot = 0
    for _, item in pairs(container.slots or {}) do
        if item ~= nil then
            in_pot = in_pot + 1
        end
    end
    if recipe == nil or #recipe == 0 then
        if in_pot >= 4 and stewer:CanCook() then
            stewer:StartCooking()
            self.cooldown = GetTime() + 0.5
        else
            self:FinishJob("missing")
        end
        return
    end

    job.attempts = (job.attempts or 0) + 1
    local wanted = {}
    for i = 1, #recipe do
        wanted[recipe[i]] = (wanted[recipe[i]] or 0) + 1
    end

    local existing = {}
    for _, item in pairs(container.slots or {}) do
        if item ~= nil then
            existing[item.prefab] = (existing[item.prefab] or 0) + 1
        end
    end
    for prefab, count in pairs(existing) do
        if wanted[prefab] == nil then
            self:Say("The pot has other ingredients.", "锅里已经有别的食材。")
            self:FinishJob("missing")
            return
        end
    end

    for prefab, count in pairs(wanted) do
        local have = existing[prefab] or 0
        for _ = have + 1, count do
            local item = self:FindPrefab(prefab, false)
            if item == nil then
                self:Say("Missing ingredients for the last recipe.", "缺少上次配方的食材。")
                self:FinishJob("missing")
                return
            end
            local food = TakeOne(self.inst, item)
            if food == nil or not container:GiveItem(food) then
                GiveBack(self.inst, food)
                self:FinishJob("missing")
                return
            end
        end
    end

    if stewer:CanCook() then
        stewer:StartCooking()
        self.cooldown = GetTime() + 0.5
    end
end

function WorkQueue:ExecuteDry(job)
    local dryer = job.target.components.dryer
    if dryer == nil then
        self:FinishJob("invalid")
        return
    end
    if dryer:IsDone() then
        if not self:WalkTo(job.target, INTERACT_RANGE, job) then
            return
        end
        job.phase = "harvest"
        self:DoAction(job.target, ACTIONS.HARVEST)
        return
    end
    if job.phase == "harvest" then
        self:FinishJob("done")
        return
    end
    if dryer:IsDrying() then
        self:DeferJob(job)
        return
    end
    if not self:WalkTo(job.target, INTERACT_RANGE, job) then
        return
    end
    if job.material == nil then
        job.material = job.target._ds_starter_last_dry
    end
    if job.material == nil then
        self:FinishJob("missing")
        return
    end
    job.attempts = (job.attempts or 0) + 1
    local item = self:FindPrefab(job.material, false)
    if item == nil then
        self:Say("Missing the last dried material.", "缺少上次晾晒的材料。")
        self:FinishJob("missing")
        return
    end
    local dry_item = TakeOne(self.inst, item)
    if dry_item == nil then
        self:FinishJob("missing")
        return
    end
    if not dryer:StartDrying(dry_item) then
        GiveBack(self.inst, dry_item)
        self:Say("The dryer refused the material.", "晾肉架无法放入该材料。")
        self:FinishJob("missing")
    end
    self.cooldown = GetTime() + 0.4
end

function WorkQueue:ExecutePlant(job)
    local target = job.target
    local grower = target.components.grower
    if grower == nil then
        self:FinishJob("invalid")
        return
    end

    local ready_crop = nil
    for crop in pairs(grower.crops or {}) do
        if crop:IsValid() and crop.components.crop ~= nil
            and crop.components.crop:IsReadyForHarvest()
        then
            ready_crop = crop
            break
        end
    end
    if ready_crop ~= nil then
        if not self:WalkTo(ready_crop, INTERACT_RANGE, job) then
            return
        end
        ready_crop.components.crop:Harvest(self.inst)
        job.phase = "harvest"
        self.cooldown = GetTime() + 0.3
        return
    end

    if job.phase == "harvest" and grower:IsEmpty() then
        self:FinishJob("done")
        return
    end
    if not grower:IsEmpty() then
        self:DeferJob(job)
        return
    end
    if not self:WalkTo(target, INTERACT_RANGE, job) then
        return
    end

    if job.seed == nil then
        job.seed = target._ds_starter_last_seed
    end
    if job.seed == nil then
        self:FinishJob("missing")
        return
    end
    job.attempts = (job.attempts or 0) + 1
    local seed = self:FindPrefab(job.seed, false)
    if seed == nil then
        self:Say("Missing the last seed.", "缺少上次使用的种子。")
        self:FinishJob("missing")
        return
    end
    local seed_item = TakeOne(self.inst, seed)
    if seed_item == nil then
        self:FinishJob("missing")
        return
    end
    if not grower:PlantItem(seed_item) then
        GiveBack(self.inst, seed_item)
        self:Say("The plot refused the seed.", "这块地无法种下该种子。")
        self:FinishJob("missing")
        return
    end
    self.cooldown = GetTime() + 0.4
end

function WorkQueue:ExecuteFertilize(job)
    local target = job.target
    local fertilizer = job.fertilizer or target._ds_starter_last_fertilizer
    if fertilizer == nil then
        self:FinishJob("missing")
        return
    end

    local needs = false
    if target.components.crop ~= nil then
        needs = not target.components.crop:IsReadyForHarvest()
    elseif target.components.grower ~= nil then
        needs = target.components.grower:IsEmpty()
            and not target.components.grower:IsFullFertile()
    elseif target.components.pickable ~= nil then
        needs = target.components.pickable:CanBeFertilized()
    end
    if not needs then
        self:FinishJob("done")
        return
    end
    if not self:WalkTo(target, INTERACT_RANGE, job) then
        return
    end

    job.attempts = (job.attempts or 0) + 1
    local item = self:FindPrefab(fertilizer, false)
    if item == nil then
        self:Say("Missing the last fertilizer.", "缺少上次使用的肥料。")
        self:FinishJob("missing")
        return
    end

    local ok = false
    local one = TakeOne(self.inst, item)
    if one == nil then
        self:FinishJob("missing")
        return
    end
    if target.components.crop ~= nil then
        ok = target.components.crop:Fertilize(one)
    elseif target.components.grower ~= nil then
        target.components.grower:Fertilize(one)
        ok = true
    elseif target.components.pickable ~= nil then
        target.components.pickable:Fertilize(one)
        ok = true
    end
    if not ok then
        GiveBack(self.inst, one)
        self:FinishJob("missing")
        return
    end
    self.cooldown = GetTime() + 0.35
end

function WorkQueue:ExecuteShop(job)
    local target = job.target
    local dispenser = target.components.shopdispenser
    if dispenser == nil or target.components.shopped == nil then
        self:FinishJob("invalid")
        return
    end
    if target:HasTag("justsellonce") and job.bought_once then
        self:FinishJob("done")
        return
    end
    if dispenser:GetItem() == nil then
        self:DeferJob(job)
        return
    end
    if target:HasTag("shopclosed") then
        self:DeferJob(job)
        return
    end
    local clock = GetClock()
    if clock ~= nil and clock:IsNight() then
        self:DeferJob(job)
        return
    end
    local shopper = self.inst.components.shopper
    if shopper == nil then
        self:Say("This character cannot shop.", "当前角色无法购买。")
        self:FinishJob("invalid")
        return
    end
    if not shopper:CanPayFor(target) then
        self:Say("Not enough coins or goods.", "金币或商品不够。")
        self:FinishJob("missing")
        return
    end
    if not self:WalkTo(target, NPC_RANGE, job) then
        return
    end
    job.bought_once = true
    self:DoAction(target, ACTIONS.SHOP)
end

function WorkQueue:ExecuteGive(job)
    local target = job.target
    local trader = target.components.trader
    if trader == nil or trader.enabled == false then
        self:FinishJob("invalid")
        return
    end
    if not self:WalkTo(target, NPC_RANGE, job) then
        return
    end
    if job.gift == nil then
        job.gift = target._ds_starter_last_gift
    end
    job.attempts = (job.attempts or 0) + 1
    local item = self:FindPrefab(job.gift, false)
    if item == nil then
        self:FinishJob("missing")
        return
    end
    if not trader:CanAccept(item) then
        self:Say("This trader will not accept that item now.", "这个 NPC 现在不收这个物品。")
        self:FinishJob("missing")
        return
    end
    if not trader:AcceptGift(self.inst, item) then
        self:FinishJob("missing")
        return
    end
    self.cooldown = GetTime() + 0.4
end

function WorkQueue:Execute(job)
    if job.kind == "work" or job.kind == "net" then
        self:ExecuteWork(job)
    elseif job.kind == "hack" or job.kind == "shear" then
        self:ExecuteHarvestWithTool(job)
    elseif job.kind == "pick" then
        self:ExecutePick(job)
    elseif job.kind == "harvest" then
        self:ExecuteHarvest(job)
    elseif job.kind == "trap" then
        self:ExecuteTrap(job)
    elseif job.kind == "fish" then
        self:ExecuteFish(job)
    elseif job.kind == "cook" then
        self:ExecuteCook(job)
    elseif job.kind == "dry" then
        self:ExecuteDry(job)
    elseif job.kind == "plant" then
        self:ExecutePlant(job)
    elseif job.kind == "fertilize" then
        self:ExecuteFertilize(job)
    elseif job.kind == "give" then
        self:ExecuteGive(job)
    elseif job.kind == "shop" then
        self:ExecuteShop(job)
    elseif job.kind == "pickup" then
        self:ExecutePickup(job)
    else
        self:FinishJob("invalid")
    end
end

function WorkQueue:Tick()
    local player = self.inst
    if player == nil or not player:IsValid() then
        self:CancelQueue(true)
        return
    end
    if player:HasTag("playerghost") or player:HasTag("isdead") then
        self:CancelQueue(true)
        return
    end
    local health = player.components.health
    if health ~= nil and health:IsDead() then
        self:CancelQueue(true)
        return
    end

    if self.cooldown > GetTime() then
        return
    end
    if self:IsBusy() then
        return
    end

    if self.current == nil then
        self.current = self:PickNext()
        if self.current == nil then
            if #self.pending == 0 then
                self:StopRunning()
            else
                self.cooldown = GetTime() + 1
            end
            return
        end
        self.last_progress_time = GetTime()
        self.last_progress_pos = player:GetPosition()
    end

    local job = self.current
    if not self:IsJobValid(job) then
        self:FinishJob("invalid")
        return
    end
    if IsOnBoat(player)
        and (job.kind == "cook"
            or job.kind == "dry"
            or job.kind == "plant"
            or job.kind == "fertilize"
            or job.kind == "give"
            or job.kind == "shop")
    then
        self:FinishJob("invalid")
        return
    end
    local attempt_limit = 80
    if job.kind == "fertilize" or job.kind == "plant" then
        attempt_limit = 320
    end
    if job.attempts ~= nil and job.attempts > attempt_limit then
        self:FinishJob("stuck")
        return
    end

    if job.kind == "fish"
        and job.target.components.flotsamfisher ~= nil
        and not IsOnBoat(player)
    then
        self:FinishJob("invalid")
        return
    end

    local blink_range = (job.kind == "give" or job.kind == "shop")
        and NPC_RANGE
        or INTERACT_RANGE
    if TryBlinkToward(self, job.target, blink_range, job) then
        return
    end

    self:Execute(job)
end

function WorkQueue:GetLabels()
    local labels = {}
    local function add(job)
        if job == nil then return end
        local label = L("Work", "工作")
        if job.kind == "pick" then
            label = L("Pick", "采摘")
        elseif job.kind == "harvest" then
            label = L("Harvest", "收获")
        elseif job.kind == "trap" then
            label = L("Trap", "收陷阱")
        elseif job.kind == "net" then
            label = L("Catch", "捕虫")
        elseif job.kind == "hack" or job.kind == "shear" then
            label = job.kind == "shear"
                and L("Shear", "剪取")
                or L("Cut", "割草")
        elseif job.kind == "fish" then
            label = L("Fish", "钓鱼")
        elseif job.kind == "cook" then
            label = L("Cook", "烹饪")
        elseif job.kind == "dry" then
            label = L("Dry", "晾晒")
        elseif job.kind == "plant" then
            label = L("Plant", "种植")
        elseif job.kind == "fertilize" then
            label = L("Fertilize", "施肥")
        elseif job.kind == "give" then
            label = L("Give", "给予")
        elseif job.kind == "shop" then
            label = L("Buy", "购买")
        elseif job.kind == "pickup" then
            label = L("Pick up", "拾取")
        elseif job.kind == "work" then
            if job.action == ACTIONS.CHOP then
                label = L("Chop", "砍伐")
            elseif job.action == ACTIONS.MINE then
                label = L("Mine", "挖矿")
            elseif job.action == ACTIONS.DIG then
                label = L("Dig", "挖掘")
            elseif job.action == ACTIONS.HAMMER then
                label = L("Hammer", "锤击")
            end
        end
        labels[#labels + 1] = label
    end
    add(self.current)
    for i = 1, #self.pending do
        add(self.pending[i])
    end
    return labels
end

function WorkQueue:GetStatus()
    local labels = self:GetLabels()
    return {
        running = #labels > 0,
        total = #labels,
        current = labels[1],
        next = labels[2],
        lines = labels,
    }
end

function WorkQueue:OnLoad(data)
    self:CancelQueue(true)
    self:Start()
end

return WorkQueue
