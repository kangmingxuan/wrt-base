#!/bin/sh
# tests/test_pkg.sh — pkg.sh 包管理器抽象层测试。

set -u
TESTS_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$TESTS_DIR/.." && pwd)

# shellcheck source=_assert.sh
. "$TESTS_DIR/_assert.sh"
# shellcheck source=../scripts/lib/common.sh
. "$REPO_DIR/scripts/lib/common.sh"
# shellcheck source=../scripts/lib/pkg.sh
. "$REPO_DIR/scripts/lib/pkg.sh"

# 强制指定 opkg
OWRT_PKG_MANAGER=opkg pkg_detect
assert_eq "opkg" "$PKG_MANAGER" "OWRT_PKG_MANAGER=opkg 强制生效"

# 强制指定 apk
OWRT_PKG_MANAGER=apk pkg_detect
assert_eq "apk" "$PKG_MANAGER" "OWRT_PKG_MANAGER=apk 强制生效"

# 自动检测：当前系统至少应有一个包管理器
unset OWRT_PKG_MANAGER
PKG_MANAGER=""
if pkg_detect; then
    assert_contains "opkg apk" "$PKG_MANAGER" "自动检测到 opkg 或 apk"
else
    printf '  skip 当前环境无 opkg 也无 apk\n'
fi

assert_summary
