#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Roll out the unified ops user (codex_agent_agent) via the Proxmox host.

This script is SANITIZED (no passwords embedded). Provide passwords via
environment variables or interactive prompts.

Requirements:
  - expect
  - network reachability to the Proxmox host (SSH/22)

Env vars:
  PROXMOX_HOST            (default: 192.168.1.250)
  PROXMOX_ROOT_PASSWORD   (required unless prompted)
  CODEX_AGENT_PASSWORD    (required unless prompted)

What it does:
  - Creates/ensures user on Proxmox host
  - Creates/ensures user inside LXC 106 via pct exec
  - Attempts to create/ensure user on VMs 100/101/103/105 via qm guest exec
    (requires qemu-guest-agent to be installed/running in those VMs)

Usage:
  ./rollout_codex_agent_user.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.250}"
PROXMOX_USER="root"
OPS_USER="codex_agent_agent"

if ! command -v expect >/dev/null 2>&1; then
  echo "Missing dependency: expect" >&2
  exit 1
fi

prompt_secret() {
  local var_name="$1"
  local prompt="$2"
  local value=""
  if [[ -z "${!var_name:-}" ]]; then
    read -r -s -p "${prompt}: " value
    echo
    printf -v "${var_name}" '%s' "${value}"
  fi
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required secret: ${var_name}" >&2
    exit 2
  fi
}

prompt_secret PROXMOX_ROOT_PASSWORD "Proxmox root password for ${PROXMOX_USER}@${PROXMOX_HOST}"
prompt_secret CODEX_AGENT_PASSWORD "Shared password for ${OPS_USER}"

# expect reads secrets from the environment via Tcl's env(...)
export PROXMOX_ROOT_PASSWORD
export CODEX_AGENT_PASSWORD

disable_script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/disable_codex_account.sh"

if [[ ! -f "${disable_script_path}" ]]; then
  echo "Missing: ${disable_script_path}" >&2
  exit 1
fi

# Remote script runs on the Proxmox host. It reads the ops password from STDIN,
# base64-encodes it, and uses it for host + CT106 + VMs via guest agent.
REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

OPS_USER="__OPS_USER__"
VM_IDS="100 101 103 105"
CT_ID="106"

echo OPSPW_READY
read -r OPSPW
B64="$(printf %s "$OPSPW" | base64 | tr -d '\n')"

ensure_user() {
  local user="$1"
  local pw="$2"
  id -u "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
  printf '%s\n' "$user:$pw" | chpasswd
  if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo "$user" || true
  elif getent group wheel >/dev/null 2>&1; then
    usermod -aG wheel "$user" || true
  fi
  printf '%s\n' "$user ALL=(ALL) ALL" > "/etc/sudoers.d/$user"
  chmod 0440 "/etc/sudoers.d/$user"
}

ensure_user "$OPS_USER" "$OPSPW"

# CT 106
if command -v pct >/dev/null 2>&1; then
  timeout 30 pct exec "$CT_ID" -- bash -lc "set -euo pipefail; OPS_USER='$OPS_USER'; OPSPW=\"\$(printf %s '$B64' | base64 -d)\"; id -u \"\$OPS_USER\" >/dev/null 2>&1 || useradd -m -s /bin/bash \"\$OPS_USER\"; printf '%s\n' \"\$OPS_USER:\$OPSPW\" | chpasswd; (getent group sudo >/dev/null 2>&1 && usermod -aG sudo \"\$OPS_USER\") || true; printf '%s\n' \"\$OPS_USER ALL=(ALL) ALL\" > /etc/sudoers.d/\$OPS_USER; chmod 0440 /etc/sudoers.d/\$OPS_USER" || true
fi

# VMs (best-effort)
if command -v qm >/dev/null 2>&1; then
  for vmid in $VM_IDS; do
    timeout 30 qm guest exec "$vmid" -- bash -lc "set -e; OPS_USER='$OPS_USER'; OPSPW=\"\$(printf %s '$B64' | base64 -d)\"; id -u \"\$OPS_USER\" >/dev/null 2>&1 || useradd -m -s /bin/bash \"\$OPS_USER\"; printf '%s\n' \"\$OPS_USER:\$OPSPW\" | chpasswd; (getent group sudo >/dev/null 2>&1 && usermod -aG sudo \"\$OPS_USER\") || true; printf '%s\n' \"\$OPS_USER ALL=(ALL) ALL\" > /etc/sudoers.d/\$OPS_USER; chmod 0440 /etc/sudoers.d/\$OPS_USER" >/dev/null 2>&1 || true
    timeout 10 qm guest exec "$vmid" -- id "$OPS_USER" >/dev/null 2>&1 || true
  done
fi

echo OK
EOF
)

REMOTE_SCRIPT="${REMOTE_SCRIPT/__OPS_USER__/${OPS_USER}}"

# Do not embed secrets (or shell-special chars like '[' or '!') into the Tcl
# script via bash interpolation. Pass everything via environment variables.
REMOTE_SCRIPT_B64="$(printf %s "${REMOTE_SCRIPT}" | base64 | tr -d '\n')"
export REMOTE_SCRIPT_B64
export PROXMOX_HOST
export PROXMOX_USER

expect <<'EOF'
set timeout 180
log_user 1

set host $env(PROXMOX_HOST)
set user $env(PROXMOX_USER)
set remote_b64 $env(REMOTE_SCRIPT_B64)
set remote_cmd [format {eval "$(echo %s | base64 -d)"} $remote_b64]

spawn ssh -T -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$env(HOME)/.ssh/known_hosts $user@$host bash -lc $remote_cmd
expect {
  -re {Are you sure you want to continue connecting} {
    send "yes\r"
    exp_continue
  }
  -re {(?i)password:} {
    log_user 0
    send -- "$env(PROXMOX_ROOT_PASSWORD)\r"
    log_user 1
    exp_continue
  }
  -re {OPSPW_READY} {
    log_user 0
    send -- "$env(CODEX_AGENT_PASSWORD)\r"
    log_user 1
    exp_continue
  }
  -re {OK} { }
  timeout { exit 124 }
  eof
}

expect eof
EOF
