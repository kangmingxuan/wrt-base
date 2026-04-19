# wrt-base

[English](README.md)

wrt-base 是 ImmortalWrt / OpenWrt 路由器的维护基线。它把安装工具、运行检查、准备备份这类一次性动作收敛成可重复执行、可版本化追踪的脚本，方便你先建立一个稳定的系统运维起点。

> 这个仓库不会把路由器变成主开发机。它只负责系统层基线。

## 特性

- **一条命令装齐维护工具**：自动检测 `opkg` 或 `apk`，不需要按固件分支手工区分。
- **健康检查脚本**：一次性检查时间、磁盘、内存、负载、出网、DNS 和包管理器可用性，输出也适合挂到 cron。
- **POSIX sh 实现**：在 BusyBox ash 上原生运行，不依赖 bash 或 make。
- **自带测试**：`sh tests/run.sh` 会运行语法检查、shellcheck（如果已安装）和单元测试。
- **VS Code Remote-SSH 基线**：包含 OpenSSH client/server、SFTP server、tar、gzip 和相关运行时依赖，方便 VS Code 的 Remote-SSH 插件在 OpenWrt 上安装并启动服务端。
- **单包失败不中断整体安装**：网络抖动或当前软件源缺包时，安装会继续执行，并在最后汇总告警。

## 快速开始

```sh
# 1. 把仓库克隆到路由器上。
opkg update && opkg install git git-http ca-bundle
git clone <你的远端 URL> /root/wrt-base
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
  health-check.sh         # 时间、磁盘、内存、负载、网络、DNS 健康检查
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

## 工具集说明

| 集合 | 内容 | 适用场景 |
| --- | --- | --- |
| **base**（始终安装） | bash, ca-bundle, curl, git, git-http, jq, less, nano, tmux | 维护本仓库和拉取远端配置所必需 |
| **minimal**（始终安装） | bind-dig, ip-full, openssl-util, tcpdump 或 tcpdump-mini | 网络与 TLS 排障所需的最小集合 |
| **full**（默认追加） | coreutils, diffutils, ethtool, findutils-\*, gawk, grep, gzip, htop, iperf3, iputils-\*, libstdcpp6, lsof, openssh-client, openssh-server, openssh-sftp-server, procps-ng-\*, python3-light, ripgrep, rsync, sed, strace, tar, tree, unzip | 更完整的维护体验，也更适合作为 VS Code Remote-SSH 和 code-server 的基础环境 |

`--minimal` 会跳过 full 集合。

## 空间占用

在当前 x86_64 软件源下，`--minimal` 大约需要 10.8 MiB，`--full` 大约需要 18.8 MiB，已包含自动选择的 `tcpdump` 包，但不包含文件系统和 overlay 的额外开销。实际占用会因目标架构、软件源和包可用性而变化。

抓包工具会根据可用存储自动选择：当可用空间不少于 16384 KB 时安装完整版 `tcpdump`，否则安装 `tcpdump-mini`。也可以通过 `OWRT_TCPDUMP_VARIANT=full|mini|auto` 强制覆盖，`OWRT_STORAGE_FREE_KB` 可用于测试这段决策逻辑。

## 健康检查阈值

```sh
sh scripts/health-check.sh \
  --disk 85 \
  --mem 90 \
  --load 2 \
  --skip-net \
  --quiet
```

- `--disk 85`：磁盘占用达到或超过 85% 时告警。
- `--mem 90`：内存占用达到或超过 90% 时告警。
- `--load 2`：1 分钟负载除以 CPU 数大于 2 时告警。
- `--skip-net`：跳过 HTTPS 出网和 DNS 检查。
- `--quiet`：仅输出异常项，适合 cron。

退出码：`0` 表示全部通过，`1` 表示至少一项失败。

## 提交修改前请运行测试

```sh
sh tests/run.sh
```

不要在测试失败时提交。`tests/run.sh` 会自动发现 `tests/test_*.sh`，所以新增脚本时也应补上对应测试。

## 许可证

[MIT](LICENSE)
