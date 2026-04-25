#!/bin/sh
# tests/test_install_tools.sh — smoke tests for install-tools.sh.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/install-tools.sh"

# shellcheck disable=SC1091
. "$TESTS_DIR/_assert.sh"

# --help should exit successfully
assert_true "sh \"$SCRIPT\" --help" "--help succeeds"

# --print-only should list baseline packages
out=$(sh "$SCRIPT" --print-only)
assert_contains "$out" "curl"  "--print-only includes curl"
assert_contains "$out" "git"   "--print-only includes git"
assert_contains "$out" "tmux"  "--print-only includes tmux"

# minimal mode should not include full-only packages
out_min=$(sh "$SCRIPT" --minimal --print-only)
case "$out_min" in
    *htop*) ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL minimal should not include htop\n' >&2 ;;
    *)      printf '  ok   minimal excludes htop\n' ;;
esac
assert_contains "$out_min" "curl" "minimal still includes curl"

# full tcpdump should be chosen when storage is sufficient
out_full_storage=$(OWRT_STORAGE_FREE_KB=20000 sh "$SCRIPT" --minimal --print-only)
assert_contains "$out_full_storage" "tcpdump" "select tcpdump when storage is sufficient"
case "$out_full_storage" in
    *tcpdump-mini*) ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL should not choose tcpdump-mini when storage is sufficient\n' >&2 ;;
    *)              printf '  ok   excludes tcpdump-mini when storage is sufficient\n' ;;
esac

# tcpdump-mini should be chosen when storage is low
out_mini_storage=$(OWRT_STORAGE_FREE_KB=8000 sh "$SCRIPT" --minimal --print-only)
assert_contains "$out_mini_storage" "tcpdump-mini" "select tcpdump-mini when storage is low"

# environment variables can override the automatic choice
forced_mini=$(OWRT_TCPDUMP_VARIANT=mini OWRT_STORAGE_FREE_KB=20000 sh "$SCRIPT" --minimal --print-only)
assert_contains "$forced_mini" "tcpdump-mini" "environment can force tcpdump-mini"

forced_full=$(OWRT_TCPDUMP_VARIANT=full OWRT_STORAGE_FREE_KB=1 sh "$SCRIPT" --minimal --print-only)
assert_contains "$forced_full" "tcpdump" "environment can force tcpdump"

# full mode should include htop
out_full=$(sh "$SCRIPT" --full --print-only)
assert_contains "$out_full" "htop" "full includes htop"
assert_contains "$out_full" "coreutils-install" "full includes coreutils-install for install(1)"
assert_contains "$out_full" "gzip" "full includes gzip"
assert_contains "$out_full" "libstdcpp6" "full includes libstdcpp6"
assert_contains "$out_full" "openssh-client" "full includes openssh-client"
assert_contains "$out_full" "openssh-server" "full includes openssh-server"
assert_contains "$out_full" "openssh-sftp-server" "full includes openssh-sftp-server"
assert_contains "$out_full" "python3-light" "full includes python3-light"
assert_contains "$out_full" "ripgrep" "full includes ripgrep"

# if tcpdump is already installed, forcing mini should skip the conflicting package
if opkg list-installed tcpdump >/dev/null 2>&1; then
    dry_run=$(OWRT_TCPDUMP_VARIANT=mini sh "$SCRIPT" --dry-run --skip-update 2>&1)
    assert_contains "$dry_run" "full tcpdump is already installed; skipping conflicting package: tcpdump-mini" \
        "forcing mini skips conflicting tcpdump-mini"
fi

# unknown options should fail
assert_false "sh \"$SCRIPT\" --bogus" "unknown option exits non-zero"

assert_summary
