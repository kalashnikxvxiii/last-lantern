#!/bin/sh
# Adds Last Lantern to the current user's application menu.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
cat > "$APPS/last-lantern.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Last Lantern
Comment=2D action roguelike
Exec="$DIR/start.sh"
Icon=$DIR/icon.png
Terminal=false
Categories=Game;ActionGame;
DESK
chmod +x "$APPS/last-lantern.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "Done: look for \"Last Lantern\" in the applications menu."
echo "If you move this folder, run the script again."
