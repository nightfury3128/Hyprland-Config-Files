#!/usr/bin/env bash
# Set a power profile via power-profiles-daemon.
# Usage: power-profile.sh <performance|balanced|power-saver>

profile="${1:?usage: power-profile.sh <performance|balanced|power-saver>}"

if ! command -v powerprofilesctl >/dev/null 2>&1; then
    notify-send -u low "Power Profile" "powerprofilesctl not found"
    exit 1
fi

if powerprofilesctl set "$profile"; then
    powerprofilesctl get
else
    notify-send -u low "Power Profile" "Failed to switch to $profile"
    exit 1
fi
