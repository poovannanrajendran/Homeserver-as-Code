#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Paperclip provider auth status"
echo "------------------------------"

echo
echo "Claude:"
docker compose exec -T paperclip sh -lc 'claude auth status 2>/dev/null || true'

echo
echo "Codex:"
docker compose exec paperclip sh -lc 'codex login status 2>&1 || true'

echo
echo "Gemini:"
docker compose exec -T paperclip sh -lc '
  if [ -n "${GEMINI_API_KEY:-}" ]; then
    echo "API key set"
  elif [ -s "$HOME/.gemini/oauth_creds.json" ]; then
    account=$(jq -r ".active // empty" "$HOME/.gemini/google_accounts.json" 2>/dev/null || true)
    mode=$(jq -r ".security.auth.selectedType // empty" "$HOME/.gemini/settings.json" 2>/dev/null || true)
    if [ -n "$account" ] && [ -n "$mode" ]; then
      echo "OAuth subscription login active ($mode, account: $account)"
    elif [ -n "$account" ]; then
      echo "OAuth subscription login active (account: $account)"
    else
      echo "OAuth subscription login active"
    fi
  else
    echo "API key unset"
  fi
'

echo
echo "Auth files:"
docker compose exec -T paperclip sh -lc '
  for path in "$HOME/.claude" "$HOME/.claude.json" "$HOME/.config/gemini" "$HOME/.codex" "$HOME/.gemini"; do
    if [ -e "$path" ]; then
      echo "$path present"
    else
      echo "$path missing"
    fi
  done
'
