#!/bin/sh
# tests/test_health_check.sh — smoke tests for health-check.sh.
# A real environment can fail because of time, disk, or network conditions,
# so these tests only cover help output and harmless options.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/health-check.sh"

# shellcheck disable=SC1091
. "$TESTS_DIR/_assert.sh"

assert_true "sh \"$SCRIPT\" --help" "--help succeeds"

# Relax thresholds and skip environment-dependent checks; force a supported
# package backend so the smoke test stays portable across CI hosts.
assert_true "OWRT_PKG_MANAGER=opkg sh \"$SCRIPT\" --skip-time --skip-net --disk 100 --mem 100 --load 1000 --quiet" \
    "relaxed thresholds with skip-net should pass"

assert_summary
