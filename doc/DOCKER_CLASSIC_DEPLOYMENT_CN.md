# AzerothCore Classic Docker 部署说明

这套部署不是沿用 AzerothCore 旧的官方 Docker 编排，而是把官方 classic 安装文档里的实际步骤重新映射成容器流程。对应关系如下：

- Linux Requirements: 编译依赖进入镜像构建阶段。
- Linux Core Installation: `cmake` 编译、安装产物进入 `worldserver` / `authserver` 镜像。
- Database Installation: MySQL 容器启动后，由 `db-prepare` 自动完成建库、建 `acore` 用户和授权。
- Linux Server Setup: 外部提供 `Data.zip` 和配置文件，容器在启动时自动注入到运行目录。
- Final Server Steps: 首次创建管理员账号、确认 `realmlist`、连接客户端，仍然保留原来的人工步骤。

官方文档入口：

- https://www.azerothcore.org/wiki/classic-installation
- https://www.azerothcore.org/wiki/linux-requirements
- https://www.azerothcore.org/wiki/linux-core-installation
- https://www.azerothcore.org/wiki/database-installation
- https://www.azerothcore.org/wiki/linux-server-setup
- https://www.azerothcore.org/wiki/final-server-steps

## 1. 目录约定

部署目录仍然使用仓库内现有的 `env/` 和 `var/` 结构：

- `env/user`
  外部输入目录。放用户提供的 `Data.zip` 和配置文件。
- `env/dist/etc`
  运行时配置目录。容器会把默认配置和外部配置整理到这里。
- `env/dist/data`
  解压后的客户端数据目录，最终包含 `dbc/`、`maps/`、`vmaps/`、`mmaps/`。
- `env/dist/logs`
  `authserver`、`worldserver` 日志目录。
- `env/dist/temp`
  临时目录。
- `var/mysql`
  MySQL 数据目录。

建议把外部文件放成下面这个结构：

```text
env/user/
├── Data.zip
├── authserver.conf
├── worldserver.conf
└── modules/
    └── *.conf
```

说明：

- `Data.zip` 是必需的，除非你已经把 `dbc/maps/vmaps/mmaps` 预先放到了 `env/dist/data`。
- `authserver.conf`、`worldserver.conf` 是可选的。
- 如果你提供了外部配置文件，容器每次启动都会先把它们同步到 `env/dist/etc`，然后再自动修正数据库连接、`DataDir`、`LogsDir`、`TempDir` 这些必须由容器托管的字段。

## 2. GitHub Actions 手动打包镜像

仓库只保留一个手动触发的工作流，负责编译并打包两个镜像：

- `worldserver`
- `authserver`

工作流会把镜像推送到 GHCR，镜像命名格式为：

- `ghcr.io/<owner>/<repo>-worldserver:<tag>`
- `ghcr.io/<owner>/<repo>-authserver:<tag>`

使用方法：

1. 打开 GitHub Actions。
2. 运行 `package-server-images`。
3. 输入本次部署要使用的 `image_tag`。
4. 等待两个镜像构建并推送完成。

本地部署时，把生成出来的镜像地址写入根目录 `.env` 里的 `WORLD_IMAGE` 和 `AUTH_IMAGE`。

## 3. 准备 `.env`

把 [`conf/dist/env.docker`](../conf/dist/env.docker) 复制到仓库根目录 `.env`，至少填写以下字段：

```dotenv
WORLD_IMAGE=ghcr.io/your-org/your-repo-worldserver:latest
AUTH_IMAGE=ghcr.io/your-org/your-repo-authserver:latest
AC_DB_PASSWORD=replace-with-your-acore-password
AC_REALM_ADDRESS=your-public-ip-or-domain
```

重点说明：

- `AC_DB_PASSWORD` 是唯一必须由用户提供的 AzerothCore 数据库密码。
- MySQL `root` 不设置密码。
- Compose 默认不对宿主机暴露 MySQL 端口，因此 `root` 只在容器网络内可用。
- 运行镜像使用容器默认 `root` 用户，不再额外创建 `acore` Linux 用户。

如果你的服务部署在内网，并且客户端通过映射端口访问，可以按实际情况改：

