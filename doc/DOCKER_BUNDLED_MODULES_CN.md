# Docker 镜像内置模块说明

本文档说明本仓库通过 `package-server-images` 工作流打包进 `worldserver` 镜像的 AzerothCore 模块，以及这些模块的主要功能、配置入口和基础使用方式。

模块不是直接提交在仓库的 `modules/` 目录里。打包镜像时，工作流会先执行：

```bash
bash apps/docker/prepare-bundled-modules.sh modules
```

这个脚本会把固定模块集合 clone 到 `modules/`，再交给 Dockerfile 编译。因此，决定生产镜像模块集合的入口是：

- [`apps/docker/prepare-bundled-modules.sh`](../apps/docker/prepare-bundled-modules.sh)
- [`.github/workflows/package-server-images.yml`](../.github/workflows/package-server-images.yml)

## 当前模块集合

| 模块 | 仓库 | 分支 | 配置文件 | SQL |
|---|---|---:|---|---|
| `mod-playerbots` | `https://github.com/mod-playerbots/mod-playerbots.git` | `master` | `playerbots.conf` | `playerbots`、`world`、`characters` |
| `mod-transmog` | `https://github.com/azerothcore/mod-transmog.git` | `master` | `transmog.conf` | `auth`、`characters`、`world` |
| `mod-autobalance` | `https://github.com/azerothcore/mod-autobalance.git` | `master` | `AutoBalance.conf` | 无独立 SQL |
| `mod-ah-bot-plus` | `https://github.com/NathanHandley/mod-ah-bot-plus.git` | `master` | `mod_ahbot.conf` | `auth`、`characters`、`world` |
| `mod-aoe-loot` | `https://github.com/azerothcore/mod-aoe-loot.git` | `master` | `mod_aoe_loot.conf` | 无独立 SQL |
| `mod-learn-spells` | `https://github.com/azerothcore/mod-learn-spells.git` | `master` | `mod_learnspells.conf` | 无独立 SQL |
| `mod-random-enchants` | `https://github.com/azerothcore/mod-random-enchants.git` | `master` | `random_enchants.conf` | `world` |

## 编译和部署方式

生产镜像仍通过 GitHub Actions 手动工作流打包：

1. 打开 GitHub Actions。
2. 运行 `package-server-images`。
3. 保持 `source_ref=Playerbot`，除非要打包其他分支。
4. 填写 `image_tag` 或选择 `tag_latest`。
5. 等待 `worldserver` 和 `authserver` 镜像推送完成。

工作流会先准备模块，再分别构建两个目标：

- `worldserver`：包含编译后的 `worldserver`、模块源码、模块配置和模块 SQL。
- `authserver`：只包含 `authserver` 运行所需内容。

如果需要本地复现打包前的模块准备步骤，可以在仓库根目录执行：

```bash
rm -rf modules/mod-playerbots \
       modules/mod-transmog \
       modules/mod-autobalance \
       modules/mod-ah-bot-plus \
       modules/mod-aoe-loot \
       modules/mod-learn-spells \
       modules/mod-random-enchants

bash apps/docker/prepare-bundled-modules.sh modules
```

注意：`modules/` 下的这些目录是构建产物输入，不是本仓库源码的一部分。不要把临时 clone 下来的模块当作本仓库代码提交，除非明确要改成 vendored 模块模式。

## 配置覆盖方式

镜像启动时会把默认配置整理到：

```text
env/dist/etc/modules/
```

你可以在宿主机提前放置同名文件覆盖默认配置：

```text
env/user/modules/
├── playerbots.conf
├── transmog.conf
├── AutoBalance.conf
├── mod_ahbot.conf
├── mod_aoe_loot.conf
├── mod_learnspells.conf
└── random_enchants.conf
```

容器启动时会先复制默认配置，再复制 `env/user/modules/` 里的同名文件，最后自动修正数据库连接、路径等必须由容器托管的字段。

Linux 文件系统大小写敏感，尤其注意：

- `AutoBalance.conf` 必须保留大写 `A` 和 `B`。

## 数据库导入

首次启动时，`db-prepare` 只负责创建数据库、创建 `acore` 用户和授权。真正的表结构、基础数据、updates 和模块 SQL 由 `worldserver` 在非交互模式下自动导入。

当前模块的数据库行为：

- `mod-playerbots` 会使用独立数据库，默认环境变量是 `AC_PLAYERBOTS_DATABASE=acore_playerbots`。
- `mod-transmog`、`mod-ah-bot-plus`、`mod-random-enchants` 的 SQL 会随 `worldserver` 自动导入到核心库。
- `mod-autobalance`、`mod-aoe-loot`、`mod-learn-spells` 没有独立模块 SQL。
- `mod-ah-bot-plus` 使用 `db-auth`、`db-characters`、`db-world` SQL 目录，目前这些目录主要用于模块更新器布局和占位。
- `mod-random-enchants` 等模块使用上游常见的 `data/sql/db-world` / `data/sql/db-characters` 目录，AzerothCore 自动更新器会直接识别这些目录。打包脚本不会再创建 `data/sql/world` / `data/sql/characters` 兼容链接，避免同一个 SQL 文件被重复扫描。

