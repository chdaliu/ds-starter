-- DS-Starter (Don't Starve single-player)
-- Features:
--   1. No spoilage for all perishable items.
--   2. No durability loss for tools, weapons, and armor.
--   3. A 64-slot altar container. Gems and amulets stored inside grant
--      effects: purple = +5% all stats (max +200%), red = heat/burn
--      resistance, blue = cold/freeze resistance (max 100%), yellow =
--      glimmer radius, orange = auto-collect radius. Removing items lowers
--      the effect; destroying the altar drops everything and refunds half
--      the recipe.
--   4. Health lock: when health reaches 1, the player becomes invincible.
--
-- Every feature can be toggled from the mod configuration menu.

local function Config(name, default)
    local value = GetModConfigData(name)
    if value == nil then
        return default
    end
    return value
end

local NO_SPOILAGE = Config("NO_SPOILAGE", false)
local NO_DURABILITY = Config("NO_DURABILITY", false)
local NO_FUEL_CONSUMPTION = Config("NO_FUEL_CONSUMPTION", false)
local SACRIFICE_GROWTH = Config("SACRIFICE_GROWTH", false)
local HEALTH_LOCK = Config("HEALTH_LOCK", false)
local INFINITE_BACKPACK = Config("INFINITE_BACKPACK", false)
local AUTO_COLLECT = Config("AUTO_COLLECT", false)
local FIVE_SLOTS = Config("FIVE_SLOTS", false)
local YINXUE_SWORD = Config("YINXUE_SWORD", false)
local TELEPORT = Config("TELEPORT", false)
local TELEPORT_SHORTCUT = Config("TELEPORT_SHORTCUT", "MOUSE_SHIFT")
local GLIMMER = Config("GLIMMER", false)
local INSTANT_FISH = Config("INSTANT_FISH", false)
local STACK_9999 = Config("STACK_9999", false)

-- Follow the game language. Chinese is detected from the active locale, with
-- fallbacks for older builds that only expose LanguageTranslator.
local function IsChinese()
    local code = nil
    if GLOBAL.LOC ~= nil and GLOBAL.LOC.GetLocaleCode ~= nil then
        local ok, value = GLOBAL.pcall(GLOBAL.LOC.GetLocaleCode)
        if ok then
            code = value
        end
    end
    if code == nil and GLOBAL.LanguageTranslator ~= nil then
        code = GLOBAL.LanguageTranslator.defaultlang
    end
    if code == nil then
        return false
    end
    code = string.lower(tostring(code))
    return code == "zh" or code == "zhr" or code == "zht"
        or code == "ch" or code == "chs"
        or string.sub(code, 1, 2) == "zh"
end

local function L(en, zh)
    if IsChinese() then
        return zh
    end
    return en
end

-- UI atlases used by the five-slot equipment bar are loaded up front, before
-- the HUD is built.
Assets = {
    Asset("ATLAS", "images/inventoryimages/ds_starter_slot_backpack.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_slot_backpack.tex"),
    Asset("ATLAS", "images/inventoryimages/ds_starter_slot_amulet.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_slot_amulet.tex"),
}

-- Custom item/recipe icons are authored at 128px while vanilla inventory
-- images are 64px, so scale them down wherever they appear. Keep this
-- independent of the feature toggles: the backpack can be enabled without
-- the sword, and the altar recipe can exist on its own.
local CUSTOM_ICON_PREFABS = {
    ds_starter_yinxue_sword = true,
    ds_starter_infinite_backpack = true,
}
local CUSTOM_ICON_IMAGES = {
    ["ds_starter_yinxue_sword.tex"] = true,
    ["ds_starter_infinite_backpack.tex"] = true,
    ["ds_starter_altar.tex"] = true,
}

AddClassPostConstruct("widgets/itemtile", function(self)
    if self.item ~= nil and CUSTOM_ICON_PREFABS[self.item.prefab] then
        self:SetBaseScale(0.5)
    end
end)

AddClassPostConstruct("widgets/recipetile", function(self)
    local old_set_visual = self.SetVisual
    if old_set_visual ~= nil then
        self.SetVisual = function(tile, atlas, image)
            old_set_visual(tile, atlas, image)
            if image ~= nil and CUSTOM_ICON_IMAGES[image] then
                tile.img:SetScale(0.5, 0.5)
            end
        end
    end
end)

-- Always add the flags component, even while individual features are off, so
-- the "sword already granted" flag survives feature toggles.
AddPlayerPostInit(function(inst)
    if inst.components.ds_starter_flags == nil then
        inst:AddComponent("ds_starter_flags")
    end
end)

AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(1, function()
        -- Establish a fresh baseline so loading a save does not immediately
        -- trigger the altar-change prompt.
        GLOBAL.DS_STARTER_LAST_ALTAR_COUNTS = nil
        GLOBAL.DSStarterRecalculateAltarEffects()
    end)
end)

-- When a grantable feature is turned off, clear its "already granted" marker.
-- Turning it back on then re-grants the item on the next load. While the
-- feature stays enabled the marker is kept, so a lost item is not replaced.
AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0, function()
        local flags = inst.components.ds_starter_flags
        if flags == nil then
            return
        end
        if not YINXUE_SWORD then
            flags:ResetSwordGranted()
        end
        if not INFINITE_BACKPACK then
            flags:ResetBackpackGranted()
        end
    end)
end)

-- Vanilla OnItemEquip assumes the inventory bar has already been rebuilt.
-- Items granted on spawn (the sword/backpack) can be equipped in the same
-- tick, before that first rebuild, which would index a nil slot and crash.
-- Defer the tile update in that case; the pending rebuild will pick the
-- item up from the inventory.
AddClassPostConstruct("widgets/inventorybar", function(self)
    local old_on_item_equip = self.OnItemEquip
    if old_on_item_equip == nil then
        return
    end

    self.OnItemEquip = function(inv, item, slot)
        if inv.equip == nil or inv.equip[slot] == nil then
            inv.rebuild_pending = true
            return
        end
        return old_on_item_equip(inv, item, slot)
    end
end)

-- Declare shared globals early: single-player runs strict.lua, which errors
-- when an undeclared global is read.
GLOBAL.DS_STARTER_RENAME_DIALOG = false
GLOBAL.DSStarterRefreshPanel = false

local function IsRenaming()
    local dialog = GLOBAL.DS_STARTER_RENAME_DIALOG
    return dialog ~= nil and dialog ~= false
end

-- Single-player does not expose ThePlayer/TheWorld globals; the game uses
-- GetPlayer()/GetWorld(). Fall back to rawget for builds that do have them.
local function GetThePlayer()
    if GLOBAL.GetPlayer ~= nil then
        return GLOBAL.GetPlayer()
    end
    return GLOBAL.rawget(GLOBAL, "ThePlayer")
end

local function GetTheWorld()
    if GLOBAL.GetWorld ~= nil then
        return GLOBAL.GetWorld()
    end
    return GLOBAL.rawget(GLOBAL, "TheWorld")
end

