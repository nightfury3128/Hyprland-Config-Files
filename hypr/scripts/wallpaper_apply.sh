#!/usr/bin/env bash
# Apply one image to every Hyprland output (needed on hybrid Intel + NVIDIA setups).
set -u

img="${1:-}"
transition_type="${2:-any}"

if [ -z "$img" ] || [ ! -f "$img" ]; then
    echo "wallpaper_apply: missing image" >&2
    exit 1
fi

if ! command -v awww >/dev/null 2>&1; then
    notify-send "Wallpaper" "awww is not installed. Install it with: sudo pacman -S awww"
    exit 1
fi

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
    sleep 0.3
fi

mapfile -t outputs < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
if [ "${#outputs[@]}" -eq 0 ]; then
    awww img "$img" \
        --transition-type "$transition_type" \
        --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1
    exit $?
fi

ok=0
for out in "${outputs[@]}"; do
    [ -n "$out" ] || continue
    if awww img "$img" -o "$out" \
        --transition-type "$transition_type" \
        --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1; then
        ok=1
    fi
done

[ "$ok" -eq 1 ] || exit 1
