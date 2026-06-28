# Docker 镜像内置模块说明

本文档说明本仓库通过 `package-server-images` 工作流打包进 `worldserver` 镜像的 AzerothCore 模块，以及这些模块的主要功能、配置入口和基础使用方式。

模块不是直接提交在仓库的 `modules/` 目录里。打包镜像时，工作流会先执行：

```bash
bash apps/docker/prepare-bundled-modules.sh modules
```

这个脚本会把固定模块集合 clone 到 `modules/`，再交给 Dockerfile 编译。因此，决定生产镜像模块集合的入口是：

- [`apps/docker/prepare-bundled-modules.sh`](../apps/docker/prepare-bundled-modules.sh)
- [`.github/workflows/package-server-images.yml`](../.github/workflows/package-server-images.yml)

脚本也会删除已经从固定集合中移除的旧模块目录，避免本地复用 `modules/` 时把旧模块一起编译进去。

## 当前模块集合

| 模块 | 仓库 | 分支 | 配置文件 | SQL |
|---|---|---:|---|---|
| `mod-playerbots` | `https://github.com/mod-playerbots/mod-playerbots.git` | `master` | `playerbots.conf` | `playerbots`、`world`、`characters` |
| `mod-transmog` | `https://github.com/azerothcore/mod-transmog.git` | `master` | `transmog.conf` | `auth`、`characters`、`world` |
| `mod-autobalance` | `https://github.com/azerothcore/mod-autobalance.git` | `master` | `AutoBalance.conf` | 无独立 SQL |
| `mod-learn-spells` | `https://github.com/azerothcore/mod-learn-spells.git` | `master` | `mod_learnspells.conf` | 无独立 SQL |
| `mod-individual-progression` | `https://github.com/ZhengPeiRu21/mod-individual-progression.git` | `master` | `individualProgression.conf` | `auth`、`characters`、`world` |
| `mod-random-enchants` | `https://github.com/azerothcore/mod-random-enchants.git` | `master` | `random_enchants.conf` | `world` |

已经移除的旧模块：

- `mod-ah-bot-plus`
- `mod-aoe-loot`

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
       modules/mod-learn-spells \
       modules/mod-individual-progression \
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
├── mod_learnspells.conf
├── individualProgression.conf
└── random_enchants.conf
```

容器启动时会先复制默认配置，再复制 `env/user/modules/` 里的同名文件，最后自动修正数据库连接、路径等必须由容器托管的字段。

Linux 文件系统大小写敏感，尤其注意：

- `AutoBalance.conf` 必须保留大写 `A` 和 `B`。
- `individualProgression.conf` 必须保留大写 `P`。

## 数据库导入

首次启动时，`db-prepare` 只负责创建数据库、创建 `acore` 用户和授权。真正的表结构、基础数据、updates 和模块 SQL 由 `worldserver` 在非交互模式下自动导入。

当前模块的数据库行为：

- `mod-playerbots` 会使用独立数据库，默认环境变量是 `AC_PLAYERBOTS_DATABASE=acore_playerbots`。
- `mod-transmog`、`mod-individual-progression`、`mod-random-enchants` 的 SQL 会随 `worldserver` 自动导入到核心库。
- `mod-autobalance`、`mod-learn-spells` 没有独立 SQL。
- `mod-random-enchants` 使用上游常见的 `data/sql/db-world` 目录，打包脚本会自动创建 `data/sql/world` 兼容链接。

`mod-individual-progression` 会大量修改世界库内容。关闭配置只会停止运行时代码逻辑，不会撤销已经导入的世界库变更。需要回退时应恢复数据库备份。

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

## mod-individual-progression

功能：

- 按角色保存个人进度，模拟 Vanilla、TBC、WotLK 各阶段逐步推进。
- 恢复部分被后续版本移除、削弱或延后开放的任务、NPC、掉落、副本入口和阶段限制。
- 支持旧 Naxxramas、Onyxia、TBC 开门/钥匙任务、Vanilla AV、奎岛阶段等内容。
- 可与 Playerbots 搭配，用机器人辅助推进阶段内容。

配置文件：

```text
env/dist/etc/modules/individualProgression.conf
env/user/modules/individualProgression.conf
```

关键要求：

- 该模块需要保存 Player Settings。默认 `IndividualProgression.SimpleConfigOverride = 1` 会尝试自动设置必要核心配置。
- 如果你关闭 `SimpleConfigOverride`，需要自行确保 `worldserver.conf` 中启用 Player Settings，并设置 `DBC.EnforceItemAttributes = 0`，否则个人进度和物品覆盖可能不符合预期。

常用命令：

```text
.ip get [$player]
.ip set [$player] <progressionLevel>
.ip setbot
.ip tele [$player] <location>
.ip setrep
.ip pvp [$player]
.ip attune <location>
```

说明：

- `.ip get` 查看自己、目标或指定玩家的进度等级。
- `.ip set` 设置玩家进度等级，通常只应由 GM 排障或活动管理时使用。
- `.ip setbot` 把队伍内机器人设置到你的进度等级。
- `.ip tele`、`.ip setrep`、`.ip pvp`、`.ip attune` 是进度相关管理命令，使用前建议先在测试服验证。

常用配置：

- `IndividualProgression.Enable`：启用或禁用运行时代码逻辑。
- `IndividualProgression.EnforceGroupRules`：是否只允许同阶段玩家组队。
- `IndividualProgression.ProgressionLimit`：限制最高可达到的进度阶段。
- `IndividualProgression.StartingProgression`：设置新角色或低阶段角色的起始进度阶段。
- `IndividualProgression.VanillaPowerAdjustment` / `VanillaHealingAdjustment`：调整 Vanilla 阶段输出和治疗。
- `IndividualProgression.TBCPowerAdjustment` / `TBCHealingAdjustment`：调整 TBC 阶段输出和治疗。
- `IndividualProgression.DisableRDF`：按进度模块语义控制随机地下城查找器。

可选资源：

- 模块仓库的 `optional/` 目录包含可选 DBC、客户端 patch 和可选 SQL。
- 本仓库打包脚本只打包模块本体；是否使用可选客户端 patch 或额外 SQL，需要你按模块上游说明单独评估。

风险提醒：

- 该模块对世界库改动范围很大，建议新服启用。
- 已经运行过一段时间的生产库接入前，应先完整备份 `auth/world/characters/playerbots` 数据库。

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

## 变更模块集合后的部署建议

如果你已经用旧模块集合启动过数据库，现在切换到当前模块集合：

1. 先备份数据库和 `env/dist/etc/modules`。
2. 重新运行 `package-server-images` 打包并推送新镜像。
3. 更新 `.env` 中的 `WORLD_IMAGE` 和 `AUTH_IMAGE`。
4. 删除不再使用的外部覆盖配置：

```bash
rm -f env/user/modules/mod_ahbot.conf env/user/modules/mod_aoe_loot.conf
```

5. 按需要添加新模块配置：

```text
env/user/modules/mod_learnspells.conf
env/user/modules/individualProgression.conf
env/user/modules/random_enchants.conf
```

6. 拉取并重启：

```bash
docker compose pull
docker compose up -d
```

如果是新服，推荐从空数据库启动，让 `worldserver` 一次性导入核心 SQL 和当前模块 SQL。这样比在已有旧模块库上叠加大范围进度模块更容易排障。
