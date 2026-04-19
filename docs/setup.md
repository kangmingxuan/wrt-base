# 初始设置指南

适用于刚装好的 ImmortalWrt / OpenWrt，准备把它当作一个有维护脚本的常驻节点。

## 1. 准备网络与软件源

确认能解析 DNS 并访问 HTTPS：

```sh
nslookup downloads.openwrt.org
curl -fsS -I https://downloads.openwrt.org | head -1
```

如果出网走代理（出厂状态下还没装 sing-box），先临时设置：

```sh
export http_proxy=http://192.168.x.x:port
export https_proxy=$http_proxy
```

## 2. 拉仓库到路由器

仓库本身只是脚本，自己不依赖路由器。先装 git（手动一次性）：

```sh
opkg update && opkg install git git-http ca-bundle
# 24.10+ SNAPSHOT 用 apk:
# apk update && apk add git git-http ca-bundle
```

然后克隆：

```sh
cd /root
git clone <你的远端 URL> openwrt-maintenance
cd openwrt-maintenance
```

## 3. 预演要装的工具

不要直接 install。先预演：

```sh
sh scripts/install-tools.sh --print-only          # 只看清单
sh scripts/install-tools.sh --dry-run             # 检测包管理器并模拟
```

确认无误后正式安装：

```sh
sh scripts/install-tools.sh                       # full
# 资源紧张时改用：
sh scripts/install-tools.sh --minimal
```

单包失败不会终止整体安装；最后会把失败列表打印出来再退出 0。

## 4. 跑一次健康检查

```sh
sh scripts/health-check.sh
```

任何一项异常都会让脚本以非 0 退出，方便接 cron 或自定义告警脚本。

## 5. 接 cron（可选）

```sh
crontab -e
# 每 10 分钟跑一次健康检查，异常项写到 logread
*/10 * * * * /root/openwrt-maintenance/scripts/health-check.sh --quiet --skip-net >/dev/null || logger -t owrt-health "health-check failed"
```

## 6. 加进 sysupgrade 备份

把仓库目录写进 `/etc/sysupgrade.conf`，避免固件升级丢失：

```sh
echo '/root/openwrt-maintenance' >>/etc/sysupgrade.conf
echo '/root/.ssh' >>/etc/sysupgrade.conf
```

跑 `sysupgrade -l` 应能看到这两条。

## 7. 时区与 NTP

```sh
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
/etc/init.d/system reload
```

时间不准会影响 TLS / Reality 握手与证书校验，sing-box 部署前务必确认。
