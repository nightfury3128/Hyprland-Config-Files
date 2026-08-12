#!/usr/bin/env bash
# Install (symlink) file-convert CLI and Dolphin service menus into user dirs.
# Idempotent. Safe to re-run. Backs up unrelated conflicts as *.bak.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$REPO_DIR/bin/file-convert"
MENU_SRC_DIR="$REPO_DIR/servicemenus"

BIN_DST="$HOME/.local/bin/file-convert"
MENU_DST_DIR="$HOME/.local/share/kio/servicemenus"

mkdir -p -- "$(dirname -- "$BIN_DST")" "$MENU_DST_DIR"

link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    [[ "$(readlink -f -- "$dst")" == "$(readlink -f -- "$src")" ]] && { echo "= $dst"; return; }
    rm -- "$dst"
  elif [[ -e "$dst" ]]; then
    mv -- "$dst" "$dst.bak.$(date +%s)"
    echo "! backed up existing $dst"
  fi
  ln -s -- "$src" "$dst"
  echo "+ $dst -> $src"
}

chmod +x "$BIN_SRC"
link "$BIN_SRC" "$BIN_DST"

shopt -s nullglob
for f in "$MENU_SRC_DIR"/*.desktop; do
  chmod +x "$f"                          # KDE requires +x or Dolphin refuses to run the action
  link "$f" "$MENU_DST_DIR/$(basename -- "$f")"
done

# Refresh KDE service cache (Plasma 6). Falls back silently on non-KDE hosts.
if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
  echo "= refreshed KDE service cache (kbuildsycoca6)"
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "NOTE: add \$HOME/.local/bin to PATH in your shell rc." ;;
esac

echo
echo "Install complete. Restart Dolphin (or log out/in) for menus to appear:"
echo "  kquitapp6 dolphin 2>/dev/null; setsid dolphin >/dev/null 2>&1 &"
echo
echo "Run: file-convert doctor"
