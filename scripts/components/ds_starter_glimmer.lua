-- Permanent personal glow. The radius grows with the number of
-- Magiluminescence amulets stored in altar containers.

local START_RADIUS = 2
local STEP = 0.5
local MAX_RADIUS = 8
local LIGHT_FALLOFF = 0.7
local LIGHT_INTENSITY = 0.65
local LIGHT_COLOUR = { 223 / 255, 208 / 255, 69 / 255 }

local Glimmer = Class(function(self, inst)
    self.inst = inst
    self.radius = START_RADIUS
end)

function Glimmer:GetRadius()
    return self.radius
end

function Glimmer:SetRadius(radius)
    self.radius = math.max(START_RADIUS, math.min(MAX_RADIUS, radius))
    self:Apply()
end

function Glimmer:Apply()
    local player = self.inst
    if player == nil or not player:IsValid() then
        return
    end

    -- Keep the follow/retry task alive even if the glow temporarily cannot
    -- be spawned (for example during a cave transition).
    if self.follow_task == nil then
        self.follow_task = player:DoPeriodicTask(0.1, function()
            local current = player._ds_starter_glow
            if current == nil or not current:IsValid() then
                -- Light entities do not persist across cave/shard
                -- transitions. Recreate the glow instead of leaving the
                -- player in the dark.
                self:Apply()
                return
            end
            local px, py, pz = player.Transform:GetWorldPosition()
            current.Transform:SetPosition(px, py + 0.9, pz)
        end)
    end

    local glow = player._ds_starter_glow
    if glow == nil or not glow:IsValid() then
        glow = SpawnPrefab("ds_starter_glow")
        if glow == nil then
            return
        end
        glow.persists = false
        player._ds_starter_glow = glow
    end

    local x, y, z = player.Transform:GetWorldPosition()
    glow.Transform:SetPosition(x, y + 0.9, z)
    glow.Light:SetRadius(self.radius)
    glow.Light:SetFalloff(LIGHT_FALLOFF)
    glow.Light:SetIntensity(LIGHT_INTENSITY)
    glow.Light:SetColour(
        LIGHT_COLOUR[1],
        LIGHT_COLOUR[2],
        LIGHT_COLOUR[3]
    )
    glow.Light:Enable(true)
    if player.AnimState ~= nil
        and player.AnimState.SetBloomEffectHandle ~= nil
    then
        player.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    end
end

function Glimmer:OnSave()
    return { radius = self.radius }
end

function Glimmer:OnLoad(data)
    -- Radius is derived from the altar container.
    self.radius = START_RADIUS
    self.inst:DoTaskInTime(0, function()
        self:Apply()
    end)
end

return Glimmer
