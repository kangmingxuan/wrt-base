# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- apk package availability detection now handles apk-tools 3.x, whose
  `apk search --exact` prints `NAME-VERSION` instead of the bare name. The
  check prefers `--quiet` output and falls back to matching both shapes, so
  `install-tools.sh` no longer reports every package as unavailable on newer
  OpenWrt snapshots.
- `health-check.sh` no longer fails on the read-only `/rom` squashfs mount,
  which is always 100% used on OpenWrt. The disk check now covers `/` and
  `/overlay` by default, and a new `--check-rom` option restores the old
  behavior.

### Added

- README guidance for slow snapshot package feeds (notably from mainland
  China), a recommended `--minimal` plus config-file extras bring-up flow for
  small routers, and a note to clone directly on the router because copying a
  checkout from macOS can introduce AppleDouble `._*` files that corrupt the
  Git pack index.
- Quick Start now shows the `apk add` bootstrap variant for apk-based
  OpenWrt snapshots alongside the `opkg` commands.

## [0.2.0] - 2026-06-01

### Added

- Configuration backup script (`scripts/backup-config.sh`) that bundles the
  `sysupgrade` backup with the explicitly installed package list, feed
  configuration, root crontab, and a device manifest into a single timestamped
  archive, with `--output-dir`, `--keep`, and `--dry-run` options.
- Baseline report script (`scripts/baseline-report.sh`) that prints a
  descriptive device snapshot (firmware, kernel, resources, network, package
  counts) as text or JSON, with `--json` and `--output` options.
- `health-check.sh` now checks NTP client status and outbound IPv6
  connectivity, and can emit machine-readable results with `--json`.
- `install-tools.sh` can load extra packages from a config file
  (`/etc/wrt-base/install-tools.conf`, `--config FILE`, or
  `OWRT_INSTALL_CONFIG`), with `--no-config` to ignore the default.

### Changed

- `baseline-report.sh` now reports a globally routable IPv6 address (2000::/3)
  for the egress IPv6 field, falling back to a global address on the egress
  interface when the kernel returns a ULA source, instead of showing a
  non-routable ULA.
- Option parsing in `health-check.sh` and `install-tools.sh` now rejects a
  missing value or an option-like operand instead of silently consuming the
  next argument.

## [0.1.0] - 2026-05-31

### Added

- Initial public release of the wrt-base maintenance baseline.
- Package installation script with automatic `opkg`/`apk` detection.
- Health check script for time, disk, memory, load, network, DNS, and package
  manager availability.
- POSIX shell test suite and GitHub Actions CI.
- English and Simplified Chinese documentation.

[Unreleased]: https://github.com/kangmingxuan/wrt-base/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/kangmingxuan/wrt-base/releases/tag/v0.2.0
[0.1.0]: https://github.com/kangmingxuan/wrt-base/releases/tag/v0.1.0
