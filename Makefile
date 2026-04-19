# wrt-base — optional shortcuts for common tasks.
# Routers usually do not have make installed, so each target is only a thin
# wrapper around the equivalent sh command for workstation convenience.

.PHONY: help test install install-minimal print health lint

help:
	@echo "Available targets:"
	@echo "  make test             Run the full tests/run.sh suite"
	@echo "  make lint             Run sh -n and shellcheck only"
	@echo "  make print            Print the packages installed by full mode"
	@echo "  make install          Install the full toolset (requires root)"
	@echo "  make install-minimal  Install the minimal toolset (requires root)"
	@echo "  make health           Run the health check"

test:
	sh tests/run.sh

lint:
	@find scripts tests -type f -name '*.sh' -exec sh -n {} \; -print
	@command -v shellcheck >/dev/null 2>&1 && \
		find scripts tests -type f -name '*.sh' -exec shellcheck -x {} + || \
		echo "shellcheck is not installed; skipping"

print:
	sh scripts/install-tools.sh --print-only

install:
	sh scripts/install-tools.sh

install-minimal:
	sh scripts/install-tools.sh --minimal

health:
	sh scripts/health-check.sh