## mod-playerbots

功能：

- 提供 AI 玩家机器人。
- 支持随机机器人在线、组队补员、任务、升级、地下城和团队副本辅助。
- 当前分支与 `Playerbot` 核心分支配套，不能当作普通 AzerothCore 模块随意移植到未适配核心。

配置文件：

```text
env/dist/etc/modules/playerbots.conf
env/user/modules/playerbots.conf
```

常用配置：

- `AiPlayerbot.Enabled`：启用或禁用模块。
- `AiPlayerbot.RandomBotAutologin`：是否自动登录随机机器人。
- `AiPlayerbot.MinRandomBots` / `AiPlayerbot.MaxRandomBots`：随机机器人在线数量范围。
- `AiPlayerbot.RandomBotMinLevel` / `AiPlayerbot.RandomBotMaxLevel`：随机机器人等级范围。
- `AiPlayerbot.BotAutologin`、`AiPlayerbot.AllowAccountBots`、`AiPlayerbot.AllowGuildBots`：控制账号或公会机器人相关行为。

基础使用：

- 模块命令以 `.playerbot bot` 为主要入口。
- 旧 IKE3 文档里的 `.bot ...` 命令，在本模块里通常需要改写为 `.playerbot bot ...`。
- 机器人控制命令较多，建议结合模块 README 和 Wiki 使用。
- 如果使用中文客户端，可以考虑配合 Unbot Addon 提升控制体验。

运行提醒：

- `db-prepare` 会自动创建 `acore_playerbots` 数据库并授权。
- `worldserver` 会自动把 `PlayerbotsDatabaseInfo` 写入 `playerbots.conf`。
- 如果机器人不能正常施法，优先检查英文 DBC 数据是否完整。

## mod-transmog

功能：

- 提供装备幻化系统。
- 支持通过幻化 NPC 更改装备外观。
- 支持配置外观收藏、隐藏部位、费用、品质限制、武器限制等规则。

配置文件：

```text
env/dist/etc/modules/transmog.conf
env/user/modules/transmog.conf
```

基础使用：

1. 用 GM 账号进入游戏。
2. 在希望放置幻化 NPC 的位置执行：

```text
.npc add 190010
```

3. 玩家与该 NPC 交互进行幻化。

常用命令：

- `.transmog show`：显示自己的幻化外观。
- `.transmog hide`：隐藏自己的幻化外观。
- `.transmog disclaimer on|off`：控制套装提示。

常用配置：

- `Transmogrification.Enable`：启用或禁用模块。
- `Transmogrification.UseCollectionSystem`：是否启用外观收藏逻辑。
- `Transmogrification.AllowMixedArmorTypes`：是否允许跨护甲类型幻化。
- `Transmogrification.AllowMixedWeaponTypes`：控制武器类型限制。
- `Transmogrification.AllowHiddenTransmog`：是否允许隐藏装备外观。

## mod-autobalance

功能：

- 按副本内实际玩家人数自动缩放怪物和 Boss 的生命、法力、护甲、伤害等。
- 适合单人、小队或搭配 Playerbots 体验原本要求更多玩家的副本内容。

配置文件：

```text
env/dist/etc/modules/AutoBalance.conf
env/user/modules/AutoBalance.conf
```

常用命令：

```text
.ab mapstat
.ab creaturestat
.ab getoffset
.ab setoffset <number>
.reload config
```

说明：

- `.ab mapstat` 查看当前地图的 AutoBalance 计算结果。
- `.ab creaturestat` 查看当前目标怪物的缩放结果。
- `.ab setoffset` 可以设置全服玩家人数偏移，让副本按更多或更少玩家来缩放。
- `.reload config` 可以重载 `AutoBalance.conf`。

常用配置：

- `AutoBalance.Enable.Global`：全局启用或禁用模块。
- `AutoBalance.Enable.5M` / `AutoBalance.Enable.10M` / `AutoBalance.Enable.25MHeroic` 等：按副本规模和难度启用或禁用模块。
- `AutoBalance.PlayerChangeNotify`：玩家人数变化时是否提示。
- `AutoBalance.LevelScaling`：是否启用等级缩放。
- `AutoBalance.StatModifier*`：按普通、英雄、团队、Boss 等维度调整属性倍率。

## mod-ah-bot-plus

功能：

- 提供增强版拍卖行机器人。
- 可配置多个普通角色作为 AH Bot 卖家/买家。
- 支持自动上架、自动竞拍/购买、快速重载配置、清空机器人拍卖和立即刷新拍卖。
- 提供更细的价格、堆叠、掉率、分类和高级定价规则。
- 适合低人口服务器维持基础 AH 供给和交易流动性。

配置文件：

```text
env/dist/etc/modules/mod_ahbot.conf
env/user/modules/mod_ahbot.conf
```

基础启用：

