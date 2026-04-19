#!/bin/sh
# common.sh — shared helpers for openwrt-maintenance scripts.
#
# 这个文件用 `.` (source) 引入，不要直接执行。
# 提供日志输出、根用户检查、命令存在性检查等通用工具。

# shellcheck shell=sh

# 防止重复加载。
if [ -n "${__OWRT_COMMON_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
__OWRT_COMMON_LOADED=1

# 颜色输出仅在 stderr 是 TTY 时启用。
if [ -t 2 ]; then
    __C_RED=$(printf '\033[31m')
    __C_YEL=$(printf '\033[33m')
    __C_GRN=$(printf '\033[32m')
    __C_DIM=$(printf '\033[2m')
    __C_RST=$(printf '\033[0m')
else
    __C_RED=""; __C_YEL=""; __C_GRN=""; __C_DIM=""; __C_RST=""
fi

log_info()  { printf '%s[INFO]%s  %s\n' "$__C_GRN" "$__C_RST" "$*" >&2; }
log_warn()  { printf '%s[WARN]%s  %s\n' "$__C_YEL" "$__C_RST" "$*" >&2; }
log_error() { printf '%s[ERROR]%s %s\n' "$__C_RED" "$__C_RST" "$*" >&2; }
log_debug() {
    [ "${OWRT_DEBUG:-0}" = "1" ] || return 0
    printf '%s[DEBUG]%s %s\n' "$__C_DIM" "$__C_RST" "$*" >&2
}

die() {
    log_error "$@"
    exit 1
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户执行"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# 把多行字符串按空白拆成一行行非空记号，输出到 stdout。
# 用法: tokens "$STRING"
tokens() {
    # shellcheck disable=SC2086
    printf '%s\n' $1 | awk 'NF'
}
