#!/usr/bin/env bash
# brightness.sh — sysfs + logind D-Bus brightness control
# Drop-in replacement for brightnessctl when it is not installed.
# Supports: get, set [+N%|-N%|N%|N], -m (machine-readable compat)

BL_DIR=""
for p in /sys/class/backlight/*/; do
    [ -f "${p}brightness" ] && [ -f "${p}max_brightness" ] && { BL_DIR="$p"; break; }
done

if [ -z "$BL_DIR" ]; then
    echo "0"
    exit 0
fi

DEVICE=$(basename "$BL_DIR")
MAX=$(cat "${BL_DIR}max_brightness" 2>/dev/null || echo 255)
CUR=$(cat "${BL_DIR}brightness" 2>/dev/null || echo 0)
PCT=$(( CUR * 100 / MAX ))

set_raw() {
    local val=$1
    (( val < 1 )) && val=1
    (( val > MAX )) && val=$MAX
    # logind D-Bus (user-space, no root needed when logged in via systemd)
    if busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
            org.freedesktop.login1.Session SetBrightness ssu \
            "backlight" "$DEVICE" "$val" 2>/dev/null; then
        return
    fi
    # Fallback: direct sysfs write (requires video group membership or udev rule)
    echo "$val" > "${BL_DIR}brightness" 2>/dev/null
}

case "${1:-get}" in
    get)
        echo "$PCT"
        ;;
    set)
        VAL="${2:-}"
        case "$VAL" in
            +*%)  STEP="${VAL#+}"; STEP="${STEP//%}"; set_raw $(( MAX * (PCT + STEP) / 100 )) ;;
            -*%)  STEP="${VAL#-}"; STEP="${STEP//%}"; set_raw $(( MAX * (PCT - STEP) / 100 )) ;;
            *%+)  STEP="${VAL/\%+}";                  set_raw $(( MAX * (PCT + STEP) / 100 )) ;;
            *%-)  STEP="${VAL/\%-}";                  set_raw $(( MAX * (PCT - STEP) / 100 )) ;;
            *%)   set_raw $(( MAX * ${VAL//%} / 100 )) ;;
            *)    set_raw "$VAL" ;;
        esac
        CUR=$(cat "${BL_DIR}brightness" 2>/dev/null || echo 0)
        echo "$(( CUR * 100 / MAX ))"
        ;;
    -m)
        # brightnessctl -m machine-readable format: device,class,current_raw,pct%,max_raw
        echo "${DEVICE},backlight,${CUR},${PCT}%,${MAX}"
        ;;
    *)
        echo "$PCT"
        ;;
esac
