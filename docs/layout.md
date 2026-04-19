# Repository Layout

```
.
├── Makefile
├── README.md
├── README.zh-CN.md
├── docs/
│   ├── setup.md
│   ├── sing-box.md
│   └── layout.md
├── scripts/
│   ├── install-tools.sh
│   ├── health-check.sh
│   └── lib/
│       ├── common.sh
│       └── pkg.sh
└── tests/
    ├── run.sh
    ├── _assert.sh
    ├── test_common.sh
    ├── test_pkg.sh
    ├── test_install_tools.sh
    └── test_health_check.sh
```

Only three layers matter in practice:

- `scripts/` contains executable entry points, while shared logic lives in `scripts/lib/`.
- `tests/` contains shell tests whose file names track the script or library responsibility they cover.
- `docs/` stays limited to repository-specific documentation instead of expanding into a general operations manual.

## Design Rules

- **Prefer POSIX `/bin/sh`**. BusyBox ash is the default shell on OpenWrt, so do not assume bash is present.
- **Library files are sourced, not executed directly**. Each file in `lib/` uses an `__OWRT_*_LOADED` guard to prevent duplicate sourcing.
- **Package manager logic is isolated**. `scripts/lib/pkg.sh` provides one interface for `opkg` and `apk`, so new backends only need changes in that file.
- **Failures must be visible**. `install-tools.sh` summarizes single-package failures; `health-check.sh` exits non-zero as soon as any check fails.
- **Tests are part of the contract**. `tests/run.sh` runs `sh -n`, `shellcheck` when available, and every `test_*.sh` file.

## Adding a New Script

1. Create `your-thing.sh` under `scripts/` and start with:

   ```sh
   #!/bin/sh
   set -u
   SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
   SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
   . "$SCRIPT_DIR/lib/common.sh"
   ```

2. Add `test_your_thing.sh` under `tests/`, source `_assert.sh`, and write the necessary `assert_*` calls.
3. Validate with `sh tests/run.sh`. Do not submit changes with failing tests.
