-- Per-player teleport beacons, stored independently for each world.

-- One turf tile is 4 world units.
local MIN_BEACON_DISTANCE = 4
local UNKNOWN_WORLD_KEY = "__unknown_world__"
local SanitizeName

local function AddKeyPart(parts, value)
    if value ~= nil and value ~= "" then
        parts[#parts + 1] = tostring(value)
    end
end

-- Build a stable key from the active world. The seed distinguishes different
-- worlds that share a prefab (for example adventure levels), and the tags
-- separate cave / ruins / interior / volcano variants.
local function GetWorldKey()
    local world = GetWorld()
    if world == nil then
        return UNKNOWN_WORLD_KEY
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

local function SanitizeBeacons(list)
    local beacons = {}
    if list == nil then
        return beacons
    end
    for i = 1, #list do
        local beacon = list[i]
        if beacon ~= nil and beacon.x ~= nil and beacon.z ~= nil then
            beacons[#beacons + 1] = {
                x = beacon.x,
                y = beacon.y or 0,
                z = beacon.z,
                name = SanitizeName(beacon.name),
            }
        end
    end
    return beacons
end

local function Utf8Sub(str, max_chars)
    local count = 0
    local i = 1
    while i <= #str and count < max_chars do
        local b = str:byte(i)
        local len = 1
        if b >= 240 then
            len = 4
        elseif b >= 224 then
            len = 3
        elseif b >= 192 then
            len = 2
        end
        i = i + len
        count = count + 1
    end
    return str:sub(1, i - 1)
end

SanitizeName = function(name)
    if name == nil then
        return ""
    end
    -- Keep the serialized format simple and safe.
    name = string.gsub(name, "[;,\r\n]", " ")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    -- Truncate by UTF-8 characters so Chinese names are not split mid-byte.
    name = Utf8Sub(name, 32)
    return name
end

local Teleport = Class(function(self, inst)
    self.inst = inst
    self.beacons = {}
    self.world_beacons = {}
    self.current_world_key = nil
end)

function Teleport:EnsureWorld()
    local key = GetWorldKey()
    local old_key = self.current_world_key

    -- The world may not have been fully available during OnLoad, or extra
    -- identifying metadata may have appeared later. Move beacons from the
    -- fallback/partial key to the full key instead of losing them.
    if old_key ~= nil and old_key ~= key then
        local pending = nil
        if old_key == UNKNOWN_WORLD_KEY then
            pending = self.world_beacons[old_key]
        elseif string.sub(key, 1, #old_key + 1) == old_key .. "|" then
            pending = self.world_beacons[old_key]
        end

        if pending ~= nil
            and #pending > 0
            and self.world_beacons[key] == nil
        then
            self.world_beacons[key] = pending
        end
        if pending ~= nil then
            self.world_beacons[old_key] = nil
        end
    end

    if old_key ~= key then
        self.current_world_key = key
        local beacons = self.world_beacons[key]
        if beacons == nil then
            beacons = {}
            self.world_beacons[key] = beacons
        end
        self.beacons = beacons
    end

    return self.beacons
end

function Teleport:GetBeacons()
    self:EnsureWorld()
    return self.beacons
end

function Teleport:GetCount()
    self:EnsureWorld()
    return #self.beacons
end

function Teleport:CanAddAt(x, z)
    self:EnsureWorld()
    for i = 1, #self.beacons do
        local beacon = self.beacons[i]
        local dx = x - beacon.x
        local dz = z - beacon.z
        if dx * dx + dz * dz < MIN_BEACON_DISTANCE * MIN_BEACON_DISTANCE then
            return false, "too_close"
        end
    end

    return true
end

function Teleport:AddBeacon(x, y, z)
    self:EnsureWorld()
    local ok, reason = self:CanAddAt(x, z)
    if not ok then
        return false, reason
    end

    self.beacons[#self.beacons + 1] = {
        x = x,
        y = y or 0,
        z = z,
        name = "",
    }
    return true
end

function Teleport:RemoveBeacon(index)
    self:EnsureWorld()
    if self.beacons[index] == nil then
        return false
    end
    table.remove(self.beacons, index)
    return true
end

-- Swap a beacon with its neighbour so the list order can be adjusted.
function Teleport:MoveBeacon(index, delta)
    self:EnsureWorld()
    local target = index + delta
    if self.beacons[index] == nil or self.beacons[target] == nil then
        return false
    end
    self.beacons[index], self.beacons[target] =
        self.beacons[target], self.beacons[index]
    return true
end

function Teleport:GetBeacon(index)
    self:EnsureWorld()
    return self.beacons[index]
end

function Teleport:SetBeaconName(index, name)
    self:EnsureWorld()
    local beacon = self.beacons[index]
    if beacon == nil then
        return false
    end
    beacon.name = SanitizeName(name)
    return true
end

function Teleport:GetBeaconName(index)
    self:EnsureWorld()
    local beacon = self.beacons[index]
    if beacon == nil then
        return ""
    end
    return beacon.name or ""
end

function Teleport:TeleportTo(index)
    self:EnsureWorld()
    local beacon = self.beacons[index]
    if beacon == nil then
        return false
    end

    local inst = self.inst
    local y = beacon.y or 0
    if inst.Physics ~= nil and inst.Physics.Teleport ~= nil then
        inst.Physics:Teleport(beacon.x, y, beacon.z)
    end
    inst.Transform:SetPosition(beacon.x, y, beacon.z)
    return true
end

function Teleport:Serialize()
    self:EnsureWorld()
    local parts = {}
    for i = 1, #self.beacons do
        local beacon = self.beacons[i]
        parts[i] = string.format(
            "%.2f,%.2f,%.2f,%s",
            beacon.x,
            beacon.y or 0,
            beacon.z,
            beacon.name or ""
        )
    end
    return table.concat(parts, ";")
end

function Teleport:OnSave()
    self:EnsureWorld()
    return { worlds = self.world_beacons }
end

function Teleport:OnLoad(data)
    self.world_beacons = {}
    self.current_world_key = nil
    self.beacons = {}

    if data == nil then
        self:EnsureWorld()
        return
    end

    if data.worlds ~= nil then
        for key, list in pairs(data.worlds) do
            if type(key) == "string" then
                self.world_beacons[key] = SanitizeBeacons(list)
            end
        end
    elseif data.beacons ~= nil then
        -- Older saves stored one shared list. Keep it for the world being
        -- loaded; other worlds start with their own empty lists.
        self.world_beacons[GetWorldKey()] = SanitizeBeacons(data.beacons)
    end

    self:EnsureWorld()
end

return Teleport
