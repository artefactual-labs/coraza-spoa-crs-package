SHELL := /bin/bash

.PHONY: build snapshot clean

build:
	./scripts/prepare-rootfs.sh

snapshot:
	goreleaser release --snapshot --skip=publish --clean

clean:
	rm -rf build dist
