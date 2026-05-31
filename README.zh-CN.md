# wrt-base

[![CI](https://github.com/kangmingxuan/wrt-base/actions/workflows/ci.yml/badge.svg)](https://github.com/kangmingxuan/wrt-base/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[English](README.md)

wrt-base 是 ImmortalWrt / OpenWrt 路由器的维护基线。它把安装工具、运行检查、准备备份这类一次性动作收敛成可重复执行、可版本化追踪的脚本，方便你先建立一个稳定的系统运维起点。

> 这个仓库不会把路由器变成主开发机。它只负责系统层基线。

## 特性

- **一条命令装齐维护工具**：自动检测 `opkg` 或 `apk`，不需要按固件分支手工区分。
- **健康检查脚本**：一次性检查时间、NTP、磁盘、内存、负载、IPv4/IPv6 出网、DNS 和包管理器可用性，支持适合 cron 的文本输出或 `--json` 输出。
- **基线报告脚本**：以文本或 JSON 形式打印固件、内核、资源、网络和包数量的设备快照，便于在维护前后对比设备状态。
- **配置备份脚本**：把 `sysupgrade` 备份与已安装包列表、软件源配置、crontab 和设备清单一起打包成带时间戳的归档文件。
- **可定制的安装集合**：通过配置文件（`/etc/wrt-base/install-tools.conf` 或 `--config FILE`）追加站点专属的包，无需改动脚本。
- **POSIX sh 实现**：在 BusyBox ash 上原生运行，不依赖 bash 或 make。
- **自带测试**：`sh tests/run.sh` 会运行语法检查、shellcheck（如果已安装）和单元测试。
- **VS Code Remote-SSH 基线**：包含 OpenSSH client/server、SFTP server、tar、gzip 和相关运行时依赖，方便 VS Code 的 Remote-SSH 插件在 OpenWrt 上安装并启动服务端。
- **单包失败不中断整体安装**：网络抖动或当前软件源缺包时，安装会继续执行，并在最后汇总告警。

## 快速开始

```sh
# 1. 把仓库克隆到路由器上。
opkg update && opkg install git git-http ca-bundle
git clone https://github.com/kangmingxuan/wrt-base.git /root/wrt-base
cd /root/wrt-base

# 2. 预览待安装的包。
sh scripts/install-tools.sh --print-only

# 3. 安装工具集。
sh scripts/install-tools.sh

# 4. 运行健康检查。
sh scripts/health-check.sh
```

## 仓库布局

```
scripts/
  install-tools.sh        # 自动适配 opkg / apk 的工具安装脚本
  health-check.sh         # 时间、NTP、磁盘、内存、负载、网络、DNS 健康检查
  baseline-report.sh      # 以文本或 JSON 输出的设备快照
  backup-config.sh        # 配置备份（sysupgrade + 额外项）打包成 tar.gz
  lib/                    # 被脚本 source 的共享 shell 库
tests/
  run.sh                  # 测试入口（sh -n + shellcheck + 单元测试）
Makefile                  # 开发机有 make 时可用的快捷目标
README.zh-CN.md           # 简体中文 README
```

## 常用命令

所有命令都可以直接用 `sh` 执行，不依赖 make。如果你的开发机安装了 make，也可以通过 `make help` 查看同名快捷目标。

| 命令 | 说明 |
| --- | --- |
| `sh tests/run.sh` | 运行完整测试套件（语法、shellcheck、单元测试） |
| `sh scripts/install-tools.sh --print-only` | 打印 full 模式将安装的包 |
| `sh scripts/install-tools.sh` | 安装 full 工具集（需要 root） |
| `sh scripts/install-tools.sh --minimal` | 安装 minimal 工具集（需要 root） |
| `sh scripts/health-check.sh` | 运行健康检查 |
| `sh scripts/health-check.sh --json` | 运行健康检查并输出 JSON 结果 |
| `sh scripts/baseline-report.sh` | 打印基线快照报告 |
| `sh scripts/backup-config.sh` | 创建配置备份归档（需要 root） |

## 工具集说明

| 集合 | 内容 | 适用场景 |
| --- | --- | --- |
| **base**（始终安装） | bash, ca-bundle, curl, git, git-http, jq, less, nano, tmux | 维护本仓库和拉取远端配置所必需 |
| **minimal**（始终安装） | bind-dig, ip-full, openssl-util, tcpdump 或 tcpdump-mini | 网络与 TLS 排障所需的最小集合 |
| **full**（默认追加） | coreutils, coreutils-install, diffutils, ethtool, `findutils-*`, gawk, grep, gzip, htop, iperf3, `iputils-*`, libstdcpp6, lsof, openssh-client, openssh-server, openssh-sftp-server, `procps-ng-*`, python3-light, ripgrep, rsync, sed, strace, tar, tree, unzip | 更完整的维护体验，也更适合作为 VS Code Remote-SSH 和 code-server 的基础环境 |

`--minimal` 会跳过 full 集合。

如果想在不改脚本的情况下安装站点专属的包，可以把它们逐行写入 `/etc/wrt-base/install-tools.conf`（每行一个包名，`#` 开头为注释），或用 `--config FILE` 指向其他文件。默认路径可通过 `OWRT_INSTALL_CONFIG` 覆盖，`--no-config` 则会忽略默认文件。这些额外的包会叠加在所选模式之上。

`install` 命令现在通过 `coreutils-install` 明确安装。OpenWrt 和 ImmortalWrt 的软件包里，GNU `install` 是拆分出来的独立包，不能指望 `coreutils` 元包默认把它带上，因此这里显式补齐。

## 空间占用

在当前 x86_64 软件源下，`--minimal` 大约需要 10.8 MiB，`--full` 大约需要 18.8 MiB，已包含自动选择的 `tcpdump` 包，但不包含文件系统和 overlay 的额外开销。实际占用会因目标架构、软件源和包可用性而变化。

抓包工具会根据可用存储自动选择：当可用空间不少于 16384 KB 时安装完整版 `tcpdump`，否则安装 `tcpdump-mini`。也可以通过 `OWRT_TCPDUMP_VARIANT=full|mini|auto` 强制覆盖，`OWRT_STORAGE_FREE_KB` 可用于测试这段决策逻辑。

## 健康检查阈值

```sh
sh scripts/health-check.sh \
  --disk 85 \
  --mem 90 \
  --load 2 \
  --skip-time \
  --skip-net \
  --quiet
```

- `--disk 85`：磁盘占用达到或超过 85% 时告警。
- `--mem 90`：内存占用达到或超过 90% 时告警。
- `--load 2`：1 分钟负载除以 CPU 数大于 2 时告警。
- `--skip-time`：跳过系统时间与 NTP 检查，在 NTP 同步前或 CI 中很有用。
- `--skip-net`：跳过 HTTPS 出网、DNS 和 IPv6 检查。
- `--quiet`：仅输出异常项，适合 cron。
- `--json`：在 stdout 输出 JSON 文档，便于接入监控。

NTP 检查在可用时优先使用 procd（`/etc/init.d/sysntpd status`）。IPv6 检查仅在设备拥有全局 IPv6 地址时测试出网连通性；没有 IPv6 的设备会记为通过。

退出码：`0` 表示全部通过，`1` 表示至少一项失败。

## 基线报告

```sh
sh scripts/baseline-report.sh            # 人类可读文本
sh scripts/baseline-report.sh --json     # 扁平 JSON 对象
sh scripts/baseline-report.sh --output /root/baseline.txt
```

报告汇总固件、内核、架构、运行时长、CPU/内存/磁盘/负载、出网 IPv4/IPv6 地址以及已安装包数量。可在维护窗口前后各跑一次，用来对比有哪些变化。

## 配置备份

```sh
sh scripts/backup-config.sh \
  --output-dir /root/backups \
  --keep 5
```

- `--output-dir DIR`：归档写入目录（默认 `/root/backups`）。
- `--keep N`：只保留输出目录中最新的 `N` 个备份（`0` 表示全部保留）。
- `--dry-run`：只暂存并列出文件，不写出最终归档。

每次运行都会生成带时间戳的 `wrt-backup-<host>-<timestamp>.tar.gz`，包含标准 `sysupgrade` 备份，以及已安装包列表、软件源配置、root crontab 和设备清单。在执行任何有风险的维护操作前，把归档复制到设备之外。

## 提交修改前请运行测试

```sh
sh tests/run.sh
```

不要在测试失败时提交。`tests/run.sh` 会自动发现 `tests/test_*.sh`，所以新增脚本时也应补上对应测试。

## 许可证

[MIT](LICENSE)
