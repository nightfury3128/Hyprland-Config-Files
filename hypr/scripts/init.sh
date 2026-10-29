#!/usr/bin/env bash

FLAG="$HOME/.cache/wallpaper_initialized"
RELOAD_SCRIPT_PATH="$HOME/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh"

# If the flag exists, just run matugen and the reload script, then exit
if [ -f "$FLAG" ]; then
    # Use the cached wallpaper image for matugen
    if [ -f "/tmp/lock_bg.png" ]; then
        matugen image "/tmp/lock_bg.png" --source-color-index 0
    fi
    
    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi
    
    exit 0
fi

# If no wallpaper dir is set, default to a common one to prevent find from failing
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

sleep 0.5

# Find a random file
file=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)

if [ -n "$file" ]; then
    cp "$file" /tmp/lock_bg.png
    
    bash "$HOME/.config/hypr/scripts/wallpaper_apply.sh" "$file" any &
    
    if [ -x "$HOME/.config/hypr/scripts/matugen_apply.sh" ]; then
        bash "$HOME/.config/hypr/scripts/matugen_apply.sh" "$file" || true
    else
        matugen image "$file" --source-color-index 0 || true
        if [ -f "$RELOAD_SCRIPT_PATH" ]; then
            bash "$RELOAD_SCRIPT_PATH" || true
        fi
    fi
fi

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
