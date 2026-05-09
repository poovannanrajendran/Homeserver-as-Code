#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

url="${PAPERCLIP_PUBLIC_URL:-http://localhost:${PAPERCLIP_HOST_PORT:-3102}}"

if command -v open >/dev/null 2>&1; then
  open "$url"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$url"
else
  echo "$url"
fi
