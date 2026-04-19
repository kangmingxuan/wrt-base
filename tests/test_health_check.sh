#!/bin/sh
# tests/test_health_check.sh — health-check.sh 烟雾测试。
# 真实环境跑可能因网络/磁盘/时间不达标而退非 0；
# 我们只检查 --help 和无害选项。

set -u
TESTS_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/health-check.sh"

# shellcheck source=_assert.sh
. "$TESTS_DIR/_assert.sh"

assert_true "sh \"$SCRIPT\" --help" "--help 正常"

# 把阈值放宽，跳过网络，应当通过
assert_true "sh \"$SCRIPT\" --skip-net --disk 100 --mem 100 --load 1000 --quiet" \
    "宽阈值 + skip-net 应该通过"

assert_summary
