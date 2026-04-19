#!/bin/sh
# tests/run.sh — run every test in the repository.
#
# Steps:
#   1. Validate POSIX shell syntax with `sh -n`
#   2. Run shellcheck when it is available
#   3. Execute every file that matches tests/test_*.sh
#
# Exit status: 0 means success, non-zero means at least one failure.

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
export REPO_DIR TESTS_DIR

# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/common.sh"

PASS=0
FAIL=0
FAILED_NAMES=""

record_fail() {
    FAIL=$((FAIL + 1))
    FAILED_NAMES="$FAILED_NAMES\n  - $1"
}

# ---- 1. Syntax ------------------------------------------------------------

log_info "== Phase 1: sh -n syntax check =="
SH_FILES=$(find "$REPO_DIR/scripts" "$REPO_DIR/tests" -type f -name '*.sh')
for f in $SH_FILES; do
    if sh -n "$f" 2>/dev/null; then
        PASS=$((PASS + 1))
        log_debug "syntax OK: $f"
    else
        record_fail "syntax: $f"
        log_warn "syntax error: $f"
        sh -n "$f" || true
    fi
done

# ---- 2. shellcheck (optional) --------------------------------------------

log_info "== Phase 2: shellcheck =="
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
    log_info "shellcheck is not installed; skipping static analysis"
fi

# ---- 3. Unit tests --------------------------------------------------------

log_info "== Phase 3: unit tests =="
TEST_FILES=$(find "$TESTS_DIR" -type f -name 'test_*.sh' | sort)
if [ -z "$TEST_FILES" ]; then
    log_warn "no test cases found"
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

# ---- Summary --------------------------------------------------------------

printf '\n'
log_info "passed: $PASS  failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    # shellcheck disable=SC2059
    printf "failed cases:$FAILED_NAMES\n" >&2
    exit 1
fi
exit 0
