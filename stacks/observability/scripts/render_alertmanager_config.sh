#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/srv/stacks/observability"
ENV_FILE="${BASE_DIR}/scripts/alertmanager.env"
TEMPLATE_FILE="${BASE_DIR}/alertmanager/alertmanager.yml.example"
OUT_FILE="${BASE_DIR}/alertmanager/alertmanager.yml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy alertmanager.env.example first."
  exit 1
fi
if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "Missing ${TEMPLATE_FILE}."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

tmp="$(mktemp)"
envsubst < "${TEMPLATE_FILE}" > "${tmp}"

if grep -q '\${' "${tmp}"; then
  echo "Unresolved template variables found in rendered alertmanager config."
  cat "${tmp}"
  rm -f "${tmp}"
  exit 1
fi

mv "${tmp}" "${OUT_FILE}"
chmod 600 "${OUT_FILE}"
echo "Rendered ${OUT_FILE}"
