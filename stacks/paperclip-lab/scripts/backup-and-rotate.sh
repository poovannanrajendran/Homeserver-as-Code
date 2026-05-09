#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/backup-db.sh
./scripts/rotate-secret.sh
