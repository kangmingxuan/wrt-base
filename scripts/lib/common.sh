#!/bin/sh
# common.sh — shared helpers for wrt-base scripts.
#
# Source this file with `.`. It is not meant to be executed directly.
# Provides logging, root checks, command detection, and token helpers.

# shellcheck shell=sh

# Prevent duplicate sourcing.
if [ -n "${__OWRT_COMMON_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
__OWRT_COMMON_LOADED=1

# Enable colored output only when stderr is a TTY.
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
    [ "$(id -u)" = "0" ] || die "please run as root"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Split multiline text into non-empty whitespace-delimited tokens, one per line.
# Usage: tokens "$STRING"
tokens() {
    # shellcheck disable=SC2086
    printf '%s\n' $1 | awk 'NF'
}
