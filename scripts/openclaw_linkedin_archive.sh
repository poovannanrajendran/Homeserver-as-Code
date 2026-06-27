#!/usr/bin/env bash
set -euo pipefail

# Archive a successful LinkedIn publish into Mem0 and a local published record.
# Input is a draft artifact produced by openclaw_linkedin_draft.sh.

HOST_MODE="${OPENCLAW_HOST_MODE:-tailnet}"
SSH_USER="${OPENCLAW_SSH_USER:-labadmin}"
REMOTE_USER="${OPENCLAW_REMOTE_USER:-openclaw}"
REMOTE_HOST_TAILNET="${OPENCLAW_HOST_TAILNET:-ai-node-01.tail4bbda6.ts.net}"
REMOTE_HOST_LAN="${OPENCLAW_HOST_LAN:-192.168.1.24}"
DEFAULT_AGENT="${OPENCLAW_LINKEDIN_ARCHIVE_AGENT:-loki}"
OUTPUT_DIR="${OPENCLAW_LINKEDIN_PUBLISHED_DIR:-output/linkedin/published}"
SCHEMA_VERSION=1
MEM0_TIMEOUT="${OPENCLAW_MEM0_TIMEOUT:-45}"
JSON=0
DRAFT_FILE=""
CONTENT=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/openclaw_linkedin_archive.sh [options]

Options:
  --draft-file <path>  Draft artifact produced by openclaw_linkedin_draft.sh (preferred)
  --content <text>     Raw post content for recovery only
  --agent <id>         Memory namespace agent (default: loki)
  --output-dir <path>  Where to write the published record (default: output/linkedin/published)
  --tailnet            Use ai-node-01 tailnet hostname (default)
  --lan                Use ai-node-01 LAN IP
  --user <ssh-user>    SSH user for the host (default: labadmin)
  --remote-user <u>    Remote OpenClaw user (default: openclaw)
  --json               Print the archived record as JSON
  -h, --help           Show help

Examples:
  scripts/openclaw_linkedin_archive.sh --draft-file output/linkedin/drafts/<id>.json
  cat post.json | scripts/openclaw_linkedin_archive.sh --content "$(jq -r .content post.json)"
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft-file)
      DRAFT_FILE="${2:-}"
      if [[ -z "$DRAFT_FILE" ]]; then
        echo "Error: --draft-file requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --content)
      CONTENT="${2:-}"
      if [[ -z "$CONTENT" ]]; then
        echo "Error: --content requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
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

if [[ -z "$DRAFT_FILE" && -z "$CONTENT" ]]; then
  if [[ ! -t 0 ]]; then
    CONTENT="$(cat)"
  fi
fi

if [[ -z "$DRAFT_FILE" && -z "$CONTENT" ]]; then
  echo "Error: content is required. Pass --draft-file or --content." >&2
  exit 1
fi

REMOTE_HOST="$REMOTE_HOST_TAILNET"
if [[ "$HOST_MODE" == "lan" ]]; then
  REMOTE_HOST="$REMOTE_HOST_LAN"
fi

mkdir -p "$OUTPUT_DIR"

python3 - "$OUTPUT_DIR" "$DRAFT_FILE" "$CONTENT" "$DEFAULT_AGENT" "$JSON" "$SSH_USER" "$REMOTE_HOST" "$REMOTE_USER" "$MEM0_TIMEOUT" "$SCHEMA_VERSION" <<'PY'
import datetime as dt
import base64
import hashlib
import json
import os
import pathlib
import shlex
import subprocess
import sys
import tempfile

output_dir = pathlib.Path(sys.argv[1])
draft_file = sys.argv[2] or ""
content_arg = sys.argv[3]
agent = sys.argv[4]
json_flag = sys.argv[5] == "1"
ssh_user = sys.argv[6]
remote_host = sys.argv[7]
remote_user = sys.argv[8]
mem0_timeout = int(sys.argv[9])
schema_version = int(sys.argv[10])

