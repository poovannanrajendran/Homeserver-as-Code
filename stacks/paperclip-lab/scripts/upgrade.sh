#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/backup-db.sh
docker compose build --pull paperclip
docker compose up -d
docker compose ps
