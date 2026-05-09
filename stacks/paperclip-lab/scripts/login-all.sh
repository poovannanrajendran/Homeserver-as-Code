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
  else
    echo "starting Codex device auth login..."
    codex login --device-auth
  fi

  echo
  echo "Gemini:"
  if [ -n "${GEMINI_API_KEY:-}" ]; then
    echo "GEMINI_API_KEY is set; Gemini can use API auth"
  elif [ -s "$HOME/.gemini/oauth_creds.json" ]; then
    account="$(jq -r '.active // empty' "$HOME/.gemini/google_accounts.json" 2>/dev/null || true)"
    mode="$(jq -r '.security.auth.selectedType // empty' "$HOME/.gemini/settings.json" 2>/dev/null || true)"
    if [ -n "$account" ] && [ -n "$mode" ]; then
      echo "OAuth subscription login active ($mode, account: $account)"
    elif [ -n "$account" ]; then
      echo "OAuth subscription login active (account: $account)"
    else
      echo "OAuth subscription login active"
    fi
  else
    echo "starting interactive Gemini session for login..."
    echo "If Gemini prompts for Google login, complete it in the browser and then exit the CLI."
    gemini
  fi
'
