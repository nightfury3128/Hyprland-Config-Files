#!/usr/bin/env bash
# Flatten matugen JSON if needed and poke consumers.
# Primary color file is user-owned under ~/.cache/quickshell/.

QS_JSON="$HOME/.cache/quickshell/qs_colors.json"
FALLBACK_JSON="$HOME/.config/hypr/scripts/quickshell/qs_colors.json"

flatten_one() {
    local target_file="$1"
    [ -f "$target_file" ] && [ -w "$target_file" ] || return 0
    python3 - "$target_file" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    raise SystemExit(0)

def flatten(obj):
    if isinstance(obj, dict):
        if "color" in obj and isinstance(obj["color"], str):
            return obj["color"]
        return {k: flatten(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [flatten(x) for x in obj]
    return obj

flat = flatten(data)
with open(path, "w") as f:
    json.dump(flat, f, indent=4)
PY
}

flatten_one "$QS_JSON"
if [ -f "$QS_JSON" ] && [ -w "$FALLBACK_JSON" ]; then
    cp "$QS_JSON" "$FALLBACK_JSON" 2>/dev/null || true
elif [ ! -f "$QS_JSON" ] && [ -f "$FALLBACK_JSON" ]; then
    mkdir -p "$(dirname "$QS_JSON")"
    cp "$FALLBACK_JSON" "$QS_JSON" 2>/dev/null || true
fi

TEXT_FILES=(
    "$HOME/.config/kitty/kitty-matugen-colors.conf"
    "$HOME/.config/wofi/style.css"
)

for file in "${TEXT_FILES[@]}"; do
    if [ -f "$file" ] && [ -w "$file" ]; then
        sed -i -E 's/\{[[:space:]]*"color":[[:space:]]*"([^"]+)"[[:space:]]*\}/\1/g' "$file"
    fi
done

killall -USR1 kitty 2>/dev/null || true
