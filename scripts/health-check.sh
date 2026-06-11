#!/bin/sh
# health-check.sh — quick health checks for a router maintenance baseline.
#
# Focus areas for the baseline:
#   - system time (required for TLS and Reality)
#   - free space on important mount points
#   - memory and load
#   - outbound connectivity and DNS
#   - package manager availability
# Any failed check returns a non-zero exit status, which is convenient for cron.

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/pkg.sh"

DISK_THRESHOLD=85   # percentage threshold for warnings
MEM_THRESHOLD=90
LOAD_FACTOR=2       # warn when 1-minute load / CPU count exceeds this factor
SKIP_TIME="false"
SKIP_NET="false"
CHECK_ROM="false"
QUIET="false"
JSON="false"

EXIT_CODE=0
TAB=$(printf '\t')
RESULT_TMP=""

usage() {
    cat <<'EOF'
Usage: health-check.sh [options]

Options:
    --disk N      Disk usage warning threshold in percent (default: 85)
    --mem N       Memory usage warning threshold in percent (default: 90)
    --load N      Warning factor for 1-minute load / CPU count (default: 2)
    --skip-time   Skip the system time and NTP checks
    --skip-net    Skip outbound HTTPS, DNS, and IPv6 checks
    --check-rom   Apply the disk threshold to /rom as well (it is read-only
                  and always 100% used on squashfs systems, so it is skipped
                  by default)
    --quiet       Print only failing checks
    --json        Print results as a JSON document on stdout
    -h, --help    Show this help message
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --disk) DISK_THRESHOLD=$(need_value "$@") || exit 1; shift ;;
            --mem)  MEM_THRESHOLD=$(need_value "$@") || exit 1; shift ;;
            --load) LOAD_FACTOR=$(need_value "$@") || exit 1; shift ;;
            --skip-time) SKIP_TIME="true" ;;
            --skip-net) SKIP_NET="true" ;;
            --check-rom) CHECK_ROM="true" ;;
            --quiet) QUIET="true" ;;
            --json) JSON="true" ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
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

# Escape a string for inclusion in a JSON double-quoted value.
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Record a single check result. In JSON mode results are buffered and rendered
# at the end; otherwise they are logged immediately.
record() {
    rstatus=$1; rname=$2; rmsg=$3
    [ "$rstatus" = "fail" ] && EXIT_CODE=1
    if [ "$JSON" = "true" ]; then
        printf '%s%s%s%s%s\n' "$rstatus" "$TAB" "$rname" "$TAB" "$rmsg" >>"$RESULT_TMP"
        return
    fi
    case "$rstatus" in
        pass) [ "$QUIET" = "true" ] || log_info "$rmsg" ;;
        fail) log_warn "$rmsg" ;;
    esac
}

ok()   { record pass "$1" "$2"; }
fail() { record fail "$1" "$2"; }

check_time() {
    [ "$SKIP_TIME" = "true" ] && return
    # Before NTP sync, the year is often 1970 or 2000.
    year=$(date +%Y)
    if [ "$year" -lt 2024 ]; then
        fail time "system time looks incorrect: $(date)"
    else
        ok time "system time: $(date)"
    fi
}

# Report whether an NTP client appears to be running. Prefer pgrep when
# available; fall back to scanning ps output (busybox lists all processes,
# while procps-ng ps is terminal-scoped, so this is only a best-effort probe).
ntpd_running() {
    if has_cmd pgrep; then
        pgrep ntpd >/dev/null 2>&1
        return
    fi
    # shellcheck disable=SC2009
    ps 2>/dev/null | grep -q '[n]tpd'
}

check_ntp() {
    [ "$SKIP_TIME" = "true" ] && return
    # On OpenWrt/ImmortalWrt, procd's init script is the authoritative source;
    # process scanning is unreliable when procps-ng ps replaces busybox ps.
    if [ -x /etc/init.d/sysntpd ]; then
        if /etc/init.d/sysntpd status 2>/dev/null | grep -qi 'running'; then
            ok ntp "NTP client (sysntpd) is running"
        else
            fail ntp "sysntpd is installed but not running"
        fi
        return
    fi
    if ntpd_running; then
        ok ntp "NTP client (ntpd) is running"
    else
        fail ntp "no running NTP client detected"
    fi
}

check_disk() {
    # Avoid a subshell pipeline by storing df output in a temporary file first.
    # OWRT_DF_FILE points at a file with `df -P` output (useful for tests;
    # PATH-mocking df does not work under standalone-mode BusyBox, which runs
    # applets without consulting PATH).
    tmp=$(mktemp 2>/dev/null || printf '/tmp/owrt-hc.%s' "$$")
    if [ -n "${OWRT_DF_FILE:-}" ]; then
        awk 'NR>1' "$OWRT_DF_FILE" >"$tmp"
    else
        df -P 2>/dev/null | awk 'NR>1' >"$tmp"
    fi
    while read -r _fs _blocks _used _avail capacity mount; do
        case "$mount" in
            /|/overlay) ;;
            # /rom is the read-only squashfs firmware image and is always
            # 100% used, so only check it when explicitly requested.
            /rom) [ "$CHECK_ROM" = "true" ] || continue ;;
            *) continue ;;
        esac
        pct=$(printf '%s' "$capacity" | tr -d '%')
        case "$pct" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$pct" -ge "$DISK_THRESHOLD" ]; then
            fail "disk:$mount" "disk usage on $mount is ${pct}% (threshold: ${DISK_THRESHOLD}%)"
        else
            ok "disk:$mount" "disk usage on $mount is ${pct}%"
        fi
    done <"$tmp"
    rm -f "$tmp"
}

