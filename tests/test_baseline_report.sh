#!/bin/sh
# tests/test_baseline_report.sh — smoke tests for baseline-report.sh.

set -u
TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SCRIPT="$REPO_DIR/scripts/baseline-report.sh"

# shellcheck disable=SC1091
. "$TESTS_DIR/_assert.sh"

assert_true "sh \"$SCRIPT\" --help" "--help succeeds"

# Text report should render a title and known fields. Force a supported package
# backend so the report works on CI hosts without opkg/apk.
out=$(OWRT_PKG_MANAGER=opkg sh "$SCRIPT")
assert_contains "$out" "baseline report" "text report has a title"
assert_contains "$out" "Architecture" "text report includes architecture"

# JSON report should be a flat object with known keys.
json=$(OWRT_PKG_MANAGER=opkg sh "$SCRIPT" --json)
assert_contains "$json" "\"arch\":" "json report includes arch key"
assert_contains "$json" "\"kernel\":" "json report includes kernel key"
case "$json" in
    \{*) printf '  ok   json starts with a brace\n' ;;
    *)   ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL json should start with a brace\n' >&2 ;;
esac

# --output writes the report to a file.
tmp=$(mktemp 2>/dev/null || printf '/tmp/wrt-baseline-test.%s' "$$")
assert_true "OWRT_PKG_MANAGER=opkg sh \"$SCRIPT\" --output \"$tmp\"" "--output succeeds"
assert_contains "$(cat "$tmp")" "Architecture" "output file contains the report"
rm -f "$tmp"

# missing value and unknown option are rejected.
assert_false "sh \"$SCRIPT\" --output" "--output without a value is rejected"
assert_false "sh \"$SCRIPT\" --bogus" "unknown option exits non-zero"

# Egress IPv6 selection: stub `ip` via OWRT_IP_BIN (an absolute path, which
# busybox execs directly instead of running its built-in applet) so the test is
# independent of the host network. The route egresses with a ULA source on a
# dev that also carries a GUA, so the report should prefer the GUA on that dev.
ip_stub_dir=$(mktemp -d 2>/dev/null || printf '/tmp/wrt-ipstub.%s' "$$")
mkdir -p "$ip_stub_dir"
cat >"$ip_stub_dir/ip" <<'STUB'
#!/bin/sh
case "$*" in
    "-6 route get"*)
        echo "2606:4700:4700::1111 from :: via fe80::1 dev wan6 src fdfe:dcba:9876::1 metric 1024 pref medium" ;;
    "-6 addr show dev wan6 scope global")
        echo "    inet6 2001:db8:abcd:1::2/64 scope global dynamic" ;;
    "-6 addr show scope global")
        echo "    inet6 2001:db8:abcd:1::2/64 scope global dynamic" ;;
    "-4 route get"*)
        echo "1.1.1.1 dev wan src 192.0.2.10 uid 0" ;;
esac
STUB
chmod +x "$ip_stub_dir/ip"
out6=$(OWRT_IP_BIN="$ip_stub_dir/ip" OWRT_PKG_MANAGER=opkg sh "$SCRIPT")
assert_contains "$out6" "2001:db8:abcd:1::2" "egress IPv6 prefers a GUA on the route's dev"

# When the route probe yields no source there is no usable IPv6 egress route,
# so the report must not borrow an address from an unrelated interface.
cat >"$ip_stub_dir/ip" <<'STUB'
#!/bin/sh
case "$*" in
    "-4 route get"*) echo "1.1.1.1 dev wan src 192.0.2.10 uid 0" ;;
esac
STUB
chmod +x "$ip_stub_dir/ip"
out_none=$(OWRT_IP_BIN="$ip_stub_dir/ip" OWRT_PKG_MANAGER=opkg sh "$SCRIPT")
case "$out_none" in
    *"Egress IPv6"*none*) printf '  ok   no IPv6 route reports egress IPv6 as none\n' ;;
    *) ASSERT_FAILS=$((ASSERT_FAILS + 1)); printf '  FAIL no IPv6 route should report egress IPv6 as none\n' >&2 ;;
esac
rm -rf "$ip_stub_dir"

assert_summary