-- All altars currently in the world. Their stored items are the source of
-- the player's altar-derived bonuses.
GLOBAL.DS_STARTER_ALTARS = {}
-- Declared in the main chunk so strict.lua allows writes from callbacks.
GLOBAL.DS_STARTER_LAST_ALTAR_COUNTS = nil

-- Text-only feedback when the altar contents actually change. The HUD's
-- health/hunger/sanity sounds are deliberately not used here.
GLOBAL.DSStarterAltarBonusPrompt = function(player)
    if player == nil
        or not player:IsValid()
        or player.components.talker == nil
    then
        return
    end

    player.components.talker:Say(L(
        "The altar's effects have been updated.",
        "祭坛效果已更新。"
    ))
end

GLOBAL.DSStarterRecalculateAltarEffects = function()
    local player = GLOBAL.GetPlayer ~= nil and GLOBAL.GetPlayer() or nil
    if player == nil or not player:IsValid() then
        return
    end

    local counts = {
        purplegem = 0,
        redgem = 0,
        bluegem = 0,
        yellowamulet = 0,
        orangeamulet = 0,
    }

    local altars = GLOBAL.DS_STARTER_ALTARS or {}
    for altar in pairs(altars) do
        if altar:IsValid() and altar.components.container ~= nil then
            for _, item in pairs(altar.components.container.slots or {}) do
                if item ~= nil and counts[item.prefab] ~= nil then
                    local amount = 1
                    if item.components.stackable ~= nil then
                        amount = item.components.stackable:StackSize()
                    end
                    counts[item.prefab] = counts[item.prefab] + amount
                end
            end
        end
    end

    local growth = player.components.ds_starter_growth
    if growth ~= nil then
        growth:SetBonuses(
            math.min(counts.purplegem, 40),
            math.min(counts.redgem, 20),
            math.min(counts.bluegem, 20)
        )
    end

    local glimmer = player.components.ds_starter_glimmer
    if glimmer ~= nil then
        glimmer:SetRadius(
            2 + math.min(counts.yellowamulet, 12) * 0.5
        )
    end

    local autocollect = player.components.ds_starter_autocollect
    if autocollect ~= nil then
        autocollect:SetRadius(
            4 + math.min(counts.orangeamulet, 12) * 0.5
        )
    end

    local last = GLOBAL.DS_STARTER_LAST_ALTAR_COUNTS
    local changed = last ~= nil and (
        last.purplegem ~= counts.purplegem
        or last.redgem ~= counts.redgem
        or last.bluegem ~= counts.bluegem
        or last.yellowamulet ~= counts.yellowamulet
        or last.orangeamulet ~= counts.orangeamulet
    )
    GLOBAL.DS_STARTER_LAST_ALTAR_COUNTS = {
        purplegem = counts.purplegem,
        redgem = counts.redgem,
        bluegem = counts.bluegem,
        yellowamulet = counts.yellowamulet,
        orangeamulet = counts.orangeamulet,
    }

    if changed then
        GLOBAL.DSStarterAltarBonusPrompt(player)
    end
end

-- Single-player reads PrefabFiles from the mod environment, not modinfo.
PrefabFiles = {
    "ds_starter_altar",
    "ds_starter_infinite_backpack",
    "ds_starter_yinxue_sword",
    "ds_starter_glow",
}

Assets = {
    Asset("ATLAS", "images/inventoryimages/ds_starter_infinite_backpack.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_infinite_backpack.tex"),
}

-- The altar always uses its own 8x8 container UI, even when the related
-- feature toggles are off (an altar may already exist in a saved world).
modimport("scripts/widgets/ds_starter_altar_container.lua")

local manual_drop_in_progress = false

