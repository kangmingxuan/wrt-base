#!/bin/sh
# install-openwrt-tools.sh — 为 ImmortalWrt / OpenWrt 安装常用维护工具。

set -u

MODE="full"
PRINT_ONLY="false"
SKIP_UPDATE="false"
FAILED_PACKAGES=""

BASE_PACKAGES="
bash
ca-bundle
curl
git
git-http
jq
less
nano
tmux
"

MINIMAL_PACKAGES="
bind-dig
ip-full
openssl-util
tcpdump-mini
"

FULL_PACKAGES="
coreutils
diffutils
ethtool
findutils-find
findutils-xargs
gawk
grep
htop
iperf3
iputils-ping
iputils-tracepath
lsof
procps-ng-pkill
procps-ng-ps
procps-ng-top
rsync
sed
shellcheck
strace
tar
tree
unzip
"

log() {
    local level="$1"; shift
    printf '[%s] %s\n' "$level" "$*"
}

die() {
    log ERROR "$@"
    exit 1
}

usage() {
    cat <<'EOF'
用法: install-openwrt-tools.sh [选项]

描述:
  为 ImmortalWrt / OpenWrt 安装常用维护工具。

选项:
  --minimal      安装较小的维护工具集
  --full         安装完整维护工具集（默认）
  --print-only   只打印待安装包列表，不执行安装
  --skip-update  跳过 opkg update
  -h, --help     显示此帮助信息
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --minimal) MODE="minimal" ;;
            --full) MODE="full" ;;
            --print-only) PRINT_ONLY="true" ;;
            --skip-update) SKIP_UPDATE="true" ;;
            -h|--help) usage; exit 0 ;;
            *) die "未知选项: $1" ;;
        esac
        shift
    done
}

check_dependencies() {
    command -v opkg >/dev/null 2>&1 || die "未找到 opkg，当前系统不像是 OpenWrt / ImmortalWrt"
    [ "$(id -u)" = "0" ] || die "请使用 root 执行该脚本"
}

is_installed() {
    opkg list-installed "$1" 2>/dev/null | grep -q "^$1 - "
}

append_failed() {
    if [ -z "$FAILED_PACKAGES" ]; then
        FAILED_PACKAGES="$1"
    else
        FAILED_PACKAGES="$FAILED_PACKAGES $1"
    fi
}

get_packages() {
    printf '%s\n' "$BASE_PACKAGES"
    printf '%s\n' "$MINIMAL_PACKAGES"
    if [ "$MODE" = "full" ]; then
        printf '%s\n' "$FULL_PACKAGES"
    fi
}

print_packages() {
    get_packages | while IFS= read -r package; do
        [ -n "$package" ] || continue
        printf '%s\n' "$package"
    done
}

install_packages() {
    # shellcheck disable=SC2046
    for package in $(get_packages); do
        [ -n "$package" ] || continue

        if is_installed "$package"; then
            log INFO "已安装，跳过: $package"
            continue
        fi

        if opkg install "$package"; then
            log INFO "安装完成: $package"
            continue
        fi

        append_failed "$package"
        log WARN "安装失败，已跳过: $package"
    done
}

main() {
    parse_args "$@"
    check_dependencies

    log INFO "当前安装模式: $MODE"

    if [ "$PRINT_ONLY" = "true" ]; then
        print_packages
        exit 0
    fi

    if [ "$SKIP_UPDATE" != "true" ]; then
        opkg update || die "opkg update 失败"
    fi

    install_packages

    if [ -n "$FAILED_PACKAGES" ]; then
        log WARN "以下包未能安装，请按当前固件的软件源情况手动确认: $FAILED_PACKAGES"
        exit 0
    fi

    log INFO "工具安装完成"
}

main "$@"