def write_json_atomic(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=str(path.parent),
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as tmp:
            tmp_name = tmp.name
            json.dump(payload, tmp, indent=2)
            tmp.write("\n")
        pathlib.Path(tmp_name).replace(path)
    finally:
        if tmp_name and pathlib.Path(tmp_name).exists():
            try:
                pathlib.Path(tmp_name).unlink()
            except OSError:
                pass

def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()

def load_draft(path_str: str):
    path = pathlib.Path(path_str)
    if not path.is_file():
        raise SystemExit(f"Error: draft file not found: {path}")
    draft = json.loads(path.read_text(encoding="utf-8"))
    if draft.get("schemaVersion") != schema_version:
        raise SystemExit(
            f"Unsupported draft schemaVersion: {draft.get('schemaVersion')!r} "
            f"(expected {schema_version})"
        )
    if draft.get("artifactType") != "linkedin_draft":
        raise SystemExit(
            f"Unsupported draft artifactType: {draft.get('artifactType')!r} "
            "(expected 'linkedin_draft')"
        )
    if draft.get("platform") != "linkedin":
        raise SystemExit(
            f"Unsupported draft platform: {draft.get('platform')!r} "
            "(expected 'linkedin')"
        )
    if draft.get("status") != "ready_to_publish":
        raise SystemExit(
            f"Draft artifact is not ready to publish: {draft.get('status')!r}"
        )
    content = (draft.get("content") or "").strip()
    if not content:
        raise SystemExit("Draft artifact does not contain content.")
    content_hash = draft.get("contentHash") or sha256_text(content)
    source_draft = {
        "id": draft.get("id"),
        "artifactType": draft.get("artifactType"),
        "schemaVersion": draft.get("schemaVersion"),
        "platform": draft.get("platform"),
        "agent": draft.get("agent"),
        "status": draft.get("status"),
        "createdAt": draft.get("createdAt"),
        "contentHash": content_hash,
        "prompt": draft.get("prompt"),
        "source": draft.get("source"),
        "draftOutput": draft.get("draftOutput"),
        "artifactPath": str(path.resolve()),
    }
    return source_draft, content, content_hash

if draft_file:
    source_draft, content, content_hash = load_draft(draft_file)
    input_mode = "draft-file"
else:
    source_draft = None
    content = content_arg.strip()
    content_hash = sha256_text(content)
    input_mode = "raw-content"

if not content:
    raise SystemExit("Error: content is required. Pass --draft-file or --content.")

now = dt.datetime.now(dt.timezone.utc)
timestamp = now.strftime("%Y%m%dT%H%M%SZ")
slug_source = " ".join(content.split()[:8]).lower()
slug = "".join(ch if ch.isalnum() else "-" for ch in slug_source)
slug = "-".join(part for part in slug.split("-") if part) or "linkedin"
published_id = f"linkedin-{timestamp}-{slug}"
published_path = output_dir / f"{published_id}.json"

record = {
    "schemaVersion": schema_version,
    "artifactType": "linkedin_published",
    "id": published_id,
    "platform": "linkedin",
    "agent": agent,
    "status": "published",
    "publishedAt": now.isoformat(),
    "content": content,
    "contentHash": content_hash,
    "inputMode": input_mode,
    "sourceDraft": source_draft,
    "memory": {
        "status": "pending",
        "archived": False,
        "result": None,
    },
}

write_json_atomic(published_path, record)

memory_text = f"Published LinkedIn post for Poovi via {agent}.\n\n{content}"
memory_text_b64 = base64.b64encode(memory_text.encode("utf-8")).decode("ascii")
known_hosts = os.path.expanduser("~/.ssh/known_hosts")
node_script = f"""
import fs from 'node:fs';
import {{ Memory }} from '/var/lib/openclaw/.openclaw/extensions/openclaw-mem0/node_modules/mem0ai/dist/oss/index.mjs';

const raw = Buffer.from(process.env.MEMORY_TEXT_B64 || '', 'base64').toString('utf8').trim();
if (!raw) {{
  throw new Error('MEMORY_TEXT_B64 is missing or empty');
}}

const qdrantApiKey = process.env.QDRANT_API_KEY;
if (!qdrantApiKey) {{
  throw new Error('QDRANT_API_KEY is missing from the environment');
}}

const plugin = JSON.parse(fs.readFileSync('/var/lib/openclaw/.openclaw/openclaw.json', 'utf8')).plugins.entries['openclaw-mem0'];
const cfg = plugin.config;
const mem = new Memory({{
  mode: cfg.mode,
  userId: cfg.userId,
  searchThreshold: cfg.searchThreshold,
  topK: cfg.topK,
  customInstructions: cfg.customInstructions,
  disableHistory: true,
  embedder: cfg.oss.embedder,
  llm: cfg.oss.llm,
  vectorStore: {{
    ...cfg.oss.vectorStore,
    config: {{
      ...cfg.oss.vectorStore.config,
      apiKey: qdrantApiKey,
      checkCompatibility: false,
    }},
  }},
}});

const result = await mem.add(raw, {{
  agentId: {agent!r},
  infer: false,
}});

console.log(JSON.stringify(result, null, 2));
"""
remote_cmd = (
    "sudo -u "
    + shlex.quote(remote_user)
    + " -H bash -lc "
    + shlex.quote(
        "export MEMORY_TEXT_B64="
        + shlex.quote(memory_text_b64)
        + "; set -a; . /etc/openclaw/mem0.env; set +a; "
        "node --input-type=module <<'NODE'\n"
        + node_script
        + "\nNODE"
    )
)
cmd = [
    "ssh",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    f"UserKnownHostsFile={known_hosts}",
    f"{ssh_user}@{remote_host}",
    remote_cmd,
]

status = 0
try:
    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=mem0_timeout,
        check=False,
    )
    mem0_output = proc.stdout.decode("utf-8", errors="replace")
    status = proc.returncode
except subprocess.TimeoutExpired as exc:
    mem0_output = ""
    if exc.stdout:
        mem0_output += exc.stdout.decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else str(exc.stdout)
    if exc.stderr:
        mem0_output += exc.stderr.decode("utf-8", errors="replace") if isinstance(exc.stderr, bytes) else str(exc.stderr)
    mem0_output = mem0_output or f"Timed out after {mem0_timeout}s"
    status = 124

record = json.loads(published_path.read_text(encoding="utf-8"))
record["memory"] = {
    "status": "ok" if status == 0 else "failed",
    "archived": status == 0,
    "result": mem0_output,
}
if status != 0:
    record["memory"]["error"] = mem0_output.strip()
write_json_atomic(published_path, record)

if json_flag:
    print(json.dumps(record, indent=2))
else:
    print(f"Published record saved: {published_path}")
    if source_draft:
        print(f"Draft ID          : {source_draft.get('id')}")
        print(f"Draft artifact    : {source_draft.get('artifactPath')}")
    if status == 0:
        print("Memory archived to agent namespace.")
    else:
        print("Memory archive failed; see memory.error in the record.")

raise SystemExit(status)
PY
