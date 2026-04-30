#!/usr/bin/env bash
# Prevent idle auto-lock while on AC power or during active audio playback.
LOG_FILE="/tmp/idle-lock-guard.log"

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

any_player_playing() {
    command -v playerctl >/dev/null 2>&1 || return 1
    playerctl -a status 2>/dev/null | awk '
        /^Playing$/ { found=1 }
        END { exit(found ? 0 : 1) }
    '
}

any_audio_playing() {
    command -v pactl >/dev/null 2>&1 || return 1
    pactl list sink-inputs 2>/dev/null | awk '
        /^\s*State:\s*RUNNING$/ { found=1 }
        END { exit(found ? 0 : 1) }
    '
}

if is_on_ac; then
    printf '%s skip: on AC\n' "$(date '+%F %T')" >> "$LOG_FILE"
    exit 0
fi

if spotify_playing; then
    printf '%s skip: spotify playing\n' "$(date '+%F %T')" >> "$LOG_FILE"
    exit 0
fi

if any_player_playing; then
    printf '%s skip: media player playing\n' "$(date '+%F %T')" >> "$LOG_FILE"
    exit 0
fi

if any_audio_playing; then
    printf '%s skip: active audio stream\n' "$(date '+%F %T')" >> "$LOG_FILE"
    exit 0
fi

printf '%s lock: no AC/audio activity\n' "$(date '+%F %T')" >> "$LOG_FILE"
exec loginctl lock-session
