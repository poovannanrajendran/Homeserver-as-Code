#!/usr/bin/env bash
set -euo pipefail

# Draft a LinkedIn post through LOKI and save the result as a durable artifact.
# This does not publish; it creates the handoff object for a separate publisher.

HOST_MODE="${OPENCLAW_HOST_MODE:-tailnet}"
SSH_USER="${OPENCLAW_SSH_USER:-labadmin}"
REMOTE_USER="${OPENCLAW_REMOTE_USER:-openclaw}"
DEFAULT_AGENT="${OPENCLAW_LINKEDIN_AGENT:-loki}"
OUTPUT_DIR="${OPENCLAW_LINKEDIN_DRAFT_DIR:-output/linkedin/drafts}"
SCHEMA_VERSION=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESSAGE=""
USE_STDIN=0
JSON=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_linkedin_draft.sh [options] [message]

Options:
  --agent <id>         Writer agent (default: loki)
  --output-dir <path>  Where to write the draft artifact (default: output/linkedin/drafts)
  --tailnet            Use ai-node-01 tailnet hostname (default)
  --lan                Use ai-node-01 LAN IP
  --user <ssh-user>    SSH user for the host (default: labadmin)
  --remote-user <u>    Remote OpenClaw user (default: openclaw)
  --message <text>     Message body
  --stdin              Read message body from stdin
  --json               Print the saved artifact as JSON
  -h, --help           Show help

Examples:
  scripts/openclaw_linkedin_draft.sh "Write a post about Blueprint Two."
  echo "Write a post about Lloyd's AI agents." | scripts/openclaw_linkedin_draft.sh --stdin --json
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
    --output-dir)
      OUTPUT_DIR="${2:-}"
      if [[ -z "$OUTPUT_DIR" ]]; then
        echo "Error: --output-dir requires a value" >&2
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

if [[ -z "$MESSAGE" && ! -t 0 ]]; then
  MESSAGE="$(cat)"
fi

if [[ -z "$MESSAGE" ]]; then
  echo "Error: message body is required. Pass it as an argument or use --stdin." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TURN_ARGS=(
  "--${HOST_MODE}"
  --user "$SSH_USER"
  --remote-user "$REMOTE_USER"
  --agent "$DEFAULT_AGENT"
  --thinking off
  --timeout 300
  --json
  --message "$MESSAGE"
)
TURN_OUTPUT="$("$SCRIPT_DIR/openclaw_agent_turn.sh" \
  "${TURN_ARGS[@]}")"

OPENCLAW_TURN_OUTPUT="$TURN_OUTPUT" python3 - "$OUTPUT_DIR" "$DEFAULT_AGENT" "$MESSAGE" "$JSON" "$SCHEMA_VERSION" <<'PY'
import datetime as dt
import json
import os
import pathlib
import re
import sys

out_dir = pathlib.Path(sys.argv[1])
agent = sys.argv[2]
prompt = sys.argv[3]
json_flag = sys.argv[4] == "1"
schema_version = int(sys.argv[5])

raw = os.environ.get("OPENCLAW_TURN_OUTPUT", "")
start = raw.find("{")
if start < 0:
    raise SystemExit("Could not parse OpenClaw JSON output.")

decoder = json.JSONDecoder()
result, _ = decoder.raw_decode(raw[start:])
payloads = ((result.get("result") or {}).get("payloads")) or []
texts = []
for payload in payloads:
    if isinstance(payload, dict) and payload.get("text"):
        text = payload["text"].strip()
        if text:
            texts.append(text)

content = texts[-1] if texts else None

if not content:
    raise SystemExit("No draft content returned by the writer agent.")

meta = result.get("result", {}).get("meta", {})
agent_meta = meta.get("agentMeta", {})
now = dt.datetime.now(dt.timezone.utc)
timestamp = now.strftime("%Y%m%dT%H%M%SZ")
slug_source = " ".join(content.split()[:8]).lower()
slug = re.sub(r"[^a-z0-9]+", "-", slug_source).strip("-") or "linkedin"
draft_id = f"linkedin-{timestamp}-{slug}"
content_hash = __import__("hashlib").sha256(content.encode("utf-8")).hexdigest()
artifact_path = out_dir / f"{draft_id}.json"
tmp_path = artifact_path.with_name(f".{artifact_path.name}.tmp")

artifact = {
    "schemaVersion": schema_version,
    "artifactType": "linkedin_draft",
    "id": draft_id,
    "platform": "linkedin",
    "agent": agent,
    "status": "ready_to_publish",
    "createdAt": now.isoformat(),
    "content": content,
    "contentHash": content_hash,
    "draftOutput": {
        "selectionStrategy": "last_non_empty_text_payload",
        "textPayloads": texts,
        "selectedTextIndex": len(texts) - 1,
    },
    "source": {
        "tool": "openclaw_agent_turn",
        "sessionId": agent_meta.get("sessionId"),
        "sessionFile": agent_meta.get("sessionFile"),
        "provider": agent_meta.get("provider"),
        "model": agent_meta.get("model"),
        "durationMs": meta.get("durationMs"),
    },
    "prompt": prompt,
}

tmp_path.write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
tmp_path.replace(artifact_path)

if json_flag:
    print(json.dumps(artifact, indent=2))
else:
    print(f"Draft saved: {artifact_path}")
    print(f"Draft ID   : {draft_id}")
    print("Content:")
    print(content)
PY
