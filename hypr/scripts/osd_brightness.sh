#!/usr/bin/env bash
ACTION="${1:-up}"
STEP="${2:-5}"
BRIGHT_SCRIPT="$HOME/.config/hypr/scripts/brightness.sh"

case "$ACTION" in
    up)   "$BRIGHT_SCRIPT" set "+${STEP}%" 2>/dev/null ;;
    down) "$BRIGHT_SCRIPT" set "-${STEP}%" 2>/dev/null ;;
esac

BRIGHT=$("$BRIGHT_SCRIPT" 2>/dev/null)
echo "brightness|${BRIGHT:-50}" > /tmp/qs_osd
