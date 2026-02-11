#!/usr/bin/env bash
set -u
set -o pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <stack-directory>"
  exit 1
fi

stack_dir="$1"
if [ ! -d "$stack_dir" ]; then
  echo "Stack directory not found: $stack_dir"
  exit 1
fi

if [ ! -f "$stack_dir/docker-compose.yml" ] && [ ! -f "$stack_dir/compose.yml" ]; then
  echo "No compose file found in: $stack_dir"
  exit 1
fi

echo "[INFO] Updating stack: $stack_dir"
cd "$stack_dir" || exit 1

docker compose pull && docker compose up -d --remove-orphans

echo "[INFO] Done."
