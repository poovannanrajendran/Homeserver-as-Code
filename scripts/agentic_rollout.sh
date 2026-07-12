#!/usr/bin/env bash
set -euo pipefail

# Stage-gated rollout helper for the Hermes Agent + Paperclip deployment plan.
# Default mode is check-only. It prints concrete readiness data for each stage.

SSH_USER="${SSH_USER:-labadmin}"
AI_NODE="${AI_NODE:-192.168.1.24}"
RUNNER="${RUNNER:-192.168.1.30}"
DOCKER_HOST="${DOCKER_HOST:-192.168.1.20}"

MODE="${1:-report}"

ssh_run() {
  local host="$1"
  shift
  ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
    "${SSH_USER}@${host}" "$@"
}

stage_header() {
  printf '\n== %s ==\n' "$1"
}

baseline() {
  stage_header "Phase 0: Baseline"
  echo "[ai-node-01]"
  ssh_run "$AI_NODE" "hostname; uptime; free -h; df -h / /var; ps -eo comm,%cpu,%mem --sort=-%cpu | head -n 8"
  echo
  echo "[automation-runner-01]"
  ssh_run "$RUNNER" "hostname; uptime; free -h; df -h / /var; docker ps --format '{{.Names}} {{.Status}}' | head -n 20"
  echo
  echo "[docker-host-01]"
  ssh_run "$DOCKER_HOST" "hostname; uptime; free -h; df -h / /var; docker ps --format '{{.Names}} {{.Status}}' | head -n 20"
}

hermes_check() {
  stage_header "Phase 1: Hermes readiness"
  ssh_run "$AI_NODE" '
    set -e
    echo "hostname=$(hostname)"
    echo "openclaw=$(command -v openclaw || true)"
    echo "hermes=$(command -v hermes || true)"
    echo "curl=$(command -v curl || true)"
    echo "node=$(command -v node || true)"
    echo "npm=$(command -v npm || true)"
    if command -v hermes >/dev/null 2>&1; then
      hermes --version || true
    else
      echo "hermes missing"
    fi
  '
}

paperclip_check() {
  stage_header "Phase 2: Paperclip readiness"
  ssh_run "$RUNNER" '
    set -e
    echo "hostname=$(hostname)"
    echo "node=$(command -v node || true)"
    echo "npm=$(command -v npm || true)"
    echo "npx=$(command -v npx || true)"
    echo "docker=$(command -v docker || true)"
    if command -v npx >/dev/null 2>&1; then
      npx --yes paperclipai --help >/tmp/paperclip-help.txt 2>&1 || true
      tail -n 5 /tmp/paperclip-help.txt || true
    fi
  '
}

route_check() {
  stage_header "Phase 3: Routing integration readiness"
  ssh_run "$AI_NODE" 'test -d /var/lib/openclaw/.openclaw && echo "openclaw config present" || echo "openclaw config missing"'
  ssh_run "$RUNNER" 'test -d /srv/stacks/observability && echo "runner control plane present" || echo "runner control plane missing"'
}

case "$MODE" in
  report)
    baseline
    hermes_check
    paperclip_check
    route_check
    ;;
  baseline)
    baseline
    ;;
  hermes-check)
    hermes_check
    ;;
  paperclip-check)
    paperclip_check
    ;;
  route-check)
    route_check
    ;;
  *)
    echo "Usage: $0 [report|baseline|hermes-check|paperclip-check|route-check]" >&2
    exit 1
    ;;
esac
