# 新手套装 (DS-Starter)

![新手套装](images/modicon.png)

> 简体中文 · [English](#english)
>
> 项目中文名：**新手套装**。面向《饥荒》单机版的新手/便利模组。所有功能默认关闭，按需在游戏内开启。
> A starter / quality-of-life mod for **Don't Starve (single-player)**. Everything is off by default; enable only what you want.

---

# 简体中文

## 安装与启用

1. 将整个 `DS-Starter` 文件夹放进《饥荒》单机版的 `mods` 目录：
   - Windows：`Steam/steamapps/common/Don't Starve/mods/`
   - macOS：找到 `Don't Starve.app` 对应的游戏数据目录，把文件夹放进 `mods/`
2. 启动游戏，打开「模组」菜单，找到 `DS-Starter` 并启用。
3. 进入世界前，在「模组」设置中按需开启本文介绍的功能。
4. 支持原版、RoG、Shipwrecked、Hamlet，以及任意 DLC 组合。

> 本模组只支持单机版，不支持《饥荒：联机版》。

## 功能使用说明

### 1. 关闭新鲜度

- **作用**：所有带新鲜度的物品永远保持 100%，不会腐烂。
- **怎么用**：开启 `No Freshness` 即可，不需要额外操作。
- **设置**：`No Freshness`
- **注意**：食物、火腿棒、花等都会保持新鲜；同时会隐藏物品格上的新鲜度百分比和腐烂背景色。

### 2. 关闭耐久度

- **作用**：工具、武器、护甲不消耗耐久。
- **怎么用**：开启 `No Durability`，正常使用工具/武器/护甲即可。
- **设置**：`No Durability`
- **注意**：只影响 `finiteuses` 和 `armor`；火把、灯笼、矿工帽等燃料不属于耐久，需要另外开启「无燃油消耗」。开启后会隐藏对应的耐久百分比 UI。

### 3. 无燃油消耗

- **作用**：火把、灯笼、矿工帽等燃料物品不消耗燃料。
- **怎么用**：开启 `No Fuel Consumption`，正常使用即可。
- **设置**：`No Fuel Consumption`
- **注意**：默认关闭；开启后会隐藏燃料百分比 UI。

### 4. 锁血

- **作用**：玩家和船只的血量最低保持 1 点，不会死亡或沉船。
- **怎么用**：开启 `Health Lock` 即可；船的血量同样受保护。
- **设置**：`Health Lock`
- **注意**：治疗和 HUD 刷新仍然正常；不要同时安装其他锁血/无敌模组。

### 5. 钓鱼立即上钩

- **作用**：抛竿后鱼立即咬钩，并自动收杆，取消等待和拉扯时间。
- **怎么用**：开启 `Instant Fishing`，正常抛竿即可，鱼咬钩后会自动收线。
- **设置**：`Instant Fishing`
- **注意**：仍然需要抛竿；与其他钓鱼模组冲突时关闭本功能。

### 6. 献祭祭坛

- **作用**：把宝石/护符放进祭坛容器，实时获得对应加成；取走会降低。
- **怎么用**：
  1. 开启 `Sacrifice Growth`（或 `Glimmer` / `Auto Collect`）；
  2. 在魔法制作栏建造祭坛：**1 紫宝石 + 4 金块 + 4 石头**；
  3. 需要 **炼金引擎（科学 Tier 2）** 解锁；
  4. 右键打开祭坛，像箱子一样放入/取出物品。
- **设置**：`Sacrifice Growth`、`Glimmer`、`Auto Collect`
- **外观**：使用洞穴远古遗迹中的远古伪科学站模型，尺寸缩小到接近科学机器，并重绘为暗红石材与金色纹路。
- **容器**：64 格，固定 8×8，箱子式界面；界面右上角有「关闭」按钮。
- **堆叠计算**：按实际堆叠数量计算，例如一组 40 个紫宝石会直接计为 40 个。
- **效果**：
  - 紫宝石：全属性 +5%/个，最高 +200%（40 个）；
  - 红宝石：热抗/灼烧抗性 +5%/个，最高 100%（20 个）；
  - 蓝宝石：冷抗/冰冻抗性 +5%/个，最高 100%（20 个）；
  - 魔光护符：微光半径 +0.5/个，最高 8（12 个）；
  - 懒人护符：自动拾取范围 +0.5/个，最高 10（12 个）。
- **注意**：超过上限数量的物品仍可存放，但不再增加效果；摧毁祭坛会先掉落全部物品，再返还半数材料（紫宝石 1、金块 2、石头 2）。

### 7. 微光

- **作用**：玩家自带魔光护符的光照效果。
- **怎么用**：
  1. 开启 `Glimmer`；
  2. 出生后自动获得微光；
  3. 把 **魔光护符（黄护符）** 放进祭坛容器，每个 +0.5 半径。
- **设置**：`Glimmer`
- **基础光照**：半径 2、Falloff 0.7、Intensity 0.65、黄色光，不需要燃料。
- **数值**：基础 2，最大 8（12 个黄护符）。
- **注意**：祭坛需要开启 `Sacrifice Growth`、`Glimmer` 或 `Auto Collect` 才会注册配方。

### 8. 饮血剑

- **作用**：击杀怪物成长的武器，并提供右键闪现。
- **怎么用**：
  1. 开启 `Blood-Drinking Sword`；
  2. 进入存档时自动获得并装备；
  3. 左键普通攻击，在**空地**上右键向鼠标位置闪现（最大 20 单位，1 秒冷却）。
- **设置**：`Blood-Drinking Sword`
- **成长**：只计算饮血剑的最后一击；普通怪物 +1 杀，Boss +50 杀；每 25 杀结算一次伤害；单次提升不足 1 点伤害时不增加。
- **伤害节点**：0 杀 15；100 杀 45；1,000 杀 75；10,000 杀 105；100,000 杀 150。
- **注意**：无法合成；丢失不补；关闭再开启该设置可重新发放一次（身上已有则不会重复）。右键点击物品、生物或建筑时保持原版操作，不会触发闪现。在水中无法闪现，也不能闪到水面上。

### 9. 传送

- **作用**：独立的传送面板，信标数量不限。
- **怎么用**：
  1. 开启 `Teleport Beacons`；
  2. 在**空地**上默认按 **Shift + 右键** 打开/关闭面板；
  3. 在面板中「添加信标」「改名」「上移/下移」「传送」「删除」。
- **设置**：`Teleport Beacons`、`Teleport Shortcut`
- **快捷键**：默认 Shift+右键，可改为 Ctrl+右键或 Alt+右键。
- **暂停**：面板打开时会暂停游戏，关闭面板后恢复正常速度。
- **注意**：不需要手持饮血剑；每页 8 个信标；新信标必须离已有信标至少 4 单位。火山和地下洞穴可以使用传送面板；Hamlet 的遗迹、洞穴内部和遗迹房子内部等室内场景不能打开面板、传送或添加信标。中文信标名可以正常输入和显示。右键点击物品、生物或建筑时不会打开传送面板，物品的右键操作保持原版。
- **世界独立**：信标列表按世界分别保存，主世界、Shipwrecked、Hamlet、火山和地下洞穴等世界互不影响。

### 10. 五格装备栏

- **作用**：在原版 3 格装备栏基础上增加背包槽和项链槽。
- **怎么用**：开启 `Five Equipment Slots`，正常装备物品即可。
- **设置**：`Five Equipment Slots`
- **槽位外观**：背包槽使用本模组自定义的淡化背包图标，项链槽使用自定义的淡化护符图标，均与原版槽位边框保持一致。
- **槽位限制**：
  - 背包槽只放背包；
  - 项链槽只放护符；
  - 头部槽只放帽子；
  - 身体槽和手部槽拒绝背包、护符、帽子。
- **注意**：如果其他模组已经定义了背包/项链槽，会复用；冲突时直接关闭本模组的五格功能。

### 11. 无限背包

- **作用**：初始获得一个超大容量背包。
- **怎么用**：
  1. 开启 `Infinite Backpack`；
  2. 进入存档时自动获得并装备；
  3. 背包默认关闭，**右键点击已装备的背包图标**打开/关闭。
- **设置**：`Infinite Backpack`
- **容量**：每页最多 120 格，最多 9 页，共 **1080 格**。
- **分页**：当前页物品超过一半时自动开放下一页；第 9 页满后不再增加。
- **整理按钮**：底部换页栏左侧有「整理」按钮，一键按 **工具/武器/防具/帽子/驱虫剂/船/船帆/剃刀/陷阱 → 食物 → 金币 → 种子/肥料 → 材料 → 无用饰品** 的优先级整理当前页。每页单独排序，不会移动或刷新其他页。食物按名称稳定排序，不受堆叠数量或保鲜状态影响；合金、齿轮、石头、树枝、猪皮等可食用材料仍归入材料。
- **关闭按钮**：底部换页栏右侧有「关闭」按钮。
- **其他**：主物品栏满后，拾取物会直接进入无限背包；背包里已有同类未满堆叠时优先堆入背包。
- **世界跳转过滤**：开启无限背包后，跳转世界时会自动过滤传送机零件等世界专属物品；眼骨、Abigail 的花、Lucy、占卜棒等个人物品不受影响。
- **注意**：无法合成；丢失不补；关闭再开启该设置可重新发放一次（已有则不会重复）。

### 12. 自动拾取

- **作用**：玩家自带懒人护符效果，自动拾取附近地面物品。
- **怎么用**：
  1. 开启 `Auto Collect`；
  2. 不需要装备背包，自动生效；
  3. 把 **懒人护符（橙护符）** 放进祭坛容器，每个 +0.5 范围。
- **设置**：`Auto Collect`
- **基础规则**：范围 4、间隔 0.33 秒、使用懒人护符原版过滤规则。
- **数值**：基础 4，最大 10（12 个橙护符）。
- **注意**：物品栏满了会进入无限背包（如果装备）；手动丢弃的物品不会被自动捡回。

### 13. 9999 堆叠

- **作用**：把所有可堆叠物品的最大堆叠数量提升到 9999。
- **怎么用**：开启 `9999 Stack Size`，正常拾取/堆叠即可。
- **设置**：`9999 Stack Size`
- **注意**：默认关闭；关闭后恢复原版堆叠上限。

### 14. 工作队列

- **作用**：按住 Shift 并左键双击目标，自动连续工作，直到目标完成或没有可做的目标。
- **怎么用**：
  1. 开启 `Work Queue`；
  2. 按住 **Shift**，左键双击要工作的目标；
  3. 队列会自动走向视野内最近的目标并执行。
- **支持的目标**：
  - 砍树、挖矿、挖掘
  - 锤击：仅 Hamlet 的易碎瓦罐和海滩上的沉船遗物箱（板条箱）；其他建筑不会自动锤击
  - 采摘、收获
  - 普通草直接用手采摘；高草优先用剪刀，其次砍刀/黄金砍刀；芦苇可在船上采集
  - 翻石头、海贝石：先采集，不会自动接着挖矿
  - 池塘钓鱼、船上钓鱼/浮木
  - 烹饪锅（使用该锅上次配方）
  - 陷阱、捕虫
  - 晾肉架（只使用该架上次材料）
  - 农场种植（只使用该地块上次种子）、施肥（只使用上次肥料）
  - NPC 给予/交易（使用当前拿起的物品；没有拿起时使用上次给过的物品）
  - Hamlet 商店柜台（购买后等待补货，补货后继续买）
  - 已在船上时自动开船前往水上目标
- **规则**：
  - 所有目标按当前位置全局最近优先重排；
  - 工具损坏会自动换下一把，全部用完才停止；
  - 高草会优先使用手里的剪刀/砍刀，不会自动挖草根；翻石头/海贝石采集后也不会自动挖矿，需要再次双击；
  - 搜索范围约为两屏，会继续处理屏幕外的同类目标；
  - 目标没有上次配方/材料/种子/物品时不会操作；
  - 玩家任何主动移动、点击、使用物品、打开界面、攻击或传送都会立即退出队列；
  - 水上任务必须已经坐在船上才会触发，不会自动上船。
- **设置**：`Work Queue`
- **注意**：默认关闭。队列不存档，退出重进会清空；锅/晾肉架/农场/NPC 的“上次使用记录”会保存。

## 快捷键总表

| 操作 | 默认快捷键 | 说明 |
|---|---|---|
| 饮血剑闪现 | 右键空地 | 需要手持饮血剑，最大 20 单位，1 秒冷却；物品/生物/建筑右键保持原版 |
| 打开传送面板 | Shift + 右键空地 | 可在设置中改为 Ctrl/Alt + 右键；物品右键不受影响 |
| 打开无限背包 | 右键点击已装备的背包图标 | 背包默认关闭 |
| 打开祭坛容器 | 右键祭坛 | 放入/取出宝石、护符 |
| 工作队列 | Shift + 左键双击 | 对目标连续工作；任何主动操作都会取消 |

## 默认设置

**所有功能默认关闭。** 进入游戏前，在「模组」设置里按需开启：

`No Freshness`、`No Durability`、`No Fuel Consumption`、`Health Lock`、`Instant Fishing`、`Sacrifice Growth`、`Glimmer`、`Blood-Drinking Sword`、`Teleport Beacons`、`Five Equipment Slots`、`Infinite Backpack`、`Auto Collect`、`9999 Stack Size`、`Work Queue`。

`Teleport Shortcut` 不是开关，默认 `Shift + 右键`。

## 兼容性

- 自定义 prefab 使用 `ds_starter_` 前缀，降低重名概率；
- 五格栏会复用其他模组已定义的背包/项链槽；
- 冲突时优先关闭功能：
  - 两个五格模组 → 关闭本模组的五格；
  - 两个右键模组 → 关闭不需要的那个；
  - 多个 UI 模组 → 关闭本模组的耐久/新鲜度 UI 隐藏；
  - 多个背包模组 → 确认无限背包仍在背包槽。
- prefab 改名后旧存档不兼容，需要新开或删除旧档。

## 语言

设置项、物品名、祭坛提示、传送面板和背包分页按钮会跟随游戏语言：中文显示中文，其他语言显示英文。

## 参考

开发时参考了以下公开仓库，用于核对组件 API 和单机版/联机版差异：

- [xpol/dont-starve-durability-tweaks](https://github.com/xpol/dont-starve-durability-tweaks)
- [czfshine/Don-t-Starve](https://github.com/czfshine/Don-t-Starve)
- [taichunmin/dont-starve-together-game-scripts](https://github.com/taichunmin/dont-starve-together-game-scripts)
- [vietnd69/dst-api-webdocs](https://github.com/vietnd69/dst-api-webdocs)
- [nsimplex/ktech](https://github.com/nsimplex/ktech)

---

# English

## Install and enable

1. Put the entire `DS-Starter` folder into the game's `mods` directory:
   - Windows: `Steam/steamapps/common/Don't Starve/mods/`
   - macOS: locate the `Don't Starve.app` data directory and put the folder in `mods/`.
2. Launch the game, open **Mods**, find `DS-Starter` and enable it.
3. Before entering a world, enable the features you want in the mod settings.
4. Works with the base game, RoG, Shipwrecked, Hamlet and any DLC combination.

> Single-player only. Don't Starve Together is not supported.

## How to use each feature

### 1. No Freshness

- **What it does**: All items with freshness stay at 100% forever.
- **How to use**: Enable `No Freshness`; no other action needed.
- **Setting**: `No Freshness`
- **Notes**: Covers food, the Ham Bat, flowers, etc.; freshness percentages and the spoilage background are hidden.

### 2. No Durability

- **What it does**: Tools, weapons and armor never lose durability.
- **How to use**: Enable `No Durability` and use them normally.
- **Setting**: `No Durability`
- **Notes**: Only `finiteuses` and `armor` are affected. Fuel (torches, lanterns, miner hats) is separate; enable `No Fuel Consumption` for that. Durability percentage UI is hidden.

### 3. No Fuel Consumption

- **What it does**: Torches, lanterns, miner hats and similar items never consume fuel.
- **How to use**: Enable `No Fuel Consumption` and use them normally.
- **Setting**: `No Fuel Consumption`
- **Notes**: Off by default; fuel percentage UI is hidden while enabled.

### 4. Health Lock

- **What it does**: Player and boat health cannot drop below 1, preventing death and sinking.
- **How to use**: Enable `Health Lock`; boat health is protected too.
- **Setting**: `Health Lock`
- **Notes**: Healing and HUD updates still work. Avoid stacking with another health-lock mod.

### 5. Instant Fishing

- **What it does**: Fish bite immediately after casting, and reeling is automatic.
- **How to use**: Enable `Instant Fishing` and cast normally; the fish is reeled in automatically after biting.
- **Setting**: `Instant Fishing`
- **Notes**: You still need to cast. Disable if it conflicts with another fishing mod.

### 6. Sacrificial Altar

- **What it does**: Store gems/amulets in the altar container to gain effects in real time; remove them to reduce the effect.
- **How to use**:
  1. Enable `Sacrifice Growth` (or `Glimmer` / `Auto Collect`);
  2. Build the altar in the Magic tab: **1 Purple Gem + 4 Gold Nuggets + 4 Rocks**;
  3. Requires an **Alchemy Engine (Science Tier 2)**;
  4. Right-click the altar to open it like a chest and add/remove items.
- **Settings**: `Sacrifice Growth`, `Glimmer`, `Auto Collect`
- **Visuals**: Uses the ruins' Ancient Pseudoscience Station model, scaled down to roughly Science Machine size and repainted in dark crimson stone with gold trim.
- **Container**: 64 slots, fixed 8x8, chest-style UI; a **Close** button is in the top-right corner.
- **Stack counting**: Counts the actual stack size, so a stack of 40 purple gems counts as 40.
- **Effects**:
  - Purple Gem: +5% all stats each, up to +200% (40);
  - Red Gem: heat/burn resistance +5% each, up to 100% (20);
  - Blue Gem: cold/freeze resistance +5% each, up to 100% (20);
  - Magiluminescence: glimmer radius +0.5 each, up to 8 (12);
  - Lazy Forager: auto-collect radius +0.5 each, up to 10 (12).
- **Notes**: Items beyond the cap can still be stored but add no effect. Destroying the altar drops all stored items, then refunds half the recipe (1 Purple Gem, 2 Gold, 2 Rocks).

### 7. Glimmer

- **What it does**: The player has the Magiluminescence light effect.
- **How to use**:
  1. Enable `Glimmer`;
  2. The light appears automatically at spawn;
  3. Put **Magiluminescence (yellow amulet)** into the altar container for +0.5 radius each.
- **Setting**: `Glimmer`
- **Base light**: radius 2, falloff 0.7, intensity 0.65, yellow, no fuel.
- **Values**: Base 2, maximum 8 (12 yellow amulets).
- **Notes**: The altar recipe exists if `Sacrifice Growth`, `Glimmer` or `Auto Collect` is enabled.

### 8. Blood-Drinking Sword

- **What it does**: A kill-grown weapon with a right-click blink.
- **How to use**:
  1. Enable `Blood-Drinking Sword`;
  2. It is granted and equipped when entering a save;
  3. Left click to attack, right click on **empty ground** to blink toward the cursor (up to 20 units, 1 second cooldown).
- **Setting**: `Blood-Drinking Sword`
- **Growth**: Only the final blow from this sword counts. Normal monsters +1 kill, bosses +50 kills; damage updates every 25 kills; a step worth less than 1 damage is ignored.
- **Damage breakpoints**: 0 kills 15; 100 kills 45; 1,000 kills 75; 10,000 kills 105; 100,000 kills 150.
- **Notes**: Cannot be crafted; lost swords are not replaced; toggling the setting off and on grants one again if missing. Right-clicking items, creatures or structures keeps the vanilla action instead of blinking. Blinking is disabled while in water and cannot target water.

### 9. Teleport Beacons

- **What it does**: An independent teleport panel with unlimited beacons.
- **How to use**:
  1. Enable `Teleport Beacons`;
  2. Press **Shift + Right Click** on **empty ground** to open or close the panel;
  3. Use Add / Rename / Move up / Move down / Go / Delete in the panel.
- **Settings**: `Teleport Beacons`, `Teleport Shortcut`
- **Shortcut**: Shift+Right Click by default; can be changed to Ctrl+Right Click or Alt+Right Click.
- **Notes**: No sword required. 8 beacons per page. New beacons need at least 4 units of spacing. The volcano and real underground caves support the teleport panel; Hamlet interiors such as ruins, cave interiors and relic-house interiors cannot open the panel, teleport or add beacons. Chinese names are supported. Right-clicking items, creatures or structures does not open the panel, so vanilla item right-click actions keep working.
- **Per-world lists**: Beacons are saved separately for each world, so the main world, Shipwrecked, Hamlet, the volcano, underground caves and other worlds no longer share one list.

### 10. Five Equipment Slots

- **What it does**: Adds a backpack slot and an amulet slot to the normal equipment bar.
- **How to use**: Enable `Five Equipment Slots` and equip items normally.
- **Setting**: `Five Equipment Slots`
- **Slot visuals**: The backpack slot uses the mod's custom faded backpack icon and the amulet slot uses its custom faded amulet icon, both on the standard slot frame.
- **Slot restrictions**:
  - Backpack slot: backpacks only;
  - Amulet slot: amulets only;
  - Head slot: hats only;
  - Body and hand slots: reject backpacks, amulets and hats.
- **Notes**: Existing `EQUIPSLOTS.BACK/NECK` from other mods are reused. If two five-slot mods conflict, disable this one.

### 11. Infinite Backpack

- **What it does**: Grants a very large starting backpack.
- **How to use**:
  1. Enable `Infinite Backpack`;
  2. It is granted and equipped when entering a save;
  3. It starts closed; **right-click the equipped backpack icon** to open or close it.
- **Setting**: `Infinite Backpack`
- **Capacity**: Up to 120 slots per page, 9 pages, **1,080 slots** total.
- **Pages**: The next page unlocks when the current last page is more than half full; page 9 is the maximum.
- **Sort button**: The **Sort** button on the left of the paging bar orders the current page as tools/weapons/armor/hats/bug repellent/boats/sails/razors/traps, food, coins, seeds/fertilizer, materials, then low-value trinkets. Each page is sorted separately, and other pages are not moved or refreshed. Food keeps a stable name order independent of stack size and freshness; edible crafting materials such as alloy, gears, rocks, twigs and pigskin stay in the material group.
- **Close button**: A **Close** button is on the right side of the bottom paging bar.
- **Other**: When the main inventory is full, pickups go into the backpack; unfinished stacks already in the backpack are filled first.
- **World hop filter**: While the infinite backpack is enabled, Teleportato parts and similar world-progression items are filtered out on a world hop. Personal items such as the eyebone, Abigail's Flower, Lucy and the Divining Rod are kept.
- **Notes**: Cannot be crafted; lost backpacks are not replaced; toggling the setting off and on grants one again if missing.

### 12. Auto Collect

- **What it does**: The player has the Lazy Forager effect and picks up nearby ground items automatically.
- **How to use**:
  1. Enable `Auto Collect`;
  2. No backpack required;
  3. Put **Lazy Forager (orange amulet)** into the altar container for +0.5 range each.
- **Setting**: `Auto Collect`
- **Base rules**: range 4, interval 0.33s, vanilla Lazy Forager filters.
- **Values**: Base 4, maximum 10 (12 orange amulets).
- **Notes**: When the inventory is full, items go into the infinite backpack if equipped. Manually dropped items are not picked up.

### 13. 9999 Stack Size

- **What it does**: Raises the maximum stack size of all stackable items to 9999.
- **How to use**: Enable `9999 Stack Size` and pick up / stack items normally.
- **Setting**: `9999 Stack Size`
- **Notes**: Off by default; turning it off restores vanilla stack limits.

### 14. Work Queue

- **What it does**: Hold Shift and left double-click a target to keep working automatically until it is done or nothing valid is left.
- **How to use**:
  1. Enable `Work Queue`;
  2. Hold **Shift** and left double-click the target;
  3. The queue walks to the nearest visible target and repeats the action.
- **Supported targets**:
  - chop, mine, dig
  - hammer: only Hamlet's smashing pot and the Shipwrecked beach crate (shipwreck relic crate); other structures are never auto-hammered
  - pick, harvest
  - normal grass is picked by hand; tall grass prefers shears, then machete/golden machete; reeds can be picked from a boat
  - flippable and limpet rocks: harvest first, never auto-mine afterwards
  - pond fishing, boat fishing/flotsam
  - crock pot (uses that pot's last recipe)
  - traps, bug net
  - dryer (only the dryer's last material)
  - farm planting (only that plot's last seed), fertilizing (only the last fertilizer)
  - trading/giving (uses the item currently held; otherwise reuses the last item given to that NPC)
  - Hamlet shop counters (wait for restock and keep buying)
  - auto-sail to visible water targets while already on a boat
- **Rules**:
  - All targets are re-sorted globally by distance from the player;
  - Broken tools are replaced automatically; the queue stops only when no usable tool is left;
  - Tall grass prefers the shears/machete in hand; grass roots are not auto-dug, and flippable/limpet rocks are not auto-mined after harvesting - double-click again to dig/mine;
  - The search radius is about two screens, so off-screen matching targets continue to be processed;
  - Targets without a remembered recipe/material/seed/item are skipped;
  - Any manual movement, click, item use, UI open, attack or teleport cancels the queue;
  - Water jobs only start while already on a boat; the queue never boards a boat automatically.
- **Setting**: `Work Queue`
- **Notes**: Off by default. The queue itself is not saved and clears on reload; remembered inputs for pots, dryers, farms and NPCs are saved.

## Shortcut summary

| Action | Default | Notes |
|---|---|---|
| Blood-Drinking Sword blink | Right Click on empty ground | Sword must be equipped; max 20 units, 1 second cooldown; item/creature/structure right-clicks keep vanilla behaviour |
| Open teleport panel | Shift + Right Click on empty ground | Can be changed to Ctrl/Alt + Right Click; pauses the game while open; item right-clicks are unaffected |
| Open infinite backpack | Right-click the equipped backpack icon | Starts closed |
| Open altar container | Right-click the altar | Add/remove gems and amulets |
| Work queue | Shift + Left double-click | Keep working on the target; any manual action cancels |

## Defaults

**All features are off by default.** Enable what you need in the mod settings:

`No Freshness`, `No Durability`, `No Fuel Consumption`, `Health Lock`, `Instant Fishing`, `Sacrifice Growth`, `Glimmer`, `Blood-Drinking Sword`, `Teleport Beacons`, `Five Equipment Slots`, `Infinite Backpack`, `Auto Collect`, `9999 Stack Size`, `Work Queue`.

`Teleport Shortcut` is not a toggle; its default is `Shift + Right Click`.

## Compatibility

- Custom prefabs use the `ds_starter_` prefix.
- The five-slot feature reuses existing backpack/amulet slots from other mods.
- When conflicts occur, disable the overlapping feature:
  - Two five-slot mods: disable this one.
  - Two right-click mods: disable the one you do not need.
  - Multiple item-info/UI mods: disable this mod's durability/freshness UI hiding.
  - Multiple backpack mods: make sure the infinite backpack is still in the backpack slot.
- Prefab renames are not save-compatible; old saves must be restarted or deleted.

## Language

Settings, item names, altar messages, the teleport panel and backpack paging follow the game language: Chinese for Chinese locales, English otherwise.

## References

- [xpol/dont-starve-durability-tweaks](https://github.com/xpol/dont-starve-durability-tweaks)
- [czfshine/Don-t-Starve](https://github.com/czfshine/Don-t-Starve)
- [taichunmin/dont-starve-together-game-scripts](https://github.com/taichunmin/dont-starve-together-game-scripts)
- [vietnd69/dst-api-webdocs](https://github.com/vietnd69/dst-api-webdocs)
- [nsimplex/ktech](https://github.com/nsimplex/ktech)
