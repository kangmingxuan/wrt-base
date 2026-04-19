# 仓库布局

```
.
├── Makefile                # 常用任务入口
├── README.md
├── docs/
│   ├── setup.md            # 路由器上首次落地步骤
│   ├── sing-box.md         # 部署 sing-box 的前置约束
│   └── layout.md           # 本文件
├── scripts/
│   ├── install-tools.sh    # 安装维护工具集（自动选择 opkg / apk）
│   ├── health-check.sh     # 系统健康检查（cron 友好）
│   └── lib/
│       ├── common.sh       # 日志、根用户检查、has_cmd、tokens
│       └── pkg.sh          # 包管理器抽象 (opkg / apk)
└── tests/
    ├── run.sh              # 测试入口
    ├── _assert.sh          # 极简断言库
    ├── test_common.sh
    ├── test_pkg.sh
    ├── test_install_tools.sh
    └── test_health_check.sh
```

## 设计原则

- **POSIX `/bin/sh` 优先**。OpenWrt 默认 BusyBox ash，不假设 bash 存在。
- **lib 只能被 source，不能直接执行**。每个 lib 顶部用 `__OWRT_*_LOADED` guard 防止重复加载。
- **包管理器解耦**。`scripts/lib/pkg.sh` 把 `opkg` / `apk` 抽成统一接口，新加管理器只要扩这一个文件。
- **失败不静默**。`install-tools.sh` 单包失败时不中断整体，最后汇总告警；`health-check.sh` 任意一项失败就退非 0。
- **测试自检**。`tests/run.sh` 同时跑 `sh -n`、`shellcheck`（如装了）、`test_*.sh`。

## 添加一个新脚本

1. 在 `scripts/` 下新建 `your-thing.sh`，开头写：

   ```sh
   #!/bin/sh
   set -u
   SELF=$(readlink -f "$0" 2>/dev/null) || SELF="$0"
   SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$SELF")" && pwd)
   . "$SCRIPT_DIR/lib/common.sh"
   ```

2. 在 `tests/` 下新建 `test_your_thing.sh`，引入 `_assert.sh`，写若干 `assert_*` 调用。
3. `sh tests/run.sh` 验证；不通过别提交。
