#!/usr/bin/env bash
set -euo pipefail

# Enables the built-in Nextcloud web updater by setting:
#   'upgrade.disable-web' => false
#
# Note: In Docker deployments, the recommended upgrade path is usually:
#   docker compose pull && docker compose up -d
# This script exists because sometimes you explicitly want the web updater UI.

stack_dir="${1:-/srv/stacks/nextcloud}"

if [ ! -d "$stack_dir" ]; then
  echo "Stack directory not found: $stack_dir" >&2
  exit 1
fi

cd "$stack_dir"

if [ ! -f docker-compose.yml ] && [ ! -f compose.yml ]; then
  echo "No compose file found in: $stack_dir" >&2
  exit 1
fi

if ! docker compose ps -q nextcloud >/dev/null 2>&1; then
  echo "Nextcloud service not found in this compose project (service name: nextcloud)" >&2
  exit 1
fi

if [ -z "$(docker compose ps -q nextcloud)" ]; then
  echo "Nextcloud container is not running. Start it first: docker compose up -d" >&2
  exit 1
fi

echo "[INFO] Enabling Nextcloud web updater (upgrade.disable-web=false)"
docker compose exec -T -u www-data -w /var/www/html nextcloud \
  php /var/www/html/occ config:system:set upgrade.disable-web --type=boolean --value=false

echo "[INFO] Current value:"
docker compose exec -T -u www-data -w /var/www/html nextcloud \
  php /var/www/html/occ config:system:get upgrade.disable-web || true

echo "[INFO] Web updater URL: http://<host>:8082/updater"
