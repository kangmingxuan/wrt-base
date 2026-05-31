# Security Policy

## Supported Versions

wrt-base follows [Semantic Versioning](https://semver.org/). Security fixes are
applied to the latest tagged release and the `main` branch. Older tags are not
patched; please upgrade to the latest release.

| Version | Supported |
| --- | --- |
| `main` (latest) | :white_check_mark: |
| Latest tagged release | :white_check_mark: |
| Older releases | :x: |

## Reporting a Vulnerability

Please **do not** open a public issue for security problems.

Report privately through GitHub Security Advisories:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability** (Private Vulnerability Reporting).

Include as much detail as possible:

- Affected script(s) and version or commit hash.
- A description of the impact and how to reproduce it.
- The OpenWrt/ImmortalWrt version and package manager (`opkg` or `apk`).

You can expect an initial acknowledgement within 7 days. We will keep you
informed about the progress toward a fix and may ask for additional details.

## Scope and Trust Model

These scripts install packages from the package feeds configured on the device
(`/etc/opkg.conf` or the apk repositories). wrt-base does **not** add, verify,
or override those feeds, and it does **not** perform additional signature
checks beyond what `opkg`/`apk` already do. Only run these scripts on devices
whose package feeds you trust.
