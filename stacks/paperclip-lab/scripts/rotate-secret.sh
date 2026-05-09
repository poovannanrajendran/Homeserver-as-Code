#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "missing .env; copy .env.example first" >&2
  exit 1
fi

secret="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(48))
PY
)"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

python3 - "$secret" > "$tmp_file" <<'PY'
import pathlib
import sys

secret = sys.argv[1]
env_path = pathlib.Path(".env")
lines = env_path.read_text().splitlines()
seen = False
out = []

for line in lines:
    stripped = line.lstrip()
    if not stripped or stripped.startswith("#") or "=" not in line:
        out.append(line)
        continue
    key, _, value = line.partition("=")
    if key == "PAPERCLIP_AGENT_JWT_SECRET":
        out.append(f"{key}={secret}")
        seen = True
    else:
        out.append(line)

if not seen:
    out.append(f"PAPERCLIP_AGENT_JWT_SECRET={secret}")

sys.stdout.write("\n".join(out) + "\n")
PY

mv "$tmp_file" .env
echo "Updated .env"

instance_id="${PAPERCLIP_INSTANCE_ID:-paperclip-locallab}"
docker compose exec -T paperclip sh -lc "
  set -e
  instance_dir='/home/paperclip/.paperclip/instances/${instance_id}'
  mkdir -p \"\$instance_dir\"
  printf 'PAPERCLIP_AGENT_JWT_SECRET=%s\n' '${secret}' > \"\$instance_dir/.env\"
"

docker compose up -d --force-recreate paperclip
docker compose ps paperclip
echo "rotated PAPERCLIP_AGENT_JWT_SECRET"
