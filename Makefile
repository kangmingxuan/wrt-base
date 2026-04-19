# openwrt-maintenance — 常用任务的快捷封装。
# 路由器上一般没装 make，所有目标都只是对 sh 命令的薄封装；
# 在开发机上敲 `make ...` 更顺手时再用。

.PHONY: help test install install-minimal print health lint

help:
	@echo "可用目标:"
	@echo "  make test             跑 tests/run.sh 全部测试"
	@echo "  make lint             只跑 sh -n + shellcheck"
	@echo "  make print            打印 full 模式将安装的包"
	@echo "  make install          安装 full 工具集（需 root）"
	@echo "  make install-minimal  安装 minimal 工具集（需 root）"
	@echo "  make health           跑健康检查"

test:
	sh tests/run.sh

lint:
	@find scripts tests -type f -name '*.sh' -exec sh -n {} \; -print
	@command -v shellcheck >/dev/null 2>&1 && \
		find scripts tests -type f -name '*.sh' -exec shellcheck -x {} + || \
		echo "未安装 shellcheck，跳过"

print:
	sh scripts/install-tools.sh --print-only

install:
	sh scripts/install-tools.sh

install-minimal:
	sh scripts/install-tools.sh --minimal

health:
	sh scripts/health-check.sh
