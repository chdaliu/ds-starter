-- Persistent per-player growth from sacrificing gems.
-- Purple gems: +5% to max health, max hunger, max sanity, damage, and speed,
--   up to +200%.
-- Red gems: +5% heat/burn resistance, up to 100%.
-- Blue gems: +5% cold/freeze resistance, up to 100%.

local SOURCE = "ds_starter_growth"
local STEP = 0.05
local MAX_BONUS = 2.0
local MAX_RESIST = 1.0

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local Growth = Class(function(self, inst)
    self.inst = inst
    self.bonus = 0
    self.red_bonus = 0
    self.blue_bonus = 0

    -- Base values are captured once, before any bonus is applied.
    self.base_health = nil
    self.base_hunger = nil
    self.base_sanity = nil
    self.base_damage = nil
    self.base_walkspeed = nil
    self.base_runspeed = nil
    self.base_fire_scale = nil
    self.base_freeze_resistance = nil
end)

function Growth:GetBonus()
    return self.bonus
end

function Growth:GetBonusPercent()
    return math.floor(self.bonus * 100 + 0.5)
end

function Growth:GetRedBonus()
    return self.red_bonus
end

function Growth:GetRedPercent()
    return math.floor(self.red_bonus * 100 + 0.5)
end

function Growth:GetBlueBonus()
    return self.blue_bonus
end

function Growth:GetBluePercent()
    return math.floor(self.blue_bonus * 100 + 0.5)
end

-- Used by the altar container: stored item counts are the source of truth.
function Growth:SetBonuses(purple, red, blue)
    local new_bonus = clamp((purple or 0) * STEP, 0, MAX_BONUS)
    local new_red = clamp((red or 0) * STEP, 0, MAX_RESIST)
    local new_blue = clamp((blue or 0) * STEP, 0, MAX_RESIST)

    -- The altar recalculates periodically. Only reapply when something
    -- actually changed, otherwise the HUD would refresh every tick.
    if new_bonus == self.bonus
        and new_red == self.red_bonus
        and new_blue == self.blue_bonus
    then
        return
    end

    self.bonus = new_bonus
    self.red_bonus = new_red
    self.blue_bonus = new_blue
    self:Apply()
end

function Growth:Apply()
    if not self.inst:IsValid() then
        return
    end

    local health = self.inst.components.health
    if health ~= nil and health:IsDead() then
        -- Do not revive a dead player while loading growth data.
        return
    end

    if health ~= nil then
        if self.base_health == nil then
            self.base_health = health.maxhealth
        end
        local percent = health:GetPercent()
        health:SetMaxHealth(self.base_health * (1 + self.bonus))
        health.currenthealth = math.min(
            health:GetMaxHealth(),
            health.maxhealth * percent
        )
        local new_percent = health:GetPercent()
        -- Equal old/new percentages refresh the HUD max without triggering
        -- the "health up/down" sound.
        self.inst:PushEvent("healthdelta", {
            oldpercent = new_percent,
            newpercent = new_percent,
            overtime = true,
        })
    end

    local hunger = self.inst.components.hunger
    if hunger ~= nil then
        if self.base_hunger == nil then
            self.base_hunger = hunger.max
        end
        local percent = hunger:GetPercent()
        hunger.max = self.base_hunger * (1 + self.bonus)
        hunger.current = math.min(hunger.max, hunger.max * percent)
        local new_percent = hunger:GetPercent()
        self.inst:PushEvent("hungerdelta", {
            oldpercent = new_percent,
            newpercent = new_percent,
            overtime = true,
        })
    end

    local sanity = self.inst.components.sanity
    if sanity ~= nil then
        if self.base_sanity == nil then
            self.base_sanity = sanity.max
        end
        local percent = sanity:GetPercent()
        sanity.max = self.base_sanity * (1 + self.bonus)
        sanity.current = math.min(
            sanity:GetMaxSanity(),
            sanity.max * percent
        )
        local new_percent = sanity:GetPercent()
        -- Writing current directly skips the vanilla sane/insane threshold
        -- checks. Keep the flag consistent with the new percentage so a
        -- high-sanity player does not keep the low-sanity screen effect.
        local tuning = rawget(_G, "TUNING") or {}
        local insane_thresh = tuning.SANITY_BECOME_INSANE_THRESH or 0.15
        local sane_thresh = tuning.SANITY_BECOME_SANE_THRESH or 0.175
        if sanity.sane == false and new_percent >= sane_thresh then
            sanity.sane = true
            if sanity.onSane ~= nil then
                sanity.onSane(self.inst)
            end
            self.inst:PushEvent("gosane", {})
        elseif sanity.sane ~= false and new_percent <= insane_thresh then
            sanity.sane = false
            if sanity.onInsane ~= nil then
                sanity.onInsane(self.inst)
            end
            self.inst:PushEvent("goinsane", {})
        end
        self.inst:PushEvent("sanitydelta", {
            oldpercent = new_percent,
            newpercent = new_percent,
            overtime = true,
        })
    end

    local combat = self.inst.components.combat
    if combat ~= nil then
        if combat.AddDamageModifier ~= nil then
            -- Don't Starve single-player uses a normalized damage bonus.
            if self.bonus > 0 then
                combat:AddDamageModifier(SOURCE, self.bonus)
            elseif combat.RemoveDamageModifier ~= nil then
                combat:RemoveDamageModifier(SOURCE)
            end
        elseif combat.externaldamagemultipliers ~= nil then
            combat.externaldamagemultipliers:SetModifier(
                self.inst,
                1 + self.bonus,
                SOURCE
            )
        elseif combat.damagemultiplier ~= nil or combat.AddDamageModifier == nil then
            -- Single-player combat has a plain damage multiplier field.
            if self.base_damage == nil then
                self.base_damage = combat.damagemultiplier or 1
            end
            combat.damagemultiplier = self.base_damage * (1 + self.bonus)
        end
    end

    local locomotor = self.inst.components.locomotor
    if locomotor ~= nil then
        if locomotor.SetExternalSpeedMultiplier ~= nil then
            locomotor:SetExternalSpeedMultiplier(
                self.inst,
                SOURCE,
                1 + self.bonus
            )
        else
            -- Single-player locomotor has no external multiplier API.
            if self.base_walkspeed == nil then
                self.base_walkspeed = locomotor.walkspeed
                self.base_runspeed = locomotor.runspeed
            end
            locomotor.walkspeed =
                self.base_walkspeed * (1 + self.bonus)
            locomotor.runspeed =
                self.base_runspeed * (1 + self.bonus)
        end
    end

    self:ApplyResistances()
