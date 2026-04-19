#!/bin/sh
# tests/_assert.sh — minimal assertion helpers used by test_*.sh files.
# shellcheck shell=sh

if [ -n "${__OWRT_ASSERT_LOADED:-}" ]; then
    # shellcheck disable=SC2317
    return 0 2>/dev/null || exit 0
fi
__OWRT_ASSERT_LOADED=1

ASSERT_FAILS=0

assert_eq() {
    # assert_eq EXPECTED ACTUAL [MSG]
    expected=$1; actual=$2; msg=${3:-}
    if [ "$expected" = "$actual" ]; then
        printf '  ok   %s\n' "${msg:-eq}"
    else
        ASSERT_FAILS=$((ASSERT_FAILS + 1))
        printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' \
            "${msg:-eq}" "$expected" "$actual" >&2
    fi
}

assert_contains() {
    # assert_contains HAYSTACK NEEDLE [MSG]
    haystack=$1; needle=$2; msg=${3:-}
    case "$haystack" in
        *"$needle"*)
            printf '  ok   %s\n' "${msg:-contains}"
            ;;
        *)
            ASSERT_FAILS=$((ASSERT_FAILS + 1))
            printf '  FAIL %s\n       needle:   %s\n       haystack: %s\n' \
                "${msg:-contains}" "$needle" "$haystack" >&2
            ;;
    esac
}

assert_true() {
    # assert_true CMD [MSG] — CMD is executed via eval
    cmd=$1; msg=${2:-$1}
    if eval "$cmd" >/dev/null 2>&1; then
        printf '  ok   %s\n' "$msg"
    else
        ASSERT_FAILS=$((ASSERT_FAILS + 1))
        printf '  FAIL %s\n' "$msg" >&2
    fi
}

assert_false() {
    cmd=$1; msg=${2:-! $1}
    if eval "$cmd" >/dev/null 2>&1; then
        ASSERT_FAILS=$((ASSERT_FAILS + 1))
        printf '  FAIL %s\n' "$msg" >&2
    else
        printf '  ok   %s\n' "$msg"
    fi
}

assert_summary() {
    if [ "$ASSERT_FAILS" -gt 0 ]; then
        printf '  %s assertions failed\n' "$ASSERT_FAILS" >&2
        exit 1
    fi
}
