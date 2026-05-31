#!/bin/sh
# baseline-report.sh — print a descriptive snapshot of the router baseline.
#
# Unlike health-check.sh, which only reports pass/fail, this script records the
# current state of the device (firmware, kernel, resources, network, packages)
# so you can capture a baseline before maintenance and compare afterwards.
#
# Output is human-readable text by default, or a flat JSON object with --json.

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/pkg.sh"

JSON="false"
OUTPUT=""
TAB=$(printf '\t')
KV=""

usage() {
    cat <<'EOF'
Usage: baseline-report.sh [options]

Print a descriptive baseline snapshot of an OpenWrt/ImmortalWrt device.

Options:
    --json         Print the report as a flat JSON object
    --output FILE  Write the report to FILE instead of stdout
    -h, --help     Show this help message

Environment:
    OWRT_PKG_MANAGER  Force opkg or apk (useful for tests)
    OWRT_DEBUG=1      Enable debug logs
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) JSON="true" ;;
            --output) OUTPUT=$(need_value "$@") || exit 1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1 (use --help for usage)" ;;
        esac
        shift
    done
}

# Echo the operand for an option, rejecting a missing value or another option.
# Usage: VAR=$(need_value "$@") || exit 1   inside the option's case branch.
need_value() {
    if [ "$#" -lt 2 ]; then
        log_error "$1 requires a value"
        return 1
    fi
    case "$2" in
        -*)
            log_error "$1 requires a value, but got option: $2"
            return 1
            ;;
    esac
    printf '%s\n' "$2"
}

# ---- Fact collection helpers ----------------------------------------------

# Append a key/label/value row to the staging store.
add() {
    printf '%s%s%s%s%s\n' "$1" "$TAB" "$2" "$TAB" "$3" >>"$KV"
}

# Append a section header (text rendering only).
add_section() {
    printf '#%s%s%s\n' "$TAB" "$1" "$TAB" >>"$KV"
}

get_hostname() {
    uci -q get system.@system[0].hostname 2>/dev/null \
        || cat /proc/sys/kernel/hostname 2>/dev/null \
        || printf 'unknown'
}

get_model() {
    if [ -r /tmp/sysinfo/model ]; then
        cat /tmp/sysinfo/model
    else
        printf 'unknown'
    fi
}

get_firmware() {
    if [ -r /etc/openwrt_release ]; then
        grep '^DISTRIB_DESCRIPTION=' /etc/openwrt_release 2>/dev/null \
            | cut -d"'" -f2
    fi
}

get_uptime() {
    [ -r /proc/uptime ] || { printf 'unknown'; return; }
    secs=$(cut -d. -f1 /proc/uptime)
    case "$secs" in
        ''|*[!0-9]*) printf 'unknown'; return ;;
    esac
    printf '%dd %dh %dm' \
        "$((secs / 86400))" "$(((secs % 86400) / 3600))" "$(((secs % 3600) / 60))"
}

disk_pct() {
    df -P "$1" 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}'
}

route_src() {
    # $1 is the address family flag (-4 or -6); $2 is a probe destination.
    has_cmd ip || return 0
    ip "$1" route get "$2" 2>/dev/null \
        | sed -n 's/.*src \([0-9a-fA-F:.]*\).*/\1/p' \
        | head -n 1
}

count_user_packages() {
    case "$PKG_MANAGER" in
        opkg)
            [ -r /usr/lib/opkg/status ] || return 0
            awk '
                /^Package:/ { pkg = $2 }
                /^Status:.*user installed/ { if (pkg != "") c++ }
                END { print c + 0 }
            ' /usr/lib/opkg/status
            ;;
        apk)
            [ -r /etc/apk/world ] && awk 'NF { c++ } END { print c + 0 }' /etc/apk/world
            ;;
    esac
}

count_total_packages() {
    case "$PKG_MANAGER" in
        opkg) opkg list-installed 2>/dev/null | awk 'END { print NR + 0 }' ;;
        apk)  apk info 2>/dev/null | awk 'END { print NR + 0 }' ;;
    esac
}

