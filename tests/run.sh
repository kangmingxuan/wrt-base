#!/bin/sh
# tests/run.sh — 跑仓库内全部测试。
#
# 步骤:
#   1. POSIX `sh -n` 语法校验所有 .sh 文件
#   2. 如果装了 shellcheck，执行静态检查
#   3. 跑 tests/test_*.sh 下的所有用例
#
# 退出码: 0 全通过，非 0 表示有失败。

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
TESTS_DIR=$(CDPATH= cd -- "$(dirname "$SELF")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$TESTS_DIR/.." && pwd)
export REPO_DIR TESTS_DIR

# shellcheck source=../scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"

PASS=0
FAIL=0
FAILED_NAMES=""

record_fail() {
    FAIL=$((FAIL + 1))
    FAILED_NAMES="$FAILED_NAMES\n  - $1"
}

# ---- 1. 语法 -------------------------------------------------------------

log_info "== 阶段 1: sh -n 语法校验 =="
SH_FILES=$(find "$REPO_DIR/scripts" "$REPO_DIR/tests" -type f -name '*.sh')
for f in $SH_FILES; do
    if sh -n "$f" 2>/dev/null; then
        PASS=$((PASS + 1))
        log_debug "syntax OK: $f"
    else
        record_fail "syntax: $f"
        log_warn "语法错误: $f"
        sh -n "$f" || true
    fi
done

# ---- 2. shellcheck（可选）-----------------------------------------------

log_info "== 阶段 2: shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
    for f in $SH_FILES; do
        if shellcheck -x "$f"; then
            PASS=$((PASS + 1))
            log_debug "shellcheck OK: $f"
        else
            record_fail "shellcheck: $f"
        fi
    done
else
    log_info "未安装 shellcheck，跳过静态检查"
fi

# ---- 3. 单元测试 ---------------------------------------------------------

log_info "== 阶段 3: 单元测试 =="
TEST_FILES=$(find "$TESTS_DIR" -type f -name 'test_*.sh' | sort)
if [ -z "$TEST_FILES" ]; then
    log_warn "未发现测试用例"
else
    for t in $TEST_FILES; do
        name=$(basename "$t")
        log_info "→ $name"
        if sh "$t"; then
            PASS=$((PASS + 1))
            log_info "  PASS $name"
        else
            record_fail "$name"
            log_warn "  FAIL $name"
        fi
    done
fi

# ---- 汇总 ---------------------------------------------------------------

printf '\n'
log_info "通过: $PASS  失败: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    # shellcheck disable=SC2059
    printf "失败列表:$FAILED_NAMES\n" >&2
    exit 1
fi
exit 0
