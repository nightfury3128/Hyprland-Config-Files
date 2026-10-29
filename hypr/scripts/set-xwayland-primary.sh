#!/usr/bin/env bash

# Give XWayland a moment to update its monitor list.
sleep 1

if xrandr --query 2>/dev/null | grep -q '^HDMI-A-1 connected'; then
    xrandr --output HDMI-A-1 --primary
fi
