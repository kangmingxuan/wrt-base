#!/bin/sh
# tests/test_common.sh — basic tests for common.sh.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)

# shellcheck source=_assert.sh
. "$TESTS_DIR/_assert.sh"
# shellcheck source=../scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"

# tokens should split multiline text into one token per line
out=$(tokens "
foo
bar
  baz
")
expected="foo
bar
baz"
assert_eq "$expected" "$out" "tokens split multiline input"

# has_cmd: sh must exist
assert_true "has_cmd sh" "has_cmd sh"
assert_false "has_cmd this-command-should-not-exist-xyz" "has_cmd missing command"

# log_info and log_warn should not fail
assert_true "log_info hello" "log_info"
assert_true "log_warn hello" "log_warn"

assert_summary
