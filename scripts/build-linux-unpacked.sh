#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELECTRON_VERSION="${ELECTRON_VERSION:-32.0.0}"
BUILD_DIR="$ROOT_DIR/.linux-build/electron-runtime"
OUT_DIR="$ROOT_DIR/dist/linux-unpacked"
APP_NAME="TLI-tracker-translated"

if [[ ! -f "$ROOT_DIR/resources/app.asar" ]]; then
  echo "resources/app.asar was not found. Run this script from a complete release checkout." >&2
  exit 1
fi

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR/resources"

npm --prefix "$BUILD_DIR" init -y >/dev/null
npm --prefix "$BUILD_DIR" install --no-audit --no-fund "electron@$ELECTRON_VERSION"

cp -a "$BUILD_DIR/node_modules/electron/dist/." "$OUT_DIR/"
cp "$ROOT_DIR/resources/app.asar" "$OUT_DIR/resources/app.asar"

if [[ -f "$ROOT_DIR/resources/app.asar.backup" ]]; then
  cp "$ROOT_DIR/resources/app.asar.backup" "$OUT_DIR/resources/app.asar.backup"
fi

mv "$OUT_DIR/electron" "$OUT_DIR/$APP_NAME"
chmod +x "$OUT_DIR/$APP_NAME"

cat > "$OUT_DIR/run.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$HERE/$APP_NAME" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --ozone-platform-hint=auto \
  "\$@"
EOF
chmod +x "$OUT_DIR/run.sh"

cat > "$OUT_DIR/README-linux.txt" <<EOF
Run with:

  ./run.sh

This package uses Electron $ELECTRON_VERSION for Linux and the existing resources/app.asar from this repository.
Use the in-app file picker to select your Torchlight: Infinite UE_game.log file wherever it lives on your Linux filesystem.
EOF

echo "Built Linux unpacked app at: $OUT_DIR"
echo "Run it with: $OUT_DIR/run.sh"
