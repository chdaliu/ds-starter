-- Persistent per-player flags that must survive feature toggles.

local FLAG_VERSION = 2

local Flags = Class(function(self, inst)
    self.inst = inst
    self.sword_granted = false
    self.backpack_granted = false
    self.test_altar_granted = false
    self.test_materials_granted = false
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

function Flags:HasTestAltarGranted()
    return self.test_altar_granted
end

function Flags:SetTestAltarGranted()
    self.test_altar_granted = true
end

function Flags:ResetTestAltarGranted()
    self.test_altar_granted = false
end

function Flags:HasTestMaterialsGranted()
    return self.test_materials_granted
end

function Flags:SetTestMaterialsGranted()
    self.test_materials_granted = true
end

function Flags:ResetTestMaterialsGranted()
    self.test_materials_granted = false
end

function Flags:OnSave()
    return {
        sword_granted = self.sword_granted,
        backpack_granted = self.backpack_granted,
        test_altar_granted = self.test_altar_granted,
        test_materials_granted = self.test_materials_granted,
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
        self.test_altar_granted = data.test_altar_granted == true
        self.test_materials_granted = data.test_materials_granted == true
    end
end

return Flags
