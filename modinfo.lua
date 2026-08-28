-- The modinfo environment only provides folder_name, locale and
-- ChooseTranslationTable, so this file uses plain Lua syntax and literals
-- only. Do not use string.*, ipairs, pairs or tostring here.
local function L(en, zh)
    if ChooseTranslationTable ~= nil then
        return ChooseTranslationTable({
            en,
            zh = zh,
            zhr = zh,
            zht = zh,
            ch = zh,
            chs = zh,
        })
    end
    if locale == "zh" or locale == "zhr" or locale == "zht"
        or locale == "ch" or locale == "chs"
    then
        return zh
    end
    return en
end

name = "新手套装"
description = L(
    "A Don't Starve single-player starter mod for the base game and all DLCs: no freshness, no durability, sacrifice growth, health lock, glimmer, the Blood-Drinking Sword, teleport beacons, infinite backpack, 9999 stacking, auto collect, and five equipment slots.",
    "饥荒单机新手模组，支持原版及全部 DLC：关闭新鲜度、关闭耐久度、钓鱼立即上钩、献祭成长、锁血、微光、饮血剑、传送、无限背包、9999 堆叠、自动拾取、五格装备栏。"
)
author = "lcd"
version = "1.5.0"
forumthread = ""

icon_atlas = "modicon.xml"
icon = "modicon.tex"

api_version = 6

dont_starve_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true
hamlet_compatible = true
dst_compatible = false

PrefabFiles = {
    "ds_starter_altar",
    "ds_starter_infinite_backpack",
    "ds_starter_yinxue_sword",
}

local ON = L("Enabled", "开启")
local OFF = L("Disabled", "关闭")

configuration_options = {
    {
        name = "NO_SPOILAGE",
        label = L("No Freshness", "关闭新鲜度"),
        hover = L(
            "Every item with freshness (food, ham bat, flowers, etc.) stays at 100% and never spoils.",
            "所有带新鲜度的物品（食物、火腿棒、花等）永远保持 100%，不会腐烂或变质。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "NO_DURABILITY",
        label = L("No Durability", "关闭耐久度"),
        hover = L(
            "Tools, weapons, and armor never consume durability.",
            "工具、武器和护甲不再消耗耐久。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "NO_FUEL_CONSUMPTION",
        label = L("No Fuel Consumption", "无燃料消耗"),
        hover = L(
            "Torches, lanterns, and other fueled items never run out of fuel. This is separate from item durability.",
            "火把、灯笼等燃料类物品不会耗尽燃料，与物品耐久相互独立。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "HEALTH_LOCK",
        label = L("Health Lock", "锁血"),
        hover = L(
            "Player health and boat health cannot drop below 1, preventing death and sinking.",
            "玩家和船只的血量都不会降到 1 以下，不会死亡或沉船。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "SACRIFICE_GROWTH",
        label = L("Sacrifice Growth", "献祭成长"),
        hover = L(
            "Build a 64-slot altar container. Store gems/amulets inside to gain effects; remove them to reduce the effect. Purple gems: +5% all stats (max +200%). Red/blue gems: resistance (max 100%).",
            "建造 64 格祭坛容器。放入宝石/护符获得效果，取出会降低。紫宝石提升全属性（最高 +200%）；红/蓝宝石提升抗性（最高 100%）。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "TELEPORT",
        label = L("Teleport Beacons", "传送"),
        hover = L(
            "Adds an independent teleport panel with unlimited named beacons. It does not require the Blood-Drinking Sword.",
            "独立的传送面板，信标数量不限、可改名，不需要手持饮血剑。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "TELEPORT_SHORTCUT",
        label = L("Teleport Shortcut", "传送快捷键"),
        hover = L(
            "Key combination used to open or close the teleport panel.",
            "用于打开或关闭传送面板的组合键。"
        ),
        options = {
            { description = L("Shift + Right Click", "Shift + 右键"), data = "MOUSE_SHIFT" },
            { description = L("Ctrl + Right Click", "Ctrl + 右键"), data = "MOUSE_CTRL" },
            { description = L("Alt + Right Click", "Alt + 右键"), data = "MOUSE_ALT" },
        },
        default = "MOUSE_SHIFT",
    },
    {
        name = "INSTANT_FISH",
        label = L("Instant Fishing", "钓鱼立即上钩"),
        hover = L(
            "Fish bite immediately after casting, and reeling is automatic, removing the fishing wait and struggle time.",
            "抛竿后鱼会立即上钩，并自动收杆，取消等待和拉扯时间。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "GLIMMER",
        label = L("Glimmer", "微光"),
        hover = L(
            "The player has an innate Magiluminescence light. Store yellow amulets in the altar container to increase its radius from 2 to 8.",
            "玩家自带魔光护符光照。把魔光护符（黄护符）放进祭坛容器，可将半径从 2 提升到 8。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "YINXUE_SWORD",
        label = L("Blood-Drinking Sword", "饮血剑"),
        hover = L(
            "Adds the Blood-Drinking Sword, a weapon that grows stronger with monster kills (max 150 damage). Right-click to blink.",
            "增加饮血剑：击杀怪物可提升伤害的成长武器（最高 150 点）。手持时右键闪现。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "FIVE_SLOTS",
        label = L("Five Equipment Slots", "五格装备栏"),
        hover = L(
            "Adds separate Backpack and Amulet equipment slots to the HUD.",
            "在正常 HUD 的装备栏中增加背包槽和项链槽。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "INFINITE_BACKPACK",
        label = L("Infinite Backpack", "无限背包"),
        hover = L(
            "Grants a starting backpack with up to 9 pages of 120 slots (1,080 total). It cannot be crafted. If lost it is not replaced, but toggling this option off and on grants it again.",
            "角色初始获得背包，每页最多 120 格、最多 9 页（共 1080 格），无法合成。丢失后不会自动补发，但关闭再开启此选项会重新给予。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "STACK_9999",
        label = L("9999 Stack Size", "9999 堆叠"),
        hover = L(
            "Raises the maximum stack size of stackable items to 9999.",
            "将所有可堆叠物品的最大堆叠数量提升到 9999。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
    {
        name = "AUTO_COLLECT",
        label = L("Auto Collect", "自动拾取"),
        hover = L(
            "The player has an innate Lazy Forager effect. Store orange amulets in the altar container to increase the pickup radius from 4 to 10.",
            "玩家自带懒人护符效果。把懒人护符（橙护符）放进祭坛容器，可将拾取范围从 4 提升到 10。"
        ),
        options = {
            { description = OFF, data = false },
            { description = ON, data = true },
        },
        default = false,
    },
}
