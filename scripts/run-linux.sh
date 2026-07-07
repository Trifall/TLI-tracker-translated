#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELECTRON_VERSION="${ELECTRON_VERSION:-32.0.0}"

if [[ ! -f "$ROOT_DIR/resources/app.asar" ]]; then
  echo "resources/app.asar was not found. Run this script from a complete release checkout." >&2
  exit 1
fi

exec npx --yes "electron@$ELECTRON_VERSION" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --ozone-platform-hint=auto \
  "$ROOT_DIR/resources/app.asar" \
  "$@"
