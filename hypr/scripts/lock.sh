#!/usr/bin/env bash

# Single lock entrypoint used by activbar and keybinds.
# Keep this aligned with hypridle lock_cmd for consistent UX.
pidof hyprlock >/dev/null 2>&1 || exec hyprlock

