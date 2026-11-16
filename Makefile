CEKIT ?= cekit
.DEFAULT_GOAL := check
.PHONY: check
check:
	CEKIT="$(CEKIT)" ./tests/check.sh
