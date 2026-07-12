#!/usr/bin/env bash
set -euo pipefail

CONTAINERS_CSV="${POSTGRES_BACKUP_CONTAINERS:-postgres}"
BACKUP_ROOT="${POSTGRES_BACKUP_ROOT:-/srv/backups/postgres}"
KEEP_LAST="${POSTGRES_BACKUP_KEEP_LAST:-7}"
KEEP_WEEKLY="${POSTGRES_BACKUP_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${POSTGRES_BACKUP_KEEP_MONTHLY:-6}"
TIMESTAMP="$(date +%Y%m%dT%H%M%S%z)"
LOCK_FILE="/run/lock/postgres-container-backup.lock"

umask 077
install -d -m 0700 "${BACKUP_ROOT}"

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "[INFO] Another PostgreSQL container backup is already running."
  exit 0
fi

prune_generations() {
  local container_dir="$1"
  python3 - "${container_dir}" "${KEEP_LAST}" "${KEEP_WEEKLY}" "${KEEP_MONTHLY}" <<'PY'
import datetime as dt
import pathlib
import shutil
import sys

root = pathlib.Path(sys.argv[1])
keep_last, keep_weekly, keep_monthly = map(int, sys.argv[2:])
generations = []
for path in root.iterdir():
    if not path.is_dir() or path.name.startswith("."):
        continue
    try:
        timestamp = dt.datetime.strptime(path.name, "%Y%m%dT%H%M%S%z")
    except ValueError:
        continue
    generations.append((timestamp, path))

generations.sort(reverse=True)
keep = {path for _, path in generations[:keep_last]}

seen_weeks = set()
for timestamp, path in generations:
    iso = timestamp.isocalendar()
    key = (iso.year, iso.week)
    if key not in seen_weeks and len(seen_weeks) < keep_weekly:
        keep.add(path)
        seen_weeks.add(key)

seen_months = set()
for timestamp, path in generations:
    key = (timestamp.year, timestamp.month)
    if key not in seen_months and len(seen_months) < keep_monthly:
        keep.add(path)
        seen_months.add(key)

for _, path in generations:
    if path not in keep:
        shutil.rmtree(path)
PY
}

IFS=',' read -r -a containers <<< "${CONTAINERS_CSV}"
for container in "${containers[@]}"; do
  container="${container//[[:space:]]/}"
  [[ -n "${container}" ]] || continue

  if [[ "$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null)" != "true" ]]; then
    echo "[ERROR] PostgreSQL container '${container}' is not running." >&2
    exit 1
  fi

  admin_user="$(docker inspect "${container}" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_USER=//p' | head -n 1)"
  admin_user="${admin_user:-postgres}"
  container_dir="${BACKUP_ROOT}/${container}"
  final_dir="${container_dir}/${TIMESTAMP}"
  temp_dir="${container_dir}/.${TIMESTAMP}.tmp"

  install -d -m 0700 "${container_dir}"
  rm -rf "${temp_dir}"
  install -d -m 0700 "${temp_dir}"
  trap 'rm -rf "${temp_dir:-}"' EXIT

  docker exec "${container}" pg_dumpall \
    --username="${admin_user}" \
    --roles-only > "${temp_dir}/postgres_roles.sql"

  mapfile -t databases < <(
    docker exec "${container}" psql \
      --username="${admin_user}" \
      --dbname=postgres \
      --tuples-only \
      --no-align \
      --command="SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname"
  )

  for database in "${databases[@]}"; do
    [[ -n "${database}" ]] || continue
    safe_name="${database//\//_}"
    dump_file="${temp_dir}/${safe_name}.dump"
    docker exec "${container}" pg_dump \
      --username="${admin_user}" \
      --dbname="${database}" \
      --format=custom \
      --no-owner \
      --no-acl > "${dump_file}"
    test -s "${dump_file}"
    docker exec -i "${container}" pg_restore --list < "${dump_file}" >/dev/null
  done

  test -s "${temp_dir}/postgres_roles.sql"
  (
    cd "${temp_dir}"
    sha256sum ./*.dump ./postgres_roles.sql > SHA256SUMS
  )
  mv "${temp_dir}" "${final_dir}"
  trap - EXIT
  prune_generations "${container_dir}"
  echo "[OK] Backed up ${#databases[@]} databases and roles from ${container} to ${final_dir}."
done
