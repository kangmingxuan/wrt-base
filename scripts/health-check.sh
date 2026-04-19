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
QUIET="false"

EXIT_CODE=0

usage() {
    cat <<'EOF'
Usage: health-check.sh [options]

Options:
    --disk N      Disk usage warning threshold in percent (default: 85)
    --mem N       Memory usage warning threshold in percent (default: 90)
    --load N      Warning factor for 1-minute load / CPU count (default: 2)
    --skip-time   Skip the system time sanity check
    --skip-net    Skip outbound HTTPS and DNS checks
    --quiet       Print only failing checks
    -h, --help    Show this help message
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --disk) DISK_THRESHOLD="$2"; shift ;;
            --mem)  MEM_THRESHOLD="$2"; shift ;;
            --load) LOAD_FACTOR="$2"; shift ;;
            --skip-time) SKIP_TIME="true" ;;
            --skip-net) SKIP_NET="true" ;;
            --quiet) QUIET="true" ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
        esac
        shift
    done
}

ok()   { [ "$QUIET" = "true" ] || log_info "$*"; }
fail() { log_warn "$*"; EXIT_CODE=1; }

check_time() {
    [ "$SKIP_TIME" = "true" ] && return
    # Before NTP sync, the year is often 1970 or 2000.
    year=$(date +%Y)
    if [ "$year" -lt 2024 ]; then
        fail "system time looks incorrect: $(date)"
    else
        ok "system time: $(date)"
    fi
}

check_disk() {
    # Avoid a subshell pipeline by storing df output in a temporary file first.
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
            fail "disk usage on $mount is ${pct}% (threshold: ${DISK_THRESHOLD}%)"
        else
            ok "disk usage on $mount is ${pct}%"
        fi
    done <"$tmp"
    rm -f "$tmp"
}

check_memory() {
    # /proc/meminfo reports values in kB.
    total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
    avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
    if [ -z "$total" ] || [ -z "$avail" ]; then
        fail "unable to read /proc/meminfo"
        return
    fi
    used_pct=$(( (total - avail) * 100 / total ))
    if [ "$used_pct" -ge "$MEM_THRESHOLD" ]; then
        fail "memory usage is ${used_pct}% (threshold: ${MEM_THRESHOLD}%)"
    else
        ok "memory usage is ${used_pct}%"
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
        fail "1-minute load is ${load1} (CPUs=${cpus}, factor=${LOAD_FACTOR})"
    else
        ok "1-minute load is ${load1} (CPUs=${cpus})"
    fi
}

check_network() {
    [ "$SKIP_NET" = "true" ] && return
    if has_cmd curl; then
        if curl -fsS --max-time 5 -o /dev/null https://www.cloudflare.com/cdn-cgi/trace; then
            ok "outbound HTTPS works"
        else
            fail "outbound HTTPS failed"
        fi
    else
        log_debug "curl is not installed; skipping outbound HTTPS check"
    fi

    if has_cmd nslookup; then
        if nslookup openwrt.org >/dev/null 2>&1; then
            ok "DNS resolution works"
        else
            fail "DNS resolution failed"
        fi
    else
        log_debug "nslookup is not installed; skipping DNS check"
    fi
}

check_pkg_index() {
    if ! pkg_detect; then
        fail "no supported package manager found (opkg/apk)"
        return
    fi
    ok "package manager: $PKG_MANAGER"
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
        ok "all checks passed"
    else
        log_warn "one or more checks failed"
    fi
    exit "$EXIT_CODE"
}

main "$@"
