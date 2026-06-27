#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source .env

docker compose exec paperclip \
  paperclipai auth bootstrap-ceo \
  --base-url "${PAPERCLIP_PUBLIC_URL:-http://localhost:${PAPERCLIP_HOST_PORT:-3102}}" \
  --expires-hours "${PAPERCLIP_BOOTSTRAP_INVITE_HOURS:-72}"
