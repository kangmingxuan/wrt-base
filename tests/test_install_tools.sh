#!/bin/sh
# tests/test_install_tools.sh — install-tools.sh 的烟雾测试。

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/install-tools.sh"

# shellcheck source=_assert.sh
. "$TESTS_DIR/_assert.sh"

# --help 退 0
assert_true "sh \"$SCRIPT\" --help" "--help 正常"

# --print-only 应输出基础包列表
out=$(sh "$SCRIPT" --print-only)
assert_contains "$out" "curl"  "--print-only 包含 curl"
assert_contains "$out" "git"   "--print-only 包含 git"
assert_contains "$out" "tmux"  "--print-only 包含 tmux"

# minimal 不应包含 full 集合
out_min=$(sh "$SCRIPT" --minimal --print-only)
case "$out_min" in
    *htop*) ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL minimal 不应包含 htop\n' >&2 ;;
    *)      printf '  ok   minimal 不含 htop\n' ;;
esac
assert_contains "$out_min" "curl" "minimal 仍含 curl"

# full 应包含 htop
out_full=$(sh "$SCRIPT" --full --print-only)
assert_contains "$out_full" "htop" "full 包含 htop"

# 未知选项应退非 0
assert_false "sh \"$SCRIPT\" --bogus" "未知选项失败退出"

assert_summary
