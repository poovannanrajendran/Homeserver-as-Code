#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
source .env
set +a

mkdir -p backups
backup="backups/paperclip-locallab-$(date +%Y%m%d-%H%M%S).sql.gz"
docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-paperclip}" "${POSTGRES_DB:-paperclip}" | gzip > "${backup}"
echo "${backup}"
