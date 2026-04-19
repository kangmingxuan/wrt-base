# openwrt-maintenance

ImmortalWrt / OpenWrt 路由器的维护基线：把一次性的“装工具、做检查、做备份”这类动作收敛成可重复执行、可版本化追踪的脚本，方便日后部署 sing-box 等长驻服务时有一个稳定的运维起点。

> 这个仓库不会把路由器变成主开发机，也不打包任何业务配置（比如 sing-box 的订阅、规则集）。它只负责系统层基线。

## 特性

- **一条命令装齐维护工具**：自动检测 `opkg` 或 `apk`（OpenWrt 24.10 SNAPSHOT 起切到 apk-tools），无需手工分支。
- **健康检查脚本**：时间、磁盘、内存、负载、出网、DNS、包管理器一次性检查，cron 友好。
- **POSIX sh 实现**：在 BusyBox ash 上原生跑，不依赖 bash 或 make。
- **自带测试**：`sh tests/run.sh` 同时跑语法检查、shellcheck（如装了）和单元测试。
- **单包失败不中断**：网络抖动或当前固件源里没有某个包时，安装会继续，最后汇总告警。

## 快速开始

```sh
# 1. 拉仓库到路由器
opkg update && opkg install git git-http ca-bundle
git clone <你的远端 URL> /root/openwrt-maintenance
cd /root/openwrt-maintenance

# 2. 预演要装哪些包
sh scripts/install-tools.sh --print-only

# 3. 实际安装（默认 full；资源紧张用 --minimal）
sh scripts/install-tools.sh

# 4. 跑健康检查
sh scripts/health-check.sh
```

更详细的初始落地流程见 [docs/setup.md](docs/setup.md)。

## 仓库布局

```
scripts/
  install-tools.sh        # 工具安装（opkg / apk 自适配）
  health-check.sh         # 健康检查（时间/磁盘/内存/负载/网络/DNS）
  lib/                    # 共享函数库（仅 source，不直接跑）
tests/
  run.sh                  # 测试入口（sh -n + shellcheck + 单元测试）
docs/
  setup.md                # 首次落地
  sing-box.md             # 部署 sing-box 的前置约束
  layout.md               # 仓库结构与设计原则
Makefile                  # make help 看可用目标
```

完整说明见 [docs/layout.md](docs/layout.md)。

## 常用命令

所有命令都用 `sh` 直接跑，不依赖 make。如果开发机上有 make，也可用 `make help` 看同名快捷目标。

| 命令 | 说明 |
| --- | --- |
| `sh tests/run.sh` | 跑全部测试（语法 / shellcheck / 单元测试） |
| `sh scripts/install-tools.sh --print-only` | 打印 full 模式将安装的包 |
| `sh scripts/install-tools.sh` | 安装 full 工具集（需 root） |
| `sh scripts/install-tools.sh --minimal` | 安装 minimal 工具集（需 root） |
| `sh scripts/health-check.sh` | 跑健康检查 |

## 工具集说明

| 集合 | 内容 | 适用 |
| --- | --- | --- |
| **base**（始终装） | bash, ca-bundle, curl, git, git-http, jq, less, nano, tmux | 维护本仓库与拉远端配置必需 |
| **minimal**（始终装） | bind-dig, ip-full, openssl-util, tcpdump 或 tcpdump-mini | 网络/TLS 排障最小集 |
| **full**（默认追加） | coreutils, diffutils, ethtool, findutils-\*, gawk, grep, htop, iperf3, iputils-\*, lsof, procps-ng-\*, rsync, sed, shellcheck, strace, tar, tree, unzip | 完整运维体验 |

`--minimal` 跳过 full 集合。

抓包工具会自动按可用存储选择：可用空间不少于 16384KB 时装完整版 tcpdump，否则装 tcpdump-mini。也可以用环境变量 `OWRT_TCPDUMP_VARIANT=full|mini|auto` 强制覆盖，`OWRT_STORAGE_FREE_KB` 可用于测试该决策。

## 健康检查阈值

```sh
sh scripts/health-check.sh \
    --disk 85 \    # 磁盘占用 ≥ 85% 告警
    --mem 90 \     # 内存占用 ≥ 90% 告警
    --load 2 \     # 1m 负载 / CPU > 2 告警
    --skip-net \   # 跳过 HTTPS 出网与 DNS 检查
    --quiet        # 仅输出异常项（cron 友好）
```

退出码：`0` 全部通过；`1` 有异常项。

## 部署 sing-box 之前

参考 [docs/sing-box.md](docs/sing-box.md)。简而言之：先 `make install` 把工具装齐，再 `make health` 把基线打通，最后让业务仓库（sing-box 配置）独立承载。

## 修改后请运行测试

```sh
sh tests/run.sh
```

未通过不要提交。`tests/run.sh` 会自动发现 `tests/test_*.sh`，新增脚本时同步加测试即可，详见 [docs/layout.md](docs/layout.md)。

## 许可证

未指定，按需自加。
# ImmortalWrt Maintenance Workspace

这个仓库用于收敛 ImmortalWrt / OpenWrt 路由器上的环境初始化、常用维护工具和独立于 sing-box 配置本身的系统运维脚本。

它的目标不是把路由器变成主开发机，而是在硬件资源充足的前提下，把常见维护动作收敛成可重复执行、可版本化追踪的基线。

## 当前内容

- `scripts/install-openwrt-tools.sh`：按最小或完整模式安装常用维护工具。
- `scripts/validate.sh`：对仓库内脚本执行最小语法与静态检查。

## 建议工具基线

如果路由器有较充足的 CPU、内存和存储空间，更适合直接按“全功能运维节点”来配置，而不是只保留最小运行时依赖。

建议至少准备以下几类工具：

- 基础维护：bash、git、git-http、ca-bundle、curl、jq、nano、less、tmux。
- Shell 与文件处理：coreutils、diffutils、findutils-find、findutils-xargs、gawk、grep、sed、rsync、tar、tree、unzip。
- 网络与系统排障：bind-dig、ip-full、tcpdump-mini、openssl-util、ethtool、iperf3、iputils-ping、iputils-tracepath、procps-ng-ps、procps-ng-top、procps-ng-pkill、htop、lsof、strace。
- 静态检查：shellcheck。

## 使用方式

1. 先用 `sh ./scripts/install-openwrt-tools.sh --print-only` 查看将要安装的包。
2. 确认软件源可用后运行 `sh ./scripts/install-openwrt-tools.sh`。
3. 如果只想保留较小的维护面，可改用 `sh ./scripts/install-openwrt-tools.sh --minimal`。

安装脚本会逐个安装包；如果某个包在当前固件的软件源里不存在，会记录告警并继续执行，不会因为单个缺包中断整批安装。

## 初始化建议

- 配好 SSH 公钥登录，并保留 `/root/.ssh`。
- 配好 Git 远端访问方式，HTTPS 远端通常需要 git-http，SSH 远端则需要现有密钥可直接使用。
- 把这个仓库、`/root/.ssh` 以及其他私有运维脚本纳入 sysupgrade 备份。
- 确认时区与 NTP 正常，避免 TLS、Reality 和证书校验受系统时间漂移影响。

## 变更后验证

每次修改脚本后建议运行：

1. `sh ./scripts/validate.sh`
