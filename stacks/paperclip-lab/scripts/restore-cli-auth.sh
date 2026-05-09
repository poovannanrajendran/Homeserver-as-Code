#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

backup="${1:-}"
if [ -z "$backup" ] || [ ! -f "$backup" ]; then
  echo "usage: ./scripts/restore-cli-auth.sh backups/cli-auth-YYYYmmdd-HHMMSS.tar.gz" >&2
  exit 1
fi

docker compose exec -T paperclip sh -lc '
  set -e
  cd "$HOME"
  tar -xzf - -C "$HOME"
  chown -R paperclip:paperclip "$HOME/.claude" "$HOME/.claude.json" "$HOME/.config/gemini" "$HOME/.codex" "$HOME/.gemini" 2>/dev/null || true
' < "$backup"

echo "restored auth from $backup"
