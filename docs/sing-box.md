# Prerequisites for Deploying sing-box

This repository does not ship the sing-box binary or its configuration. It only prepares the router to serve as a reliable system baseline for long-running services.

## Minimum Checklist

Before deploying sing-box, verify at least the following items:

| Item | How to Verify | Risk |
| --- | --- | --- |
| Correct system time | `date` shows the current year | TLS and Reality handshakes fail |
| CA bundle available | `ca-bundle` is installed | Remote configuration or rule-set fetches fail |
| DNS works | `nslookup openwrt.org` | Domain-based rules and remote fetches fail |
| Enough disk space | `df -h /` still shows free headroom | Logs, caches, and temp files fill the root filesystem |
| Enough memory headroom | `free -m` or `free` | High concurrency can trigger OOM kills |

Most of these checks are already covered by `sh scripts/health-check.sh`; tool dependencies are handled by `sh scripts/install-tools.sh`.

## Boundary Between This Repository and sing-box

- This repository owns system-level maintenance scripts, health checks, and baseline tools.
- sing-box configuration, subscriptions, rule sets, and routing policy should be maintained separately.
- During firmware upgrades, back up this repository path and the sing-box configuration path independently through `sysupgrade`.
