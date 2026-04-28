#!/usr/bin/env bash

ACTION=$1
TYPE=$2
ID=$3
VAL=$4

case $ACTION in
    set-volume)
        if command -v wpctl >/dev/null 2>&1; then
            TARGET="$ID"
            if [[ -z "$TARGET" ]]; then
                [[ "$TYPE" == "source" ]] && TARGET="@DEFAULT_AUDIO_SOURCE@" || TARGET="@DEFAULT_AUDIO_SINK@"
            fi
            wpctl set-volume "$TARGET" "$VAL%" 2>/dev/null || pactl set-"$TYPE"-volume "$ID" "$VAL%"
        else
            pactl set-"$TYPE"-volume "$ID" "$VAL%"
        fi
        ;;
    toggle-mute)
        if command -v wpctl >/dev/null 2>&1; then
            TARGET="$ID"
            if [[ -z "$TARGET" ]]; then
                [[ "$TYPE" == "source" ]] && TARGET="@DEFAULT_AUDIO_SOURCE@" || TARGET="@DEFAULT_AUDIO_SINK@"
            fi
            wpctl set-mute "$TARGET" toggle 2>/dev/null || pactl set-"$TYPE"-mute "$ID" toggle
        else
            pactl set-"$TYPE"-mute "$ID" toggle
        fi
        ;;
    set-default)
        if command -v wpctl >/dev/null 2>&1; then
            wpctl set-default "$ID" 2>/dev/null || pactl set-default-"$TYPE" "$ID"
        else
            pactl set-default-"$TYPE" "$ID"
        fi
        ;;
esac
