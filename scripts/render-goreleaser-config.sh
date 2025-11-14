#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ $# -gt 0 ]; then
  OUT_PATH="$1"
  mkdir -p "$(dirname "${OUT_PATH}")"
else
  OUT_PATH="$(mktemp "${TMPDIR:-/tmp}/goreleaser.XXXXXX.yml")"
fi

: "${PACKAGE_RELEASE:=1}"

envsubst '${PACKAGE_RELEASE}' < "${ROOT_DIR}/.goreleaser.yml" > "${OUT_PATH}"
printf '%s\n' "${OUT_PATH}"
