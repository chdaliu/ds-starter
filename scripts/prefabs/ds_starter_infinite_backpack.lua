local assets =
{
    Asset("ANIM", "anim/backpack.zip"),
    Asset("ANIM", "anim/swap_backpack.zip"),
    Asset("ANIM", "anim/ui_backpack_2x4.zip"),
    Asset("ATLAS", "images/inventoryimages/ds_starter_infinite_backpack.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_infinite_backpack.tex"),
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "swap_backpack", "backpack")
    owner.AnimState:OverrideSymbol("swap_body", "swap_backpack", "swap_body")

    -- Let the inventory fall back to this container when all normal slots
    -- are full, so picked-up items go straight into the infinite backpack.
    if owner.components.inventory ~= nil then
        owner.components.inventory:SetOverflow(inst)
    end
    -- The container stays closed until the player opens it (right-click).
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    if owner.components.inventory ~= nil then
        owner.components.inventory:SetOverflow(nil)
    end
    if inst.components.container ~= nil then
        inst.components.container:Close(owner)
    end
end

local function onequiptomodel(inst, owner, from_ground)
    if owner ~= nil and owner.components.inventory ~= nil then
        owner.components.inventory:SetOverflow(nil)
    end
    if inst.components.container ~= nil then
        inst.components.container:Close(owner)
    end
end

local function fn(Sim)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("backpack1")
    inst.AnimState:SetBuild("swap_backpack")
    inst.AnimState:PlayAnimation("anim")
    -- Warm leather tint that matches the custom inventory icon.
    inst.AnimState:SetMultColour(1.0, 0.88, 0.68, 1)
    inst.AnimState:SetAddColour(0.05, 0.03, 0, 0)

    local minimap = inst.entity:AddMiniMapEntity()
    minimap:SetIcon("backpack.png")

    inst:AddTag("backpack")
    inst:AddTag("ds_starter_infinite_backpack")
    inst:AddTag("irreplaceable")

    inst.foleysound = "dontstarve/movement/foley/backpack"

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.cangoincontainer = false
    inst.components.inventoryitem.atlasname =
        "images/inventoryimages/ds_starter_infinite_backpack.xml"
    inst.components.inventoryitem.imagename =
        "ds_starter_infinite_backpack"

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    if inst.components.equippable.SetOnEquipToModel ~= nil then
        inst.components.equippable:SetOnEquipToModel(onequiptomodel)
    end

    inst:AddComponent("container")
    -- Large capacity; the widget unlocks pages on demand (240 slots each).
    inst.components.container:SetNumSlots(120 * 9)
    inst.components.container.widgetslotpos = {}
    inst.components.container.widgetanimbank = "ui_backpack_2x4"
    inst.components.container.widgetanimbuild = "ui_backpack_2x4"
    inst.components.container.widgetpos = Vector3(0, 0, 0)
    inst.components.container.side_widget = false
    inst.components.container.type = "pack"
    inst.components.container.onopenfn = function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/backpack_open", "open")
    end
    inst.components.container.onclosefn = function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/backpack_close", "open")
    end

    return inst
end

return Prefab("ds_starter_infinite_backpack", fn, assets)
