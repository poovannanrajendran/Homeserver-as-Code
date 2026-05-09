#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p backups
backup="backups/cli-auth-$(date +%Y%m%d-%H%M%S).tar.gz"

if [ -z "$(docker compose ps -q paperclip 2>/dev/null || true)" ]; then
  echo "paperclip container is not available; skipping auth backup" >&2
  exit 0
fi

docker compose exec -T paperclip sh -lc '
  set -e
  cd "$HOME"
  paths=""
  for path in .claude .claude.json .config/gemini .codex .gemini; do
    if [ -e "$path" ]; then
      paths="$paths $path"
    fi
  done
  if [ -z "$paths" ]; then
    exit 0
  fi
  # shellcheck disable=SC2086
  tar -czf - $paths
' > "$backup"

echo "$backup"
