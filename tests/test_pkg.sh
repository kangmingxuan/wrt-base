#!/bin/sh
# tests/test_pkg.sh — tests for the pkg.sh package manager abstraction.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)

# shellcheck source=_assert.sh
. "$TESTS_DIR/_assert.sh"
# shellcheck source=../scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"
# shellcheck source=../scripts/lib/pkg.sh
. "$REPO_DIR/scripts/lib/pkg.sh"

# force opkg
OWRT_PKG_MANAGER=opkg pkg_detect
assert_eq "opkg" "$PKG_MANAGER" "OWRT_PKG_MANAGER=opkg is honored"

# force apk
OWRT_PKG_MANAGER=apk pkg_detect
assert_eq "apk" "$PKG_MANAGER" "OWRT_PKG_MANAGER=apk is honored"

# auto-detection: the current system should expose at least one package manager
unset OWRT_PKG_MANAGER
PKG_MANAGER=""
if pkg_detect; then
    assert_contains "opkg apk" "$PKG_MANAGER" "auto-detect finds opkg or apk"
else
    printf '  skip neither opkg nor apk is available in this environment\n'
fi

assert_summary
