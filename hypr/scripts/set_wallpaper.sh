#!/usr/bin/env bash
# Set a still wallpaper with awww, then regenerate matugen colors.
# With no argument, restore the last image or the bundled lock screen.
set -u

APPLY="$HOME/.config/hypr/scripts/matugen_apply.sh"
FALLBACK="$HOME/dotfiles/wallpapers/LockScreen.jpg"
LAST="$HOME/.cache/quickshell/current_wallpaper"

if ! command -v awww >/dev/null 2>&1; then
    notify-send "Wallpaper" "awww is not installed. Install it with: sudo pacman -S awww"
    exit 1
fi

img="${1:-}"
if [ -z "$img" ]; then
    if [ -f "$LAST" ]; then
        img=$(cat "$LAST")
    elif [ -f "$FALLBACK" ]; then
        img="$FALLBACK"
    fi
fi

if [ -z "$img" ] || [ ! -f "$img" ]; then
    notify-send "Wallpaper" "No wallpaper file to set."
    exit 1
fi

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
    sleep 0.3
fi

awww img "$img" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1
cp "$img" /tmp/lock_bg.png 2>/dev/null || true
mkdir -p "$(dirname "$LAST")"
printf '%s\n' "$img" > "$LAST"

if [ -x "$APPLY" ]; then
    "$APPLY" "$img"
fi
