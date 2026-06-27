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
for p in /srv/data /srv/stacks /srv/backups/postgres/postgres /opt/children-email-digest /mnt/nextcloud-data /mnt/media-library /mnt/pbs-datastore; do
  if [ -e "$p" ] || sudo -n test -e "$p" 2>/dev/null; then
    echo "  OK  $p"
  else
    echo "  MISS $p"
  fi
done

echo "[INFO] Children Email Digest backup state:"
if docker ps --format '{{.Names}}' | grep -Fxq 'ced-app'; then
  echo "  OK  ced-app is running"
else
  echo "  MISS ced-app is not running"
fi

if docker exec postgres psql -U postgres -d children_email_digest -Atqc 'SELECT 1' 2>/dev/null | grep -Fxq '1'; then
  echo "  OK  children_email_digest accepts queries"
else
  echo "  MISS children_email_digest query failed"
fi

if [[ -r /srv/backups/postgres/postgres ]]; then
  latest_dump="$(find /srv/backups/postgres/postgres -mindepth 2 -maxdepth 2 -type f -name 'children_email_digest.dump' -print 2>/dev/null | sort | tail -n 1)"
else
  latest_dump="$(sudo -n find /srv/backups/postgres/postgres -mindepth 2 -maxdepth 2 -type f -name 'children_email_digest.dump' -print 2>/dev/null | sort | tail -n 1)"
fi
if [[ -n "${latest_dump}" ]]; then
  echo "  OK  latest logical dump: ${latest_dump}"
else
  echo "  MISS no children_email_digest logical dump found"
fi
