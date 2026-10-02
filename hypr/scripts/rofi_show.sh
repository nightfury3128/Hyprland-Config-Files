#!/usr/bin/env bash
# App launcher: themed wofi, applications only (no handlers/services).
set -u

STYLE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css"
GET_APPS="$HOME/.config/hypr/scripts/get_apps.sh"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wofi-apps.map"
PROMPT="Search apps..."

if pgrep -x wofi >/dev/null 2>&1; then
    pkill -x wofi
    exit 0
fi

if ! command -v wofi >/dev/null 2>&1; then
    notify-send "Launcher" "wofi is not installed. Install it with: sudo pacman -S wofi"
    exit 1
fi

mkdir -p "$(dirname "$CACHE")"
: > "$CACHE"

entries=""
while IFS='|' read -r name exec_path icon_path _desk; do
    [ -z "$name" ] && continue
    [ -z "$exec_path" ] && continue
    printf '%s\t%s\n' "$name" "$exec_path" >> "$CACHE"
    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        entries+="img:${icon_path}:text:${name}"$'\n'
    else
        entries+="${name}"$'\n'
    fi
done < <(bash "$GET_APPS" 2>/dev/null)

choice=$(printf '%s' "$entries" | wofi \
    --dmenu \
    --allow-images \
    --insensitive \
    --prompt "$PROMPT" \
    --width 420 \
    --height 560 \
    --hide-scroll \
    --matching contains \
    --style "$STYLE" \
    --cache-file /dev/null)

[ -z "${choice:-}" ] && exit 0

# Strip wofi image markup if present.
name="$choice"
case "$choice" in
    img:*:text:*) name="${choice##*:text:}" ;;
esac

cmd=$(awk -F'\t' -v n="$name" '$1 == n { print $2; exit }' "$CACHE")
[ -z "$cmd" ] && exit 0

setsid -f bash -lc "$cmd" >/dev/null 2>&1 &
