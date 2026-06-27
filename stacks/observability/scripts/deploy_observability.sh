#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/stacks/observability"

mkdir -p "${BASE_DIR}/prometheus/rules" "${BASE_DIR}/alertmanager" "${BASE_DIR}/textfile" "${BASE_DIR}/scripts"

if [[ ! -f "${BASE_DIR}/.env" ]]; then
  echo "ERROR: ${BASE_DIR}/.env is missing. Copy .env.example, replace placeholders, and chmod 600." >&2
  exit 1
fi
if grep -q 'CHANGE_ME' "${BASE_DIR}/.env"; then
  echo "ERROR: ${BASE_DIR}/.env still contains CHANGE_ME placeholders." >&2
  exit 1
fi
chmod 600 "${BASE_DIR}/.env"

if [[ -x "${BASE_DIR}/scripts/render_alertmanager_config.sh" ]]; then
  "${BASE_DIR}/scripts/render_alertmanager_config.sh"
else
  echo "WARN: ${BASE_DIR}/scripts/render_alertmanager_config.sh not executable or missing; skipping render."
fi

if [[ -x "${BASE_DIR}/scripts/host_checks.sh" ]]; then
  "${BASE_DIR}/scripts/host_checks.sh" || true
fi

if [[ -x "${BASE_DIR}/scripts/install_host_checks_cron.sh" ]]; then
  "${BASE_DIR}/scripts/install_host_checks_cron.sh" || true
fi

cd "${BASE_DIR}"
docker compose up -d

curl -fsS -X POST http://127.0.0.1:9090/-/reload >/dev/null || true

echo "Services:"
docker compose ps

echo "Targets snapshot:"
curl -fsS http://127.0.0.1:9090/api/v1/targets \
  | jq -r '.data.activeTargets[] | [.labels.job,.labels.instance,.health,.lastError] | @tsv' \
  | sort

echo "Alerts snapshot:"
curl -fsS http://127.0.0.1:9090/api/v1/rules \
  | jq -r '.data.groups[]?.rules[]? | select(.type=="alerting") | [.name,.state,.health] | @tsv' \
  | sort
