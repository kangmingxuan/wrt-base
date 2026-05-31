#!/bin/sh
# install-tools.sh — install maintenance tools for ImmortalWrt/OpenWrt.
#
# The default mode is "full" for a complete maintenance baseline.
# Use --minimal for a smaller troubleshooting-oriented set.
# Single-package failures do not abort the run; warnings are summarized at the end.

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/pkg.sh"

MODE="full"
PRINT_ONLY="false"
SKIP_UPDATE="false"
DRY_RUN="false"
FAILED_PACKAGES=""
TCPDUMP_FULL_MIN_FREE_KB="16384"
CONFIG_FILE=""
NO_CONFIG="false"
DEFAULT_CONFIG="${OWRT_INSTALL_CONFIG:-/etc/wrt-base/install-tools.conf}"

# ---- Package set definitions ----------------------------------------------

# Baseline tools: installed in every mode.
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

# Minimum network and system troubleshooting set: installed in minimal and full.
MINIMAL_PACKAGES="
bind-dig
ip-full
openssl-util
"

# Full maintenance set: installed only in full mode.
FULL_PACKAGES="
coreutils
coreutils-install
diffutils
ethtool
findutils-find
findutils-xargs
gawk
grep
gzip
htop
iperf3
iputils-ping
iputils-tracepath
libstdcpp6
lsof
openssh-client
openssh-server
openssh-sftp-server
procps-ng-pkill
procps-ng-ps
procps-ng-top
python3-light
ripgrep
rsync
sed
strace
tar
tree
unzip
"

# ---- CLI ------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: install-tools.sh [options]

Install common maintenance tools for ImmortalWrt/OpenWrt with automatic opkg/apk detection.

Options:
    --minimal       Install only the baseline and minimum troubleshooting set
    --full          Install the full set (default)
    --config FILE   Add extra packages listed in FILE (one per line, # comments)
    --no-config     Ignore the default config file (does not affect --config)
    --print-only    Print the package list without installing anything
    --dry-run       Detect the package manager and print actions without installing
    --skip-update   Skip package feed update
    -h, --help      Show this help message

Config file:
    When --config is not given, the default config file is loaded if present:
      /etc/wrt-base/install-tools.conf  (override with OWRT_INSTALL_CONFIG)
    Each non-empty, non-comment line names one extra package to install on top
    of the selected mode. Use --no-config to ignore it.

Environment:
    OWRT_PKG_MANAGER      Force opkg or apk (useful for tests)
    OWRT_TCPDUMP_VARIANT  Force the tcpdump variant: auto|full|mini
    OWRT_STORAGE_FREE_KB  Override detected free storage in KB (useful for tests)
    OWRT_INSTALL_CONFIG   Override the default config file path
    OWRT_DEBUG=1          Enable debug logs
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --minimal) MODE="minimal" ;;
            --full)    MODE="full" ;;
            --config) CONFIG_FILE=$(need_value "$@") || exit 1; shift ;;
            --no-config) NO_CONFIG="true" ;;
            --print-only) PRINT_ONLY="true" ;;
            --dry-run) DRY_RUN="true" ;;
            --skip-update) SKIP_UPDATE="true" ;;
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

# ---- Core logic ------------------------------------------------------------

selected_packages() {
    tokens "$BASE_PACKAGES"
    tokens "$MINIMAL_PACKAGES"
    choose_tcpdump_package
    if [ "$MODE" = "full" ]; then
        tokens "$FULL_PACKAGES"
    fi
    extra_packages
}

# Resolve the active config file path, or print nothing when none applies.
# An explicit --config always wins; --no-config only suppresses the default.
resolve_config() {
    if [ -n "$CONFIG_FILE" ]; then
        [ -r "$CONFIG_FILE" ] && printf '%s\n' "$CONFIG_FILE"
        return 0
    fi
    [ "$NO_CONFIG" = "true" ] && return 0
    [ -r "$DEFAULT_CONFIG" ] && printf '%s\n' "$DEFAULT_CONFIG"
    return 0
}

# Emit extra packages declared in the config file. Each line may use leading
# indentation and a trailing '#' comment; only the first whitespace-delimited
# token on a non-empty line is treated as a package name.
extra_packages() {
    cfg=$(resolve_config)
    [ -n "$cfg" ] || return 0
    awk '{ sub(/#.*/, ""); if ($1 != "") print $1 }' "$cfg" 2>/dev/null
}

