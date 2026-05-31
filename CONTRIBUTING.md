# Contributing

Thank you for considering a contribution to wrt-base.

## Before You Start

- All scripts must use POSIX `/bin/sh`. Do not assume bash is available.
- BusyBox ash is the default shell on OpenWrt, so avoid bash-specific syntax.

## Development Flow

1. Fork the repository and create a feature branch.
2. Make your changes.
3. Run the test suite:

   ```sh
   sh tests/run.sh
   ```

4. Submit only after all tests pass.
5. Open a pull request and briefly explain the purpose of the change.

## Adding a New Script

In short:

- Add the script under `scripts/` and source `lib/common.sh`.
- Add a matching `test_*.sh` under `tests/` and source `_assert.sh`.
- `sh tests/run.sh` auto-discovers new test files.

## Commit Style

Use the [Conventional Commits](https://www.conventionalcommits.org/) format:

- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation
- `test:` tests
- `chore:` build or miscellaneous maintenance

## Releases

This project follows [Semantic Versioning](https://semver.org/). User-facing
changes should update `CHANGELOG.md` under the `Unreleased` section.

Maintainers publish releases by creating a signed or annotated tag named
`vMAJOR.MINOR.PATCH`, for example:

```sh
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

The release workflow creates or updates the matching GitHub Release from the
tag and `CHANGELOG.md` entry.

## Code Style

- Indentation: 4 spaces, as defined in `.editorconfig`.
- Quote variable expansions: use `"$var"` instead of `$var`.
- Add a short comment before a function when its purpose is not obvious.
- Protect each `lib/*.sh` with an `__OWRT_*_LOADED` guard to prevent duplicate sourcing.
- Contributions are accepted under the repository's MIT license.

## Reporting Issues

Please use GitHub Issues and include as much of the following as possible:

- OpenWrt or ImmortalWrt version, for example `cat /etc/openwrt_release`
- Package manager type, `opkg` or `apk`
- Full error output
