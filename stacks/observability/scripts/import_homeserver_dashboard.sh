#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
DASHBOARD_JSON="${DASHBOARD_JSON:-/srv/stacks/observability/grafana/dashboards/homeserver-health.json}"

curl -fsS "${GRAFANA_URL}/api/health" >/dev/null

python3 - <<PY
import json
from pathlib import Path
p = Path("${DASHBOARD_JSON}")
d = json.loads(p.read_text())
Path("/tmp/import-dashboard.json").write_text(json.dumps({"dashboard": d, "overwrite": True}))
print("payload_ready")
PY

curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  -H "Content-Type: application/json" \
  -X POST "${GRAFANA_URL}/api/dashboards/db" \
  --data-binary @/tmp/import-dashboard.json \
  | jq -r '.status,.uid,.url'
