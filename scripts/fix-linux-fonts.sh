#!/usr/bin/env bash
# Fix invisible text when running ETOR via native Linux Electron
# (scripts/run-linux.sh or dist/linux-unpacked/run.sh).
#
# Symptom: window opens, sidebar/icons/borders render, but NO words are visible.
# The log shows:  Could not find any font: Noto Sans, sans.
# Cause: the remote web UI asks for "Segoe UI" / "Microsoft YaHei". Electron's
# font lookup resolves those (and other fallbacks) to zero-width glyphs unless
# fontconfig carries explicit aliases for them — even when Noto is installed.
#
# Fix: install a user-level fontconfig alias file pointing those families at
# installed Noto faces. Touches neither the app nor your game; fully reversible
# (see UNDO below). Verified: canvas + layout text widths go from 0 to normal
# after installing this file and re-running fc-cache.
#
# Usage:  bash scripts/fix-linux-fonts.sh
# Requires: Noto Sans + Noto Sans CJK SC installed, fc-cache on PATH.
# UNDO: rm ~/.config/fontconfig/conf.d/99-etor-aliases.conf && fc-cache -f
set -euo pipefail

CONF_DIR="$HOME/.config/fontconfig/conf.d"
CONF_FILE="$CONF_DIR/99-etor-aliases.conf"

command -v fc-cache >/dev/null || { echo "error: fc-cache not found" >&2; exit 1; }
fc-list "Noto Sans" file >/dev/null 2>&1 || { echo "error: Noto Sans not installed" >&2; exit 1; }
fc-list "Noto Sans CJK SC" file >/dev/null 2>&1 || { echo "error: Noto Sans CJK SC not installed" >&2; exit 1; }

mkdir -p "$CONF_DIR"
cat > "$CONF_FILE" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- ETOR remote UI asks for Windows/Chinese fonts absent on Linux.
       Point them at installed Noto faces. User-level, reversible:
       delete this file and run fc-cache -f. -->
  <alias>
    <family>Segoe UI</family>
    <prefer><family>Noto Sans</family></prefer>
  </alias>
  <alias>
    <family>Microsoft YaHei</family>
    <prefer><family>Noto Sans CJK SC</family></prefer>
  </alias>
</fontconfig>
EOF

fc-cache -f >/dev/null
echo "Installed $CONF_FILE"
fc-match "Segoe UI"
fc-match "Microsoft YaHei"
echo "Done. Relaunch ETOR (scripts/run-linux.sh)."
echo "To undo: rm \"$CONF_FILE\" && fc-cache -f"
