-- Innate Lazy Forager-like auto collection.
-- Range and filtering follow the vanilla orange amulet; the only added rule
-- is a radius that grows with orange amulets stored in the altar.

local START_RADIUS = 4
local MAX_RADIUS = 10
local PICKUP_INTERVAL = 0.33

local MUST_TAGS = { "isinventoryitem" }
local CANT_TAGS = {
    "sunken", "bookshelfed", "INLIMBO", "NOCLICK", "NOFORAGE",
    "catchable", "fire", "minesprung", "mineactive", "spider",
    "ds_starter_manual_drop",
}

local function HasOverflowRoom(inventory, item)
    local overflow = inventory.overflow
    if overflow == nil or overflow.components.container == nil then
        return false
    end

    local container = overflow.components.container
    for i = 1, container:GetNumSlots() do
        local existing = container:GetItemInSlot(i)
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
    return false
end

local function CanAcceptItem(inventory, item)
    if inventory:GetNextAvailableSlot(item) ~= nil then
        return true
    end
    return HasOverflowRoom(inventory, item)
end

local AutoCollect = Class(function(self, inst)
    self.inst = inst
    self.radius = START_RADIUS
    self.task = nil
end)

function AutoCollect:GetRadius()
    return self.radius
end

function AutoCollect:SetRadius(radius)
    self.radius = math.max(START_RADIUS, math.min(MAX_RADIUS, radius))
end

function AutoCollect:Pickup(owner)
    if owner == nil or owner.components.inventory == nil then
        return
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(
        x, y, z, self.radius, MUST_TAGS, CANT_TAGS
    )
    local buffered = owner:GetBufferedAction()

    for i = 1, #ents do
        local item = ents[i]
        if item.components.inventoryitem ~= nil
            and item.components.inventoryitem.canbepickedup
            and item.components.inventoryitem.cangoincontainer
            and not item.components.inventoryitem:IsHeld()
            and (buffered == nil
                or buffered.action ~= ACTIONS.PICKUP
                or buffered.target ~= item)
            and CanAcceptItem(owner.components.inventory, item)
        then
            local puff = SpawnPrefab("sand_puff")
            if puff ~= nil then
                puff.Transform:SetPosition(
                    item.Transform:GetWorldPosition()
                )
            end

            local item_pos = item:GetPosition()
            if item.components.stackable ~= nil then
                item = item.components.stackable:Get()
            end

            if item.components.trap ~= nil
                and item.components.trap:IsSprung()
            then
                item.components.trap:Harvest(owner)
            else
                owner.components.inventory:GiveItem(
                    item,
                    nil,
                    Vector3(TheSim:GetScreenPos(item_pos:Get()))
                )
            end

            return
        end
    end
end

function AutoCollect:Start()
    if self.task ~= nil then
        return
    end
    self.task = self.inst:DoPeriodicTask(PICKUP_INTERVAL, function()
        self:Pickup(self.inst)
    end)
end

function AutoCollect:OnLoad(data)
    self.radius = START_RADIUS
    self:Start()
end

return AutoCollect
