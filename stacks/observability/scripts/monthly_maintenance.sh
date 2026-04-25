#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/stacks/observability"
STATE_DIR="${BASE_DIR}/state"
STATE_FILE="${STATE_DIR}/monthly-maintenance.json"
ENV_FILE="${BASE_DIR}/scripts/monthly_maintenance.env"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8)

mkdir -p "${STATE_DIR}"

load_env() {
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
  fi
}

now_iso() {
  date -Is
}

json_escape() {
  python3 - <<'PY' "$1"
import json, sys
print(json.dumps(sys.argv[1])[1:-1])
PY
}

write_state() {
  local phase="$1"
  local message="$2"
  local resumed_from="${3:-}"
  cat > "${STATE_FILE}" <<JSON
{
  "phase": "$(json_escape "${phase}")",
  "message": "$(json_escape "${message}")",
  "resumed_from": "$(json_escape "${resumed_from}")",
  "updated_at": "$(json_escape "$(now_iso)")"
}
JSON
}

clear_state() {
  rm -f "${STATE_FILE}"
}

state_phase() {
  [[ -f "${STATE_FILE}" ]] || return 1
  python3 - <<'PY' "${STATE_FILE}"
import json, sys
print(json.load(open(sys.argv[1])).get("phase", ""))
PY
}

state_message() {
  [[ -f "${STATE_FILE}" ]] || return 1
  python3 - <<'PY' "${STATE_FILE}"
import json, sys
print(json.load(open(sys.argv[1])).get("message", ""))
PY
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
  notify_webhook "${SLACK_WEBHOOK_URL:-}" "${title}" "${body}" || true
  notify_webhook "${DISCORD_WEBHOOK_URL:-}" "${title}" "${body}" || true
}

ssh_remote() {
  local host="$1"
  local user="$2"
  shift 2
  ssh "${SSH_OPTS[@]}" "${user}@${host}" "$@"
}

wait_for_ssh() {
  local host="$1"
  local user="$2"
  local deadline=$((SECONDS + ${3:-600}))
  while (( SECONDS < deadline )); do
    if ssh "${SSH_OPTS[@]}" "${user}@${host}" 'true' >/dev/null 2>&1; then
      return 0
    fi
    sleep 10
  done
  return 1
}

host_needs_reboot_remote() {
  local host="$1"
  local user="$2"
  ssh_remote "${host}" "${user}" 'test -f /var/run/reboot-required'
}

update_remote_host() {
  local host="$1"
  local user="$2"
  local name="$3"
  local update_cmd="$4"
  local reboot_cmd="$5"

  notify "Monthly maintenance start" "Updating ${name} (${host})."
  ssh_remote "${host}" "${user}" "${update_cmd}"

  if host_needs_reboot_remote "${host}" "${user}"; then
    notify "Monthly maintenance reboot" "${name} requires reboot. Rebooting now."
    ssh_remote "${host}" "${user}" "${reboot_cmd}" || true
    wait_for_ssh "${host}" "${user}" 900
    notify "Monthly maintenance resume" "${name} is back after reboot."
  fi
}

summarize_runner() {
  local grafana_db prometheus alertmanager timer_status
  grafana_db="$(curl -fsS http://127.0.0.1:3000/api/health 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("database","unknown"))' 2>/dev/null || echo unknown)"
  prometheus="$(curl -fsS http://127.0.0.1:9090/-/healthy >/dev/null 2>&1 && echo healthy || echo unhealthy)"
  alertmanager="$(curl -fsS http://127.0.0.1:9093/-/healthy >/dev/null 2>&1 && echo healthy || echo unhealthy)"
  timer_status="$(systemctl is-active youtube-sync.timer 2>/dev/null || true)"
  printf 'Grafana database: %s\nPrometheus: %s\nAlertmanager: %s\nYouTube timer: %s\n' "${grafana_db}" "${prometheus}" "${alertmanager}" "${timer_status}"
}

send_final_summary() {
  local summary
  summary="$(summarize_runner)"
  notify "Monthly maintenance finished" "${summary}"
}

resume_if_needed() {
  load_env
  if [[ ! -f "${STATE_FILE}" ]]; then
    return 1
  fi
  local phase msg
  phase="$(state_phase || true)"
  msg="$(state_message || true)"
  if [[ "${phase}" != "awaiting_postboot" ]]; then
    return 1
  fi
  notify "Monthly maintenance resumed" "Resuming post-reboot checks on automation-runner-01. ${msg}"
  clear_state
  send_final_summary
}

main() {
  load_env

  if [[ "${1:-}" == "--resume" ]]; then
    resume_if_needed
    return 0
  fi

  local pve_host docker_host ai_node runner_host pve_user remote_user start_message
  pve_host="${PVE_HOST:-192.168.1.250}"
  docker_host="${DOCKER_HOST:-192.168.1.20}"
  ai_node="${AI_NODE:-192.168.1.24}"
  runner_host="${RUNNER_HOST:-192.168.1.30}"
  pve_user="${PVE_SSH_USER:-root}"
  remote_user="${REMOTE_SSH_USER:-labadmin}"
  start_message="Starting monthly maintenance from $(hostname) at $(now_iso)."

  write_state "running" "${start_message}"
  notify "Monthly maintenance started" "${start_message}"

  update_remote_host "${pve_host}" "${pve_user}" "Proxmox host" \
    'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y' \
    'reboot'

  update_remote_host "${docker_host}" "${remote_user}" "docker-host-01" \
    'sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && sudo systemctl restart docker' \
    'sudo reboot'

  update_remote_host "${ai_node}" "${remote_user}" "ai-node-01" \
    'sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y && sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && sudo -u openclaw openclaw update || true' \
    'sudo reboot'

  write_state "awaiting_postboot" "automation-runner-01 update completed; waiting for post-boot verification." "running"
  notify "Monthly maintenance reboot" "automation-runner-01 will reboot if required, then resume post-boot validation."

  if host_needs_reboot_remote "${runner_host}" "${remote_user}"; then
    ssh_remote "${runner_host}" "${remote_user}" 'sudo reboot' || true
    exit 0
  fi

  clear_state
  send_final_summary
}

main "$@"
