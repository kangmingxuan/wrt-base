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

# Relax thresholds and skip network checks; this should pass
assert_true "sh \"$SCRIPT\" --skip-net --disk 100 --mem 100 --load 1000 --quiet" \
    "relaxed thresholds with skip-net should pass"

assert_summary
