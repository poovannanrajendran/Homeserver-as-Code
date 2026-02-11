#!/usr/bin/env bash
set -u
set -o pipefail

echo "[INFO] Backup preflight checks"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker not found"
  exit 1
fi

echo "[INFO] Docker version:"
docker --version

echo "[INFO] Running containers:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "[INFO] Key data paths:"
for p in /srv/data /srv/stacks /mnt/nextcloud-data /mnt/media-library /mnt/pbs-datastore; do
  if [ -e "$p" ]; then
    echo "  OK  $p"
  else
    echo "  MISS $p"
  fi
done
