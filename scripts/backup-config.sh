#!/bin/sh
# backup-config.sh — create a portable configuration backup for a router.
#
# The backup bundles two layers:
#   1. The standard sysupgrade archive (sysupgrade -b), which captures the
#      files listed in /etc/sysupgrade.conf and the opkg/apk baseline.
#   2. A set of extra maintenance-oriented exports that sysupgrade does not
#      always include: installed package list, feed configuration, crontab,
#      and a short device manifest.
#
# Everything is collected into a single timestamped .tar.gz so it can be copied
# off the device before a risky maintenance operation.

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/pkg.sh"

OUTPUT_DIR="/root/backups"
KEEP="0"
DRY_RUN="false"

usage() {
    cat <<'EOF'
Usage: backup-config.sh [options]

Create a timestamped configuration backup archive for OpenWrt/ImmortalWrt.

Options:
    --output-dir DIR  Directory to write the archive into (default: /root/backups)
    --keep N          Keep only the N most recent backups in the output dir (0 = keep all)
    --dry-run         Show what would be collected without writing the final archive
    -h, --help        Show this help message

Environment:
    OWRT_DEBUG=1      Enable debug logs

The archive contains:
    sysupgrade.tar.gz        Standard sysupgrade backup (sysupgrade -b)
    installed-packages.txt   Explicitly installed packages
    feeds/                   opkg/apk feed configuration
    crontab.root             Root crontab, when present
    manifest.txt             Firmware, kernel, architecture, and device summary
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --output-dir) OUTPUT_DIR=$(need_value "$@") || exit 1; shift ;;
            --keep) KEEP=$(need_value "$@") || exit 1; shift ;;
            --dry-run) DRY_RUN="true" ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1 (use --help for usage)" ;;
        esac
        shift
    done

    case "$KEEP" in
        ''|*[!0-9]*) die "--keep expects a non-negative integer" ;;
    esac
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

# Write a short device manifest into the staging directory.
write_manifest() {
    manifest=$1
    {
        printf 'Generated:    %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
        printf 'Hostname:     %s\n' "$(uci -q get system.@system[0].hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null)"
        printf 'Architecture: %s\n' "$(uname -m)"
        printf 'Kernel:       %s\n' "$(uname -sr)"
        if [ -r /etc/openwrt_release ]; then
            printf '\n--- /etc/openwrt_release ---\n'
            cat /etc/openwrt_release
        fi
        if pkg_detect; then
            printf '\nPackage manager: %s\n' "$PKG_MANAGER"
        fi
    } >"$manifest" 2>/dev/null
}

# Export only the explicitly (user) installed packages, not their dependencies,
# so a restore reinstalls the intended set instead of the full dependency tree.
write_installed_packages() {
    out=$1
    case "$PKG_MANAGER" in
        opkg)
            # opkg records explicit installs as "Status: install user installed"
            # in its status database. Fall back to the full list if unavailable.
            if [ -r /usr/lib/opkg/status ]; then
                awk '
                    /^Package:/ { pkg = $2 }
                    /^Status:.*user installed/ { if (pkg != "") print pkg }
                ' /usr/lib/opkg/status | sort >"$out"
                [ -s "$out" ] && return 0
            fi
            opkg list-installed 2>/dev/null | awk '{print $1}' | sort >"$out"
            ;;
        apk)
            # apk tracks explicitly installed packages in the world file.
            if [ -r /etc/apk/world ]; then
                sort /etc/apk/world >"$out"
            else
                apk info 2>/dev/null | sort >"$out"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Copy feed configuration into the staging directory.
copy_feeds() {
    dest=$1
    mkdir -p "$dest"
    if [ -f /etc/opkg/distfeeds.conf ]; then
        cp /etc/opkg/distfeeds.conf "$dest/" 2>/dev/null || true
    fi
    if [ -d /etc/opkg ]; then
        # Custom feeds and keys live alongside distfeeds.conf.
        find /etc/opkg -maxdepth 1 -type f -name '*.conf' -exec cp {} "$dest/" \; 2>/dev/null || true
    fi
    if [ -d /etc/apk ]; then
        find /etc/apk -maxdepth 2 -type f \( -name '*.list' -o -name 'repositories' \) \
            -exec cp {} "$dest/" \; 2>/dev/null || true
    fi
}

main() {
    parse_args "$@"
    require_root

    has_cmd sysupgrade || die "sysupgrade not found; this does not look like OpenWrt or ImmortalWrt"
    pkg_detect || log_warn "no supported package manager detected; package list will be skipped"

    timestamp=$(date '+%Y%m%d-%H%M%S')
    host=$(uci -q get system.@system[0].hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || printf 'router')
    archive_name="wrt-backup-${host}-${timestamp}.tar.gz"

    stage=$(mktemp -d 2>/dev/null || printf '/tmp/wrt-backup.%s' "$$")
    [ -d "$stage" ] || mkdir -p "$stage" || die "failed to create staging directory"

    log_info "collecting sysupgrade backup"
    if ! sysupgrade -k -b "$stage/sysupgrade.tar.gz" >/dev/null 2>&1; then
        rm -rf "$stage"
        die "sysupgrade backup failed"
    fi

    if [ -n "$PKG_MANAGER" ]; then
        log_info "exporting installed package list"
        write_installed_packages "$stage/installed-packages.txt" || \
            log_warn "could not export installed package list"
    fi

    log_info "copying feed configuration"
    copy_feeds "$stage/feeds"

    if crontab -l >/dev/null 2>&1; then
        log_info "exporting root crontab"
        crontab -l >"$stage/crontab.root" 2>/dev/null || true
    fi

    log_info "writing device manifest"
    write_manifest "$stage/manifest.txt"

    if [ "$DRY_RUN" = "true" ]; then
        log_info "[dry-run] staged files:"
        find "$stage" -type f | sed "s#^$stage/#  #" >&2
        rm -rf "$stage"
        log_info "[dry-run] no archive written"
        exit 0
    fi

    mkdir -p "$OUTPUT_DIR" || die "failed to create output directory: $OUTPUT_DIR"
    archive_path="$OUTPUT_DIR/$archive_name"

    if ! tar -czf "$archive_path" -C "$stage" . 2>/dev/null; then
        rm -rf "$stage"
        die "failed to create archive: $archive_path"
    fi
    rm -rf "$stage"

    log_info "backup written: $archive_path"

    if [ "$KEEP" -gt 0 ]; then
        prune_old_backups
    fi
}

# Remove old wrt-backup archives, keeping the newest $KEEP files.
# Archive names embed a sortable timestamp (wrt-backup-<host>-YYYYMMDD-HHMMSS),
# so a reverse lexical sort orders them newest-first without relying on
# date(1) -r or stat(1), which BusyBox does not reliably provide.
prune_old_backups() {
    listing=$(
        for f in "$OUTPUT_DIR"/wrt-backup-*.tar.gz; do
            [ -f "$f" ] || continue
            printf '%s\n' "$f"
        done | sort -r
    )
    [ -n "$listing" ] || return 0

    count=0
    printf '%s\n' "$listing" | while IFS= read -r path; do
        [ -n "$path" ] || continue
        count=$((count + 1))
        if [ "$count" -gt "$KEEP" ]; then
            rm -f "$path" && log_info "pruned old backup: $path"
        fi
    done
}

main "$@"
