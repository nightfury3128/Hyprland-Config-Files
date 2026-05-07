#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="/tmp/qs_launcher_state"
STYLE_FILE="${HOME}/.config/wofi/style.css"

set_launcher_state() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

if pgrep -x "wofi" >/dev/null 2>&1; then
    pkill -x "wofi" >/dev/null 2>&1 || true
    set_launcher_state 0
    exit 0
fi

set_launcher_state 1
trap 'set_launcher_state 0' EXIT INT TERM

wofi --show drun --style "$STYLE_FILE" "$@"
