#!/usr/bin/env bash
set -euo pipefail

SCRIPT="/srv/stacks/observability/scripts/host_checks.sh"
CRON_LINE="*/5 * * * * ${SCRIPT} >/dev/null 2>&1"

if [[ ! -x "${SCRIPT}" ]]; then
  echo "ERROR: ${SCRIPT} not found or not executable."
  echo "Run: chmod +x ${SCRIPT}"
  exit 1
fi

TMP="$(mktemp)"
(crontab -l 2>/dev/null | grep -Fv "${SCRIPT}" || true) > "${TMP}"
echo "${CRON_LINE}" >> "${TMP}"
crontab "${TMP}"
rm -f "${TMP}"

echo "Installed cron:"
crontab -l | grep -F "${SCRIPT}" || true
