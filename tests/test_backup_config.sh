#!/bin/sh
# tests/test_backup_config.sh — smoke tests for backup-config.sh.
# These tests avoid invoking the real sysupgrade, which requires a router and
# root, and instead cover argument handling and help output.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/backup-config.sh"

# shellcheck disable=SC1091
. "$TESTS_DIR/_assert.sh"

# --help should exit successfully and describe the archive contents
assert_true "sh \"$SCRIPT\" --help" "--help succeeds"
out=$(sh "$SCRIPT" --help)
assert_contains "$out" "sysupgrade" "--help mentions sysupgrade backup"
assert_contains "$out" "--keep" "--help documents --keep"
assert_contains "$out" "--output-dir" "--help documents --output-dir"

# --keep must reject non-numeric values
assert_false "sh \"$SCRIPT\" --keep abc" "non-numeric --keep is rejected"

# unknown options should fail
assert_false "sh \"$SCRIPT\" --bogus" "unknown option exits non-zero"

assert_summary
