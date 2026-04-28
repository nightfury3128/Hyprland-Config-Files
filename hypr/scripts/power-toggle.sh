#!/bin/bash

CURRENT=$(powerprofilesctl get)

if [ "$CURRENT" = "performance" ]; then
    powerprofilesctl set balanced
    notify-send "Power Mode" "Balanced"
else
    powerprofilesctl set performance
    notify-send "Power Mode" "Performance"
fi
