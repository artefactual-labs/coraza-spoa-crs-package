#!/bin/sh
set -e

SERVICE="coraza-spoa.service"
USER="coraza-spoa"
GROUP="coraza-spoa"
CONFIG_DIR="/etc/coraza-spoa"
RULES_DIR="${CONFIG_DIR}/rules"
LOG_DIR="/var/log/coraza-spoa"
HAPROXY_CFG="/etc/haproxy/coraza.cfg"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_group() {
  if ! getent group "${GROUP}" >/dev/null 2>&1; then
    if command_exists groupadd; then
      groupadd --system "${GROUP}" >/dev/null 2>&1 || true
    fi
  fi
}

ensure_user() {
  if ! id -u "${USER}" >/dev/null 2>&1; then
    if command_exists useradd; then
      useradd --system --no-create-home --home-dir /nonexistent \
        --gid "${GROUP}" --shell /usr/sbin/nologin "${USER}" >/dev/null 2>&1 || \
      useradd --system --no-create-home --home-dir /nonexistent \
        --gid "${GROUP}" --shell /sbin/nologin "${USER}" >/dev/null 2>&1 || true
    fi
  fi
}

fix_permissions() {
  install -d -m0750 -o root -g "${GROUP}" "${CONFIG_DIR}"
  install -d -m0755 -o "${USER}" -g "${GROUP}" "${LOG_DIR}"

  if [ -d "${RULES_DIR}" ]; then
    chown -R root:"${GROUP}" "${CONFIG_DIR}"
    find "${CONFIG_DIR}" -type d -exec chmod 0750 {} \; 2>/dev/null || true
    find "${CONFIG_DIR}" -type f -exec chmod 0640 {} \; 2>/dev/null || true
  fi
}

configure_selinux() {
  if command_exists selinuxenabled && selinuxenabled >/dev/null 2>&1; then
    if command_exists semanage; then
      for PORT in 9000; do
        semanage port -a -t http_port_t -p tcp "${PORT}" >/dev/null 2>&1 || \
        semanage port -m -t http_port_t -p tcp "${PORT}" >/dev/null 2>&1 || true
      done
    fi
  fi
}

ensure_haproxy_newline() {
  if [ -f "${HAPROXY_CFG}" ]; then
    tail_char=$(tail -c1 "${HAPROXY_CFG}" 2>/dev/null || printf '')
    if [ -n "${tail_char}" ] && [ "${tail_char}" != "$(printf '\n')" ]; then
      printf '\n' >> "${HAPROXY_CFG}"
    fi
  fi
}

reload_systemd() {
  if command_exists systemctl && [ -d /run/systemd/system ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable --now "${SERVICE}" >/dev/null 2>&1 || true
  fi
}

ensure_group
ensure_user
fix_permissions
configure_selinux
ensure_haproxy_newline
reload_systemd

exit 0
