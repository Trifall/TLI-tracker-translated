#!/usr/bin/env bash
# Fix invisible text when running the Windows ETOR build under Wine.
#
# Symptom: window opens, sidebar/icons/borders/numbers render, but NO words are
# visible. Cause: the remote web UI asks for "Segoe UI" / "Microsoft YaHei",
# which don't exist on Linux, and Wine's generic sans-serif fallback measures
# every glyph as 0px wide, so nothing is painted.
#
# Fix: install user-level font aliases — copies of Noto Sans / Noto Sans CJK SC
# renamed to "Segoe UI" and "Microsoft YaHei". Touches neither the app nor your
# game; fully reversible (see UNDO below).
#
# Usage:
#   WINEPREFIX="$HOME/Applications/ETOR/prefix" bash scripts/fix-wine-fonts.sh
#   (WINEPREFIX = the folder containing drive_c. Defaults to the above.)
# Requires: python3 + fonttools (pip install --user fonttools), fc-list, wine.
# UNDO: rm -rf ~/.local/share/fonts/etor-alias && fc-cache -f
set -euo pipefail

WINEPREFIX="${WINEPREFIX:-$HOME/Applications/ETOR/prefix}"
ALIAS="$HOME/.local/share/fonts/etor-alias"

if [[ ! -d "$WINEPREFIX/drive_c" ]]; then
  echo "error: $WINEPREFIX does not look like a Wine prefix (no drive_c)." >&2
  echo "Set WINEPREFIX to the folder that contains drive_c and retry." >&2
  echo "Not using Wine? For native Linux Electron, use scripts/fix-linux-fonts.sh instead." >&2
  exit 1
fi
for cmd in python3 fc-list fc-cache wineboot wineserver; do
  command -v "$cmd" >/dev/null || { echo "error: missing required command: $cmd" >&2; exit 1; }
done
python3 -c "import fontTools" 2>/dev/null || {
  echo "error: python3 module 'fontTools' not found." >&2
  echo "Install it with:  pip install --user fonttools  (or ask someone technical)" >&2
  exit 1
}

# Locate source fonts via fontconfig; fall back to the classic FHS paths.
find_font() { fc-list "$1" file 2>/dev/null | head -n1 | cut -d: -f1; }
LATIN_REGULAR="$(find_font 'Noto Sans:style=Regular')"
LATIN_BOLD="$(find_font 'Noto Sans:style=Bold')"
CJK_REGULAR="$(find_font 'Noto Sans CJK SC:style=Regular')"
CJK_BOLD="$(find_font 'Noto Sans CJK SC:style=Bold')"
[[ -f "${LATIN_REGULAR:-x}" ]] || LATIN_REGULAR="/usr/share/fonts/noto/NotoSans-Regular.ttf"
[[ -f "${LATIN_BOLD:-x}" ]]    || LATIN_BOLD="/usr/share/fonts/noto/NotoSans-Bold.ttf"
[[ -f "${CJK_REGULAR:-x}" ]]   || CJK_REGULAR="/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc"
[[ -f "${CJK_BOLD:-x}" ]]      || CJK_BOLD="/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc"
for f in "$LATIN_REGULAR" "$LATIN_BOLD" "$CJK_REGULAR" "$CJK_BOLD"; do
  [[ -f "$f" ]] || { echo "error: source font not found: $f" >&2; exit 1; }
done

mkdir -p "$ALIAS"

python3 - "$ALIAS" "$LATIN_REGULAR" "$LATIN_BOLD" "$CJK_REGULAR" "$CJK_BOLD" <<'PY'
import os, sys
from fontTools.ttLib import TTFont, TTCollection

OUT, LAT_R, LAT_B, CJK_R, CJK_B = sys.argv[1:5]
os.makedirs(OUT, exist_ok=True)

def rename(font, family, subfamily, psname, fullname, weight):
    name = font["name"]
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17):
            name.removeNames(rec.nameID, rec.platformID, rec.platEncID, rec.langID)
    def add(nid, s):
        name.setName(s, nid, 3, 1, 0x409)   # Windows / en-US
        name.setName(s, nid, 1, 0, 0)       # Mac / Roman
    add(1, family); add(2, subfamily); add(3, f"{family}-{subfamily}")
    add(4, fullname); add(6, psname); add(16, family); add(17, subfamily)
    font["OS/2"].usWeightClass = weight
    if "Bold" in subfamily:
        font["OS/2"].fsSelection |= (1 << 5)
    else:
        font["OS/2"].fsSelection &= ~(1 << 5)

# Latin glyphs -> "Segoe UI"
for src, sub, ps, wt in [(LAT_R, "Regular", "SegoeUI", 400),
                         (LAT_B, "Bold", "SegoeUI-Bold", 700)]:
    f = TTFont(src)
    rename(f, "Segoe UI", sub, ps,
           "Segoe UI" if sub == "Regular" else f"Segoe UI {sub}", wt)
    f.save(os.path.join(OUT, ps + ".ttf"))

# CJK glyphs -> "Microsoft YaHei" (pull the SC face out of each TTC)
for ttc, bold in [(CJK_R, False), (CJK_B, True)]:
    coll = TTCollection(ttc)
    face = next(f for f in coll.fonts
                if "CJK SC" in (f["name"].getDebugName(1) or "")
                and "Mono" not in (f["name"].getDebugName(1) or ""))
    sub = "Bold" if bold else "Regular"
    ps = "MicrosoftYaHei-Bold" if bold else "MicrosoftYaHei"
    rename(face, "Microsoft YaHei", sub, ps,
           "Microsoft YaHei Bold" if bold else "Microsoft YaHei",
           700 if bold else 400)
    face.save(os.path.join(OUT, ps + ".otf"))
PY

fc-cache -f "$ALIAS"
wineserver -k 2>/dev/null || true
WINEPREFIX="$WINEPREFIX" WINEARCH=win64 WINEDEBUG=-all wineboot -u
echo "Done. Relaunch ETOR — sidebar should read Overview, Items, Price Database, History, etc."
echo "To undo: rm -rf \"$ALIAS\" && fc-cache -f"
