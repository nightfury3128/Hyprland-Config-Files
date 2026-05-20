# Dotfiles

Personal desktop dotfiles for:

- OS: Arch Linux
- Window Manager: Hyprland

This repo is centered on a Hyprland + QuickShell workflow with custom widgets, launchers, and utility scripts.

## Repository Layout

- `hypr/`: Core Hyprland stack (`hyprland.conf`, `hypridle*.conf`, `hyprlock.conf`, and scripts).
- `hypr/scripts/quickshell/`: QuickShell UI and modules (Dynamic Island, launcher, network, music, battery, notifications, wallpaper tools, and more).
- `hypr/scripts/`: Operational scripts for lock, power, brightness, volume, screenshots, startup management, and watchers.
- `kitty/`, `starship/`, `gtk-3.0/`, `mimeapps/`: Terminal, prompt, toolkit, and default app configs.
Zw
## Runtime Architecture

- `hypr/hyprland.conf` is the entrypoint for monitor setup, keybinds, visuals, and startup commands.
- `hypr/scripts/qs_manager.sh` controls QuickShell lifecycle and toggles modules (launcher, popups, etc.).
- `hypr/scripts/power-monitor.sh` switches idle behavior based on AC/battery and drives the matching `hypridle` profile.
- QuickShell watchers in `hypr/scripts/quickshell/watchers/` feed UI state for audio, battery, network, and keyboard telemetry.

## Key Features

- Dynamic Island style shell UI via QuickShell.
- Integrated launcher and utility popups (network, battery, volume, monitor, wallpaper, notifications, timer, focus time).
- Media controls and metadata display.
- Screenshot and clipboard helpers.
- Hyprland keybinds for workspace navigation, window control, media keys, and system controls.

## Common Edit Points

- Main WM config: `hypr/hyprland.conf`
- Idle profiles: `hypr/hypridle.conf`, `hypr/hypridle-ac.conf`, `hypr/hypridle-battery.conf`
- Lock screen: `hypr/hyprlock.conf`
- QuickShell main entry: `hypr/scripts/quickshell/Main.qml`
- Network module: `hypr/scripts/quickshell/network/NetworkPopup.qml`
- Launcher manager: `hypr/scripts/qs_manager.sh`

## Reload / Restart

After making config or QML changes:

- Reload Hyprland: `hyprctl reload`
- Restart QuickShell (if UI modules do not pick up changes): `~/.config/hypr/scripts/qs_manager.sh restart`
- Restart idle pipeline when editing idle scripts/config:
  - `pkill -x hypridle`
  - `~/.config/hypr/scripts/power-monitor.sh &`
