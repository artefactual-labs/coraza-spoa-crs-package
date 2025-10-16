#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "${ROOT_DIR}/versions.env" ]; then
  # shellcheck disable=SC1091
  . "${ROOT_DIR}/versions.env"
fi

: "${CORAZA_SPOA_VERSION:?Set CORAZA_SPOA_VERSION (e.g., v0.7.0)}"
: "${CRS_REF:?Set CRS_REF (e.g., v4.0.0)}"
: "${CRS_VERSION:?Set CRS_VERSION (e.g., 4.0.0)}"
: "${CORAZA_CONF_REF:?Set CORAZA_CONF_REF (e.g., main)}"

ARCH_LIST="${ARCHITECTURES:-amd64}"
IFS=' ' read -r -a ARCHES <<< "${ARCH_LIST}"

BUILD_DIR="${ROOT_DIR}/build"
PREBUILT_DIR="${BUILD_DIR}/prebuilt"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
SRC_DIR="${BUILD_DIR}/src"

log() {
  printf '[prepare-rootfs] %s\n' "$*" >&2
}

clean_dirs() {
  rm -rf "${BUILD_DIR}"
  mkdir -p "${PREBUILT_DIR}" "${ROOTFS_DIR}" "${SRC_DIR}"
}

clone_repo() {
  local repo_url=$1
  local ref=$2
  local dest=$3

  if [ -d "${dest}" ]; then
    rm -rf "${dest}"
  fi

  git clone --depth 1 --branch "${ref}" "${repo_url}" "${dest}"
}

build_coraza_spoa() {
  local src=$1
  local main_pkg

  detect_main_package() {
    local repo=$1
    local first_candidate=""
    local file
    while IFS= read -r file; do
      if grep -q '^package main' "$file"; then
        local dir="${file%/*}"
        local rel="${dir#$repo/}"
        [ "$rel" = "$dir" ] && rel="."
        if printf '%s\n' "$rel" | grep -qi 'spoa'; then
          if [ "$rel" = "." ]; then
            echo "."
          else
            echo "./${rel}"
          fi
          return 0
        fi
        if [ -z "$first_candidate" ]; then
          if [ "$rel" = "." ]; then
            first_candidate="."
          else
            first_candidate="./${rel}"
          fi
        fi
      fi
    done < <(find "${repo}" -maxdepth 3 -type f -name 'main.go' | sort)

    if [ -n "$first_candidate" ]; then
      echo "$first_candidate"
      return 0
    fi

    if [ -f "${repo}/main.go" ]; then
      echo "."
      return 0
    fi

    echo "./cmd/coraza-spoa"
    return 0
  }

  main_pkg=$(detect_main_package "${src}")
  log "Detected main package path: ${main_pkg}"

  for arch in "${ARCHES[@]}"; do
    local output="${PREBUILT_DIR}/linux_${arch}/coraza-spoa"
    mkdir -p "$(dirname "${output}")"
    log "Building coraza-spoa ${CORAZA_SPOA_VERSION} for linux/${arch}"
    (cd "${src}" && GOOS=linux GOARCH="${arch}" CGO_ENABLED=0 \
      go build -trimpath -ldflags "-s -w" \
      -o "${output}" "${main_pkg}")
  done
}

prepare_coraza_conf() {
  local dest_dir=$1
  mkdir -p "${dest_dir}"

  log "Fetching coraza.conf-recommended from ${CORAZA_CONF_REF}"
  curl -fsSL "https://raw.githubusercontent.com/corazawaf/coraza/${CORAZA_CONF_REF}/coraza.conf-recommended" \
    -o "${dest_dir}/coraza.conf"

  printf '\n' >> "${dest_dir}/coraza.conf"
}

prepare_crs() {
  local src_dir=$1
  local dest_dir=$2

  log "Cloning coreruleset ${CRS_REF}"
  clone_repo "https://github.com/coreruleset/coreruleset.git" "${CRS_REF}" "${src_dir}/coreruleset"

  install -d -m0755 "${dest_dir}"
  install -D -m0644 "${src_dir}/coreruleset/crs-setup.conf.example" "${dest_dir}/crs-setup.conf"

  rm -rf "${dest_dir}/rules"
  cp -R "${src_dir}/coreruleset/rules" "${dest_dir}/rules"
  find "${dest_dir}/rules" -type d -exec chmod 0755 {} +
  find "${dest_dir}/rules" -type f -exec chmod 0644 {} +
}

copy_static_assets() {
  install -d -m0755 "${ROOTFS_DIR}/etc/coraza-spoa"
  install -d -m0755 "${ROOTFS_DIR}/etc/haproxy"
  install -d -m0755 "${ROOTFS_DIR}/etc/systemd/system"
  install -d -m0755 "${ROOTFS_DIR}/etc/logrotate.d"
  install -d -m0755 "${ROOTFS_DIR}/etc/default"
  install -d -m0755 "${ROOTFS_DIR}/var/log/coraza-spoa"

  install -D -m0644 "${ROOT_DIR}/config/config.yaml" "${ROOTFS_DIR}/etc/coraza-spoa/config.yaml"
  prepare_coraza_conf "${ROOTFS_DIR}/etc/coraza-spoa"
  prepare_crs "${SRC_DIR}" "${ROOTFS_DIR}/etc/coraza-spoa"

  install -D -m0644 "${ROOT_DIR}/haproxy/coraza.cfg" "${ROOTFS_DIR}/etc/haproxy/coraza.cfg"
  install -D -m0644 "${ROOT_DIR}/systemd/coraza-spoa.service" "${ROOTFS_DIR}/etc/systemd/system/coraza-spoa.service"
  install -D -m0644 "${ROOT_DIR}/logrotate/coraza-spoa" "${ROOTFS_DIR}/etc/logrotate.d/coraza-spoa"
  install -D -m0644 "${ROOT_DIR}/packaging/default/coraza-spoa" "${ROOTFS_DIR}/etc/default/coraza-spoa"
}

main() {
  clean_dirs

  log "Cloning coraza-spoa ${CORAZA_SPOA_VERSION}"
  clone_repo "https://github.com/corazawaf/coraza-spoa.git" "${CORAZA_SPOA_VERSION}" "${SRC_DIR}/coraza-spoa"
  build_coraza_spoa "${SRC_DIR}/coraza-spoa"

  copy_static_assets

  log "Root filesystem is ready in ${ROOTFS_DIR}"
}

main "$@"
