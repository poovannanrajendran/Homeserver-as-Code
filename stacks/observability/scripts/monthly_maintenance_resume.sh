#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/stacks/observability"
STATE_FILE="${BASE_DIR}/state/monthly-maintenance.json"
SCRIPT="${BASE_DIR}/scripts/monthly_maintenance.sh"

if [[ -f "${STATE_FILE}" ]]; then
  exec "${SCRIPT}" --resume
fi

exit 0
