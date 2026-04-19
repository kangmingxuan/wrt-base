#!/bin/sh
# health-check.sh — 路由器维护节点的快速健康检查。
#
# 关注的是“跑 sing-box 之类长驻服务前应该确认的事”：
#   - 系统时间是否正常（TLS / Reality 强依赖）
#   - 关键挂载点是否还有空间
#   - 内存与负载
#   - 出网连通性与 DNS
#   - opkg / apk 元数据是否能取到
# 任何一项异常都会让脚本以非零退出码结束，方便 cron 报警。

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$SELF")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/pkg.sh
. "$SCRIPT_DIR/lib/pkg.sh"

DISK_THRESHOLD=85   # 百分比，超过即告警
MEM_THRESHOLD=90
LOAD_FACTOR=2       # 1 分钟负载 / CPU 数 超过该倍数即告警
SKIP_NET="false"
QUIET="false"

EXIT_CODE=0

usage() {
    cat <<'EOF'
用法: health-check.sh [选项]

选项:
  --disk N      磁盘占用告警阈值（百分比，默认 85）
  --mem N       内存占用告警阈值（百分比，默认 90）
  --load N      1 分钟负载 / CPU 数 告警倍数（默认 2）
  --skip-net    跳过出网与 DNS 检查
  --quiet       仅打印异常项
  -h, --help    显示帮助
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --disk) DISK_THRESHOLD="$2"; shift ;;
            --mem)  MEM_THRESHOLD="$2"; shift ;;
            --load) LOAD_FACTOR="$2"; shift ;;
            --skip-net) SKIP_NET="true" ;;
            --quiet) QUIET="true" ;;
            -h|--help) usage; exit 0 ;;
            *) die "未知选项: $1" ;;
        esac
        shift
    done
}

ok()   { [ "$QUIET" = "true" ] || log_info "$*"; }
fail() { log_warn "$*"; EXIT_CODE=1; }

check_time() {
    # 启动后 NTP 还没同步时，年份常常是 1970/2000。
    year=$(date +%Y)
    if [ "$year" -lt 2024 ]; then
        fail "系统时间异常: $(date)"
    else
        ok "系统时间: $(date)"
    fi
}

check_disk() {
    # df 输出在管道里会进入子 shell，因此结果先收进临时文件，外层再消费。
    tmp=$(mktemp 2>/dev/null || printf '/tmp/owrt-hc.%s' "$$")
    df -P 2>/dev/null | awk 'NR>1' >"$tmp"
    while read -r _fs _blocks _used _avail capacity mount; do
        case "$mount" in
            /|/overlay|/rom) ;;
            *) continue ;;
        esac
        pct=$(printf '%s' "$capacity" | tr -d '%')
        case "$pct" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$pct" -ge "$DISK_THRESHOLD" ]; then
            fail "磁盘 $mount ${pct}%（阈值 ${DISK_THRESHOLD}%）"
        else
            ok "磁盘 $mount ${pct}%"
        fi
    done <"$tmp"
    rm -f "$tmp"
}

check_memory() {
    # /proc/meminfo 字段单位是 kB
    total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
    [ -n "$total" ] && [ -n "$avail" ] || { fail "无法读取 /proc/meminfo"; return; }
    used_pct=$(( (total - avail) * 100 / total ))
    if [ "$used_pct" -ge "$MEM_THRESHOLD" ]; then
        fail "内存占用 ${used_pct}% （阈值 ${MEM_THRESHOLD}%）"
    else
        ok "内存占用 ${used_pct}%"
    fi
}

check_load() {
    cpus=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
    [ "$cpus" -gt 0 ] || cpus=1
    load1=$(awk '{print $1}' /proc/loadavg)
    # 用整数比较（放大 100 避免浮点）
    load1_x100=$(printf '%s' "$load1" | awk '{printf "%d", $1*100}')
    threshold_x100=$(( cpus * LOAD_FACTOR * 100 ))
    if [ "$load1_x100" -gt "$threshold_x100" ]; then
        fail "负载 1m=${load1}（CPU=${cpus}, 阈值倍数=${LOAD_FACTOR}）"
    else
        ok "负载 1m=${load1}（CPU=${cpus}）"
    fi
}

check_network() {
    [ "$SKIP_NET" = "true" ] && return
    if has_cmd curl; then
        if curl -fsS --max-time 5 -o /dev/null https://www.cloudflare.com/cdn-cgi/trace; then
            ok "HTTPS 出网正常"
        else
            fail "HTTPS 出网失败"
        fi
    else
        log_debug "未安装 curl，跳过 HTTPS 出网检查"
    fi

    if has_cmd nslookup; then
        if nslookup openwrt.org >/dev/null 2>&1; then
            ok "DNS 解析正常"
        else
            fail "DNS 解析失败"
        fi
    else
        log_debug "未安装 nslookup，跳过 DNS 检查"
    fi
}

check_pkg_index() {
    if ! pkg_detect; then
        fail "未找到包管理器（opkg/apk）"
        return
    fi
    ok "包管理器: $PKG_MANAGER"
}

main() {
    parse_args "$@"
    check_time
    check_disk
    check_memory
    check_load
    check_network
    check_pkg_index

    if [ "$EXIT_CODE" -eq 0 ]; then
        ok "全部检查通过"
    else
        log_warn "存在异常项，请处理"
    fi
    exit "$EXIT_CODE"
}

main "$@"
