#!/usr/bin/env bash
set -euo pipefail

# Send a prompt into the live OpenClaw Telegram ingress from a terminal.
# By default this targets the latest Telegram session for fury, so it is useful
# for quick smoke tests and routing checks.

HOST_MODE="${OPENCLAW_HOST_MODE:-tailnet}"
SSH_USER="${OPENCLAW_SSH_USER:-labadmin}"
REMOTE_USER="${OPENCLAW_REMOTE_USER:-openclaw}"
REMOTE_HOME="${OPENCLAW_REMOTE_HOME:-/var/lib/openclaw}"
REMOTE_HOST_TAILNET="${OPENCLAW_HOST_TAILNET:-ai-node-01.tail4bbda6.ts.net}"
REMOTE_HOST_LAN="${OPENCLAW_HOST_LAN:-192.168.1.24}"
DEFAULT_AGENT="${OPENCLAW_AGENT:-fury}"
CHANNEL="${OPENCLAW_CHANNEL:-telegram}"
ACCOUNT="${OPENCLAW_ACCOUNT:-default}"
TARGET="${OPENCLAW_TARGET:-}"
MESSAGE=""
USE_STDIN=0
JSON=0
DRY_RUN=0
SILENT=0
REPLY_TO=""
THREAD_ID=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_send.sh [options] [message]

Options:
  --agent <id>         Agent whose latest Telegram session should be targeted (default: fury)
  --target <dest>      Explicit Telegram chat id or @username
  --channel <name>     Channel to send through (default: telegram)
  --account <id>       Channel account id (default: default)
  --tailnet            Use ai-node-01 tailnet hostname (default)
  --lan                Use ai-node-01 LAN IP
  --user <ssh-user>    SSH user for the host (default: labadmin)
  --remote-user <u>    Remote OpenClaw user (default: openclaw)
  --message <text>     Message body
  --stdin              Read message body from stdin
  --reply-to <id>      Reply to a specific message id
  --thread-id <id>     Telegram forum thread id
  --silent             Send silently
  --dry-run            Print the payload without sending
  --json               Return JSON from OpenClaw
  -h, --help           Show help

Examples:
  scripts/openclaw_send.sh --agent fury "Give me 5 LinkedIn post ideas about AI agents in Lloyd's market."
  scripts/openclaw_send.sh --target 5753819446 --message "Smoke test from terminal"
  echo "Write a concise LinkedIn post about Blueprint Two." | scripts/openclaw_send.sh --stdin
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
    --target)
      TARGET="${2:-}"
      if [[ -z "$TARGET" ]]; then
        echo "Error: --target requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --channel)
      CHANNEL="${2:-}"
      if [[ -z "$CHANNEL" ]]; then
        echo "Error: --channel requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --account)
      ACCOUNT="${2:-}"
      if [[ -z "$ACCOUNT" ]]; then
        echo "Error: --account requires a value" >&2
        exit 1
      fi
      shift 2
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
    --message)
      MESSAGE="${2:-}"
      if [[ -z "$MESSAGE" ]]; then
        echo "Error: --message requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --stdin)
      USE_STDIN=1
      shift
      ;;
    --reply-to)
      REPLY_TO="${2:-}"
      if [[ -z "$REPLY_TO" ]]; then
        echo "Error: --reply-to requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --thread-id)
      THREAD_ID="${2:-}"
      if [[ -z "$THREAD_ID" ]]; then
        echo "Error: --thread-id requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --silent)
      SILENT=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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
      if [[ -z "$MESSAGE" ]]; then
        MESSAGE="$1"
        shift
      else
        echo "Error: unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$MESSAGE" && "$USE_STDIN" -eq 1 ]]; then
  MESSAGE="$(cat)"
fi

if [[ -z "$MESSAGE" ]]; then
  if [[ ! -t 0 ]]; then
    MESSAGE="$(cat)"
  fi
fi

if [[ -z "$MESSAGE" ]]; then
  echo "Error: message body is required. Pass it as an argument or use --stdin." >&2
  exit 1
fi

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

if [[ -z "$TARGET" ]]; then
  SESSION_JSON="$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${REMOTE_HOST}" \
    sudo -u "$REMOTE_USER" -H env HOME="$REMOTE_HOME" openclaw sessions --agent "$DEFAULT_AGENT" --json 2>/dev/null || true)"

  TARGET="$(
    AGENT="$DEFAULT_AGENT" python3 -c '
import json
import os
import sys

agent = os.environ.get("AGENT", "")
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

sessions = data.get("sessions") or []
candidates = []
for session in sessions:
    key = session.get("key", "")
    if key.startswith(f"agent:{agent}:telegram:"):
        parts = key.split(":")
        if len(parts) >= 5:
            candidates.append((session.get("updatedAt", 0), parts[-1], key))

if not candidates:
    sys.exit(1)

candidates.sort(key=lambda item: item[0], reverse=True)
print(candidates[0][1])
' <<<"$SESSION_JSON"
  )" || true
fi

if [[ -z "$TARGET" ]]; then
  echo "Error: could not infer a Telegram target for agent '$DEFAULT_AGENT'." >&2
  echo "Set OPENCLAW_TARGET or pass --target explicitly." >&2
  exit 1
fi

SEND_CMD=(
  openclaw message send
  --channel "$CHANNEL"
  --account "$ACCOUNT"
  --target "$TARGET"
  --message "$MESSAGE"
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  SEND_CMD+=(--dry-run)
fi
if [[ "$JSON" -eq 1 ]]; then
  SEND_CMD+=(--json)
fi
if [[ "$SILENT" -eq 1 ]]; then
  SEND_CMD+=(--silent)
fi
if [[ -n "$REPLY_TO" ]]; then
  SEND_CMD+=(--reply-to "$REPLY_TO")
fi
if [[ -n "$THREAD_ID" ]]; then
  SEND_CMD+=(--thread-id "$THREAD_ID")
fi

echo "[INFO] host=${REMOTE_HOST} agent=${DEFAULT_AGENT} channel=${CHANNEL} account=${ACCOUNT} target=${TARGET}" >&2

REMOTE_SEND_CMD="HOME=$(shell_quote "$REMOTE_HOME")"
for arg in "${SEND_CMD[@]}"; do
  REMOTE_SEND_CMD+=" $(shell_quote "$arg")"
done

exec ssh "${SSH_OPTS[@]}" "${SSH_USER}@${REMOTE_HOST}" sudo -u "$REMOTE_USER" -H bash -lc "$REMOTE_SEND_CMD"
