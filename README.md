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
