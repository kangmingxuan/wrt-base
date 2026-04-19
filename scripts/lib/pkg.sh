#!/bin/sh
# pkg.sh — 包管理器抽象层，统一 opkg 和 apk 的接口。
#
# OpenWrt 23.05 / ImmortalWrt 24.10 仍使用 opkg；
# OpenWrt SNAPSHOT / 25.x 起切换到 apk-tools (apk-mk2)。
# 这一层让上层脚本不用关心具体管理器。
#
# 提供:
#   pkg_detect              填充 PKG_MANAGER (opkg|apk)
#   pkg_update              刷新软件源元数据
#   pkg_is_available NAME   检查软件源是否提供该包
#   pkg_is_installed NAME   检查包是否已安装
#   pkg_install NAME        安装单个包

# shellcheck shell=sh

if [ -n "${__OWRT_PKG_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
__OWRT_PKG_LOADED=1

PKG_MANAGER=""

pkg_detect() {
    if [ -n "${OWRT_PKG_MANAGER:-}" ]; then
        PKG_MANAGER="$OWRT_PKG_MANAGER"
    elif command -v apk >/dev/null 2>&1 && apk --version 2>/dev/null | grep -qi 'apk'; then
        # 优先 apk：新版 OpenWrt 用它
        PKG_MANAGER="apk"
    elif command -v opkg >/dev/null 2>&1; then
        PKG_MANAGER="opkg"
    else
        return 1
    fi
    return 0
}

pkg_update() {
    case "$PKG_MANAGER" in
        opkg) opkg update ;;
        apk)  apk update ;;
        *)    return 1 ;;
    esac
}

pkg_is_available() {
    name=$1
    case "$PKG_MANAGER" in
        opkg) opkg list "$name" 2>/dev/null | grep -q "^$name - " ;;
        apk)  apk search --exact "$name" 2>/dev/null | grep -q "^$name$" ;;
        *)    return 2 ;;
    esac
}

pkg_is_installed() {
    name=$1
    case "$PKG_MANAGER" in
        opkg) opkg list-installed "$name" 2>/dev/null | grep -q "^$name - " ;;
        apk)  apk info -e "$name" >/dev/null 2>&1 ;;
        *)    return 2 ;;
    esac
}

pkg_install() {
    name=$1
    case "$PKG_MANAGER" in
        opkg) opkg install "$name" ;;
        apk)  apk add "$name" ;;
        *)    return 2 ;;
    esac
}
