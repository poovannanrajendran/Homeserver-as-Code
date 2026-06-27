#!/usr/bin/env bash
set -euo pipefail

#
# Remote deploy Outline + Authentik compose stacks to a docker host over SSH.
# Requires: ssh access (preferably SSH keys), and sudo on the target.
#
# Usage:
#   scripts/deploy_outline_authentik_remote.sh labadmin@192.168.1.20
#

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <user@host> [stack_root=/srv/stacks] [data_root=/srv/data]" >&2
  exit 1
fi

target="$1"
stack_root="${2:-/srv/stacks}"
data_root="${3:-/srv/data}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

auth_src="$repo_root/stacks/authentik/docker-compose.yml"
outline_src="$repo_root/stacks/outline/docker-compose.yml"
auth_env_src="$repo_root/examples/env/authentik.env.example"
outline_env_src="$repo_root/examples/env/outline.env.example"

for f in "$auth_src" "$outline_src" "$auth_env_src" "$outline_env_src"; do
  if [ ! -f "$f" ]; then
    echo "Missing file: $f" >&2
    exit 1
  fi
done

echo "[INFO] Target: $target"
echo "[INFO] Stack root: $stack_root"
echo "[INFO] Data root: $data_root"

ssh -o BatchMode=yes "$target" "true" 2>/dev/null || {
  echo "[ERROR] SSH BatchMode failed (no key auth). Setup SSH keys first, then retry." >&2
  echo "[HINT] On your laptop, run: ssh-copy-id $target" >&2
  exit 2
}

echo "[INFO] Creating directories on target..."
ssh "$target" "sudo mkdir -p '$stack_root/authentik' '$stack_root/outline' '$data_root/authentik' '$data_root/outline'; sudo chown \$(id -un):\$(id -gn) '$stack_root/authentik' '$stack_root/outline'"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/authentik" "$tmp_dir/outline"
cp "$auth_src" "$tmp_dir/authentik/docker-compose.yml"
cp "$outline_src" "$tmp_dir/outline/docker-compose.yml"

# Only seed .env if missing on the target (avoid clobbering user secrets).
cp "$auth_env_src" "$tmp_dir/authentik/.env.example"
cp "$outline_env_src" "$tmp_dir/outline/.env.example"

echo "[INFO] Uploading compose files..."
scp -q "$tmp_dir/authentik/docker-compose.yml" "$target:$stack_root/authentik/docker-compose.yml"
scp -q "$tmp_dir/outline/docker-compose.yml" "$target:$stack_root/outline/docker-compose.yml"
scp -q "$tmp_dir/authentik/.env.example" "$target:$stack_root/authentik/.env.example"
scp -q "$tmp_dir/outline/.env.example" "$target:$stack_root/outline/.env.example"

echo "[INFO] Seeding env examples (non-destructive)..."
ssh "$target" "test -f '$stack_root/authentik/.env' || cp '$stack_root/authentik/.env.example' '$stack_root/authentik/.env'; chmod 600 '$stack_root/authentik/.env'"
ssh "$target" "test -f '$stack_root/outline/.env' || cp '$stack_root/outline/.env.example' '$stack_root/outline/.env'; chmod 600 '$stack_root/outline/.env'"

if ssh "$target" "grep -Eq 'CHANGE_ME|<[^>]+>' '$stack_root/authentik/.env' '$stack_root/outline/.env'"; then
  echo "[STOP] Runtime .env files still contain placeholders; services were not started." >&2
  echo "[NEXT] Update these mode-0600 files, then rerun this script:" >&2
  echo "  - $stack_root/authentik/.env" >&2
  echo "  - $stack_root/outline/.env" >&2
  exit 3
fi

echo "[INFO] Starting stacks..."
ssh "$target" "cd '$stack_root/authentik' && docker compose up -d"
ssh "$target" "cd '$stack_root/outline' && docker compose up -d"

echo
echo "[INFO] Runtime secrets and URLs were loaded from ignored .env files:"
echo "  - $stack_root/authentik/.env"
echo "  - $stack_root/outline/.env"
echo
echo "[INFO] To reload after future secret changes:"
echo "  ssh $target 'cd $stack_root/outline && docker compose up -d'"
