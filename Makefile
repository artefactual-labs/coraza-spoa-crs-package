SHELL := /bin/bash

.PHONY: build snapshot clean

build:
	./scripts/prepare-rootfs.sh

snapshot:
	CONFIG=$$(./scripts/render-goreleaser-config.sh); \
	trap 'rm -f "$$CONFIG"' EXIT; \
	goreleaser release --snapshot --skip=publish --clean --config "$$CONFIG"

clean:
	rm -rf build dist
