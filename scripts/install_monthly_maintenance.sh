#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${1:-$(pwd)}"
TARGET_BASE="${TARGET_BASE:-/srv/stacks/observability}"

install -d -m 0755 "${TARGET_BASE}/scripts" "${TARGET_BASE}/systemd" "${TARGET_BASE}/state"
install -m 0755 "${SRC_DIR}/stacks/observability/scripts/monthly_maintenance.sh" "${TARGET_BASE}/scripts/monthly_maintenance.sh"
install -m 0755 "${SRC_DIR}/stacks/observability/scripts/monthly_maintenance_resume.sh" "${TARGET_BASE}/scripts/monthly_maintenance_resume.sh"
install -m 0644 "${SRC_DIR}/stacks/observability/scripts/monthly_maintenance.env.example" "${TARGET_BASE}/scripts/monthly_maintenance.env.example"
install -m 0644 "${SRC_DIR}/stacks/observability/systemd/monthly-maintenance.service" /etc/systemd/system/monthly-maintenance.service
install -m 0644 "${SRC_DIR}/stacks/observability/systemd/monthly-maintenance.timer" /etc/systemd/system/monthly-maintenance.timer
install -m 0644 "${SRC_DIR}/stacks/observability/systemd/monthly-maintenance-resume.service" /etc/systemd/system/monthly-maintenance-resume.service
install -m 0644 "${SRC_DIR}/stacks/observability/systemd/monthly-maintenance-resume.timer" /etc/systemd/system/monthly-maintenance-resume.timer

systemctl daemon-reload
systemctl enable --now monthly-maintenance.timer monthly-maintenance-resume.timer

echo "Installed monthly maintenance timers."
systemctl list-timers --all --no-pager | grep -E 'monthly-maintenance' || true
