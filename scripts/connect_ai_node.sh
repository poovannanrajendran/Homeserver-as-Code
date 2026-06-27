#!/usr/bin/env bash
set -euo pipefail

# Simple connector for ai-node-01 with optional root escalation.

HOST_LAN="192.168.1.24"
HOST_TAILNET="ai-node-01.tail4bbda6.ts.net"
SSH_USER="labadmin"
USE_TAILNET=1
WANT_ROOT=0
CMD=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/connect_ai_node.sh [--tailnet|--lan] [--root] [--user <user>] [--cmd "<command>"]

Options:
  --tailnet         Connect via ai-node-01.tail4bbda6.ts.net (default)
  --lan             Connect via 192.168.1.24
  --root            Escalate to root on connect (sudo required)
  --user <user>     SSH user (default: labadmin)
  --cmd "<command>"  Run one command and exit
  -h, --help        Show this help

Examples:
  scripts/connect_ai_node.sh
  scripts/connect_ai_node.sh --root
  scripts/connect_ai_node.sh --lan --cmd "systemctl status openclaw-gateway --no-pager"
  scripts/connect_ai_node.sh --tailnet --root --cmd "whoami && hostname"
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailnet)
      USE_TAILNET=1
      shift
      ;;
    --lan)
      USE_TAILNET=0
      shift
      ;;
    --root)
      WANT_ROOT=1
      shift
      ;;
    --user)
      SSH_USER="${2:-}"
      if [[ -z "$SSH_USER" ]]; then
        echo "Error: --user requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --cmd)
      CMD="${2:-}"
      if [[ -z "$CMD" ]]; then
        echo "Error: --cmd requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

HOST="$HOST_TAILNET"
if [[ "$USE_TAILNET" -eq 0 ]]; then
  HOST="$HOST_LAN"
fi

SSH_OPTS=(
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$HOME/.ssh/known_hosts"
)

TARGET="${SSH_USER}@${HOST}"

echo "[INFO] Connecting to ${TARGET}"
if [[ "$WANT_ROOT" -eq 1 ]]; then
  echo "[INFO] Root mode enabled (sudo on remote host)"
fi

if [[ -n "$CMD" ]]; then
  ESCAPED_CMD=$(printf '%q' "$CMD")
  if [[ "$WANT_ROOT" -eq 1 ]]; then
    exec ssh "${SSH_OPTS[@]}" "$TARGET" "sudo bash -lc ${ESCAPED_CMD}"
  else
    exec ssh "${SSH_OPTS[@]}" "$TARGET" "bash -lc ${ESCAPED_CMD}"
  fi
else
  if [[ "$WANT_ROOT" -eq 1 ]]; then
    exec ssh "${SSH_OPTS[@]}" -t "$TARGET" "sudo -i"
  else
    exec ssh "${SSH_OPTS[@]}" -t "$TARGET"
  fi
fi
