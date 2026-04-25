#!/usr/bin/env bash
set -euo pipefail

LLoyds_ENV="${1:-/Users/poovannanrajendran/Documents/GitHub/lloyds-market-news-digest/.env}"
RUNNER_DIR="${RUNNER_DIR:-/srv/stacks/observability/scripts}"

mkdir -p "${RUNNER_DIR}"

if [[ ! -f "${LLoyds_ENV}" ]]; then
  echo "Missing Lloyds env: ${LLoyds_ENV}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${LLoyds_ENV}"
set +a

cat > "${RUNNER_DIR}/schedule_guard.env" <<EOF
SLACK_WEBHOOK_URL=${ALERT_WEBHOOK_SLACK:-}
DISCORD_WEBHOOK_URL=${ALERT_WEBHOOK_DISCORD:-}
EOF
chmod 600 "${RUNNER_DIR}/schedule_guard.env"

cat > "${RUNNER_DIR}/monthly_maintenance.env" <<EOF
SLACK_WEBHOOK_URL=${ALERT_WEBHOOK_SLACK:-}
DISCORD_WEBHOOK_URL=${ALERT_WEBHOOK_DISCORD:-}
EOF
chmod 600 "${RUNNER_DIR}/monthly_maintenance.env"

echo "Updated ${RUNNER_DIR}/schedule_guard.env"
echo "Updated ${RUNNER_DIR}/monthly_maintenance.env"
