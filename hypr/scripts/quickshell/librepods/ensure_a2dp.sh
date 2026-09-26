#!/usr/bin/env bash
# Ensure AirPods use A2DP (music) when classic-BT connected. Escapes HFP if nothing needs the mic.

set -euo pipefail

MAC="${1:-}"
if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    CTL="${LIBREPODS_CTL:-$HOME/librepods/linux/build/librepods-ctl}"
    if [ -x "$CTL" ]; then
        MAC=$(timeout 0.8 "$CTL" status 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)
    fi
fi
if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    MAC=$(grep -m1 '^bluetoothAddress=' "$HOME/.config/AirPodsTrayApp/AirPodsTrayApp.conf" 2>/dev/null | cut -d= -f2- || true)
fi
if [ -z "$MAC" ] || [ "$MAC" = "null" ]; then
    exit 0
fi

# Opt-in: caller can pass --skip-if-popup as $2 to no-op while the network
# popup is open (previous unconditional behavior blocked popup-initiated
# connects from ever landing on A2DP).
if [ "${2:-}" = "--skip-if-popup" ] && [ "$(cat /tmp/qs_active_widget 2>/dev/null)" = "network" ]; then
    exit 0
fi

INFO=$(timeout 1 bluetoothctl info "$MAC" 2>/dev/null || true)
echo "$INFO" | grep -q 'Connected: yes' || exit 0

CARD="bluez_card.${MAC//:/_}"
STAMP="/tmp/qs_ensure_a2dp_${MAC//:/_}.stamp"
NOW=$(date +%s)
if [ -f "$STAMP" ]; then
    LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
    if [ $((NOW - LAST)) -lt 8 ]; then
        exit 0
    fi
fi

ACTIVE=$(pactl list cards 2>/dev/null | awk -v card="$CARD" '
    $0 ~ "Name: " card { found=1 }
    found && /^[[:space:]]*Active Profile:/ { print $3; exit }
')

# Prefer A2DP unless profile already a2dp-*; escape off/HFP
NEED_SWITCH=0
if [ -z "$ACTIVE" ] || [ "$ACTIVE" = "off" ] || [[ "$ACTIVE" == headset-head-unit* ]]; then
    NEED_SWITCH=1
fi

if [ "$NEED_SWITCH" = 1 ]; then
    PROFILE=""
    for p in a2dp-sink a2dp-sink-sbc_xq a2dp-sink-sbc; do
        if pactl list cards 2>/dev/null | awk -v card="$CARD" -v prof="$p" '
            $0 ~ "Name: " card { found=1 }
            found && $0 ~ ("^[[:space:]]*" prof ":") { exit 0 }
            END { exit 1 }
        '; then
            PROFILE="$p"
            break
        fi
    done
    if [ -n "$PROFILE" ]; then
        pactl set-card-profile "$CARD" "$PROFILE" 2>/dev/null || true
    fi
fi

SINK=$(pactl list sinks short 2>/dev/null | awk -v mac="${MAC//:/_}" '$2 ~ mac { print $2; exit }')
if [ -n "$SINK" ]; then
    # Only claim default if current default is empty/broken or already AirPods-ish
    CUR=$(pactl get-default-sink 2>/dev/null || true)
    if [ -z "$CUR" ] || [[ "$CUR" == *bluez_output* ]] || [[ "$CUR" == *auto_null* ]]; then
        pactl set-default-sink "$SINK" 2>/dev/null || true
    fi
fi

echo "$NOW" > "$STAMP"
