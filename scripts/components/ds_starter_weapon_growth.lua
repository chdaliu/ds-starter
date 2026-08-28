-- Persistent kill-based growth for the Yinxue Sword.
-- Every 25 kills moves the sword to the next damage checkpoint, so the weapon
-- grows in visible steps instead of changing on every single kill.

local STEP = 25
local BOSS_KILLS = 50
local MAX_KILLS = 100000

-- Damage breakpoints: base, then the four growth milestones.
local BREAKPOINTS = {
    { kills = 0, damage = 15 },
    { kills = 100, damage = 45 },
    { kills = 1000, damage = 75 },
    { kills = 10000, damage = 105 },
    { kills = 100000, damage = 150 },
}

local function Clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

-- Linear interpolation between the two surrounding breakpoints.
-- Damage is always an integer: a step worth less than 1 point is ignored.
local function DamageAt(kills)
    kills = Clamp(kills, 0, MAX_KILLS)
    if kills >= MAX_KILLS then
        return BREAKPOINTS[#BREAKPOINTS].damage
    end

    for i = 2, #BREAKPOINTS do
        local prev_point = BREAKPOINTS[i - 1]
        local next_point = BREAKPOINTS[i]
        if kills < next_point.kills then
            local span = next_point.kills - prev_point.kills
            local t = span > 0 and (kills - prev_point.kills) / span or 0
            local damage = prev_point.damage
                + (next_point.damage - prev_point.damage) * t
            return math.floor(damage)
        end
    end

    return BREAKPOINTS[#BREAKPOINTS].damage
end

local Growth = Class(function(self, inst)
    self.inst = inst
    self.kills = 0
end)

function Growth:GetKills()
    return self.kills
end

-- Damage only changes when the 25-kill checkpoint changes.
function Growth:GetCheckpoint()
    return math.floor(self.kills / STEP) * STEP
end

function Growth:GetDamage()
    return DamageAt(self:GetCheckpoint())
end

function Growth:Apply()
    local weapon = self.inst.components.weapon
    if weapon ~= nil then
        weapon:SetDamage(self:GetDamage())
    end
end

-- Normal kills add 1; bosses count as 50 kills.
function Growth:AddKill(victim)
    local old_damage = self:GetDamage()

    local amount = 1
    if victim ~= nil and (victim:HasTag("epic") or victim:HasTag("boss")) then
        amount = BOSS_KILLS
    end

    self.kills = Clamp(self.kills + amount, 0, MAX_KILLS)
    local new_damage = self:GetDamage()
    if new_damage > old_damage then
        self:Apply()
    end
    return amount
end

function Growth:OnSave()
    return { kills = self.kills }
end

function Growth:OnLoad(data)
    if data ~= nil and data.kills ~= nil then
        self.kills = Clamp(data.kills, 0, MAX_KILLS)
    end
    self:Apply()
end

function Growth:OnInit()
    self:Apply()
end

return Growth
