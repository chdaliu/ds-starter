-- Persistent per-player flags that must survive feature toggles.

local FLAG_VERSION = 2

local Flags = Class(function(self, inst)
    self.inst = inst
    self.sword_granted = false
    self.backpack_granted = false
end)

function Flags:HasSwordGranted()
    return self.sword_granted
end

function Flags:SetSwordGranted()
    self.sword_granted = true
end

function Flags:ResetSwordGranted()
    self.sword_granted = false
end

function Flags:HasBackpackGranted()
    return self.backpack_granted
end

function Flags:SetBackpackGranted()
    self.backpack_granted = true
end

function Flags:ResetBackpackGranted()
    self.backpack_granted = false
end

function Flags:OnSave()
    return {
        sword_granted = self.sword_granted,
        backpack_granted = self.backpack_granted,
        version = FLAG_VERSION,
    }
end

function Flags:OnLoad(data)
    if data == nil then
        return
    end

    if data.version == nil or data.version < FLAG_VERSION then
        -- Older saves could mark an item as granted even when its prefab
        -- failed to spawn. Reset once; the grant logic checks the player's
        -- inventory first, so an existing item is never duplicated.
        self.sword_granted = false
        self.backpack_granted = false
    else
        self.sword_granted = data.sword_granted == true
        self.backpack_granted = data.backpack_granted == true
    end
end

return Flags
