#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

force=0
if [ "${1:-}" = "--force" ]; then
  force=1
fi

relevant_changes="$(git status --porcelain --untracked-files=all -- paperclip/poovi_papercompany stacks/paperclip-lab docs/runbooks/paperclip-local-docker-lab.md | sed '/^$/d' || true)"

if [ "$force" -eq 0 ] && [ -z "$relevant_changes" ]; then
  echo "No paperclip-relevant changes detected. Skipping rebuild."
  exit 0
fi

if [ -n "$relevant_changes" ]; then
  echo "Relevant changes detected:"
  printf '%s\n' "$relevant_changes"
fi

docker compose up -d --build --force-recreate paperclip
docker compose ps paperclip
