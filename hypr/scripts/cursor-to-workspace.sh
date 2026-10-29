#!/usr/bin/env bash
# Move only the mouse cursor to the center of the monitor that currently owns
# workspace $1. Does not focus the workspace or move windows.

set -euo pipefail

ws="${1:?usage: cursor-to-workspace.sh <workspace-id>}"

mon=$(hyprctl workspaces -j | jq -r --argjson ws "$ws" '.[] | select(.id == $ws) | .monitor')
[ -n "$mon" ] && [ "$mon" != "null" ] || exit 0

coords=$(hyprctl monitors -j | jq -r --arg m "$mon" '
    .[] | select(.name == $m) |
    "\((.x + .width / 2) | floor) \((.y + .height / 2) | floor)"
')
[ -n "$coords" ] || exit 0

# shellcheck disable=SC2086
hyprctl dispatch movecursor $coords >/dev/null
