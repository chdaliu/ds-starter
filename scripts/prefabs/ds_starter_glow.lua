-- Personal glow light parented to the player.

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()

    inst.Light:Enable(true)
    inst.Light:SetRadius(2)
    inst.Light:SetFalloff(0.7)
    inst.Light:SetIntensity(0.65)
    inst.Light:SetColour(223/255, 208/255, 69/255)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("DECOR")

    inst.persists = false

    return inst
end

return Prefab("ds_starter_glow", fn)
