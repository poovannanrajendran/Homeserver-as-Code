#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose exec paperclip \
  paperclipai auth login \
  --api-base http://127.0.0.1:3102 \
  --instance-admin
