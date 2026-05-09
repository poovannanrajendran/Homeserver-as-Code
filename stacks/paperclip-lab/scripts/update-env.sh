#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "missing .env; copy .env.example first" >&2
  exit 1
fi

if [ "$#" -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
  cat >&2 <<'EOF'
Usage:
  ./scripts/update-env.sh KEY VALUE [KEY VALUE ...]

Examples:
  ./scripts/update-env.sh PAPERCLIP_THEME_NAME paperclip-locallab-blue
  ./scripts/update-env.sh PAPERCLIP_PUBLIC_URL http://localhost:3102 OPENAI_API_KEY sk-...
EOF
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

auth_backup=""
if docker compose ps -q paperclip >/dev/null 2>&1; then
  auth_backup="$(./scripts/backup-cli-auth.sh 2>/dev/null || true)"
fi

python3 - "$@" > "$tmp_file" <<'PY'
import pathlib
import sys

env_path = pathlib.Path(".env")
lines = env_path.read_text().splitlines()
updates = dict(zip(sys.argv[1::2], sys.argv[2::2]))
seen = set()
out = []

for line in lines:
    stripped = line.lstrip()
    if not stripped or stripped.startswith("#") or "=" not in line:
        out.append(line)
        continue
    key, _, value = line.partition("=")
    if key in updates:
        out.append(f"{key}={updates[key]}")
        seen.add(key)
    else:
        out.append(line)

for key, value in updates.items():
    if key not in seen:
        out.append(f"{key}={value}")

sys.stdout.write("\n".join(out) + "\n")
PY

mv "$tmp_file" .env
echo "Updated .env"

docker compose up -d --build --force-recreate paperclip
if [ -n "$auth_backup" ] && [ -f "$auth_backup" ]; then
  ./scripts/restore-cli-auth.sh "$auth_backup"
fi
docker compose ps paperclip