-- Items that must not be carried into another world. The eyebone, Lucy,
-- Abigail's flower and other irreplaceable personal items are intentionally
-- not filtered; only world-progression items belong here.
if INFINITE_BACKPACK then
    local WORLD_LOCKED_TAGS = { "teleportato_part" }
    local WORLD_LOCKED_PREFABS = {}

    local function IsWorldLocked(item)
        if item == nil or not item:IsValid() then
            return false
        end
        for i = 1, #WORLD_LOCKED_TAGS do
            if item:HasTag(WORLD_LOCKED_TAGS[i]) then
                return true
            end
        end
        for i = 1, #WORLD_LOCKED_PREFABS do
            if item.prefab == WORLD_LOCKED_PREFABS[i] then
                return true
            end
        end
        return false
    end

    local function StripContainer(container, removed)
        if container == nil or container.slots == nil then
            return
        end

        local pending = {}
        for slot, item in pairs(container.slots) do
            if item ~= nil then
                if IsWorldLocked(item) then
                    pending[#pending + 1] = { slot = slot, item = item }
                elseif item.components ~= nil
                    and item.components.container ~= nil
                then
                    StripContainer(item.components.container, removed)
                end
            end
        end

        for i = 1, #pending do
            local entry = pending[i]
            container:RemoveItemBySlot(entry.slot)
            removed[#removed + 1] = entry.item.prefab
            if entry.item:IsValid() then
                entry.item:Remove()
            end
        end
    end

    AddComponentPostInit("inventory", function(self)
        local old_on_save = self.OnSave
        if old_on_save == nil then
            return
        end

        self.OnSave = function(inv)
            local owner = inv.inst
            if owner ~= nil
                and owner:HasTag("player")
                and owner.is_teleporting
            then
                local removed = {}

                local pending_items = {}
                for _, item in pairs(inv.itemslots or {}) do
                    if item ~= nil then
                        if IsWorldLocked(item) then
                            pending_items[#pending_items + 1] = item
                        elseif item.components ~= nil
                            and item.components.container ~= nil
                        then
                            StripContainer(item.components.container, removed)
                        end
                    end
                end
                for i = 1, #pending_items do
                    local item = pending_items[i]
                    inv:RemoveItem(item, true)
                    removed[#removed + 1] = item.prefab
                    if item:IsValid() then
                        item:Remove()
                    end
                end

                local pending_equips = {}
                for eslot, item in pairs(inv.equipslots or {}) do
                    if item ~= nil then
                        if IsWorldLocked(item) then
                            pending_equips[#pending_equips + 1] = {
                                slot = eslot,
                                item = item,
                            }
                        elseif item.components ~= nil
                            and item.components.container ~= nil
                        then
                            StripContainer(item.components.container, removed)
                        end
                    end
                end
                for i = 1, #pending_equips do
                    local entry = pending_equips[i]
                    inv:Unequip(entry.slot)
                    removed[#removed + 1] = entry.item.prefab
                    if entry.item:IsValid() then
                        entry.item:Remove()
                    end
                end

                if inv.activeitem ~= nil then
                    if IsWorldLocked(inv.activeitem) then
                        local item = inv.activeitem
                        removed[#removed + 1] = item.prefab
                        inv:SetActiveItem(nil)
                        if item:IsValid() then
                            item:Remove()
                        end
                    elseif inv.activeitem.components ~= nil
                        and inv.activeitem.components.container ~= nil
                    then
                        StripContainer(
                            inv.activeitem.components.container,
                            removed
                        )
                    end
                end

                if #removed > 0 and owner.components.talker ~= nil then
                    owner.components.talker:Say(L(
                        "Some items belong to this world and cannot be taken along.",
                        "部分当前世界的特殊物品无法带走。"
                    ))
                end
            end

            return old_on_save(inv)
        end
    end)
end

-- Read by prefab files (which run in the global environment).
GLOBAL.DS_STARTER_SACRIFICE_ENABLED = SACRIFICE_GROWTH

-- Hide durability/fuel percentages and the perishable overlay when the
-- matching "never loses it" feature is enabled.
AddClassPostConstruct("widgets/itemtile", function(self)
    local item = self.item
    if item == nil then
        return
    end

    if NO_SPOILAGE then
        if self.bg ~= nil then
            self.bg:Hide()
        end
        if self.spoilage ~= nil then
            self.spoilage:Hide()
        end
        self.HasSpoilage = function()
            return false
        end
        self.SetPerishPercent = function(tile)
            if tile.spoilage ~= nil then
                tile.spoilage:Hide()
            end
        end
    end

    local hide_percent = (NO_DURABILITY and (
        item.components.finiteuses ~= nil or item.components.armor ~= nil
    )) or (NO_FUEL_CONSUMPTION and item.components.fueled ~= nil)
        or (NO_SPOILAGE and item.components.perishable ~= nil)

    local function HideOverlays(tile)
        if tile.percent ~= nil then
            tile.percent:Hide()
        end
        if NO_SPOILAGE then
            if tile.bg ~= nil then
                tile.bg:Hide()
            end
            if tile.spoilage ~= nil then
                tile.spoilage:Hide()
            end
        end
    end

    if hide_percent then
        HideOverlays(self)
        self.SetPercent = function(tile)
            HideOverlays(tile)
        end
    end

    -- Stacking calls SetQuantity on the existing tile. Re-hide the overlays
    -- there as well so they cannot come back after a merge.
    local old_set_quantity = self.SetQuantity
    if old_set_quantity ~= nil then
        self.SetQuantity = function(tile, quantity)
            old_set_quantity(tile, quantity)
            HideOverlays(tile)
        end
    end
end)

local function GetEquippedBackpack(inventory)
    if inventory == nil then
        return nil
    end
    local backpack = nil
    if GLOBAL.EQUIPSLOTS.BACK ~= nil then
        backpack = inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.BACK)
    end
    if backpack == nil then
        backpack = inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.BODY)
    end
    if backpack ~= nil and backpack.components.container ~= nil then
        return backpack
    end
    return nil
end

-- Wrap a component's OnLoad so saved items are restored after loading.
local function HookOnLoad(component, restore)
    local old_onload = component.OnLoad
    if old_onload then
        component.OnLoad = function(self, data, ...)
            old_onload(self, data, ...)
            restore(self)
        end
    end
end

---------------------------------------------------------------------------
-- 1. No spoilage
---------------------------------------------------------------------------
if NO_SPOILAGE then
    AddComponentPostInit("perishable", function(self)
        local function keep_fresh(component)
            if component.perishtime then
                component.perishremainingtime = component.perishtime
            end
            if component.StopPerishing then
                component:StopPerishing()
            end
        end

        keep_fresh(self)

        local old_start_perishing = self.StartPerishing
        if old_start_perishing then
            self.StartPerishing = function(component)
                keep_fresh(component)
            end
        end

        local old_set_percent = self.SetPercent
        if old_set_percent then
            self.SetPercent = function(component, percent)
                old_set_percent(component, 1)
            end
        end

        local old_set_perish_time = self.SetPerishTime
        if old_set_perish_time then
            self.SetPerishTime = function(component, time)
                old_set_perish_time(component, time)
                keep_fresh(component)
            end
        end

        local old_long_update = self.LongUpdate
        if old_long_update then
            self.LongUpdate = function(component, dt, ...)
                keep_fresh(component)
            end
        end

        local old_perish = self.Perish
        if old_perish then
            self.Perish = function(component)
                keep_fresh(component)
            end
        end

        HookOnLoad(self, keep_fresh)
    end)
end

---------------------------------------------------------------------------
-- 2. No durability
---------------------------------------------------------------------------
if NO_DURABILITY then
    -- Tools and weapons use the finiteuses component.
    AddComponentPostInit("finiteuses", function(self)
        local function keep_full(component)
            if component.total then
                component.current = component.total
                component.inst:RemoveTag("usesdepleted")
            end
        end

        keep_full(self)

        local old_set_max_uses = self.SetMaxUses
        if old_set_max_uses then
            self.SetMaxUses = function(component, value)
                old_set_max_uses(component, value)
                keep_full(component)
            end
        end

        local old_set_uses = self.SetUses
        if old_set_uses then
            self.SetUses = function(component, value)
                old_set_uses(component, component.total or value)
            end
        end

        local old_use = self.Use
        if old_use then
            self.Use = function(component, ...)
                keep_full(component)
            end
        end

        HookOnLoad(self, keep_full)
    end)

    -- Armor uses condition/maxcondition. Keep the condition at maximum.
    AddComponentPostInit("armor", function(self)
        local function keep_full(component)
            if component.maxcondition then
                component.condition = component.maxcondition
            end
        end

        keep_full(self)

        local old_set_condition = self.SetCondition
        if old_set_condition then
            self.SetCondition = function(component, amount)
                old_set_condition(component, component.maxcondition or amount)
            end
        end

        HookOnLoad(self, keep_full)
    end)
end

if NO_FUEL_CONSUMPTION then
    -- Torches, lanterns, miner hats, and similar items use the fueled component.
    AddComponentPostInit("fueled", function(self)
        local function keep_full(component)
            if component.maxfuel then
                component.currentfuel = component.maxfuel
                component.inst:RemoveTag("fueldepleted")
            end
        end

        keep_full(self)

        local old_start_consuming = self.StartConsuming
        if old_start_consuming then
            self.StartConsuming = function(component)
                keep_full(component)
            end
        end

        local old_do_delta = self.DoDelta
        if old_do_delta then
            self.DoDelta = function(component, amount, doer)
                keep_full(component)
            end
        end

        local old_set_percent = self.SetPercent
        if old_set_percent then
            self.SetPercent = function(component, amount)
                keep_full(component)
            end
        end

        HookOnLoad(self, keep_full)
    end)
end

---------------------------------------------------------------------------
-- 3. Sacrifice for growth
---------------------------------------------------------------------------
if SACRIFICE_GROWTH or GLIMMER or AUTO_COLLECT then
    if SACRIFICE_GROWTH then
    -- Add the persistent growth component to the player and apply
    -- heat/cold damage reduction on top of the normal health handling.
    AddPlayerPostInit(function(inst)
        if inst.components.ds_starter_growth == nil then
            inst:AddComponent("ds_starter_growth")
        end

        local health = inst.components.health
        if health ~= nil then
            local old_do_delta = health.DoDelta
            health.DoDelta = function(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
                local growth = self.inst.components.ds_starter_growth
                if growth ~= nil and amount < 0 then
                    if cause == "hot" or cause == "heat" then
                        amount = amount * (1 - growth:GetRedBonus())
                    elseif cause == "cold" or cause == "freezing" then
                        amount = amount * (1 - growth:GetBlueBonus())
                    end
                end
                return old_do_delta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
            end
        end

        inst.components.ds_starter_growth:Apply()

    end)
    end

    if GLIMMER then
        AddPlayerPostInit(function(inst)
            if inst.components.ds_starter_glimmer == nil then
                inst:AddComponent("ds_starter_glimmer")
            end
            inst:DoTaskInTime(0, function()
                inst.components.ds_starter_glimmer:Apply()
            end)
        end)
    end

    GLOBAL.STRINGS.NAMES.DS_STARTER_ALTAR =
        L("Sacrificial Altar", "献祭祭坛")
    GLOBAL.STRINGS.RECIPE_DESC.DS_STARTER_ALTAR = L(
        "A storage altar. Gems and amulets placed inside grant effects; removing them reduces the effect. Purple gems: +5% all stats (max +200%). Red/blue gems: resistance (max 100%). Magiluminescence: glimmer radius. Lazy Forager: auto-collect radius.",
        "一个容器祭坛。放入宝石/护符会获得效果，取出会降低。紫宝石：全属性 +5%（最高 +200%）；红/蓝宝石：抗性（最高 100%）；魔光护符：微光范围；懒人护符：自动拾取范围。"
    )
    GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.DS_STARTER_ALTAR = L(
        "A strange storage altar. Items placed inside seem to empower you.",
        "一座奇怪的容器祭坛，放入的物品似乎能强化你。"
    )

    -- Use a station that exists in the base game and every DLC.
    -- Hamlet replaces the Prestihatitator with the Hogus Porkusator, so
    -- Magic Tier 1 is not universal.
    local recipe_tab =
        GLOBAL.RECIPETABS.MAGIC or GLOBAL.RECIPETABS.SURVIVAL or GLOBAL.RECIPETABS.TOOLS
    local recipe_tech =
        GLOBAL.TECH.SCIENCE_TWO or GLOBAL.TECH.SCIENCE_ONE or GLOBAL.TECH.NONE

    -- Single-player exposes Recipe() rather than AddRecipe().
    --
    -- The argument list differs between builds:
    --   base game / RoG: Recipe(name, ingredients, tab, tech, placer, ...)
    --   Shipwrecked / Hamlet: Recipe(name, ingredients, tab, tech,
    --                               game_type, placer, ...)
    -- Passing the placer in the wrong position makes the recipe unusable
    -- (and, in SW/Hamlet, drops it from every recipe list).
    local function RecipeUsesGameType()
        local recipe_class = GLOBAL.Recipe
        local ctor = recipe_class ~= nil and recipe_class._ctor or nil
        if ctor ~= nil then
            local debug_lib = GLOBAL.debug
            if debug_lib ~= nil and debug_lib.getinfo ~= nil then
                local ok, info = GLOBAL.pcall(
                    debug_lib.getinfo, ctor, "u"
                )
                if ok and info ~= nil and info.nparams ~= nil then
                    -- base/RoG ctor has 9 params (self included).
                    return info.nparams > 9
                end
            end
        end

        local function DLCEnabled(index)
            if index == nil or GLOBAL.IsDLCEnabled == nil then
                return false
            end
            local ok, value = GLOBAL.pcall(GLOBAL.IsDLCEnabled, index)
            return ok and value == true
        end

        return DLCEnabled(GLOBAL.CAPY_DLC)
            or DLCEnabled(GLOBAL.PORKLAND_DLC)
    end

    local altar_ingredients = {
        GLOBAL.Ingredient("purplegem", 1),
        GLOBAL.Ingredient("goldnugget", 4),
        GLOBAL.Ingredient("rocks", 4),
    }
    local placer_name = "ds_starter_altar_placer"
    local altar_recipe
    if RecipeUsesGameType() then
        altar_recipe = Recipe(
            "ds_starter_altar",
            altar_ingredients,
            recipe_tab,
            recipe_tech,
            nil, -- common recipe, available in every world type
            placer_name
        )
    else
        altar_recipe = Recipe(
            "ds_starter_altar",
            altar_ingredients,
            recipe_tab,
            recipe_tech,
            placer_name
        )
    end
    if altar_recipe ~= nil and GLOBAL.resolvefilepath ~= nil then
        altar_recipe.atlas = GLOBAL.resolvefilepath(
            "images/inventoryimages/ds_starter_altar.xml"
        )
        altar_recipe.image = "ds_starter_altar.tex"
    end
end

---------------------------------------------------------------------------
-- 4. Health lock
---------------------------------------------------------------------------
if HEALTH_LOCK then
    AddPlayerPostInit(function(inst)
        local health = inst.components.health
        if health == nil then
            return
        end

        -- Clamp incoming damage so health never drops below 1.
        local old_do_delta = health.DoDelta
        health.DoDelta = function(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
            if amount < 0 then
                local max_damage = self.currenthealth - 1
                if max_damage < 0 then
                    max_damage = 0
                end
                if amount < -max_damage then
                    amount = -max_damage
                end
            else
                -- Healing and HUD refreshes must still work while locked.
                ignore_invincible = true
            end

            return old_do_delta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        end

        -- Mark the load pass so saved dead players are not revived by the
        -- SetVal clamp below.
        local old_health_onload = health.OnLoad
        if old_health_onload then
            health.OnLoad = function(self, data, ...)
                self._ds_starter_loading = true
                local ret = old_health_onload(self, data, ...)
                self._ds_starter_loading = nil
                return ret
            end
        end

        -- Also clamp direct value changes such as SetPercent(0).
        local old_set_val = health.SetVal
        health.SetVal = function(self, val, cause, afflicter)
            if not self._ds_starter_loading
                and self.currenthealth > 0
                and val < 1
            then
                val = 1
            end
            return old_set_val(self, val, cause, afflicter)
        end
    end)

    -- Shipwrecked / Hamlet boats use boathealth instead of health.
    AddComponentPostInit("boathealth", function(self)
        local old_do_delta = self.DoDelta
        if old_do_delta == nil then
            return
        end

        self.DoDelta = function(component, amount, ...)
            if amount < 0 then
                local max_damage = component.currenthealth - 1
                if max_damage < 0 then
                    max_damage = 0
                end
                if amount < -max_damage then
                    amount = -max_damage
                end
            end
            return old_do_delta(component, amount, ...)
        end
    end)
end

---------------------------------------------------------------------------
-- 5. Five equipment slots
---------------------------------------------------------------------------
if FIVE_SLOTS then
    -- Reuse slots created by another mod instead of redefining them.
    if GLOBAL.EQUIPSLOTS.BACK == nil then
        GLOBAL.EQUIPSLOTS.BACK = "back"
    else
        print("[DS-Starter] compatibility: EQUIPSLOTS.BACK already exists")
    end
    if GLOBAL.EQUIPSLOTS.NECK == nil then
        GLOBAL.EQUIPSLOTS.NECK = "neck"
    else
        print("[DS-Starter] compatibility: EQUIPSLOTS.NECK already exists")
    end

    AddPrefabPostInitAny(function(inst)
        if inst.components.equippable == nil then
            return
        end

        local current = inst.components.equippable.equipslot
        if inst:HasTag("backpack") then
            -- Only move vanilla body-slot backpacks; leave another slot
            -- mod's assignment untouched.
            if current == nil or current == GLOBAL.EQUIPSLOTS.BODY then
                inst.components.equippable.equipslot =
                    GLOBAL.EQUIPSLOTS.BACK
            end
        elseif inst.prefab ~= nil
            and string.find(inst.prefab, "amulet", 1, true) ~= nil
        then
            if current ~= GLOBAL.EQUIPSLOTS.BACK
                and current ~= GLOBAL.EQUIPSLOTS.NECK
            then
                inst.components.equippable.equipslot =
                    GLOBAL.EQUIPSLOTS.NECK
            end
        end
    end)

    AddClassPostConstruct("widgets/inventorybar", function(self)
        if self.AddEquipSlot == nil then
            return
        end

        local function HasSlot(slot)
            for _, info in ipairs(self.equipslotinfo or {}) do
                if info.slot == slot then
                    return true
                end
            end
            return false
        end

        -- Backpack and amulet use the plain slot frame; a faded backpack /
        -- amulet icon is layered on top by the equipslot hook below. This
        -- keeps them consistent with the other slots instead of borrowing
        -- the boat compass and lantern frames.
        if not HasSlot(GLOBAL.EQUIPSLOTS.BACK) then
            self:AddEquipSlot(
                GLOBAL.EQUIPSLOTS.BACK,
                "images/hud.xml",
                "inv_slot.tex"
            )
        end
        if not HasSlot(GLOBAL.EQUIPSLOTS.NECK) then
            self:AddEquipSlot(
                GLOBAL.EQUIPSLOTS.NECK,
                "images/hud.xml",
                "inv_slot.tex"
            )
        end
    end)

    local WidgetImage = GLOBAL.require("widgets/image")

    AddClassPostConstruct("widgets/equipslot", function(self)
        local atlas = nil
        local image = nil
        if self.equipslot == GLOBAL.EQUIPSLOTS.BACK then
            atlas = "images/inventoryimages/ds_starter_slot_backpack.xml"
            image = "ds_starter_slot_backpack.tex"
        elseif self.equipslot == GLOBAL.EQUIPSLOTS.NECK then
            atlas = "images/inventoryimages/ds_starter_slot_amulet.xml"
            image = "ds_starter_slot_amulet.tex"
        else
            return
        end

        local icon = self:AddChild(WidgetImage(atlas, image))
        icon:SetScale(1)
    end)

    -- Keep each equipment slot to its own item type.
    local function IsBackpack(item)
        return item:HasTag("backpack")
    end
    local function IsAmulet(item)
        return item:HasTag("amulet")
            or (item.prefab ~= nil
                and string.find(item.prefab, "amulet", 1, true) ~= nil)
    end
    local function IsHat(item)
        return item:HasTag("hat")
    end
    local function CanEquipInSlot(item, slot)
        if slot == GLOBAL.EQUIPSLOTS.BACK then
            return IsBackpack(item)
        elseif slot == GLOBAL.EQUIPSLOTS.NECK then
            return IsAmulet(item)
        elseif slot == GLOBAL.EQUIPSLOTS.HEAD then
            return IsHat(item)
        elseif slot == GLOBAL.EQUIPSLOTS.BODY
            or slot == GLOBAL.EQUIPSLOTS.HANDS
        then
            return not IsBackpack(item)
                and not IsAmulet(item)
                and not IsHat(item)
        end
        return true
    end

    AddComponentPostInit("inventory", function(self)
        local old_equip = self.Equip
        if old_equip == nil then
            return
        end
        self.Equip = function(inv, item, old_to_active)
            if item ~= nil and item.components.equippable ~= nil then
                local slot = item.components.equippable.equipslot
                if not CanEquipInSlot(item, slot) then
                    return
                end
            end
            return old_equip(inv, item, old_to_active)
        end
    end)
end

---------------------------------------------------------------------------
-- 5.3 9999 stacking
---------------------------------------------------------------------------
if STACK_9999 then
    local MAX_STACK = 9999

    AddComponentPostInit("stackable", function(self)
        local old_set_max_size = self.SetMaxSize
        if old_set_max_size ~= nil then
            self.SetMaxSize = function(component)
                old_set_max_size(component, MAX_STACK)
            end
        end
        self.maxsize = MAX_STACK
    end)

    AddPrefabPostInitAny(function(inst)
        if inst.components.stackable ~= nil then
            inst.components.stackable.maxsize = MAX_STACK
        end
    end)
end

---------------------------------------------------------------------------
-- 5.4 Instant fishing
---------------------------------------------------------------------------
if INSTANT_FISH then
    AddComponentPostInit("fishingrod", function(self)
        local old_set_wait_times = self.SetWaitTimes
        if old_set_wait_times ~= nil then
            self.SetWaitTimes = function(component)
                old_set_wait_times(component, 0, 0)
            end
        end
        self.minwaittime = 0
        self.maxwaittime = 0

        -- After hooking, reel automatically instead of waiting for the
        -- player to click through the strain state.
        local old_hook = self.Hook
        if old_hook ~= nil then
            self.Hook = function(component, ...)
                local ret = old_hook(component, ...)
                component.inst:DoTaskInTime(0.1, function()
                    if component:HasHookedFish()
                        and component.fisherman ~= nil
                    then
                        component:Reel()
                    end
                end)
                return ret
            end
        end
    end)
end

---------------------------------------------------------------------------
-- 6. Infinite Backpack
---------------------------------------------------------------------------
if INFINITE_BACKPACK then
    -- Single-player stores container widget settings directly on the
    -- container component in the prefab, so no containers.params setup here.
    GLOBAL.STRINGS.NAMES.DS_STARTER_INFINITE_BACKPACK =
        L("Infinite Backpack", "无限背包")
    GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.DS_STARTER_INFINITE_BACKPACK = L(
        "A backpack with endless storage.",
        "一个似乎永远装不满的背包。"
    )

    local function HasInfiniteBackpack(inventory)
        if inventory == nil then
            return false
        end
        for _, item in pairs(inventory.itemslots or {}) do
            if item ~= nil and item.prefab == "ds_starter_infinite_backpack" then
                return true
            end
        end
        for _, item in pairs(inventory.equipslots or {}) do
            if item ~= nil and item.prefab == "ds_starter_infinite_backpack" then
                return true
            end
        end
        return false
    end

    -- The backpack is granted once per save instead of being crafted.
    -- It is not replaced after being lost, but disabling and re-enabling
    -- this feature clears the marker so it is granted again.
    AddPlayerPostInit(function(inst)
        inst:DoTaskInTime(0, function()
            local flags = inst.components.ds_starter_flags
            if flags == nil or flags:HasBackpackGranted() then
                return
            end

            local inventory = inst.components.inventory
            if inventory == nil then
                return
            end

            if HasInfiniteBackpack(inventory) then
                flags:SetBackpackGranted()
                return
            end

            local backpack = GLOBAL.SpawnPrefab("ds_starter_infinite_backpack")
            if backpack == nil then
                inst:DoTaskInTime(1, function()
                    if inst.components.ds_starter_flags == nil
                        or inst.components.ds_starter_flags:HasBackpackGranted()
                    then
                        return
                    end
                    local retry = GLOBAL.SpawnPrefab("ds_starter_infinite_backpack")
                    if retry ~= nil then
                        inventory:GiveItem(retry)
                        if inventory.Equip ~= nil then
                            inventory:Equip(retry)
                        end
                        inst.components.ds_starter_flags:SetBackpackGranted()
                    end
                end)
                return
            end

            inventory:GiveItem(backpack)
            if inventory.Equip ~= nil then
                inventory:Equip(backpack)
            end
            flags:SetBackpackGranted()
        end)
    end)

    -- If the infinite backpack already holds an unfinished stack of the
    -- incoming item, stack new pickups there before the main inventory.
    AddComponentPostInit("inventory", function(self)
        local old_get_slot = self.GetNextAvailableSlot
        if old_get_slot == nil then
            return
        end

        self.GetNextAvailableSlot = function(inv, item)
            local overflow = inv.overflow
            if overflow ~= nil
                and overflow.prefab == "ds_starter_infinite_backpack"
                and overflow.components.container ~= nil
                and item ~= nil
                and item.components.stackable ~= nil
            then
                local prefabname = item.prefab
                for slot, existing in pairs(
                    overflow.components.container.slots or {}
                ) do
                    if existing ~= nil
                        and existing.prefab == prefabname
                        and existing.components.stackable ~= nil
                        and not existing.components.stackable:IsFull()
                    then
                        return slot, overflow
                    end
                end
            end

            return old_get_slot(inv, item)
        end
    end)

    modimport("scripts/widgets/ds_starter_infinite_backpack_container.lua")
end

if AUTO_COLLECT then
    -- Mark items dropped manually so Auto Collect ignores them.
    if GLOBAL.ACTIONS.DROP ~= nil and GLOBAL.ACTIONS.DROP.fn ~= nil then
        local old_drop = GLOBAL.ACTIONS.DROP.fn
        GLOBAL.ACTIONS.DROP.fn = function(act)
            local item = act.invobject
            manual_drop_in_progress = true
            local ok, ret = GLOBAL.pcall(old_drop, act)
            manual_drop_in_progress = false
            if not ok then
                GLOBAL.error(ret)
            end
            if item ~= nil
                and item:IsValid()
                and item.components.inventoryitem ~= nil
                and item.components.inventoryitem.owner == nil
            then
                item:AddTag("ds_starter_manual_drop")
            end
            return ret
        end
    end

    AddComponentPostInit("inventoryitem", function(self)
        local old_put = self.OnPutInInventory
        if old_put ~= nil then
            self.OnPutInInventory = function(self, owner, ...)
                self.inst:RemoveTag("ds_starter_manual_drop")
                return old_put(self, owner, ...)
            end
        end

        local old_dropped = self.OnDropped
        if old_dropped ~= nil then
            self.OnDropped = function(self, ...)
                local ret = old_dropped(self, ...)
                if manual_drop_in_progress then
                    self.inst:AddTag("ds_starter_manual_drop")
                end
                return ret
            end
        end

        local old_save = self.OnSave
        self.OnSave = function(self, ...)
            local data = old_save and old_save(self, ...) or nil
            if self.inst:HasTag("ds_starter_manual_drop") then
                data = data or {}
                data.ds_starter_manual_drop = true
            end
            return data
        end

        local old_load = self.OnLoad
        self.OnLoad = function(self, data, ...)
            if old_load ~= nil then
                old_load(self, data, ...)
            end
            if data ~= nil and data.ds_starter_manual_drop then
                self.inst:AddTag("ds_starter_manual_drop")
            end
        end
    end)

    AddPlayerPostInit(function(inst)
        if inst.components.ds_starter_autocollect == nil then
            inst:AddComponent("ds_starter_autocollect")
        end
        inst.components.ds_starter_autocollect:Start()
    end)
end

---------------------------------------------------------------------------
-- 7. Blood-Drinking Sword
---------------------------------------------------------------------------
if YINXUE_SWORD then
    GLOBAL.STRINGS.NAMES.DS_STARTER_YINXUE_SWORD = L("Blood-Drinking Sword", "饮血剑")
    GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.DS_STARTER_YINXUE_SWORD = L(
        "A bloodthirsty blade that grows stronger with every slain foe.",
        "一柄饮血成长的魔刀，刀锋会随斩杀的敌人不断增强。"
    )
    -- The sword is granted at spawn and cannot be crafted.
    if GLOBAL.Recipes ~= nil then
        GLOBAL.Recipes.ds_starter_yinxue_sword = nil
    end

    local function HasYinxueSword(player)
        local inventory = player.components.inventory
        if inventory == nil then
            return false
        end

        for _, item in pairs(inventory.itemslots or {}) do
            if item ~= nil and item.prefab == "ds_starter_yinxue_sword" then
                return true
            end
        end
        for _, item in pairs(inventory.equipslots or {}) do
            if item ~= nil and item.prefab == "ds_starter_yinxue_sword" then
                return true
            end
        end

        local backpack = GetEquippedBackpack(inventory)
        if backpack ~= nil
            and backpack.components.container ~= nil
            and backpack.components.container.slots ~= nil
        then
            for _, item in pairs(backpack.components.container.slots) do
                if item ~= nil and item.prefab == "ds_starter_yinxue_sword" then
                    return true
                end
            end
        end

        return false
    end

    -- Grant exactly one sword per save. The flag lives in an always-present
    -- component, so disabling and re-enabling the feature does not grant more.
    AddPlayerPostInit(function(inst)
        inst:DoTaskInTime(0, function()
            local flags = inst.components.ds_starter_flags
            if flags == nil or flags:HasSwordGranted() then
                return
            end
            if HasYinxueSword(inst) then
                flags:SetSwordGranted()
                return
            end

            local inventory = inst.components.inventory
            if inventory == nil then
                return
            end

            local sword = GLOBAL.SpawnPrefab("ds_starter_yinxue_sword")
            if sword == nil then
                -- The prefab was not registered yet; retry instead of
                -- marking the save as granted without a sword.
                inst:DoTaskInTime(1, function()
                    if inst.components.ds_starter_flags == nil
                        or inst.components.ds_starter_flags:HasSwordGranted()
                    then
                        return
                    end
                    local retry = GLOBAL.SpawnPrefab("ds_starter_yinxue_sword")
                    if retry ~= nil then
                        inventory:GiveItem(retry)
                        if inventory.Equip ~= nil then
                            inventory:Equip(retry)
                        end
                        inst.components.ds_starter_flags:SetSwordGranted()
                    end
                end)
                return
            end

            inventory:GiveItem(sword)
            if inventory.Equip ~= nil then
                inventory:Equip(sword)
            end
            flags:SetSwordGranted()
        end)
    end)

    local YINXUE_STAGES = {
        {
            kills = 100,
            en = "The Blood-Drinking Sword awakens.",
            zh = "饮血剑开始苏醒。",
        },
        {
            kills = 1000,
            en = "The Blood-Drinking Sword's edge is complete.",
            zh = "饮血剑的剑气大成。",
        },
        {
            kills = 10000,
            en = "The Blood-Drinking Sword's true power is unsealed.",
            zh = "饮血剑的真意解封。",
        },
        {
            kills = 100000,
            en = "The Blood-Drinking Sword has reached its limit.",
            zh = "饮血剑已臻极致。",
        },
    }

    local function IsYinxueTarget(victim)
        if victim == nil or not victim:IsValid() then
            return false
        end
        if victim:HasTag("player")
            or victim:HasTag("playerghost")
            or victim:HasTag("structure")
            or victim:HasTag("wall")
            or victim:HasTag("INLIMBO")
            or victim:HasTag("FX")
            or victim:HasTag("companion")
            or victim:HasTag("follower")
        then
            return false
        end
        return victim:HasTag("monster")
            or victim:HasTag("epic")
            or victim:HasTag("boss")
    end

    -- Remember the weapon used for the most recent hit. The "killed" event
    -- fires on the attacker, so checking the victim's last weapon credits only
    -- kills whose final blow came from the Blood-Drinking Sword.
    AddComponentPostInit("combat", function(self)
        local old_get_attacked = self.GetAttacked
        if old_get_attacked == nil then
            return
        end
        self.GetAttacked = function(self, attacker, damage, weapon, ...)
            self.inst._ds_starter_last_weapon = weapon
            self.inst._ds_starter_last_weapon_time = GLOBAL.GetTime()
            return old_get_attacked(self, attacker, damage, weapon, ...)
        end
    end)

    AddPlayerPostInit(function(inst)
        inst:ListenForEvent("killed", function(inst, data)
            local victim = data ~= nil and data.victim or nil
            if victim == nil then
                return
            end

            local weapon = victim._ds_starter_last_weapon
            local hit_time = victim._ds_starter_last_weapon_time
            victim._ds_starter_last_weapon = nil
            victim._ds_starter_last_weapon_time = nil

            if weapon == nil
                or type(weapon) ~= "table"
                or not weapon:IsValid()
                or weapon.prefab ~= "ds_starter_yinxue_sword"
                or weapon.components.ds_starter_weapon_growth == nil
            then
                return
            end
            if hit_time == nil or GLOBAL.GetTime() - hit_time > 5 then
                return
            end
            if not IsYinxueTarget(victim) then
                return
            end

            local growth = weapon.components.ds_starter_weapon_growth
            local old_kills = growth:GetKills()
            growth:AddKill(victim)
            local new_kills = growth:GetKills()

            for _, stage in ipairs(YINXUE_STAGES) do
                if old_kills < stage.kills and new_kills >= stage.kills then
                    if inst.components.talker ~= nil then
                        inst.components.talker:Say(L(stage.en, stage.zh))
                    end
                    break
                end
            end
        end)
    end)

    -----------------------------------------------------------------------
    -- Blood-Drinking Sword: blink
    -----------------------------------------------------------------------
    local BLINK_RANGE = 20
    local BLINK_COOLDOWN = 1

    AddPlayerPostInit(function(inst)
        inst._ds_starter_last_blink = nil
    end)

    local function Say(player, en, zh)
        if player ~= nil and player.components.talker ~= nil then
            player.components.talker:Say(L(en, zh))
        end
    end

    local function TeleportPlayer(player, x, y, z)
        if player.Physics ~= nil and player.Physics.Teleport ~= nil then
            player.Physics:Teleport(x, y, z)
        end
        player.Transform:SetPosition(x, y, z)
    end

    local function IsPassable(x, z)
        if GLOBAL.IsPassableAtPoint ~= nil then
            return GLOBAL.IsPassableAtPoint(x, 0, z)
        end

        local map = GetTheWorld() ~= nil and GetTheWorld().Map or nil
        if map == nil or map.IsPassableAtPoint == nil then
            return true
        end
        return map:IsPassableAtPoint(x, z)
    end

    local function IsUnsafeWorld(player)
        local world = GetTheWorld()
        if world == nil then
            return true
        end

        if player ~= nil
            and (player:HasTag("inside_interior")
                or player:HasTag("ininterior"))
        then
            return true
        end

        if world.IsCave ~= nil and world:IsCave() then
            return true
        end
        if world.IsRuins ~= nil and world:IsRuins() then
            return true
        end
        if world:HasTag("cave")
            or world:HasTag("ruins")
            or world:HasTag("ruin")
            or world:HasTag("interior")
            or world:HasTag("indoor")
            or world:HasTag("volcano")
        then
            return true
        end

        return false
    end

    local GetYinxueSword

    local function Blink(player, x, z)
        if player == nil or player:HasTag("playerghost") then
            return
        end
        if IsUnsafeWorld(player) then
            Say(player, "Cannot teleport here.", "这里不能传送。")
            return
        end

        local inventory = player.components.inventory
        if inventory == nil then
            return
        end
        local weapon = GetYinxueSword(player)
        if weapon == nil then
            return
        end

        local now = GLOBAL.GetTime()
        if player._ds_starter_last_blink ~= nil
            and now - player._ds_starter_last_blink < BLINK_COOLDOWN
        then
            return
        end

        local px, py, pz = player.Transform:GetWorldPosition()
        local dx = x - px
        local dz = z - pz
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance < 0.1 then
            return
        end

        if distance > BLINK_RANGE then
            local scale = BLINK_RANGE / distance
            x = px + dx * scale
            z = pz + dz * scale
        end

        if not IsPassable(x, z) then
            Say(player, "Cannot blink there.", "那里无法闪现。")
            return
        end

        local locomotor = player.components.locomotor
        if locomotor ~= nil and locomotor.Stop ~= nil then
            locomotor:Stop()
        end
        TeleportPlayer(player, x, 0, z)
        player._ds_starter_last_blink = now
    end

    -- Only the sword actually held in the hand counts; never auto-swap the
    -- player's equipped tool for a sword sitting in the inventory.
    GetYinxueSword = function(player)
        local inventory = player ~= nil and player.components.inventory or nil
        if inventory == nil then
            return nil
        end
        local sword = inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS)
        if sword ~= nil and sword.prefab == "ds_starter_yinxue_sword" then
            return sword
        end
        return nil
    end

    GLOBAL.DSStarterBlink = function(x, z)
        Blink(GetThePlayer(), x, z)
    end
end

---------------------------------------------------------------------------
-- 7.5 Teleport beacons (independent of the sword)
---------------------------------------------------------------------------
if TELEPORT then
    GLOBAL.DSStarterL = L
    modimport("scripts/widgets/ds_starter_teleport_panel.lua")

    -- Single-player has no SetForceProcessTextInput, so route text input to
    -- the rename dialog while it is open.
    if GLOBAL.TheFrontEnd ~= nil
        and GLOBAL.TheFrontEnd.SetForceProcessTextInput == nil
        and not GLOBAL.TheFrontEnd._ds_starter_text_hooked
    then
        GLOBAL.TheFrontEnd._ds_starter_text_hooked = true
        local old_onraw = GLOBAL.TheFrontEnd.OnRawKey
        local old_ontext = GLOBAL.TheFrontEnd.OnTextInput

        GLOBAL.TheFrontEnd.OnRawKey = function(self, key, down)
            local dialog = GLOBAL.DS_STARTER_RENAME_DIALOG
            if dialog ~= nil and dialog ~= false and dialog.edit ~= nil then
                dialog.edit:OnRawKey(key, down)
                return
            end
            return old_onraw(self, key, down)
        end

        GLOBAL.TheFrontEnd.OnTextInput = function(self, text)
            local dialog = GLOBAL.DS_STARTER_RENAME_DIALOG
            if dialog ~= nil and dialog ~= false and dialog.edit ~= nil then
                dialog.edit:OnTextInput(text)
                return
            end
            return old_ontext(self, text)
        end
    end

    AddPlayerPostInit(function(inst)
        if inst.components.ds_starter_teleport == nil then
            inst:AddComponent("ds_starter_teleport")
        end
    end)

    local function Say(player, en, zh)
        if player ~= nil and player.components.talker ~= nil then
            player.components.talker:Say(L(en, zh))
        end
    end

    local function IsUnsafeWorld(player)
        local world = GetTheWorld()
        if world == nil then
            return true
        end

        if player ~= nil
            and (player:HasTag("inside_interior")
                or player:HasTag("ininterior"))
        then
            return true
        end

        if world.IsCave ~= nil and world:IsCave() then
            return true
        end
        if world.IsRuins ~= nil and world:IsRuins() then
            return true
        end
        if world:HasTag("cave")
            or world:HasTag("ruins")
            or world:HasTag("ruin")
            or world:HasTag("interior")
            or world:HasTag("indoor")
            or world:HasTag("volcano")
        then
            return true
        end

        return false
    end

    local function GetTeleportComponent(player)
        if player == nil then
            return nil
        end
        return player.components.ds_starter_teleport
    end

    GLOBAL.DSStarterGetBeacons = function()
        local component = GetTeleportComponent(GetThePlayer())
        if component == nil then
            return {}
        end
        return component:GetBeacons()
    end

    GLOBAL.DSStarterAddBeacon = function()
        local player = GetThePlayer()
        if player == nil or player:HasTag("playerghost") then
            return
        end
        if IsUnsafeWorld(player) then
            Say(player, "Cannot place a beacon here.", "这里不能设置信标。")
            return
        end
        local component = GetTeleportComponent(player)
        if component == nil then
            return
        end

        local x, y, z = player.Transform:GetWorldPosition()
        local ok, reason = component:AddBeacon(x, y, z)
        if not ok then
            if reason == "full" then
                Say(player, "The beacon list is full.", "信标数量已满。")
            else
                Say(
                    player,
                    "Too close to another beacon.",
                    "离已有信标太近了。"
                )
            end
        end
    end

    GLOBAL.DSStarterRemoveBeacon = function(index)
        local component = GetTeleportComponent(GetThePlayer())
        if component ~= nil then
            component:RemoveBeacon(index)
        end
    end

    GLOBAL.DSStarterMoveBeacon = function(index, delta)
        local component = GetTeleportComponent(GetThePlayer())
        if component ~= nil then
            component:MoveBeacon(index, delta)
        end
    end

    GLOBAL.DSStarterTeleportBeacon = function(index)
        local player = GetThePlayer()
        if player == nil or player:HasTag("playerghost") then
            return
        end
        if IsUnsafeWorld(player) then
            Say(player, "Cannot teleport here.", "这里不能传送。")
            return
        end
        local component = GetTeleportComponent(player)
        if component ~= nil then
            component:TeleportTo(index)
        end
    end

    GLOBAL.DSStarterRenameBeacon = function(index, name)
        local player = GetThePlayer()
        if player == nil then
            return
        end
        local component = GetTeleportComponent(player)
        if component ~= nil then
            component:SetBeaconName(index, name)
        end
    end

    GLOBAL.DSStarterRequestBeacons = function()
        if type(GLOBAL.DSStarterRefreshPanel) == "function" then
            GLOBAL.DSStarterRefreshPanel()
        end
    end

    GLOBAL.DSStarterTogglePanel = function()
        local player = GetThePlayer()
        if player == nil or player.HUD == nil then
            return
        end

        local panel = player._ds_starter_teleport_panel
        if panel == nil then
            panel = GLOBAL.DSStarterCreateTeleportPanel(player)
            player.HUD:AddChild(panel)
            player._ds_starter_teleport_panel = panel
            GLOBAL.DSStarterRefreshPanel = function()
                if panel.isopen then
                    panel:Refresh()
                end
            end
        end
        panel:Toggle()
    end
end

---------------------------------------------------------------------------
-- 7.6 Right-click routing
---------------------------------------------------------------------------
if TELEPORT or YINXUE_SWORD then
    local function TeleportModifierDown()
        local key = GLOBAL.KEY_SHIFT
        if TELEPORT_SHORTCUT == "MOUSE_CTRL" then
            key = GLOBAL.KEY_CTRL
        elseif TELEPORT_SHORTCUT == "MOUSE_ALT" then
            key = GLOBAL.KEY_ALT
        end
        return key ~= nil and GLOBAL.TheInput:IsKeyDown(key)
    end

    AddComponentPostInit("playercontroller", function(self)
        local old_onright = self.OnRightClick
        if old_onright == nil then
            return
        end

        self.OnRightClick = function(pc, down)
            if down and not IsRenaming() then
                local player = pc.inst
                if player ~= nil and not player:HasTag("playerghost") then
                    local inventory = player.components.inventory
                    local active_item = inventory ~= nil
                        and inventory:GetActiveItem()
                        or nil
                    local right_action = pc.GetRightMouseAction ~= nil
                        and pc:GetRightMouseAction()
                        or nil

                    -- Only route the click when it is a plain click on empty
                    -- ground. Clicks on HUD slots, world items/creatures, or
                    -- while holding an item keep their vanilla behaviour
                    -- (split, use, attack, deploy, etc.).
                    if active_item == nil
                        and right_action == nil
                        and GLOBAL.TheInput:GetHUDEntityUnderMouse() == nil
                        and GLOBAL.TheInput:GetWorldEntityUnderMouse() == nil
                    then
                        if TELEPORT and TeleportModifierDown() then
                            GLOBAL.DSStarterTogglePanel()
                            return
                        end

                        if YINXUE_SWORD then
                            local weapon = inventory ~= nil
                                and inventory:GetEquippedItem(
                                    GLOBAL.EQUIPSLOTS.HANDS
                                )
                                or nil
                            if weapon ~= nil
                                and weapon.prefab == "ds_starter_yinxue_sword"
                            then
                                local position = GLOBAL.TheInput:GetWorldPosition()
                                if position ~= nil then
                                    GLOBAL.DSStarterBlink(
                                        position.x,
                                        position.z
                                    )
                                end
                                return
                            end
                        end
                    end
                end
            end

            return old_onright(pc, down)
        end
    end)
end