gather() {
    add_section "System"
    add generated "Generated" "$(date '+%Y-%m-%d %H:%M:%S %z')"
    add hostname "Hostname" "$(get_hostname)"
    add model "Model" "$(get_model)"
    add firmware "Firmware" "$(get_firmware)"
    add kernel "Kernel" "$(uname -sr)"
    add arch "Architecture" "$(uname -m)"
    add uptime "Uptime" "$(get_uptime)"

    add_section "Resources"
    cpus=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0)
    add cpus "CPUs" "$cpus"
    if [ -r /proc/loadavg ]; then
        read -r l1 l5 l15 _rest </proc/loadavg
        add load "Load (1/5/15m)" "$l1 $l5 $l15"
    fi
    total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
    avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
    if [ -n "$total" ] && [ -n "$avail" ] && [ "$total" -gt 0 ]; then
        add mem_used_pct "Memory used" "$(( (total - avail) * 100 / total ))"
    fi
    root_pct=$(disk_pct /)
    [ -n "$root_pct" ] && add disk_root_pct "Disk / used" "$root_pct"
    if [ -d /overlay ]; then
        overlay_pct=$(disk_pct /overlay)
        [ -n "$overlay_pct" ] && add disk_overlay_pct "Disk /overlay used" "$overlay_pct"
    fi

    add_section "Network"
    ip4=$(route_src -4 1.1.1.1)
    add wan_ip4 "Egress IPv4" "${ip4:-none}"
    ip6=$(route_src -6 2606:4700:4700::1111)
    add wan_ip6 "Egress IPv6" "${ip6:-none}"
    if has_cmd ip && ip -6 addr show scope global 2>/dev/null | grep -qiE 'inet6 [23][0-9a-f]*:'; then
        add ipv6_global "Global IPv6" "yes"
    else
        add ipv6_global "Global IPv6" "no"
    fi

    add_section "Packages"
    if [ -n "$PKG_MANAGER" ]; then
        add pkg_manager "Manager" "$PKG_MANAGER"
        user_count=$(count_user_packages)
        [ -n "$user_count" ] && add pkg_user_installed "User-installed" "$user_count"
        total_count=$(count_total_packages)
        [ -n "$total_count" ] && add pkg_total "Total installed" "$total_count"
    else
        add pkg_manager "Manager" "none"
    fi
}

# ---- Rendering -------------------------------------------------------------

json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

render_text() {
    printf '== wrt-base baseline report ==\n'
    while IFS="$TAB" read -r key label value; do
        case "$key" in
            '') continue ;;
            '#') printf '\n-- %s --\n' "$label" ;;
            *)   printf '  %-20s %s\n' "$label" "$value" ;;
        esac
    done <"$KV"
}

render_json() {
    printf '{\n'
    first=1
    while IFS="$TAB" read -r key label value; do
        case "$key" in
            ''|'#') continue ;;
        esac
        if [ "$first" = 1 ]; then first=0; else printf ',\n'; fi
        case "$value" in
            ''|*[!0-9]*) printf '  "%s": "%s"' "$key" "$(json_escape "$value")" ;;
            *)           printf '  "%s": %s' "$key" "$value" ;;
        esac
    done <"$KV"
    printf '\n}\n'
}

render() {
    if [ "$JSON" = "true" ]; then
        render_json
    else
        render_text
    fi
}

main() {
    parse_args "$@"
    pkg_detect 2>/dev/null || true

    KV=$(mktemp 2>/dev/null || printf '/tmp/wrt-baseline.%s' "$$")
    : >"$KV"
    gather

    if [ -n "$OUTPUT" ]; then
        if render >"$OUTPUT"; then
            log_info "baseline report written: $OUTPUT"
        else
            rm -f "$KV"
            die "failed to write report: $OUTPUT"
        fi
    else
        render
    fi

    rm -f "$KV"
}

main "$@"
