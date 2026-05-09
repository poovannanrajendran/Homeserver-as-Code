#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/backup-cli-auth.sh || true

docker compose exec paperclip sh -lc '
  set -e

  echo "Claude:"
  if claude auth status 2>/dev/null | grep -q "\"loggedIn\": true"; then
    echo "already logged in"
  elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "ANTHROPIC_API_KEY is set; Claude can use API auth"
  else
    echo "starting interactive Claude login..."
    claude auth login --claudeai
  fi

  echo
  echo "Codex:"
  if codex login status 2>&1 | grep -qi "logged in"; then
    echo "already logged in"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    echo "using OPENAI_API_KEY for Codex login"
    printenv OPENAI_API_KEY | codex login --with-api-key
  else
    echo "starting interactive Codex login..."
    codex login
  fi

  echo
  echo "Gemini:"
  if [ -n "${GEMINI_API_KEY:-}" ]; then
    echo "GEMINI_API_KEY is set; Gemini can use API auth"
  else
    echo "starting interactive Gemini session for login..."
    echo "If Gemini prompts for Google login, complete it in the browser and then exit the CLI."
    gemini
  fi
'
