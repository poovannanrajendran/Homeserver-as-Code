#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0

check() {
  local label="$1"
  shift
  printf "%-30s : " "$label"
  if "$@"; then
    echo "ok"
  else
    echo "fail"
    fail=1
  fi
}

echo "Paperclip lab doctor"
echo "--------------------"

check ".env present" test -f .env
check "docker available" sh -lc 'docker version >/dev/null 2>&1'
check "paperclip service" sh -lc 'docker compose ps --status running paperclip >/dev/null 2>&1'
check "postgres service" sh -lc 'docker compose ps --status running postgres >/dev/null 2>&1'
check "port 3102 listening" sh -lc 'python3 -c "import os,socket,sys; p=int(os.environ.get(\"PAPERCLIP_HOST_PORT\",\"3102\")); s=socket.socket(); s.settimeout(2); 
try: s.connect((\"127.0.0.1\", p))
except OSError: sys.exit(1)
finally: s.close()"'
check "lab health endpoint" sh -lc 'curl -fsS "http://localhost:${PAPERCLIP_HOST_PORT:-3102}/api/health" >/dev/null'
check "claude installed" sh -lc 'docker compose exec -T paperclip sh -lc "command -v claude >/dev/null"'
check "gemini installed" sh -lc 'docker compose exec -T paperclip sh -lc "command -v gemini >/dev/null"'
check "codex installed" sh -lc 'docker compose exec -T paperclip sh -lc "command -v codex >/dev/null"'

if [ -f .env ]; then
  echo
  echo "Key env summary:"
  ./scripts/show-env.sh | sed -n '1,20p'
fi

exit "$fail"
