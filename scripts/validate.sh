#!/bin/sh
# validate.sh — 运行仓库内最小必要校验。

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
# shellcheck disable=SC1007,SC2046
REPO_DIR=$(CDPATH= cd -- "$(dirname "$SELF")/.." && pwd)
readonly REPO_DIR
readonly INSTALL_SCRIPT="$REPO_DIR/scripts/install-openwrt-tools.sh"

log() {
    local level="$1"; shift
    printf '[%s] %s\n' "$level" "$*"
}

die() { log ERROR "$@"; exit 1; }

[ -f "$INSTALL_SCRIPT" ] || die "未找到安装脚本: $INSTALL_SCRIPT"

sh -n "$INSTALL_SCRIPT" || die "install-openwrt-tools.sh 语法校验失败"
log INFO "install-openwrt-tools.sh 语法校验通过"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$INSTALL_SCRIPT" || die "install-openwrt-tools.sh 未通过 shellcheck"
    log INFO "install-openwrt-tools.sh 通过 shellcheck"
else
    log INFO "未安装 shellcheck，已跳过 shell 静态检查"
fi

log INFO "仓库最小校验通过"
