#!/usr/bin/env bash
set -euo pipefail

# Wait for the latest OpenClaw session to change, then print a one-line summary.
# Useful after scripts/openclaw_send.sh to confirm the next turn landed.

HOST_MODE="${OPENCLAW_HOST_MODE:-tailnet}"
SSH_USER="${OPENCLAW_SSH_USER:-labadmin}"
REMOTE_USER="${OPENCLAW_REMOTE_USER:-openclaw}"
REMOTE_HOME="${OPENCLAW_REMOTE_HOME:-/var/lib/openclaw}"
REMOTE_HOST_TAILNET="${OPENCLAW_HOST_TAILNET:-ai-node-01.tail4bbda6.ts.net}"
REMOTE_HOST_LAN="${OPENCLAW_HOST_LAN:-192.168.1.24}"
DEFAULT_AGENT="${OPENCLAW_AGENT:-fury}"
POLL_SECONDS="${OPENCLAW_POLL_SECONDS:-2}"
TIMEOUT_SECONDS="${OPENCLAW_TIMEOUT_SECONDS:-120}"
ALL_AGENTS=0
JSON=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_session_follow.sh [options]

Options:
  --agent <id>       Agent to watch (default: fury)
  --all-agents       Watch across all agents
  --tailnet          Use ai-node-01 tailnet hostname (default)
  --lan              Use ai-node-01 LAN IP
  --user <ssh-user>  SSH user for the host (default: labadmin)
  --remote-user <u>  Remote OpenClaw user (default: openclaw)
  --poll <sec>       Poll interval in seconds (default: 2)
  --timeout <sec>    Maximum wait time in seconds (default: 120)
  --json             Return the raw latest session JSON once a change is seen
  -h, --help         Show help

Examples:
  scripts/openclaw_session_follow.sh
  scripts/openclaw_session_follow.sh --agent fury --timeout 180
  scripts/openclaw_session_follow.sh --all-agents --json
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
    --poll)
      POLL_SECONDS="${2:-}"
      if [[ -z "$POLL_SECONDS" ]]; then
        echo "Error: --poll requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      if [[ -z "$TIMEOUT_SECONDS" ]]; then
        echo "Error: --timeout requires a value" >&2
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

fetch_sessions() {
  local remote_cmd
  remote_cmd="sudo -u $(shell_quote "$REMOTE_USER") -H env HOME=$(shell_quote "$REMOTE_HOME") openclaw sessions"
  if [[ "$ALL_AGENTS" -eq 1 ]]; then
    remote_cmd+=" --all-agents"
  else
    remote_cmd+=" --agent $(shell_quote "$DEFAULT_AGENT")"
  fi
  remote_cmd+=' --json'

  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${REMOTE_HOST}" "$remote_cmd"
}

SESSION_JSON="$(fetch_sessions)"
BASELINE_JSON="$SESSION_JSON"

while [[ $TIMEOUT_SECONDS -gt 0 ]]; do
  CURRENT_JSON="$(fetch_sessions)"
  if [[ "$CURRENT_JSON" != "$BASELINE_JSON" ]]; then
    SESSION_JSON="$CURRENT_JSON"
    break
  fi
  sleep "$POLL_SECONDS"
  TIMEOUT_SECONDS=$((TIMEOUT_SECONDS - POLL_SECONDS))
done

if [[ "$JSON" -eq 1 ]]; then
  printf '%s\n' "$SESSION_JSON"
  exit 0
fi

python3 -c "import json,sys; data=json.load(sys.stdin); sessions=data.get('sessions') or []; \
sys.exit(0) if not sessions else None; \
latest=max(sessions, key=lambda s: s.get('updatedAt', 0)); \
print(f\"{latest.get('key', '<unknown>')} | {latest.get('modelProvider', '<unknown>')}/{latest.get('model', '<unknown>')} | age={latest.get('ageMs', 'unknown')}ms | tokens={latest.get('totalTokens', 'unknown')}/{latest.get('contextTokens', 'unknown')}\")" <<<"$SESSION_JSON"
