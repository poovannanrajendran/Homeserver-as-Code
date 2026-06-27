#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/stacks/observability"
ENV_FILE="${BASE_DIR}/scripts/schedule_guard.env"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
  fi
}

notify_webhook() {
  local url="$1"
  local title="$2"
  local body="$3"
  [[ -n "${url}" ]] || return 0
  python3 - <<'PY' "$url" "$title" "$body"
import json, sys, urllib.request
url, title, body = sys.argv[1:4]
payload = {"text": f"**{title}**\n{body}"}
req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json"})
with urllib.request.urlopen(req, timeout=10) as resp:
    resp.read()
PY
}

notify() {
  local title="$1"
  local body="$2"
  notify_webhook "${SLACK_WEBHOOK_URL:-${ALERT_WEBHOOK_SLACK:-}}" "${title}" "${body}" || true
  notify_webhook "${DISCORD_WEBHOOK_URL:-${ALERT_WEBHOOK_DISCORD:-}}" "${title}" "${body}" || true
}

ssh_remote() {
  local host="$1"
  local user="$2"
  shift 2
  ssh "${SSH_OPTS[@]}" "${user}@${host}" "$@"
}

check_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "${haystack}" == *"${needle}"* ]]
}

failures=()
report_lines=()

record_check() {
  local name="$1"
  local ok="$2"
  local detail="$3"
  if [[ "${ok}" == "1" ]]; then
    report_lines+=("OK: ${name} - ${detail}")
  else
    report_lines+=("FAIL: ${name} - ${detail}")
    failures+=("${name}")
  fi
}

main() {
  load_env

  local ai_host docker_host ai_user docker_user
  ai_host="${AI_NODE_HOST:-192.168.1.24}"
  docker_host="${DOCKER_HOST:-192.168.1.20}"
  ai_user="${AI_SSH_USER:-labadmin}"
  docker_user="${DOCKER_SSH_USER:-labadmin}"

  local runner_timers
  runner_timers="$(systemctl list-timers --all --no-pager 2>/dev/null || true)"
  for timer in monthly-maintenance.timer monthly-maintenance-resume.timer youtube-sync.timer; do
    if check_contains "${runner_timers}" "${timer}"; then
      record_check "runner:${timer}" 1 "present"
    else
      record_check "runner:${timer}" 0 "missing from systemctl list-timers"
    fi
  done

  local ai_timers ai_cron
  ai_timers="$(ssh_remote "${ai_host}" "${ai_user}" 'systemctl list-timers --all --no-pager 2>/dev/null || true' || true)"
  for timer in openclaw-weekly-update.timer ai-node-weekly-os-update.timer ai-node-conditional-reboot.timer; do
    if check_contains "${ai_timers}" "${timer}"; then
      record_check "ai-node:${timer}" 1 "present"
    else
      record_check "ai-node:${timer}" 0 "missing from systemctl list-timers"
    fi
  done

  ai_cron="$(ssh_remote "${ai_host}" "${ai_user}" 'crontab -l 2>/dev/null || true' || true)"
  if check_contains "${ai_cron}" 'youtube_enrichment/run_enrichment.sh'; then
    record_check "ai-node:youtube_enrichment.cron" 1 "present"
  else
    record_check "ai-node:youtube_enrichment.cron" 0 "missing from crontab"
  fi

  local docker_ps
  docker_ps="$(ssh_remote "${docker_host}" "${docker_user}" 'docker ps --format "{{.Names}}" 2>/dev/null || true' || true)"
  if check_contains "${docker_ps}" 'nextcloud-cron'; then
    record_check "docker-host:nextcloud-cron" 1 "running"
  else
    record_check "docker-host:nextcloud-cron" 0 "missing from docker ps"
  fi

  local summary
  summary="$(printf '%s\n' "${report_lines[@]}")"
  if [[ ${#failures[@]} -gt 0 ]]; then
    notify "Schedule guard failed" "The following schedules were missing or inactive:\n$(printf '%s\n' "${failures[@]}")\n\nDetails:\n${summary}"
    printf '%s\n' "${summary}" >&2
    exit 1
  fi

  notify "Schedule guard passed" "${summary}"
  printf '%s\n' "${summary}"
}

main "$@"
