#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ "$#" -eq 1 ]; then
  case "$1" in
    *=*)
      key="${1%%=*}"
      value="${1#*=}"
      ;;
    *)
      echo "usage: ./scripts/set-env.sh KEY VALUE or KEY=VALUE" >&2
      exit 1
      ;;
  esac
elif [ "$#" -eq 2 ]; then
  key="$1"
  value="$2"
else
  cat >&2 <<'EOF'
Usage:
  ./scripts/set-env.sh KEY VALUE

Examples:
  ./scripts/set-env.sh PAPERCLIP_THEME_NAME paperclip-locallab-blue
  ./scripts/set-env.sh OPENROUTER_API_KEY sk-or-...
EOF
  exit 1
fi

if [[ ! "$key" =~ ^[A-Z0-9_]+$ ]]; then
  echo "invalid key: $key" >&2
  exit 1
fi

./scripts/update-env.sh "$key" "$value"
