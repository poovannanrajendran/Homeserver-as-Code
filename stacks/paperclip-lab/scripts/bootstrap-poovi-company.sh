#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose exec paperclip paperclipai company import /companies/poovi_papercompany \
  --target new \
  --new-company-name "Poovi Paper Company" \
  --include company,agents,tasks,skills \
  --collision rename \
  --api-base http://127.0.0.1:3102 \
  --yes
