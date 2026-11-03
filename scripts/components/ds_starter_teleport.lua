-- Per-player teleport beacons.

-- One turf tile is 4 world units.
local MIN_BEACON_DISTANCE = 4

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

local function SanitizeName(name)
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
end)

function Teleport:GetBeacons()
    return self.beacons
end

function Teleport:GetCount()
    return #self.beacons
end

function Teleport:CanAddAt(x, z)
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
    if self.beacons[index] == nil then
        return false
    end
    table.remove(self.beacons, index)
    return true
end

-- Swap a beacon with its neighbour so the list order can be adjusted.
function Teleport:MoveBeacon(index, delta)
    local target = index + delta
    if self.beacons[index] == nil or self.beacons[target] == nil then
        return false
    end
    self.beacons[index], self.beacons[target] =
        self.beacons[target], self.beacons[index]
    return true
end

function Teleport:GetBeacon(index)
    return self.beacons[index]
end

function Teleport:SetBeaconName(index, name)
    local beacon = self.beacons[index]
    if beacon == nil then
        return false
    end
    beacon.name = SanitizeName(name)
    return true
end

function Teleport:GetBeaconName(index)
    local beacon = self.beacons[index]
    if beacon == nil then
        return ""
    end
    return beacon.name or ""
end

function Teleport:TeleportTo(index)
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
    return { beacons = self.beacons }
end

function Teleport:OnLoad(data)
    self.beacons = {}
    if data == nil or data.beacons == nil then
        return
    end

    for i = 1, #data.beacons do
        local beacon = data.beacons[i]
        if beacon ~= nil and beacon.x ~= nil and beacon.z ~= nil then
            self.beacons[#self.beacons + 1] = {
                x = beacon.x,
                y = beacon.y or 0,
                z = beacon.z,
                name = SanitizeName(beacon.name),
            }
        end
    end
end

return Teleport
