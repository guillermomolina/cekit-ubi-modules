CEKIT ?= cekit
PODMAN ?= podman
IMAGE ?= localhost/examples/startup-hooks:latest
.DEFAULT_GOAL := build
.PHONY: generate build run clean

generate:
	$(CEKIT) build --dry-run buildah

build:
	$(CEKIT) build buildah --tag "$(IMAGE)" --no-squash

run:
	$(PODMAN) run --rm -it "$(IMAGE)"

clean:
	$(PODMAN) rmi "$(IMAGE)"
