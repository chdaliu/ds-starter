-- Persistent altar contributions, split by world.
-- Altars in every visited world keep contributing while the player is
-- elsewhere, so sacrificing gems does not stop working after a world hop.

local COUNT_KEYS = {
    "purplegem",
    "redgem",
    "bluegem",
    "yellowamulet",
    "orangeamulet",
}

local function EmptyCounts()
    local counts = {}
    for i = 1, #COUNT_KEYS do
        counts[COUNT_KEYS[i]] = 0
    end
    return counts
end

local function CopyCounts(source)
    local counts = EmptyCounts()
    if source ~= nil then
        for i = 1, #COUNT_KEYS do
            local key = COUNT_KEYS[i]
            counts[key] = math.max(0, math.floor(tonumber(source[key]) or 0))
        end
    end
    return counts
end

local function AddKeyPart(parts, value)
    if value ~= nil and value ~= "" then
        parts[#parts + 1] = tostring(value)
    end
end

local function GetWorldKey()
    local world = GetWorld()
    if world == nil then
        return "unknown"
    end

    local parts = {}
    AddKeyPart(parts, world.prefab or "world")

    if world.IsCave ~= nil and world:IsCave() then
        AddKeyPart(parts, "cave")
    end
    if world.IsRuins ~= nil and world:IsRuins() then
        AddKeyPart(parts, "ruins")
    end
    if world.HasTag ~= nil then
        local tags = { "cave", "ruins", "ruin", "interior", "indoor", "volcano" }
        for i = 1, #tags do
            if world:HasTag(tags[i]) then
                AddKeyPart(parts, tags[i])
            end
        end
    end

    local meta = world.meta
    if meta ~= nil then
        AddKeyPart(parts, meta.level_id)
        if meta.seed ~= nil then
            AddKeyPart(parts, "seed:" .. tostring(meta.seed))
        end
    end

    return table.concat(parts, "|")
end

local AltarOfferings = Class(function(self, inst)
    self.inst = inst
    self.world_counts = {}
end)

function AltarOfferings:SetWorldCounts(counts)
    self.world_counts[GetWorldKey()] = CopyCounts(counts)
    self:ApplyTotals()
end

function AltarOfferings:GetTotals()
    local totals = EmptyCounts()
    for _, counts in pairs(self.world_counts) do
        for i = 1, #COUNT_KEYS do
            local key = COUNT_KEYS[i]
            totals[key] = totals[key] + (counts[key] or 0)
        end
    end
    return totals
end

function AltarOfferings:ApplyTotals()
    local player = self.inst
    if player == nil or not player:IsValid() then
        return
    end

    local totals = self:GetTotals()

    local growth = player.components.ds_starter_growth
    if growth ~= nil then
        growth:SetBonuses(
            math.min(totals.purplegem, 40),
            math.min(totals.redgem, 20),
            math.min(totals.bluegem, 20)
        )
    end

    local glimmer = player.components.ds_starter_glimmer
    if glimmer ~= nil then
        glimmer:SetRadius(2 + math.min(totals.yellowamulet, 12) * 0.5)
    end

    local autocollect = player.components.ds_starter_autocollect
    if autocollect ~= nil then
        autocollect:SetRadius(4 + math.min(totals.orangeamulet, 12) * 0.5)
    end
end

function AltarOfferings:OnSave()
    return { worlds = self.world_counts }
end

function AltarOfferings:OnLoad(data)
    self.world_counts = {}
    if data ~= nil and data.worlds ~= nil then
        for key, counts in pairs(data.worlds) do
            if type(key) == "string" then
                self.world_counts[key] = CopyCounts(counts)
            end
        end
    end
    self.inst:DoTaskInTime(0, function()
        self:ApplyTotals()
    end)
end

return AltarOfferings
