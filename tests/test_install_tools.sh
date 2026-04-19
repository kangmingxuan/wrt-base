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

# 存储空间足够时应选择完整版 tcpdump
out_full_storage=$(OWRT_STORAGE_FREE_KB=20000 sh "$SCRIPT" --minimal --print-only)
assert_contains "$out_full_storage" "tcpdump" "可用空间足够时选择 tcpdump"
case "$out_full_storage" in
    *tcpdump-mini*) ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL 空间足够时不应选择 tcpdump-mini\n' >&2 ;;
    *)              printf '  ok   空间足够时不含 tcpdump-mini\n' ;;
esac

# 存储空间不足时应选择 mini
out_mini_storage=$(OWRT_STORAGE_FREE_KB=8000 sh "$SCRIPT" --minimal --print-only)
assert_contains "$out_mini_storage" "tcpdump-mini" "可用空间不足时选择 tcpdump-mini"

# 环境变量可以强制覆盖自动决策
forced_mini=$(OWRT_TCPDUMP_VARIANT=mini OWRT_STORAGE_FREE_KB=20000 sh "$SCRIPT" --minimal --print-only)
assert_contains "$forced_mini" "tcpdump-mini" "环境变量可强制选择 tcpdump-mini"

forced_full=$(OWRT_TCPDUMP_VARIANT=full OWRT_STORAGE_FREE_KB=1 sh "$SCRIPT" --minimal --print-only)
assert_contains "$forced_full" "tcpdump" "环境变量可强制选择 tcpdump"

# full 应包含 htop
out_full=$(sh "$SCRIPT" --full --print-only)
assert_contains "$out_full" "htop" "full 包含 htop"

# 当前环境若已装 tcpdump，强制选择 mini 时应跳过冲突包
if opkg list-installed tcpdump >/dev/null 2>&1; then
    dry_run=$(OWRT_TCPDUMP_VARIANT=mini sh "$SCRIPT" --dry-run --skip-update 2>&1)
    assert_contains "$dry_run" "已安装完整版 tcpdump，跳过冲突包: tcpdump-mini" \
        "强制 mini 时跳过与 tcpdump 冲突的 tcpdump-mini"
fi

# 未知选项应退非 0
assert_false "sh \"$SCRIPT\" --bogus" "未知选项失败退出"

assert_summary
