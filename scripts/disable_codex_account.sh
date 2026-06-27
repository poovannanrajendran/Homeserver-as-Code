#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Disable (or remove) an ops user created for homelab automation.

This is intended as the "easy off switch" for the shared username/password
pattern when you no longer want the account active.

Usage:
  sudo ./disable_codex_account.sh --user codex_agent_agent [--lock] [--remove-sudo] [--wipe-ssh] [--delete-user]

Actions (defaults are safe + reversible):
  --lock        Lock the account (disables password login). (default: on)
  --remove-sudo Remove sudo privileges (/etc/sudoers.d/<user>, groups). (default: on)
  --wipe-ssh    Remove ~/.ssh/authorized_keys for the user. (default: off)
  --delete-user Delete the user and home directory (irreversible). (default: off)
EOF
}

USER_NAME=""
DO_LOCK=1
DO_REMOVE_SUDO=1
DO_WIPE_SSH=0
DO_DELETE_USER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="${2:-}"; shift 2 ;;
    --lock)
      DO_LOCK=1; shift ;;
    --no-lock)
      DO_LOCK=0; shift ;;
    --remove-sudo)
      DO_REMOVE_SUDO=1; shift ;;
    --keep-sudo)
      DO_REMOVE_SUDO=0; shift ;;
    --wipe-ssh)
      DO_WIPE_SSH=1; shift ;;
    --delete-user)
      DO_DELETE_USER=1; shift ;;
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
  echo "--user is required" >&2
  exit 2
fi

if ! getent passwd "${USER_NAME}" >/dev/null 2>&1; then
  echo "User '${USER_NAME}' does not exist; nothing to do."
  exit 0
fi

home_dir="$(getent passwd "${USER_NAME}" | awk -F: '{print $6}')"

if [[ "${DO_REMOVE_SUDO}" -eq 1 ]]; then
  rm -f "/etc/sudoers.d/${USER_NAME}" || true

  if getent group sudo >/dev/null 2>&1; then
    gpasswd -d "${USER_NAME}" sudo >/dev/null 2>&1 || true
  fi
  if getent group wheel >/dev/null 2>&1; then
    gpasswd -d "${USER_NAME}" wheel >/dev/null 2>&1 || true
  fi
fi

if [[ "${DO_WIPE_SSH}" -eq 1 ]]; then
  rm -f "${home_dir}/.ssh/authorized_keys" || true
fi

if [[ "${DO_LOCK}" -eq 1 ]]; then
  # Lock password and expire account (still reversible via usermod/passwd).
  passwd -l "${USER_NAME}" >/dev/null 2>&1 || true
  chage -E0 "${USER_NAME}" >/dev/null 2>&1 || true
  # Optional: set nologin shell for an additional guard.
  usermod -s /usr/sbin/nologin "${USER_NAME}" >/dev/null 2>&1 || true
fi

if [[ "${DO_DELETE_USER}" -eq 1 ]]; then
  userdel -r "${USER_NAME}"
  echo "OK: deleted user '${USER_NAME}' (and home)."
  exit 0
fi

echo "OK: disabled user '${USER_NAME}' (lock=${DO_LOCK}, remove_sudo=${DO_REMOVE_SUDO}, wipe_ssh=${DO_WIPE_SSH})."
