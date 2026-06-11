# wrt-base

[![CI](https://github.com/kangmingxuan/wrt-base/actions/workflows/ci.yml/badge.svg)](https://github.com/kangmingxuan/wrt-base/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[Simplified Chinese](README.zh-CN.md)

wrt-base is a maintenance baseline for ImmortalWrt and OpenWrt routers. It turns one-off tasks such as installing tools, running checks, and preparing backups into repeatable, versioned scripts, so you have a stable operational starting point for the system itself.

> This repository does not turn a router into a primary development machine. It only manages the system baseline.

## Features

- **Install the maintenance toolset with one command**: Automatically detects `opkg` or `apk` so you do not need per-firmware branches.
- **Health check script**: Checks time, NTP, disk, memory, load, outbound IPv4/IPv6 connectivity, DNS, and package manager availability in one pass, with cron-friendly text or `--json` output.
- **Baseline report script**: Prints a descriptive snapshot of firmware, kernel, resources, network, and package counts as text or JSON, so you can capture the device state before and after maintenance.
- **Configuration backup script**: Bundles the `sysupgrade` backup with the installed package list, feed configuration, crontab, and a device manifest into a single timestamped archive.
- **Customizable install set**: Add site-specific packages through a config file (`/etc/wrt-base/install-tools.conf` or `--config FILE`) without editing the script.
- **POSIX sh implementation**: Runs natively on BusyBox ash with no bash or make dependency.
- **Built-in tests**: `sh tests/run.sh` runs syntax checks, shellcheck when available, and unit tests.
- **VS Code Remote-SSH baseline**: Includes the OpenSSH client/server, SFTP server, tar, gzip, and related runtime packages needed for the VS Code Remote-SSH extension to install its server on OpenWrt.
- **Single-package failures do not abort the run**: If the network is unstable or a package is unavailable in the current feed, installation continues and summarizes warnings at the end.

## Quick Start

```sh
# 1. Clone the repository onto the router.
#    On opkg firmware (OpenWrt 23.05 / ImmortalWrt 24.10):
opkg update && opkg install git git-http ca-bundle
#    On apk firmware (newer OpenWrt snapshots):
apk update && apk add git git-http ca-bundle
git clone https://github.com/kangmingxuan/wrt-base.git /root/wrt-base
cd /root/wrt-base

# 2. Preview the package list.
sh scripts/install-tools.sh --print-only

# 3. Install the toolset.
sh scripts/install-tools.sh

# 4. Run the health check.
sh scripts/health-check.sh
```

> Clone directly on the router rather than copying a checkout from another
> machine. Copying from macOS in particular (tar, scp, finder copies) can
> introduce AppleDouble `._*` metadata files that corrupt the Git pack index
> on the device.

## Repository Layout

```
scripts/
  install-tools.sh        # Tool installation with opkg/apk auto-detection
  health-check.sh         # Health checks for time, NTP, disk, memory, load, network, DNS
  baseline-report.sh      # Descriptive device snapshot as text or JSON
  backup-config.sh        # Configuration backup (sysupgrade + extras) into a tar.gz
  lib/                    # Shared shell library files sourced by scripts
tests/
  run.sh                  # Test entry point (sh -n + shellcheck + unit tests)
Makefile                  # Run make help to see optional shortcuts
README.zh-CN.md           # Simplified Chinese README
```

## Common Commands

All commands run directly with `sh` and do not depend on make. If your workstation has make installed, `make help` provides matching shortcuts.

| Command | Description |
| --- | --- |
| `sh tests/run.sh` | Run the full test suite (syntax, shellcheck, unit tests) |
| `sh scripts/install-tools.sh --print-only` | Print the packages that full mode would install |
| `sh scripts/install-tools.sh` | Install the full toolset (requires root) |
| `sh scripts/install-tools.sh --minimal` | Install the minimal toolset (requires root) |
| `sh scripts/health-check.sh` | Run the health check |
| `sh scripts/health-check.sh --json` | Run the health check and print JSON results |
| `sh scripts/baseline-report.sh` | Print a baseline snapshot report |
| `sh scripts/backup-config.sh` | Create a configuration backup archive (requires root) |

## Toolset Notes

| Set | Contents | Intended Use |
| --- | --- | --- |
| **base** (always installed) | bash, ca-bundle, curl, git, git-http, jq, less, nano, tmux | Required to maintain this repository and pull remote configuration |
| **minimal** (always installed) | bind-dig, ip-full, openssl-util, tcpdump or tcpdump-mini | Minimum set for network and TLS troubleshooting |
| **full** (added by default) | coreutils, coreutils-install, diffutils, ethtool, `findutils-*`, gawk, grep, gzip, htop, iperf3, `iputils-*`, libstdcpp6, lsof, openssh-client, openssh-server, openssh-sftp-server, `procps-ng-*`, python3-light, ripgrep, rsync, sed, strace, tar, tree, unzip | Full maintenance experience, including a better baseline for VS Code Remote-SSH and code-server workflows |

`--minimal` skips the full set.

To install extra site-specific packages without editing the script, list them (one package per line, `#` starts a comment) in `/etc/wrt-base/install-tools.conf`, or point `--config FILE` at another file. The default path can be overridden with `OWRT_INSTALL_CONFIG`, and `--no-config` ignores the default file. Extra packages are added on top of the selected mode.

`install` is added via `coreutils-install`. OpenWrt and ImmortalWrt package feeds ship GNU `install` as a split package instead of guaranteeing it through the `coreutils` meta-package, so the repository now installs it explicitly.

### Recommended Bring-Up for Small Routers

For the first installation on a small router, prefer `--minimal` and add only the extras you actually need through the config file, instead of starting with the full set:

```sh
mkdir -p /etc/wrt-base
cat > /etc/wrt-base/install-tools.conf <<'EOF'
coreutils-nohup
lsof
ss
EOF
sh scripts/install-tools.sh --minimal
```

This keeps `openssh-server` and Python off the device, which matters when Dropbear is already configured as the only management entry point. You can re-run the script with `--full` later once the baseline is stable.

### Slow Package Feeds

Snapshot firmware installs packages from the official OpenWrt snapshot feed, which can be very slow from some regions (notably mainland China, where double-digit KB/s rates and timeouts on multi-MB packages are common). Keep in mind:

- An apparently stalled install is usually still downloading. Re-running `sh scripts/install-tools.sh --skip-update` is safe: already-installed packages are skipped and only the failed ones are retried.
- If you build a custom snapshot image, bake the common packages into the image instead of installing them on the device afterwards.
- Prefer a trusted local proxy or a router-level proxy path over arbitrary third-party snapshot mirrors: snapshot feeds move fast, and a stale mirror can break kernel module (`kmod-*`) installation due to kernel ABI drift.

## Space Usage

On the current x86_64 feed, `--minimal` installs about 10.8 MiB and `--full` installs about 18.8 MiB, including the auto-selected `tcpdump` package and excluding filesystem/overlay overhead. Actual usage varies by target, feed, and package availability.

Packet capture is selected automatically based on free storage: if at least 16384 KB is available, the script installs the full `tcpdump`; otherwise it installs `tcpdump-mini`. You can override the decision with `OWRT_TCPDUMP_VARIANT=full|mini|auto`, and `OWRT_STORAGE_FREE_KB` is available for testing that logic.

## Health Check Thresholds

```sh
sh scripts/health-check.sh \
  --disk 85 \
  --mem 90 \
  --load 2 \
  --skip-time \
  --skip-net \
  --quiet
```

- `--disk 85`: warn when disk usage is 85% or higher.
- `--mem 90`: warn when memory usage is 90% or higher.
- `--load 2`: warn when 1-minute load divided by CPU count exceeds 2.
- `--skip-time`: skip the system time and NTP checks, which is useful before NTP sync or in CI.
- `--skip-net`: skip HTTPS outbound, DNS, and IPv6 checks.
- `--quiet`: print only abnormal items, which is useful for cron.
- `--json`: print results as a JSON document on stdout, which is convenient for monitoring.
- `--check-rom`: apply the disk threshold to `/rom` as well.

The disk check covers `/` and `/overlay`. The read-only `/rom` squashfs image always reports 100% used on OpenWrt, so it is excluded by default; pass `--check-rom` if you really want it checked.

The NTP check uses procd (`/etc/init.d/sysntpd status`) when available. The IPv6 check only tests outbound connectivity when the device has a global IPv6 address; devices without IPv6 are reported as a pass.

Exit status: `0` means every check passed; `1` means at least one check failed.

## Baseline Report

```sh
sh scripts/baseline-report.sh            # human-readable text
sh scripts/baseline-report.sh --json     # flat JSON object
sh scripts/baseline-report.sh --output /root/baseline.txt
```

The report summarizes firmware, kernel, architecture, uptime, CPU/memory/disk/load, egress IPv4/IPv6 addresses, and installed package counts. Capture it before a maintenance window and again afterwards to see what changed.

## Configuration Backup

```sh
sh scripts/backup-config.sh \
  --output-dir /root/backups \
  --keep 5
```

- `--output-dir DIR`: where to write the archive (default: `/root/backups`).
- `--keep N`: keep only the `N` most recent backups in the output directory (`0` keeps all).
- `--dry-run`: stage and list the files without writing the final archive.

Each run produces a timestamped `wrt-backup-<host>-<timestamp>.tar.gz` containing the standard `sysupgrade` backup plus the installed package list, feed configuration, root crontab, and a device manifest. Copy the archive off the device before any risky maintenance operation.

## Run Tests Before Submitting Changes

```sh
sh tests/run.sh
```

Do not submit changes with failing tests. `tests/run.sh` auto-discovers `tests/test_*.sh`, so add a matching test whenever you add a new script.

## License

[MIT](LICENSE)
