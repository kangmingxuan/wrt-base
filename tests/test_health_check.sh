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

# JSON output is emitted on stdout with a checks array and a result field.
json=$(OWRT_PKG_MANAGER=opkg sh "$SCRIPT" --skip-time --skip-net --disk 100 --mem 100 --load 1000 --json)
assert_contains "$json" "\"checks\":" "json output includes a checks array"
assert_contains "$json" "\"result\":" "json output includes a result field"

# Options that expect a value must reject a missing value or a following option.
assert_false "sh \"$SCRIPT\" --disk" "--disk without a value is rejected"
assert_false "sh \"$SCRIPT\" --disk --quiet" "--disk followed by an option is rejected"

assert_summary
