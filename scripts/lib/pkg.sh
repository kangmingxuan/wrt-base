#!/bin/sh
# pkg.sh — package manager abstraction for opkg and apk.
#
# OpenWrt 23.05 and ImmortalWrt 24.10 still use opkg.
# Newer OpenWrt snapshots and 25.x switch to apk-tools.
# This layer keeps higher-level scripts independent from the backend.
#
# Provides:
#   pkg_detect              populate PKG_MANAGER (opkg|apk)
#   pkg_update              refresh package feed metadata
#   pkg_is_available NAME   check whether a package exists in the feed
#   pkg_is_installed NAME   check whether a package is installed
#   pkg_install NAME        install a single package

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
        # Prefer apk on newer OpenWrt releases.
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
