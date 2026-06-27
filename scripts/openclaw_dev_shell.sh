#!/usr/bin/env bash
set -euo pipefail

# Connect to ai-node-01 and enter the OpenClaw Python dev environment.
# Pass --root to run as root while preserving the caller's HOME for venv usage.

ROOT=0
MODE="tailnet"
SSH_USER="labadmin"
HOST_LAN="192.168.1.24"
HOST_TAILNET="ai-node-01.tail4bbda6.ts.net"

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_dev_shell.sh [--tailnet|--lan] [--root]

Options:
  --tailnet   Connect via Tailscale DNS (default)
  --lan       Connect via LAN IP
  --root      Use sudo -E on remote host
  -h, --help  Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailnet)
      MODE="tailnet"
      shift
      ;;
    --lan)
      MODE="lan"
      shift
      ;;
    --root)
      ROOT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

HOST="$HOST_TAILNET"
if [[ "$MODE" == "lan" ]]; then
  HOST="$HOST_LAN"
fi

TARGET="${SSH_USER}@${HOST}"
SSH_OPTS=(
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$HOME/.ssh/known_hosts"
)

if [[ "$ROOT" -eq 1 ]]; then
  exec ssh "${SSH_OPTS[@]}" -t "$TARGET" "sudo -E openclaw-dev-shell"
else
  exec ssh "${SSH_OPTS[@]}" -t "$TARGET" "openclaw-dev-shell"
fi
