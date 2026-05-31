#!/bin/sh
# tests/test_baseline_report.sh — smoke tests for baseline-report.sh.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/baseline-report.sh"

# shellcheck disable=SC1091
. "$TESTS_DIR/_assert.sh"

assert_true "sh \"$SCRIPT\" --help" "--help succeeds"

# Text report should render a title and known fields. Force a supported package
# backend so the report works on CI hosts without opkg/apk.
out=$(OWRT_PKG_MANAGER=opkg sh "$SCRIPT")
assert_contains "$out" "baseline report" "text report has a title"
assert_contains "$out" "Architecture" "text report includes architecture"

# JSON report should be a flat object with known keys.
json=$(OWRT_PKG_MANAGER=opkg sh "$SCRIPT" --json)
assert_contains "$json" "\"arch\":" "json report includes arch key"
assert_contains "$json" "\"kernel\":" "json report includes kernel key"
case "$json" in
    \{*) printf '  ok   json starts with a brace\n' ;;
    *)   ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL json should start with a brace\n' >&2 ;;
esac

# --output writes the report to a file.
tmp=$(mktemp 2>/dev/null || printf '/tmp/wrt-baseline-test.%s' "$$")
assert_true "OWRT_PKG_MANAGER=opkg sh \"$SCRIPT\" --output \"$tmp\"" "--output succeeds"
assert_contains "$(cat "$tmp")" "Architecture" "output file contains the report"
rm -f "$tmp"

# missing value and unknown option are rejected.
assert_false "sh \"$SCRIPT\" --output" "--output without a value is rejected"
assert_false "sh \"$SCRIPT\" --bogus" "unknown option exits non-zero"

assert_summary