get_storage_free_kb() {
    if [ -n "${OWRT_STORAGE_FREE_KB:-}" ]; then
        printf '%s\n' "$OWRT_STORAGE_FREE_KB"
        return 0
    fi

    storage_path=/overlay
    [ -d "$storage_path" ] || storage_path=/

    df -Pk "$storage_path" 2>/dev/null | awk 'NR==2 {print $4; exit}'
}

choose_tcpdump_package() {
    case "${OWRT_TCPDUMP_VARIANT:-auto}" in
        full)
            log_info "forcing full tcpdump via environment override"
            printf '%s\n' tcpdump
            return 0
            ;;
        mini)
            log_info "forcing tcpdump-mini via environment override"
            printf '%s\n' tcpdump-mini
            return 0
            ;;
        auto|'')
            ;;
        *)
            die "OWRT_TCPDUMP_VARIANT only supports auto|full|mini"
            ;;
    esac

    free_kb=$(get_storage_free_kb)
    case "$free_kb" in
        ''|*[!0-9]*)
            log_warn "unable to detect free storage; defaulting to tcpdump-mini"
            printf '%s\n' tcpdump-mini
            return 0
            ;;
    esac

    if [ "$free_kb" -ge "$TCPDUMP_FULL_MIN_FREE_KB" ]; then
        log_info "${free_kb}KB free; selecting full tcpdump"
        printf '%s\n' tcpdump
    else
        log_info "${free_kb}KB free, below ${TCPDUMP_FULL_MIN_FREE_KB}KB; selecting tcpdump-mini"
        printf '%s\n' tcpdump-mini
    fi
}

should_skip_package() {
    package_name=$1

    case "$package_name" in
        tcpdump-mini)
            if pkg_is_installed tcpdump; then
                log_info "full tcpdump is already installed; skipping conflicting package: tcpdump-mini"
                return 0
            fi
            ;;
        tcpdump)
            if pkg_is_installed tcpdump-mini; then
                log_info "tcpdump-mini is already installed; skipping conflicting package: tcpdump"
                return 0
            fi
            ;;
    esac

    return 1
}

# In POSIX sh, the right side of a pipeline runs in a subshell.
# Store failures in a temp file first, then read them back into FAILED_PACKAGES.
install_all_collect() {
    tmp=$(mktemp 2>/dev/null || printf '/tmp/owrt-install.%s' "$$")
    : > "$tmp"
    selected_packages | while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        if should_skip_package "$pkg"; then
            continue
        fi
        if pkg_is_installed "$pkg"; then
            log_info "already installed; skipping: $pkg"
            continue
        fi
        if ! pkg_is_available "$pkg"; then
            printf '%s\n' "$pkg" >>"$tmp"
            log_warn "package is unavailable in the current feed: $pkg"
            continue
        fi
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[dry-run] would install: $pkg"
            continue
        fi
        if pkg_install "$pkg" >/dev/null 2>&1; then
            log_info "installed: $pkg"
        else
            printf '%s\n' "$pkg" >>"$tmp"
            log_warn "installation failed and was skipped: $pkg"
        fi
    done
    FAILED_PACKAGES=$(tr '\n' ' ' <"$tmp" | sed 's/ $//')
    rm -f "$tmp"
}

main() {
    parse_args "$@"

    # An explicit --config is always validated, even alongside --no-config.
    if [ -n "$CONFIG_FILE" ] && [ ! -r "$CONFIG_FILE" ]; then
        die "config file not readable: $CONFIG_FILE"
    fi

    if [ "$PRINT_ONLY" = "true" ]; then
        selected_packages
        exit 0
    fi

    pkg_detect || die "failed to detect opkg or apk; this does not look like OpenWrt or ImmortalWrt"
    log_info "package manager: $PKG_MANAGER"
    log_info "installation mode: $MODE"

    if [ "$DRY_RUN" != "true" ]; then
        require_root
    fi

    if [ "$SKIP_UPDATE" != "true" ] && [ "$DRY_RUN" != "true" ]; then
        pkg_update || die "$PKG_MANAGER update failed; check package feeds and try again"
    fi

    install_all_collect

    if [ -n "$FAILED_PACKAGES" ]; then
        log_warn "the following packages could not be installed; verify them against the current firmware feeds: $FAILED_PACKAGES"
        exit 0
    fi

    log_info "tool installation complete"
}

main "$@"
