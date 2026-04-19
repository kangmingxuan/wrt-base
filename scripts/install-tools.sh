#!/bin/sh
# install-tools.sh — 为 ImmortalWrt / OpenWrt 安装常用维护工具。
#
# 默认安装 "full" 工具集，提供完整运维体验。
# 用 --minimal 切换到精简集合。
# 单包失败不会终止整体安装，最后会汇总告警。

set -u

SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$SELF")" && pwd)
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/pkg.sh
. "$SCRIPT_DIR/lib/pkg.sh"

MODE="full"
PRINT_ONLY="false"
SKIP_UPDATE="false"
DRY_RUN="false"
FAILED_PACKAGES=""

# ---- 包集合定义 ------------------------------------------------------------

# 基础维护：所有模式都装。
BASE_PACKAGES="
bash
ca-bundle
curl
git
git-http
jq
less
nano
tmux
"

# 网络与系统排障最小集合：minimal 与 full 都装。
MINIMAL_PACKAGES="
bind-dig
ip-full
openssl-util
tcpdump-mini
"

# 完整运维集合：仅 full 模式安装。
FULL_PACKAGES="
coreutils
diffutils
ethtool
findutils-find
findutils-xargs
gawk
grep
htop
iperf3
iputils-ping
iputils-tracepath
lsof
procps-ng-pkill
procps-ng-ps
procps-ng-top
rsync
sed
shellcheck
strace
tar
tree
unzip
"

# ---- CLI ------------------------------------------------------------------

usage() {
    cat <<'EOF'
用法: install-tools.sh [选项]

为 ImmortalWrt / OpenWrt 安装常用维护工具，自动检测 opkg 或 apk。

选项:
  --minimal       只安装基础 + 排障最小集合
  --full          安装完整集合（默认）
  --print-only    只打印待安装列表，不执行安装
  --dry-run       检测包管理器并打印将执行的动作，不真正安装
  --skip-update   跳过软件源 update
  -h, --help      显示帮助

环境变量:
  OWRT_PKG_MANAGER  强制指定 opkg 或 apk（用于测试）
  OWRT_DEBUG=1      打印调试日志
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --minimal) MODE="minimal" ;;
            --full)    MODE="full" ;;
            --print-only) PRINT_ONLY="true" ;;
            --dry-run) DRY_RUN="true" ;;
            --skip-update) SKIP_UPDATE="true" ;;
            -h|--help) usage; exit 0 ;;
            *) die "未知选项: $1（用 --help 查看用法）" ;;
        esac
        shift
    done
}

# ---- 核心逻辑 -------------------------------------------------------------

selected_packages() {
    tokens "$BASE_PACKAGES"
    tokens "$MINIMAL_PACKAGES"
    if [ "$MODE" = "full" ]; then
        tokens "$FULL_PACKAGES"
    fi
}

# 注意：管道右侧在 POSIX sh 里运行在子 shell，
# 所以失败列表先写入临时文件，主 shell 再读回 FAILED_PACKAGES。
install_all_collect() {
    tmp=$(mktemp 2>/dev/null || printf '/tmp/owrt-install.%s' "$$")
    : > "$tmp"
    selected_packages | while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        if pkg_is_installed "$pkg"; then
            log_info "已安装，跳过: $pkg"
            continue
        fi
        if [ "$DRY_RUN" = "true" ]; then
            log_info "[dry-run] 将安装: $pkg"
            continue
        fi
        if pkg_install "$pkg" >/dev/null 2>&1; then
            log_info "安装完成: $pkg"
        else
            printf '%s\n' "$pkg" >>"$tmp"
            log_warn "安装失败，已跳过: $pkg"
        fi
    done
    FAILED_PACKAGES=$(tr '\n' ' ' <"$tmp" | sed 's/ $//')
    rm -f "$tmp"
}

main() {
    parse_args "$@"

    if [ "$PRINT_ONLY" = "true" ]; then
        selected_packages
        exit 0
    fi

    pkg_detect || die "未检测到 opkg 或 apk，当前系统不像 OpenWrt / ImmortalWrt"
    log_info "包管理器: $PKG_MANAGER"
    log_info "安装模式: $MODE"

    if [ "$DRY_RUN" != "true" ]; then
        require_root
    fi

    if [ "$SKIP_UPDATE" != "true" ] && [ "$DRY_RUN" != "true" ]; then
        pkg_update || die "$PKG_MANAGER update 失败，检查软件源后重试"
    fi

    install_all_collect

    if [ -n "$FAILED_PACKAGES" ]; then
        log_warn "下列包未能安装，请按当前固件软件源情况手动确认: $FAILED_PACKAGES"
        exit 0
    fi

    log_info "工具安装完成"
}

main "$@"
