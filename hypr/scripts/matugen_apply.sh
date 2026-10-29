#!/usr/bin/env bash
# Generate colors into a user-owned cache file. The copy under the dotfiles
# tree is often root-owned, so matugen must not write there.
set -u

img="${1:-}"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
cache="$HOME/.cache/quickshell/qs_colors.json"
reload="$HOME/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh"

mkdir -p "$HOME/.cache/quickshell" "$HOME/.config/wofi" "$HOME/.config/kitty"

if [ -z "$img" ] || [ ! -f "$img" ]; then
    exit 0
fi
if ! command -v matugen >/dev/null 2>&1; then
    exit 0
fi
if [ ! -f "$cfg" ]; then
    exit 0
fi

matugen image "$img" --mode dark --config "$cfg" >/dev/null 2>&1 || true

if [ -f "$reload" ]; then
    bash "$reload" || true
fi
