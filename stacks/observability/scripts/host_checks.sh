#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/srv/stacks/observability/textfile"
OUT_FILE="${OUT_DIR}/host_checks.prom"
TMP_FILE="$(mktemp)"
NOW="$(date +%s)"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"

ENV_FILE="/srv/stacks/observability/scripts/host_checks.env"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

# Defaults (override in host_checks.env)
PROXMOX_HOST="${PROXMOX_HOST:-192.168.1.250}"
VM_DOCKER_HOST="${VM_DOCKER_HOST:-192.168.1.20}"
VM_AI_NODE="${VM_AI_NODE:-192.168.1.24}"
VM_RUNNER="${VM_RUNNER:-192.168.1.30}"

PVE_SSH_USER="${PVE_SSH_USER:-root}"
PVE_SSH_PASS="${PVE_SSH_PASS:-}"
VM_SSH_USER="${VM_SSH_USER:-labadmin}"
VM_SSH_PASS="${VM_SSH_PASS:-}"

LLOYDS_PG_URL="${LLOYDS_PG_URL:-}"
MEMEX_PG_URL="${MEMEX_PG_URL:-}"
YT_PG_URL="${YT_PG_URL:-}"
SUPABASE_PG_URL="${SUPABASE_PG_URL:-}"
MONGO_ATLAS_HOST="${MONGO_ATLAS_HOST:-poovannnan.6r4o1.mongodb.net}"
MONGO_ATLAS_PORT="${MONGO_ATLAS_PORT:-27017}"

mkdir -p "${OUT_DIR}"

emit() {
  echo "$*" >> "${TMP_FILE}"
}

metric_label_escape() {
  echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

emit "# HELP obs_health_collector_run_timestamp Unix time when the collector ran."
emit "# TYPE obs_health_collector_run_timestamp gauge"
emit "obs_health_collector_run_timestamp{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\"} ${NOW}"

count_crons() {
  local total=0
  if [[ -f /etc/crontab ]]; then
    local c
    c="$(grep -Evc '^\s*($|#)' /etc/crontab || true)"
    total=$((total + c))
  fi
  if [[ -d /etc/cron.d ]]; then
    while IFS= read -r -d '' file; do
      local c
      c="$(grep -Evc '^\s*($|#)' "${file}" || true)"
      total=$((total + c))
    done < <(find /etc/cron.d -maxdepth 1 -type f -print0 2>/dev/null || true)
  fi
  local userc=0
  userc="$(crontab -l 2>/dev/null | grep -Evc '^\s*($|#)' || true)"
  total=$((total + userc))
  echo "${total}"
}

emit "# HELP obs_cron_jobs_total Number of active cron entries on this host."
emit "# TYPE obs_cron_jobs_total gauge"
emit "obs_cron_jobs_total{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",source=\"local\"} $(count_crons)"

remote_cron_count_cmd='(grep -Evc "^\s*($|#)" /etc/crontab 2>/dev/null || true); for f in /etc/cron.d/*; do [ -f "$f" ] && grep -Evc "^\s*($|#)" "$f" 2>/dev/null || true; done; (crontab -l 2>/dev/null | grep -Evc "^\s*($|#)" || true)'
remote_count() {
  local target="$1"
  local user="$2"
  local pass="$3"
  local cmd_out
  if [[ -n "${pass}" ]] && command -v sshpass >/dev/null 2>&1; then
    cmd_out="$(sshpass -p "${pass}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${user}@${target}" "${remote_cron_count_cmd}" 2>/dev/null || true)"
  else
    cmd_out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${user}@${target}" "${remote_cron_count_cmd}" 2>/dev/null || true)"
  fi
  local total=0
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    if [[ "${line}" =~ ^[0-9]+$ ]]; then
      total=$((total + line))
    fi
  done <<< "${cmd_out}"
  echo "${total}"
}

emit "obs_cron_jobs_total{host=\"${PROXMOX_HOST}\",source=\"remote\"} $(remote_count "${PROXMOX_HOST}" "${PVE_SSH_USER}" "${PVE_SSH_PASS}")"
for target in "${VM_DOCKER_HOST}" "${VM_AI_NODE}" "${VM_RUNNER}"; do
  emit "obs_cron_jobs_total{host=\"${target}\",source=\"remote\"} $(remote_count "${target}" "${VM_SSH_USER}" "${VM_SSH_PASS}")"
done

emit "# HELP obs_filesystem_used_percent Filesystem used percentage."
emit "# TYPE obs_filesystem_used_percent gauge"
declare -A seen_mounts=()
while read -r fs usep _rest; do
  usep="${usep%\%}"
  if [[ -n "${seen_mounts[${fs}]:-}" ]]; then
    continue
  fi
  seen_mounts["${fs}"]=1
  emit "obs_filesystem_used_percent{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",mount=\"$(metric_label_escape "${fs}")\"} ${usep}"
done < <(df -P / /var 2>/dev/null | awk 'NR>1 {print $6, $5}')

emit "# HELP obs_ping_up Host ping check (1=up,0=down)."
emit "# TYPE obs_ping_up gauge"
for target in "${PROXMOX_HOST}" "${VM_DOCKER_HOST}" "${VM_AI_NODE}" "${VM_RUNNER}"; do
  if ping -c 1 -W 2 "${target}" >/dev/null 2>&1; then
    emit "obs_ping_up{source=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",target=\"${target}\"} 1"
  else
    emit "obs_ping_up{source=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",target=\"${target}\"} 0"
  fi
done

emit "# HELP obs_ssh_up SSH TCP reachability check (1=up,0=down)."
emit "# TYPE obs_ssh_up gauge"
for target in "${PROXMOX_HOST}" "${VM_DOCKER_HOST}" "${VM_AI_NODE}" "${VM_RUNNER}"; do
  if timeout 3 bash -c "echo > /dev/tcp/${target}/22" >/dev/null 2>&1; then
    emit "obs_ssh_up{source=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",target=\"${target}\"} 1"
  else
    emit "obs_ssh_up{source=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",target=\"${target}\"} 0"
  fi
done

emit "# HELP obs_proxmox_https_up Proxmox UI HTTPS health (1=up,0=down)."
emit "# TYPE obs_proxmox_https_up gauge"
HTTP_CODE="$(curl -ksS -m 5 -o /dev/null -w '%{http_code}' "https://${PROXMOX_HOST}:8006/" || echo 000)"
if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "401" ]]; then
  emit "obs_proxmox_https_up{target=\"${PROXMOX_HOST}\",http_code=\"${HTTP_CODE}\"} 1"
