-- Sacrificial Altar (Don't Starve single-player)
-- Now a 64-slot container: gems and amulets stored inside grant effects.
-- Taking items out reduces the effect; destroying it drops everything.

local assets = {
    -- Ancient Pseudoscience Station from the ruins: the vanilla bank/anim.
    Asset("ANIM", "anim/crafting_table.zip"),
    -- Repainted build/atlas shipped by this mod.
    Asset("ANIM", "anim/ds_starter_altar.zip"),
    Asset("ATLAS", "images/inventoryimages/ds_starter_altar.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_altar.tex"),
    -- Five-slot equipment-bar watermarks. Keep these on an always-loaded
    -- prefab as well, so the HUD can use them even if modmain Assets are
    -- reloaded/unloaded during world hops.
    Asset("ATLAS", "images/inventoryimages/ds_starter_slot_backpack.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_slot_backpack.tex"),
    Asset("ATLAS", "images/inventoryimages/ds_starter_slot_amulet.xml"),
    Asset("IMAGE", "images/inventoryimages/ds_starter_slot_amulet.tex"),
    -- Only used as a fallback if the custom 8x8 UI is unavailable.
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
}

local SLOT_COUNT = 64
local SLOT_COLS = 8
local SLOT_ROWS = 8
local SLOT_SPACING = 70

local function IsChinese()
    local code = nil
    if LOC ~= nil and LOC.GetLocaleCode ~= nil then
        local ok, value = pcall(LOC.GetLocaleCode)
        if ok then
            code = value
        end
    end
    if code == nil and LanguageTranslator ~= nil then
        code = LanguageTranslator.defaultlang
    end
    if code == nil then
        return false
    end
    code = string.lower(tostring(code))
    return code == "zh" or code == "zhr" or code == "zht"
        or code == "ch" or code == "chs"
        or string.sub(code, 1, 2) == "zh"
end

local function L(en, zh)
    if IsChinese() then
        return zh
    end
    return en
end

local function MakeSlotPositions()
    local positions = {}
    for row = 1, SLOT_ROWS do
        for col = 1, SLOT_COLS do
            table.insert(positions, Vector3(
                (col - (SLOT_COLS + 1) / 2) * SLOT_SPACING,
                ((SLOT_ROWS + 1) / 2 - row) * SLOT_SPACING,
                0
            ))
        end
    end
    return positions
end

local function Recalculate()
    local recalc = _G.rawget(_G, "DSStarterRecalculateAltarEffects")
    if recalc ~= nil then
        pcall(recalc)
    end
end

local function RegisterAltar(inst)
    local altars = _G.rawget(_G, "DS_STARTER_ALTARS")
    if altars == nil then
        altars = {}
        _G.DS_STARTER_ALTARS = altars
    end
    altars[inst] = true
    Recalculate()
end

local function UnregisterAltar(inst)
    local altars = _G.rawget(_G, "DS_STARTER_ALTARS")
    if altars ~= nil then
        altars[inst] = nil
    end
    Recalculate()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    MakeObstaclePhysics(inst, 0.35)

    -- Use the ruins' Ancient Pseudoscience Station model, scaled down to
    -- roughly the footprint of a Science Machine.
    inst.AnimState:SetBank("crafting_table")
    inst.AnimState:SetBuild("ds_altar_build")
    inst.AnimState:PlayAnimation("idle")
    inst.Transform:SetScale(0.55, 0.55, 0.55)

    inst:AddTag("altar")
    inst:AddTag("ds_starter_altar")
    inst:AddTag("structure")
    inst:AddTag("stone")

    inst:AddComponent("inspectable")

    inst:AddComponent("container")
    local positions = MakeSlotPositions()
    inst.components.container:SetNumSlots(SLOT_COUNT)
    inst.components.container.widgetslotpos = positions
    inst.components.container.widgetanimbank = "ui_chest_3x3"
    inst.components.container.widgetanimbuild = "ui_chest_3x3"
    inst.components.container.widgetpos = Vector3(0, 0, 0)
    inst.components.container.side_widget = false
    inst.components.container.type = "chest"

    inst.components.container.onopenfn = function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_open")
        Recalculate()
        -- Recalculate while open as well: merging a stack into an existing
        -- stack does not fire "itemget", so a one-shot event is not enough.
        if inst._ds_starter_recalc_task == nil then
            inst._ds_starter_recalc_task = inst:DoPeriodicTask(
                0.5,
                Recalculate
            )
        end
    end
    inst.components.container.onclosefn = function(inst)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/chest_close")
        if inst._ds_starter_recalc_task ~= nil then
            inst._ds_starter_recalc_task:Cancel()
            inst._ds_starter_recalc_task = nil
        end
        Recalculate()
    end

    inst:AddComponent("lootdropper")
    -- Half of the recipe, rounded up: 1 purple gem, 2 gold, 2 rocks.
    inst.components.lootdropper:SetLoot({
        "purplegem", "goldnugget", "goldnugget", "rocks", "rocks",
    })

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(function(inst, worker)
        if inst.components.container ~= nil then
            inst.components.container:DropEverything()
        end
        if inst.components.lootdropper ~= nil then
            inst.components.lootdropper:DropLoot()
        end
        SpawnPrefab("collapse_small").Transform:SetPosition(
            inst.Transform:GetWorldPosition()
        )
        inst.SoundEmitter:PlaySound("dontstarve/common/destroy_stone")
        inst:Remove()
    end)

    inst.OnLoad = function(inst)
        inst:DoTaskInTime(0.1, Recalculate)
    end

    inst:ListenForEvent("itemget", Recalculate)
    inst:ListenForEvent("itemlose", Recalculate)
    inst:ListenForEvent("onremove", function()
        UnregisterAltar(inst)
    end)

    RegisterAltar(inst)

    return inst
end

return Prefab("ds_starter_altar", fn, assets),
    MakePlacer(
        "ds_starter_altar_placer",
        "crafting_table",
        "ds_altar_build",
        "idle",
        nil,
        nil,
        nil,
        0.55
    )