1. 准备一个或多个专用普通玩家角色，不建议用真实玩家日常使用的角色，也不要使用 Playerbots 机器人角色。
2. 查出这些角色在 `characters.characters` 表里的 GUID，写入 `AuctionHouseBot.GUIDs`。
3. 启用卖家逻辑：`AuctionHouseBot.EnableSeller = true`。
4. 如需让机器人购买玩家拍卖，再启用买家逻辑：`AuctionHouseBot.Buyer.Enabled = true`。
5. 重启 `worldserver`，让模块按新配置初始化。

常用配置：

- `AuctionHouseBot.EnableSeller`：启用或禁用自动上架。
- `AuctionHouseBot.Buyer.Enabled`：启用或禁用自动竞拍/购买。
- `AuctionHouseBot.GUIDs`：AH Bot 使用的角色 GUID 列表。
- `AuctionHouseBot.ItemsPerCycle`：每轮处理的物品数量。
- `AuctionHouseBot.ReturnExpiredAuctionItemsToBot`：机器人拍卖过期后是否把物品退回机器人。
- `AuctionHouseBot.MaxBuyoutPriceInCopper`：限制机器人可处理的一口价上限。
- `AuctionHouseBot.AdvancedListingRules.UseDropRates.Enabled`：是否按掉率规则筛选上架物品。
- `AuctionHouseBot.ListProportion.*`：控制不同分类和品质的上架比例。
- `AuctionHouseBot.PriceMultiplier.*`：按分类、品质、物品等级等规则调整价格。
- `AuctionHouseBot.ListingStack.*`：控制堆叠数量和堆叠随机规则。

常用命令：

```text
.ahbot reload
.ahbot empty
.ahbot update
```

说明：

- `.ahbot reload` 重新加载 `mod_ahbot.conf`。
- `.ahbot empty` 清空所有 AH Bot 拍卖，不影响玩家拍卖；已有出价会退还给玩家。
- `.ahbot update` 立即触发一次拍卖刷新或补货。
- 默认每个 tick 只上架一部分物品，拍卖行完全铺满需要一些时间；可以通过 `AuctionHouseBot.ItemsPerCycle` 调整。

## mod-aoe-loot

功能：

- 提供范围拾取功能，玩家点击一个尸体时，可以把附近可拾取尸体的金币和物品合并到同一个拾取窗口。
- 支持配置拾取半径，以及是否允许组队状态下使用范围拾取。
- 适合直接作为服务器默认体验启用，减少逐个拾取尸体的操作。

配置文件：

```text
env/dist/etc/modules/mod_aoe_loot.conf
env/user/modules/mod_aoe_loot.conf
```

常用配置：

- `AOELoot.Enable`：全局启用或禁用模块。
- `AOELoot.Message`：玩家登录时是否显示模块提示；如果不需要玩家侧提示，可以设为 `0`。
- `AOELoot.Range`：范围拾取搜索半径，默认 `55.0`，模块会限制在 `5.0` 到 `100.0` 之间。
- `AOELoot.Group`：玩家处于队伍中时是否允许范围拾取。

运行提醒：

- 模块没有独立 SQL 目录，不需要额外数据库环境变量。
- 如果范围拾取后尸体停留时间太长，可以在 `worldserver.conf` 中把 `Rate.Corpse.Decay.Looted` 调低，例如 `0.01`。

## mod-learn-spells

功能：

- 玩家升级时自动学习该等级可用职业法术。
- 适合减少频繁回主城找训练师的操作。

配置文件：

```text
env/dist/etc/modules/mod_learnspells.conf
env/user/modules/mod_learnspells.conf
```

常用配置：

- `LearnSpells.Enable`：启用或禁用模块。
- `LearnSpells.Announce`：登录时是否显示模块提示。
- `LearnSpells.OnFirstLogin`：首次登录时是否补学当前等级之前的法术。
- `LearnSpells.MaxLevel`：自动学习法术的最高等级。

基础使用：

- 启用后无需玩家命令。
- 玩家升级时自动学习可用法术。
- 如果是瞬升或已有角色，建议按需要启用 `LearnSpells.OnFirstLogin`。

## mod-random-enchants

功能：

- 玩家通过拾取、任务奖励、专业制造或队伍 Roll 获得物品时，按概率给物品附加随机附魔。
- 适合偏 Fun 或强化掉落随机性的服务器。

配置文件：

```text
env/dist/etc/modules/random_enchants.conf
env/user/modules/random_enchants.conf
```

常用配置：

- `RandomEnchants.Enable`：启用或禁用模块。
- `RandomEnchants.AnnounceOnLogin`：登录时是否显示模块提示。
- `RandomEnchants.OnLoginMessage`：登录提示文本。
- `RandomEnchants.OnLoot`：拾取物品时是否触发。
- `RandomEnchants.OnCreate`：专业制造物品时是否触发。
- `RandomEnchants.OnQuestReward`：任务奖励物品时是否触发。
- `RandomEnchants.OnGroupRoll`：队伍 Roll 获得物品时是否触发。
- `RandomEnchants.EnchantChance1` / `EnchantChance2` / `EnchantChance3`：第一、第二、第三条随机附魔的概率。

基础使用：

- 启用后无需玩家命令。
- 玩家正常获得物品时，模块按配置概率处理随机附魔。
- 如果你希望服务器更接近原版体验，应关闭该模块或把概率调低。
