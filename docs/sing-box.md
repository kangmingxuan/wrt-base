# 部署 sing-box 的前置约束

这个仓库本身不打包 sing-box 二进制或配置；这里只列出在路由器上跑 sing-box 长期稳定所需要的环境前提，跑 `health-check.sh` 时也会校验大部分项。

## 必备项

| 项 | 怎么验证 | 不满足的后果 |
| --- | --- | --- |
| 系统时间正确 | `date` 显示当前年份 | TLS / Reality 握手失败 |
| CA 证书包 | 已装 `ca-bundle` | curl/jq 拉远端配置失败 |
| 出网 DNS 可用 | `nslookup openwrt.org` | 启动时拉规则集失败 |
| 持久化空间 | `df -h /` 还有 ≥ 50MB | sing-box 日志/缓存写不下，OOM-like 崩溃 |
| 内存余量 | `free -m` 有 ≥ 30% 可用 | 大流量并发时被 OOM kill |

## 推荐项

- 装 `htop`、`lsof`、`strace`：故障排查时少装的 30 秒比异常多撑 30 分钟更值。
- 装 `tcpdump` 或 `tcpdump-mini`：抓出口流量诊断 TLS 异常；脚本会按可用存储自动选择，空间足够时优先完整版 tcpdump。
- 装 `tmux`：长任务（如规则集预热）放在 detach session 里，避免 SSH 掉线就死。

`sh scripts/install-tools.sh` (默认 full) 覆盖这些。

## 部署位置建议

- 二进制：`/usr/bin/sing-box`（init 脚本默认路径）
- 配置：`/etc/sing-box/config.json`
- 日志：写到 `/var/log/sing-box/`，配合 logrotate
- 把 `/etc/sing-box` 加进 `/etc/sysupgrade.conf`，避免升级丢配置

## 与本仓库的边界

- 本仓库 = 维护脚本与基线工具（系统层）
- sing-box 自己的配置、订阅、规则集 → 单独的私有仓库
- 这样升级路由固件时，两者都能各自被 sysupgrade 备份与恢复
