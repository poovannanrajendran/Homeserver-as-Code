#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose exec paperclip sh -lc '
  set -e
  printf "claude: "
  claude --version
  printf "gemini: "
  gemini --version
  printf "codex: "
  codex --version
'
