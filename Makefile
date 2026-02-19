.PHONY: lint lint-scripts help

SHELL := /bin/bash

# All shell scripts in the repo (excludes _build/ which is gitignored/non-authoritative)
SCRIPTS := $(shell find scripts/ src/ infra/logging/scripts/ -name "*.sh" 2>/dev/null | sort)

help:
	@echo "Available targets:"
	@echo "  make lint         Run shellcheck on all scripts"
	@echo "  make lint-scripts Same as lint"

lint lint-scripts:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not found — install with: sudo apt install shellcheck" >&2; \
		exit 1; \
	fi
	@echo "Running shellcheck on $(words $(SCRIPTS)) scripts..."
	@shellcheck --shell=bash --severity=warning $(SCRIPTS) && \
		echo "All scripts passed shellcheck." || \
		(echo "shellcheck found issues — see above." && exit 1)