check_memory() {
    # /proc/meminfo reports values in kB.
    total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
    if [ -z "$total" ] || [ -z "$avail" ]; then
        fail mem "unable to read /proc/meminfo"
        return
    fi
    used_pct=$(( (total - avail) * 100 / total ))
    if [ "$used_pct" -ge "$MEM_THRESHOLD" ]; then
        fail mem "memory usage is ${used_pct}% (threshold: ${MEM_THRESHOLD}%)"
    else
        ok mem "memory usage is ${used_pct}%"
    fi
}

check_load() {
    cpus=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
    [ "$cpus" -gt 0 ] || cpus=1
    load1=$(awk '{print $1}' /proc/loadavg)
    # Compare as integers by multiplying by 100.
    load1_x100=$(printf '%s' "$load1" | awk '{printf "%d", $1*100}')
    threshold_x100=$(( cpus * LOAD_FACTOR * 100 ))
    if [ "$load1_x100" -gt "$threshold_x100" ]; then
        fail load "1-minute load is ${load1} (CPUs=${cpus}, factor=${LOAD_FACTOR})"
    else
        ok load "1-minute load is ${load1} (CPUs=${cpus})"
    fi
}

check_network() {
    [ "$SKIP_NET" = "true" ] && return
    if has_cmd curl; then
        if curl -fsS --max-time 5 -o /dev/null https://www.cloudflare.com/cdn-cgi/trace; then
            ok https "outbound HTTPS works"
        else
            fail https "outbound HTTPS failed"
        fi
    else
        log_debug "curl is not installed; skipping outbound HTTPS check"
    fi

    if has_cmd nslookup; then
        if nslookup openwrt.org >/dev/null 2>&1; then
            ok dns "DNS resolution works"
        else
            fail dns "DNS resolution failed"
        fi
    else
        log_debug "nslookup is not installed; skipping DNS check"
    fi
}

# Report whether the device has at least one global unicast IPv6 address
# (2000::/3). Unique local addresses (fc00::/7) carry "scope global" too but are
# not publicly routable, so they are deliberately excluded.
has_global_ipv6() {
    has_cmd ip || return 1
    ip -6 addr show scope global 2>/dev/null | grep -qiE 'inet6 [23][0-9a-f]*:'
}

check_ipv6() {
    [ "$SKIP_NET" = "true" ] && return
    if ! has_global_ipv6; then
        # No IPv6 deployment is a valid configuration, so this is not a failure.
        ok ipv6 "no global IPv6 address; skipping IPv6 connectivity check"
        return
    fi
    if has_cmd curl; then
        if curl -fsS -6 --max-time 5 -o /dev/null https://www.cloudflare.com/cdn-cgi/trace; then
            ok ipv6 "outbound IPv6 HTTPS works"
        else
            fail ipv6 "global IPv6 is present but outbound IPv6 HTTPS failed"
        fi
    else
        log_debug "curl is not installed; skipping IPv6 check"
    fi
}

check_pkg_index() {
    if ! pkg_detect; then
        fail pkg "no supported package manager found (opkg/apk)"
        return
    fi
    ok pkg "package manager: $PKG_MANAGER"
}

# Render buffered results as a JSON document on stdout.
emit_json() {
    result=pass
    [ "$EXIT_CODE" -eq 0 ] || result=fail
    printf '{\n  "checks": [\n'
    first=1
    while IFS="$TAB" read -r st nm msg; do
        [ -n "$st" ] || continue
        if [ "$first" = 1 ]; then first=0; else printf ',\n'; fi
        printf '    {"name": "%s", "status": "%s", "message": "%s"}' \
            "$(json_escape "$nm")" "$st" "$(json_escape "$msg")"
    done <"$RESULT_TMP"
    printf '\n  ],\n  "result": "%s"\n}\n' "$result"
}

main() {
    parse_args "$@"

    if [ "$JSON" = "true" ]; then
        RESULT_TMP=$(mktemp 2>/dev/null || printf '/tmp/owrt-hc-json.%s' "$$")
        : >"$RESULT_TMP"
    fi

    check_time
    check_ntp
    check_disk
    check_memory
    check_load
    check_network
    check_ipv6
    check_pkg_index

    if [ "$JSON" = "true" ]; then
        emit_json
        rm -f "$RESULT_TMP"
        exit "$EXIT_CODE"
    fi

    if [ "$EXIT_CODE" -eq 0 ]; then
        ok summary "all checks passed"
    else
        log_warn "one or more checks failed"
    fi
    exit "$EXIT_CODE"
}

main "$@"
