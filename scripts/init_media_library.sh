#!/usr/bin/env bash
set -euo pipefail

MEDIA_ROOT="${1:-/mnt/media-library}"
OWNER="${2:-1000:1000}"
MODE="${3:-775}"

echo "[INFO] Initializing media library under: ${MEDIA_ROOT}"

mkdir -p \
  "${MEDIA_ROOT}/movies" \
  "${MEDIA_ROOT}/tv" \
  "${MEDIA_ROOT}/music" \
  "${MEDIA_ROOT}/home-videos" \
  "${MEDIA_ROOT}/photos" \
  "${MEDIA_ROOT}/concerts" \
  "${MEDIA_ROOT}/audiobooks"

chown -R "${OWNER}" "${MEDIA_ROOT}"
chmod -R "${MODE}" "${MEDIA_ROOT}"

echo "[INFO] Media library folders created."
echo "[INFO] Owner: ${OWNER}"
echo "[INFO] Mode: ${MODE}"
