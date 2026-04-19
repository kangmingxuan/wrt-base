# Initial Setup Guide

This document keeps only the minimum flow for getting wrt-base onto a fresh router. Broader system bootstrap work, cron design, and sing-box runtime details are intentionally left out.

## 1. Clone the Repository

First make sure `git` and `ca-bundle` are available:

```sh
opkg update && opkg install git git-http ca-bundle
# Use apk on 24.10+ snapshots:
# apk update && apk add git git-http ca-bundle
```

Then clone the repository:

```sh
cd /root
git clone <your remote URL> wrt-base
cd wrt-base
```

## 2. Preview and Install the Toolset

Inspect the package list first, then simulate the run:

```sh
sh scripts/install-tools.sh --print-only
sh scripts/install-tools.sh --dry-run
```

Install after you confirm the plan:

```sh
sh scripts/install-tools.sh
# Use this when resources are tight:
sh scripts/install-tools.sh --minimal
```

The script keeps going for packages that can still be installed and summarizes failures at the end.

## 3. Run the Health Check

```sh
sh scripts/health-check.sh
```

A non-zero exit status means at least one baseline check failed.

## 4. Make It Persistent

Add the repository directory to `/etc/sysupgrade.conf` so firmware upgrades do not wipe the maintenance scripts:

```sh
echo '/root/wrt-base' >>/etc/sysupgrade.conf
```

If you also need to preserve sing-box configuration or SSH keys, add those paths separately.