end

function Growth:ApplyResistances()
    local health = self.inst.components.health
    if health ~= nil then
        if health.fire_damage_scale ~= nil then
            if self.base_fire_scale == nil then
                self.base_fire_scale = health.fire_damage_scale
            end
            health.fire_damage_scale = self.base_fire_scale * (1 - self.red_bonus)
        end

        if health.vulnerabletoheatdamage ~= nil then
            if self.base_heat_vulnerable == nil then
                self.base_heat_vulnerable = health.vulnerabletoheatdamage
            end
            health.vulnerabletoheatdamage =
                self.base_heat_vulnerable and self.red_bonus < MAX_RESIST
        end

        if self.red_bonus >= MAX_RESIST then
            self.inst:AddTag("fireimmune")
        else
            self.inst:RemoveTag("fireimmune")
        end
    end

    local temperature = self.inst.components.temperature
    if temperature ~= nil then
        if temperature.overheattemp ~= nil then
            if self.base_overheattemp == nil then
                self.base_overheattemp = temperature.overheattemp
            end
            temperature.overheattemp = self.red_bonus >= MAX_RESIST
                and 1000 or self.base_overheattemp
        end

        if temperature.inherentsummerinsulation ~= nil then
            if self.base_summer_insulation == nil then
                self.base_summer_insulation =
                    temperature.inherentsummerinsulation
            end
            temperature.inherentsummerinsulation =
                self.red_bonus >= MAX_RESIST
                and 10000 or self.base_summer_insulation
        end

        if temperature.inherentinsulation ~= nil then
            if self.base_winter_insulation == nil then
                self.base_winter_insulation = temperature.inherentinsulation
            end
            temperature.inherentinsulation =
                self.blue_bonus >= MAX_RESIST
                and 10000 or self.base_winter_insulation
        end

        if self.blue_bonus >= MAX_RESIST
            and temperature.SetTemperature ~= nil
            and (temperature.current or 0) < 1
        then
            temperature:SetTemperature(1)
        end
    end

    local freezable = self.inst.components.freezable
    if freezable ~= nil then
        if self.base_freeze_resistance == nil then
            self.base_freeze_resistance = freezable.resistance or 1
        end

        if self.blue_bonus >= MAX_RESIST then
            if freezable.IsFrozen ~= nil and freezable:IsFrozen() then
                if freezable.Unfreeze ~= nil then
                    freezable:Unfreeze()
                end
            end
            if freezable.Reset ~= nil then
                freezable:Reset()
            end

            freezable.resistance = 1000000
            if not self.freeze_overridden then
                self.orig_freeze = freezable.Freeze
                self.orig_addcoldness = freezable.AddColdness
                self.freeze_overridden = true
                if freezable.Freeze ~= nil then
                    freezable.Freeze = function(component) end
                end
                if freezable.AddColdness ~= nil then
                    freezable.AddColdness = function(component, ...) end
                end
            end
        else
            if self.freeze_overridden then
                freezable.Freeze = self.orig_freeze
                freezable.AddColdness = self.orig_addcoldness
                self.orig_freeze = nil
                self.orig_addcoldness = nil
                self.freeze_overridden = nil
            end
            freezable.resistance =
                self.base_freeze_resistance / math.max(0.01, 1 - self.blue_bonus)
        end
    end
end

function Growth:OnSave()
    return {
        bonus = self.bonus,
        red = self.red_bonus,
        blue = self.blue_bonus,
    }
end

function Growth:OnLoad(data)
    -- Bonuses are derived from the altar containers, not from this component.
    self.bonus = 0
    self.red_bonus = 0
    self.blue_bonus = 0
    self.inst:DoTaskInTime(0, function()
        self:Apply()
    end)
end

function Growth:OnInit()
    -- Wait one tick so all player components are ready.
    self.inst:DoTaskInTime(0, function()
        self:Apply()
    end)
end

return Growth
