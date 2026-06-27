#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
docker compose ps
curl -fsS "http://localhost:${PAPERCLIP_HOST_PORT:-3102}/api/health"
echo
