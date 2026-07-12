#!/usr/bin/env bash
set -euo pipefail

# Run a direct OpenClaw agent turn from a terminal.
# This is the actual terminal-to-agent path, unlike message send which only
# speaks to Telegram. Pass OpenClaw agent options through unchanged.

HOST_MODE="${OPENCLAW_HOST_MODE:-tailnet}"
SSH_USER="${OPENCLAW_SSH_USER:-labadmin}"
REMOTE_USER="${OPENCLAW_REMOTE_USER:-openclaw}"
REMOTE_HOME="${OPENCLAW_REMOTE_HOME:-/var/lib/openclaw}"
REMOTE_HOST_TAILNET="${OPENCLAW_HOST_TAILNET:-ai-node-01.tail4bbda6.ts.net}"
REMOTE_HOST_LAN="${OPENCLAW_HOST_LAN:-192.168.1.24}"
DEFAULT_TO="${OPENCLAW_AGENT_TO:-}"
FORWARD_ARGS=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_agent_turn.sh [options]

Wrapper options:
  --tailnet          Use ai-node-01 tailnet hostname (default)
  --lan              Use ai-node-01 LAN IP
  --user <ssh-user>  SSH user for the host (default: labadmin)
  --remote-user <u>  Remote OpenClaw user (default: openclaw)
  -h, --help         Show help

Everything else is forwarded to `openclaw agent` unchanged.

Examples:
  scripts/openclaw_agent_turn.sh --agent fury --message "Reply with exactly: ping" --timeout 30 --json
  scripts/openclaw_agent_turn.sh --agent loki --message "Write one sentence about Lloyd's market and AI agents."
  OPENCLAW_AGENT_TO=<telegram-chat-id> scripts/openclaw_agent_turn.sh --agent loki --message "Draft a LinkedIn post" --deliver --reply-channel telegram
USAGE
}

shell_quote() {
  printf '%q' "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailnet)
      HOST_MODE="tailnet"
      shift
      ;;
    --lan)
      HOST_MODE="lan"
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
    --remote-user)
      REMOTE_USER="${2:-}"
      if [[ -z "$REMOTE_USER" ]]; then
        echo "Error: --remote-user requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        FORWARD_ARGS+=("$1")
        shift
      done
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#FORWARD_ARGS[@]} -eq 0 ]]; then
  usage
  exit 1
fi

HAS_TO=0
for arg in "${FORWARD_ARGS[@]}"; do
  if [[ "$arg" == "--to" || "$arg" == "-t" ]]; then
    HAS_TO=1
    break
  fi
done

if [[ "$HAS_TO" -eq 0 && -n "$DEFAULT_TO" ]]; then
  FORWARD_ARGS=(--to "$DEFAULT_TO" "${FORWARD_ARGS[@]}")
fi

REMOTE_HOST="$REMOTE_HOST_TAILNET"
if [[ "$HOST_MODE" == "lan" ]]; then
  REMOTE_HOST="$REMOTE_HOST_LAN"
fi

SSH_OPTS=(
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$HOME/.ssh/known_hosts"
)

REMOTE_BASE_CMD="sudo -u $(shell_quote "$REMOTE_USER") -H env HOME=$(shell_quote "$REMOTE_HOME") openclaw agent"
REMOTE_GATEWAY_CMD="$REMOTE_BASE_CMD"
REMOTE_LOCAL_CMD="$REMOTE_BASE_CMD --local"
for arg in "${FORWARD_ARGS[@]}"; do
  REMOTE_GATEWAY_CMD+=" $(shell_quote "$arg")"
  REMOTE_LOCAL_CMD+=" $(shell_quote "$arg")"
done

run_remote() {
  local cmd="$1"
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${REMOTE_HOST}" "$cmd" 2>&1
}

OUTPUT="$(run_remote "$REMOTE_GATEWAY_CMD")" || STATUS=$?
STATUS="${STATUS:-0}"

if [[ "$STATUS" -ne 0 ]] && grep -qE 'device identity required|gateway closed \(1008\): device identity required' <<<"$OUTPUT"; then
  printf '%s\n' "[openclaw-agent-turn] gateway rejected local loopback device auth; retrying with --local" >&2
  OUTPUT="$(run_remote "$REMOTE_LOCAL_CMD")" || STATUS=$?
  STATUS="${STATUS:-0}"
fi

printf '%s\n' "$OUTPUT"
exit "$STATUS"
