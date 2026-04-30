#!/usr/bin/env bash
# Prevent idle auto-lock while on AC power or during active audio playback.

is_on_ac() {
    local online
    for online in /sys/class/power_supply/*/online; do
        [ -r "$online" ] || continue
        case "$online" in
            *BAT*|*bat*) continue ;;
        esac
        if [ "$(cat "$online" 2>/dev/null)" = "1" ]; then
            return 0
        fi
    done
    return 1
}

spotify_playing() {
    command -v playerctl >/dev/null 2>&1 || return 1
    [ "$(playerctl --player=spotify status 2>/dev/null)" = "Playing" ]
}

any_audio_playing() {
    command -v pactl >/dev/null 2>&1 || return 1
    pactl list sink-inputs 2>/dev/null | rg -q '^\s*State:\s*RUNNING$'
}

if is_on_ac || spotify_playing || any_audio_playing; then
    exit 0
fi

exec loginctl lock-session