- `AC_REALM_ADDRESS`
- `AC_REALM_LOCAL_ADDRESS`
- `AC_REALM_LOCAL_SUBNET_MASK`
- `AC_REALM_PORT`
- `AC_AUTH_EXTERNAL_PORT`
- `AC_WORLD_EXTERNAL_PORT`
- `AC_SOAP_EXTERNAL_PORT`

## 4. 首次启动

先准备好外部输入：

1. 把 `Data.zip` 放到 `env/user/Data.zip`。
2. 如有自定义配置，把 `authserver.conf`、`worldserver.conf` 放到 `env/user/`。
3. 拉取镜像：

```bash
docker compose pull
```

4. 启动：

```bash
docker compose up -d
```

首次启动时 Compose 会自动按下面的顺序完成初始化：

1. `database`
   启动 MySQL 8.4，启用空密码 `root`，仅用于容器内部网络。
2. `data-init`
   读取外部 `Data.zip`，解压到 `env/dist/data`。
3. `db-prepare`
   创建 `acore_auth`、`acore_world`、`acore_characters`。
   创建或更新 `acore@'%'` 用户，并把 `.env` 中的 `AC_DB_PASSWORD` 应用进去。
   这一步只覆盖官方数据库安装流程，不负责 SQL 导入。
4. `worldserver`
   在 `AC_DISABLE_INTERACTIVE=1` 下自行执行官方首启 SQL 导入和更新流程。
5. `authserver`
   等待 `acore_auth.realmlist` 已经导入完成后再启动，并按 `.env` 自动修正 `realmlist` 地址。

## 5. 运行校验

查看初始化日志：

```bash
docker compose logs -f database data-init db-prepare
```

查看服务日志：

```bash
docker compose logs -f authserver worldserver
```

如果一切正常，`worldserver` 日志里应能看到服务启动完成，且不会再报：

- `Incorrect DataDir value`
- `Access denied for user 'acore'`
- 缺少 `dbc/maps/vmaps/mmaps`

## 6. 创建管理员账号

这一步与官方 final server steps 一样，仍然需要人工执行。

附着到 `worldserver` 控制台：

```bash
docker compose attach worldserver
```

创建管理员账号：

```text
account create admin StrongPassword123
account set gm admin 3 -1
account set addon admin 1
```

脱离控制台可用 `Ctrl+P` 然后 `Ctrl+Q`。

## 7. 重新导入数据或数据库

默认情况下：

- 如果 `env/dist/data` 里已经有 `dbc/maps/vmaps/mmaps`，`data-init` 会跳过 `Data.zip` 解压。
- 如果数据库里已经存在核心表，`worldserver` 会只执行必要更新，不会再重新做整库导入。

只有在你明确需要重跑时，才把 `.env` 改成：

```dotenv
AC_FORCE_DATA_IMPORT=1
```

然后执行：

```bash
docker compose up --force-recreate data-init db-prepare
docker compose up -d authserver worldserver
```

如果你还需要重新导入数据库，请清空 `var/mysql` 后再重新执行启动流程，因为 SQL 导入现在由 `worldserver` 本身负责。

完成后建议把 `AC_FORCE_DATA_IMPORT` 恢复为 `0`。

## 8. 常用命令

直接使用 `docker compose` 即可，也可以通过仓库自带包装命令：

```bash
./acore.sh docker start:app:d
./acore.sh docker logs worldserver
./acore.sh docker attach worldserver
./acore.sh docker db:shell
```

如果你需要进入 MySQL：

```bash
docker compose exec database mysql -u root
```

如果你需要进入某个服务容器：

```bash
docker compose exec worldserver bash
docker compose exec authserver bash
```

## 9. 注意事项

- 这套部署默认不暴露 MySQL 到宿主机，是为了配合“`root` 无密码但仅容器内可用”的要求。
- `authserver.conf`、`worldserver.conf` 即使由用户外部提供，数据库连接和容器路径仍会在启动时被自动修正，这是为了保证和 Docker 运行目录一致。
- 如果你的外部配置文件里改了 `SOAP.Port`、`BindIP`、日志路径、`DataDir` 等字段，请同步检查 `.env` 和端口映射是否匹配。
- 旧的 Docker 多 profile、本地 `docker compose build`、`client-data-init`、`db-import` 专用镜像流程已移除，避免再依赖官方旧 Docker 方案。
