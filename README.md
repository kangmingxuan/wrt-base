# wrt-base

[Simplified Chinese](README.zh-CN.md)

wrt-base is a maintenance baseline for ImmortalWrt and OpenWrt routers. It turns one-off tasks such as installing tools, running checks, and preparing backups into repeatable, versioned scripts, so you have a stable operational starting point before deploying long-running services such as sing-box.

> This repository does not turn a router into a primary development machine, and it does not ship any workload-specific configuration such as sing-box subscriptions or rule sets. It only manages the system baseline.

## Features

- **Install the maintenance toolset with one command**: Automatically detects `opkg` or `apk` so you do not need per-firmware branches.
- **Health check script**: Checks time, disk, memory, load, outbound connectivity, DNS, and package manager availability in one pass, with cron-friendly output.
- **POSIX sh implementation**: Runs natively on BusyBox ash with no bash or make dependency.
- **Built-in tests**: `sh tests/run.sh` runs syntax checks, shellcheck when available, and unit tests.
- **Single-package failures do not abort the run**: If the network is unstable or a package is unavailable in the current feed, installation continues and summarizes warnings at the end.

## Quick Start

```sh
# 1. Clone the repository onto the router.
opkg update && opkg install git git-http ca-bundle
git clone <your remote URL> /root/wrt-base
cd /root/wrt-base

# 2. Preview the package list.
sh scripts/install-tools.sh --print-only

# 3. Install the toolset.
sh scripts/install-tools.sh

# 4. Run the health check.
sh scripts/health-check.sh
```

For a more detailed first-time setup flow, see [docs/setup.md](docs/setup.md).

## Repository Layout

```
scripts/
  install-tools.sh        # Tool installation with opkg/apk auto-detection
  health-check.sh         # Health checks for time, disk, memory, load, network, and DNS
  lib/                    # Shared shell library files sourced by scripts
tests/
  run.sh                  # Test entry point (sh -n + shellcheck + unit tests)
docs/
  setup.md                # First-time router setup
  sing-box.md             # Prerequisites for deploying sing-box
  layout.md               # Repository structure and design rules
Makefile                  # Run make help to see optional shortcuts
README.zh-CN.md           # Simplified Chinese README
```

See [docs/layout.md](docs/layout.md) for the full structure and design notes.

## Common Commands

All commands run directly with `sh` and do not depend on make. If your workstation has make installed, `make help` provides matching shortcuts.

| Command | Description |
| --- | --- |
| `sh tests/run.sh` | Run the full test suite (syntax, shellcheck, unit tests) |
| `sh scripts/install-tools.sh --print-only` | Print the packages that full mode would install |
| `sh scripts/install-tools.sh` | Install the full toolset (requires root) |
| `sh scripts/install-tools.sh --minimal` | Install the minimal toolset (requires root) |
| `sh scripts/health-check.sh` | Run the health check |

## Toolset Notes

| Set | Contents | Intended Use |
| --- | --- | --- |
| **base** (always installed) | bash, ca-bundle, curl, git, git-http, jq, less, nano, tmux | Required to maintain this repository and pull remote configuration |
| **minimal** (always installed) | bind-dig, ip-full, openssl-util, tcpdump or tcpdump-mini | Minimum set for network and TLS troubleshooting |
| **full** (added by default) | coreutils, diffutils, ethtool, findutils-\*, gawk, grep, htop, iperf3, iputils-\*, lsof, procps-ng-\*, rsync, sed, shellcheck, strace, tar, tree, unzip | Full maintenance experience |

`--minimal` skips the full set.

Packet capture is selected automatically based on free storage: if at least 16384 KB is available, the script installs the full `tcpdump`; otherwise it installs `tcpdump-mini`. You can override the decision with `OWRT_TCPDUMP_VARIANT=full|mini|auto`, and `OWRT_STORAGE_FREE_KB` is available for testing that logic.

## Health Check Thresholds

```sh
sh scripts/health-check.sh \
  --disk 85 \
  --mem 90 \
  --load 2 \
  --skip-net \
  --quiet
```

- `--disk 85`: warn when disk usage is 85% or higher.
- `--mem 90`: warn when memory usage is 90% or higher.
- `--load 2`: warn when 1-minute load divided by CPU count exceeds 2.
- `--skip-net`: skip HTTPS outbound and DNS checks.
- `--quiet`: print only abnormal items, which is useful for cron.

Exit status: `0` means every check passed; `1` means at least one check failed.

## Before Deploying sing-box

See [docs/sing-box.md](docs/sing-box.md). In short: run `sh scripts/install-tools.sh` to install the toolset, run `sh scripts/health-check.sh` to verify the baseline, and keep workload repositories such as sing-box configuration separate from this one.

## Run Tests Before Submitting Changes

```sh
sh tests/run.sh
```

Do not submit changes with failing tests. `tests/run.sh` auto-discovers `tests/test_*.sh`, so add a matching test whenever you add a new script. See [docs/layout.md](docs/layout.md) for the project conventions.

## License

[MIT](LICENSE)
