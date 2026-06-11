#!/bin/sh
# tests/test_pkg.sh — tests for the pkg.sh package manager abstraction.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)

# shellcheck disable=SC1091
. "$TESTS_DIR/_assert.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/common.sh"
# shellcheck disable=SC1091
. "$REPO_DIR/scripts/lib/pkg.sh"

# force opkg
OWRT_PKG_MANAGER=opkg pkg_detect
assert_eq "opkg" "$PKG_MANAGER" "OWRT_PKG_MANAGER=opkg is honored"

# force apk
OWRT_PKG_MANAGER=apk pkg_detect
assert_eq "apk" "$PKG_MANAGER" "OWRT_PKG_MANAGER=apk is honored"

# auto-detection: the current system should expose at least one package manager
unset OWRT_PKG_MANAGER
PKG_MANAGER=""
if pkg_detect; then
    assert_contains "opkg apk" "$PKG_MANAGER" "auto-detect finds opkg or apk"
else
    printf '  skip neither opkg nor apk is available in this environment\n'
fi

# ---- apk availability detection against both `apk search` output shapes ----
# apk-tools 3.x prints "NAME-VERSION" (and bare names with --quiet); older
# variants print bare names and may reject --quiet entirely.

MOCK_DIR=$(mktemp -d 2>/dev/null || printf '/tmp/owrt-test-pkg.%s' "$$")
mkdir -p "$MOCK_DIR"
cat >"$MOCK_DIR/apk" <<'EOF'
#!/bin/sh
# Fake apk for tests, driven by:
#   MOCK_APK_STYLE      quiet3x | noquiet-bare | noquiet-versioned
#   MOCK_APK_AVAILABLE  space-separated names the feed "contains"
#   MOCK_APK_PRINT      print this name instead of the queried one
[ "$1" = "search" ] || exit 1
shift
quiet=false
name=""
for arg in "$@"; do
    case "$arg" in
        --quiet|-q) quiet=true ;;
        -*) ;;
        *) name=$arg ;;
    esac
done
case "$MOCK_APK_STYLE" in
    noquiet-*)
        if [ "$quiet" = "true" ]; then
            echo "apk: unrecognized option: quiet" >&2
            exit 1
        fi
        ;;
esac
case " $MOCK_APK_AVAILABLE " in
    *" $name "*) ;;
    *) exit 0 ;;
esac
name=${MOCK_APK_PRINT:-$name}
case "$MOCK_APK_STYLE" in
    quiet3x)
        if [ "$quiet" = "true" ]; then
            printf '%s\n' "$name"
        else
            printf '%s-5.3-r3\n' "$name"
        fi
        ;;
    noquiet-bare)      printf '%s\n' "$name" ;;
    noquiet-versioned) printf '%s-5.3-r3\n' "$name" ;;
esac
EOF
chmod +x "$MOCK_DIR/apk"

OLD_PATH=$PATH
PATH="$MOCK_DIR:$PATH"
export MOCK_APK_STYLE MOCK_APK_AVAILABLE
OWRT_PKG_MANAGER=apk pkg_detect

MOCK_APK_STYLE=quiet3x MOCK_APK_AVAILABLE="bash git"
assert_true "pkg_is_available bash" "apk-tools 3.x --quiet output is detected"
assert_false "pkg_is_available no-such-pkg" "apk-tools 3.x missing package is not detected"

MOCK_APK_STYLE=noquiet-bare
assert_true "pkg_is_available bash" "bare-name output without --quiet is detected"
assert_false "pkg_is_available no-such-pkg" "bare-name missing package is not detected"

MOCK_APK_STYLE=noquiet-versioned
assert_true "pkg_is_available bash" "NAME-VERSION output without --quiet is detected"
assert_false "pkg_is_available no-such-pkg" "NAME-VERSION missing package is not detected"

# Regex metacharacters in package names (e.g. a dot) must be matched
# literally: a lookalike name in the output is not a hit.
export MOCK_APK_PRINT
MOCK_APK_AVAILABLE="libpython3.12"
MOCK_APK_PRINT=""
MOCK_APK_STYLE=noquiet-versioned
assert_true "pkg_is_available libpython3.12" "dotted package name is detected"
MOCK_APK_PRINT="libpython3x12"
assert_false "pkg_is_available libpython3.12" "dot does not match a lookalike in versioned output"
MOCK_APK_STYLE=quiet3x
assert_false "pkg_is_available libpython3.12" "dot does not match a lookalike in --quiet output"
MOCK_APK_PRINT=""

PATH=$OLD_PATH
rm -rf "$MOCK_DIR"

assert_summary
