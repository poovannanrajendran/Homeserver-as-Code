#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "missing .env; copy .env.example first" >&2
  exit 1
fi

python3 - <<'PY'
import pathlib

env_path = pathlib.Path(".env")
data = {}

for raw in env_path.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in raw:
        continue
    key, value = raw.split("=", 1)
    data[key] = value

rows = [
    ("PAPERCLIP_VERSION", data.get("PAPERCLIP_VERSION", "")),
    ("PAPERCLIP_INSTANCE_ID", data.get("PAPERCLIP_INSTANCE_ID", "")),
    ("PAPERCLIP_HOST_PORT", data.get("PAPERCLIP_HOST_PORT", "")),
    ("PAPERCLIP_PUBLIC_URL", data.get("PAPERCLIP_PUBLIC_URL", "")),
    ("PAPERCLIP_THEME_NAME", data.get("PAPERCLIP_THEME_NAME", "")),
    ("PAPERCLIP_BRAND_COLOR", data.get("PAPERCLIP_BRAND_COLOR", "")),
    ("POSTGRES_USER", data.get("POSTGRES_USER", "")),
    ("POSTGRES_DB", data.get("POSTGRES_DB", "")),
    ("POSTGRES_PASSWORD", "set" if data.get("POSTGRES_PASSWORD") else "unset"),
    ("PAPERCLIP_AGENT_JWT_SECRET", "set" if data.get("PAPERCLIP_AGENT_JWT_SECRET") else "unset"),
    ("N8N_MCP_URL", data.get("N8N_MCP_URL", "")),
    ("N8N_MCP_BEARER_TOKEN", "set" if data.get("N8N_MCP_BEARER_TOKEN") else "unset"),
    ("LOCAL_MAC_MCP_URL", data.get("LOCAL_MAC_MCP_URL", "")),
    ("OLLAMA_BASE_URL", data.get("OLLAMA_BASE_URL", "")),
    ("OLLAMA_OPENAI_BASE_URL", data.get("OLLAMA_OPENAI_BASE_URL", "")),
    ("POOVI_GROUNDING_PACK_PATH", data.get("POOVI_GROUNDING_PACK_PATH", "")),
    ("ANTHROPIC_API_KEY", "set" if data.get("ANTHROPIC_API_KEY") else "unset"),
    ("OPENAI_API_KEY", "set" if data.get("OPENAI_API_KEY") else "unset"),
    ("GEMINI_API_KEY", "set" if data.get("GEMINI_API_KEY") else "unset"),
    ("OPENROUTER_API_KEY", "set" if data.get("OPENROUTER_API_KEY") else "unset"),
    ("X_API_KEY", "set" if data.get("X_API_KEY") else "unset"),
    ("X_API_SECRET", "set" if data.get("X_API_SECRET") else "unset"),
]

width = max(len(name) for name, _ in rows)
for name, value in rows:
    print(f"{name.ljust(width)} : {value}")
PY
