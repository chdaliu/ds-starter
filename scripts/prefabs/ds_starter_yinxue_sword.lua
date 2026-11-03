-- Yinxue Sword (Don't Starve single-player)
-- A kill-grown weapon. Growth is stored on the weapon itself.

local assets = {
    Asset("ANIM", "anim/nightmaresword.zip"),
    Asset("ANIM", "anim/swap_blood_drinking.zip"),
    Asset("ANIM", "anim/ds_blood_sword.zip"),
    Asset("ATLAS", "images/inventoryimages/ds_starter_yinxue_sword.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_yinxue_sword.tex"),
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol(
        "swap_object",
        "swap_blood_drinking",
        "swap_nightmaresword"
    )
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("nightmaresword")
    inst.AnimState:SetBuild("ds_blood_sword")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("weapon")
    inst:AddTag("irreplaceable")

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(15)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname =
        "images/inventoryimages/ds_starter_yinxue_sword.xml"
    inst.components.inventoryitem.imagename = "ds_starter_yinxue_sword"

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent("ds_starter_weapon_growth")

    return inst
end

return Prefab("ds_starter_yinxue_sword", fn, assets)
