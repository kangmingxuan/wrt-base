#!/bin/sh
# tests/test_common.sh — common.sh 的基本测试。

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)

# shellcheck source=_assert.sh
. "$TESTS_DIR/_assert.sh"
# shellcheck source=../scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"

# tokens 应该把多行字符串变成逐行 token 输出
out=$(tokens "
foo
bar
  baz
")
expected="foo
bar
baz"
assert_eq "$expected" "$out" "tokens 拆分多行"

# has_cmd: sh 一定有
assert_true "has_cmd sh" "has_cmd sh"
assert_false "has_cmd this-command-should-not-exist-xyz" "has_cmd 不存在的命令"

# log_info / log_warn 不应让脚本失败
assert_true "log_info hello" "log_info"
assert_true "log_warn hello" "log_warn"

assert_summary
