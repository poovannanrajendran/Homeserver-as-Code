#!/usr/bin/env bash
set -euo pipefail

# Inspect the newest OpenClaw session for an agent from a terminal.
# This pairs with scripts/openclaw_send.sh for quick smoke testing.

HOST_MODE="${OPENCLAW_HOST_MODE:-tailnet}"
SSH_USER="${OPENCLAW_SSH_USER:-labadmin}"
REMOTE_USER="${OPENCLAW_REMOTE_USER:-openclaw}"
REMOTE_HOME="${OPENCLAW_REMOTE_HOME:-/var/lib/openclaw}"
REMOTE_HOST_TAILNET="${OPENCLAW_HOST_TAILNET:-ai-node-01.tail4bbda6.ts.net}"
REMOTE_HOST_LAN="${OPENCLAW_HOST_LAN:-192.168.1.24}"
DEFAULT_AGENT="${OPENCLAW_AGENT:-fury}"
JSON=0
ALL_AGENTS=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_session_latest.sh [options]

Options:
  --agent <id>       Agent to inspect (default: fury)
  --all-agents       Inspect the newest session across all agents
  --tailnet          Use ai-node-01 tailnet hostname (default)
  --lan              Use ai-node-01 LAN IP
  --user <ssh-user>  SSH user for the host (default: labadmin)
  --remote-user <u>  Remote OpenClaw user (default: openclaw)
  --json             Return the raw latest session object as JSON
  -h, --help         Show help

Examples:
  scripts/openclaw_session_latest.sh
  scripts/openclaw_session_latest.sh --agent fury --json
  scripts/openclaw_session_latest.sh --all-agents
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      DEFAULT_AGENT="${2:-}"
      if [[ -z "$DEFAULT_AGENT" ]]; then
        echo "Error: --agent requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --all-agents)
      ALL_AGENTS=1
      shift
      ;;
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
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unexpected argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

REMOTE_HOST="$REMOTE_HOST_TAILNET"
if [[ "$HOST_MODE" == "lan" ]]; then
  REMOTE_HOST="$REMOTE_HOST_LAN"
fi

SSH_OPTS=(
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$HOME/.ssh/known_hosts"
)

shell_quote() {
  printf '%q' "$1"
}

REMOTE_CMD="sudo -u $(shell_quote "$REMOTE_USER") -H env HOME=$(shell_quote "$REMOTE_HOME") openclaw sessions"
if [[ "$ALL_AGENTS" -eq 1 ]]; then
  REMOTE_CMD+=' --all-agents'
else
  REMOTE_CMD+=" --agent $(shell_quote "$DEFAULT_AGENT")"
fi
REMOTE_CMD+=' --json'

SESSION_JSON="$(
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${REMOTE_HOST}" "$REMOTE_CMD"
)"

if [[ "$JSON" -eq 1 ]]; then
  printf '%s\n' "$SESSION_JSON"
  exit 0
fi

python3 -c "import json,sys; data=json.load(sys.stdin); sessions=data.get('sessions') or []; \
print('No sessions found.') if not sessions else None; \
latest=max(sessions, key=lambda s: s.get('updatedAt', 0)) if sessions else None; \
sys.exit(0) if not sessions else None; \
print(f\"Latest session: {latest.get('key', '<unknown>')}\"); \
print(f\"Session ID    : {latest.get('sessionId', '<unknown>')}\"); \
print(f\"Agent         : {latest.get('agentId', '<unknown>')}\"); \
print(f\"Model         : {latest.get('modelProvider', '<unknown>')}/{latest.get('model', '<unknown>')}\"); \
age_ms=latest.get('ageMs'); \
print(f\"Age           : {age_ms} ms\") if age_ms is not None else None; \
tokens=latest.get('totalTokens'); ctx=latest.get('contextTokens'); \
print(f\"Tokens        : {tokens if tokens is not None else 'unknown'} / {ctx if ctx is not None else 'unknown'}\") if (tokens is not None or ctx is not None) else None" <<<"$SESSION_JSON"
