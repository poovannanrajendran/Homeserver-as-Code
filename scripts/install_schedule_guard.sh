#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${1:-$(pwd)}"
TARGET_BASE="${TARGET_BASE:-/srv/stacks/observability}"

install -d -m 0755 "${TARGET_BASE}/scripts" "${TARGET_BASE}/systemd"
install -m 0755 "${SRC_DIR}/stacks/observability/scripts/schedule_guard.sh" "${TARGET_BASE}/scripts/schedule_guard.sh"
install -m 0644 "${SRC_DIR}/stacks/observability/scripts/schedule_guard.env.example" "${TARGET_BASE}/scripts/schedule_guard.env.example"
install -m 0644 "${SRC_DIR}/stacks/observability/systemd/schedule-guard.service" /etc/systemd/system/schedule-guard.service
install -m 0644 "${SRC_DIR}/stacks/observability/systemd/schedule-guard.timer" /etc/systemd/system/schedule-guard.timer

systemctl daemon-reload
systemctl enable --now schedule-guard.timer

echo "Installed schedule guard timer."
systemctl list-timers --all --no-pager | grep -E 'schedule-guard' || true
