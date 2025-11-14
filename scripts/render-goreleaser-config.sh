#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_PATH="${1:-${ROOT_DIR}/build/.goreleaser.rendered.yml}"

mkdir -p "$(dirname "${OUT_PATH}")"

: "${PACKAGE_RELEASE:=1}"

envsubst '${PACKAGE_RELEASE}' < "${ROOT_DIR}/.goreleaser.yml" > "${OUT_PATH}"
printf '%s\n' "${OUT_PATH}"