else
  emit "obs_proxmox_https_up{target=\"${PROXMOX_HOST}\",http_code=\"${HTTP_CODE}\"} 0"
fi

emit "# HELP obs_mongo_atlas_tcp_up Mongo Atlas TCP check (1=up,0=down)."
emit "# TYPE obs_mongo_atlas_tcp_up gauge"
if timeout 5 bash -c "echo > /dev/tcp/${MONGO_ATLAS_HOST}/${MONGO_ATLAS_PORT}" >/dev/null 2>&1; then
  emit "obs_mongo_atlas_tcp_up{target=\"${MONGO_ATLAS_HOST}:${MONGO_ATLAS_PORT}\"} 1"
else
  emit "obs_mongo_atlas_tcp_up{target=\"${MONGO_ATLAS_HOST}:${MONGO_ATLAS_PORT}\"} 0"
fi

emit "# HELP obs_postgres_db_size_bytes PostgreSQL database size in bytes."
emit "# TYPE obs_postgres_db_size_bytes gauge"
emit "# HELP obs_postgres_query_ok PostgreSQL query check (1=up,0=down)."
emit "# TYPE obs_postgres_query_ok gauge"

pg_check() {
  local name="$1"
  local url="$2"
  if [[ -z "${url}" ]]; then
    emit "obs_postgres_query_ok{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 0"
    emit "obs_postgres_db_size_bytes{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 0"
    return
  fi

  if ! command -v psql >/dev/null 2>&1; then
    emit "obs_postgres_query_ok{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 0"
    emit "obs_postgres_db_size_bytes{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 0"
    return
  fi

  if timeout 8 psql "${url}" -Atqc "SELECT 1;" >/dev/null 2>&1; then
    emit "obs_postgres_query_ok{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 1"
    local size
    size="$(timeout 10 psql "${url}" -Atqc "SELECT pg_database_size(current_database());" 2>/dev/null || echo 0)"
    size="${size:-0}"
    if [[ ! "${size}" =~ ^[0-9]+$ ]]; then
      size=0
    fi
    emit "obs_postgres_db_size_bytes{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} ${size}"
  else
    emit "obs_postgres_query_ok{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 0"
    emit "obs_postgres_db_size_bytes{host=\"$(metric_label_escape "${HOSTNAME_FQDN}")\",db=\"${name}\"} 0"
  fi
}

pg_check "lloyds_digest_local" "${LLOYDS_PG_URL}"
pg_check "memex_local" "${MEMEX_PG_URL}"
pg_check "youtube_liked_videos_remote" "${YT_PG_URL}"
pg_check "supabase_postgres" "${SUPABASE_PG_URL}"

emit "# HELP obs_supabase_configured Supabase DB URL configured (1=yes,0=no)."
emit "# TYPE obs_supabase_configured gauge"
if [[ -n "${SUPABASE_PG_URL}" ]]; then
  emit "obs_supabase_configured 1"
else
  emit "obs_supabase_configured 0"
fi

emit "# HELP obs_qdrant_http_up Qdrant authenticated HTTP readiness check (1=up,0=down)."
emit "# TYPE obs_qdrant_http_up gauge"
QDRANT_URL="${QDRANT_URL:-http://192.168.1.20:6333}"
QDRANT_STATUS="$(curl -s -H "api-key: ${QDRANT_API_KEY:-}" -o /dev/null -w "%{http_code}" "${QDRANT_URL}/readyz" || echo 000)"
if [[ "${QDRANT_STATUS}" == "200" ]]; then
  emit "obs_qdrant_http_up{target=\"192.168.1.20:6333\",http_code=\"${QDRANT_STATUS}\"} 1"
else
  emit "obs_qdrant_http_up{target=\"192.168.1.20:6333\",http_code=\"${QDRANT_STATUS}\"} 0"
fi

mv "${TMP_FILE}" "${OUT_FILE}"
chmod 0644 "${OUT_FILE}"
