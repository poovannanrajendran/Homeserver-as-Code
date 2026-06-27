#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Create a consistent ops user across homelab Linux hosts / LXCs.

Usage:
  sudo ./bootstrap_codex_account.sh [--user codex] [--password '...'] [--pubkey-file /path/to/key.pub]
                                   [--sudo] [--sudo-nopasswd] [--no-sudo]

Notes:
  - Prefer SSH keys. A shared password across all hosts increases blast radius.
  - This script is Debian/Ubuntu oriented (Proxmox/Debian, Ubuntu guests, etc).
EOF
}

USER_NAME="codex"
USER_PASSWORD=""
PUBKEY_FILE=""
SUDO_MODE="sudo" # sudo | nopasswd | none

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="${2:-}"; shift 2 ;;
    --password)
      USER_PASSWORD="${2:-}"; shift 2 ;;
    --pubkey-file)
      PUBKEY_FILE="${2:-}"; shift 2 ;;
    --sudo)
      SUDO_MODE="sudo"; shift ;;
    --sudo-nopasswd)
      SUDO_MODE="nopasswd"; shift ;;
    --no-sudo)
      SUDO_MODE="none"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (use sudo)." >&2
  exit 1
fi

if [[ -z "${USER_NAME}" ]]; then
  echo "--user must not be empty" >&2
  exit 2
fi

if ! getent passwd "${USER_NAME}" >/dev/null 2>&1; then
  # Create with home dir + bash; keep it simple across Debian/Ubuntu.
  useradd -m -s /bin/bash "${USER_NAME}"
fi

# Optional password set (not required if using SSH keys).
if [[ -n "${USER_PASSWORD}" ]]; then
  echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd
fi

# Optional SSH key install.
if [[ -n "${PUBKEY_FILE}" ]]; then
  if [[ ! -f "${PUBKEY_FILE}" ]]; then
    echo "pubkey file not found: ${PUBKEY_FILE}" >&2
    exit 2
  fi

  home_dir="$(getent passwd "${USER_NAME}" | awk -F: '{print $6}')"
  install -d -m 0700 -o "${USER_NAME}" -g "${USER_NAME}" "${home_dir}/.ssh"
  install -m 0600 -o "${USER_NAME}" -g "${USER_NAME}" /dev/null "${home_dir}/.ssh/authorized_keys"

  # Append if not already present (idempotent).
  pubkey="$(cat "${PUBKEY_FILE}")"
  if ! grep -Fqx "${pubkey}" "${home_dir}/.ssh/authorized_keys"; then
    printf '%s\n' "${pubkey}" >> "${home_dir}/.ssh/authorized_keys"
  fi
fi

# Sudo setup.
case "${SUDO_MODE}" in
  none)
    ;;
  sudo|nopasswd)
    if getent group sudo >/dev/null 2>&1; then
      usermod -aG sudo "${USER_NAME}"
    elif getent group wheel >/dev/null 2>&1; then
      usermod -aG wheel "${USER_NAME}"
    fi

    sudoers_file="/etc/sudoers.d/${USER_NAME}"
    if [[ "${SUDO_MODE}" == "nopasswd" ]]; then
      echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "${sudoers_file}"
    else
      echo "${USER_NAME} ALL=(ALL) ALL" > "${sudoers_file}"
    fi
    chmod 0440 "${sudoers_file}"
    ;;
  *)
    echo "Unexpected sudo mode: ${SUDO_MODE}" >&2
    exit 2
    ;;
esac

echo "OK: ensured user '${USER_NAME}' exists; sudo='${SUDO_MODE}'; password_set=$([[ -n ${USER_PASSWORD} ]] && echo yes || echo no); pubkey_installed=$([[ -n ${PUBKEY_FILE} ]] && echo yes || echo no)"
