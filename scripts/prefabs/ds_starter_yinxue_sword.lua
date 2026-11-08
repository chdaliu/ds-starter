-- Yinxue Sword (Don't Starve single-player)
-- A kill-grown weapon. Growth is stored on the weapon itself.

local assets = {
    Asset("ANIM", "anim/nightmaresword.zip"),
    Asset("ANIM", "anim/swap_blood_drinking.zip"),
    Asset("ANIM", "anim/ds_blood_sword.zip"),
    Asset("ATLAS", "images/inventoryimages/ds_starter_yinxue_sword.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_yinxue_sword.tex"),
}

local prefabs = {
    "sand_puff_large_front",
    "sand_puff_large_back",
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

    -- Use the Lazy Explorer's blink component so right-clicking shows the
    -- vanilla Blink prompt and uses its animation, sand puffs and sounds.
    -- The component is used without durability or cooldown restrictions, but
    -- blinking from a boat to land is not allowed.
    inst:AddComponent("blinkstaff")
    local blinkstaff = inst.components.blinkstaff
    local old_can_blink = blinkstaff.CanBlinkToPoint
    function blinkstaff:CanBlinkToPoint(pt)
        if old_can_blink ~= nil and not old_can_blink(self, pt) then
            return false
        end
        local player = GetPlayer()
        local driver = player ~= nil and player.components.driver or nil
        if driver ~= nil
            and driver.GetIsDriving ~= nil
            and driver:GetIsDriving()
            and pt ~= nil
        then
            local ground = GetWorld()
            if ground ~= nil
                and ground.Map ~= nil
                and ground.Map.GetTileAtPoint ~= nil
            then
                local tile = ground.Map:GetTileAtPoint(pt.x, pt.y, pt.z)
                return ground.Map.IsWater ~= nil
                    and ground.Map:IsWater(tile) == true
            end
            return false
        end
        return true
    end

    return inst
end

return Prefab("ds_starter_yinxue_sword", fn, assets, prefabs)
