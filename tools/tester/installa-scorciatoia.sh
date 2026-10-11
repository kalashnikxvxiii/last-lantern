#!/bin/sh
# Aggiunge Ultima Lanterna al menu delle applicazioni dell'utente corrente.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
cat > "$APPS/ultima-lanterna.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Ultima Lanterna
Comment=Roguelike d'azione 2D
Exec="$DIR/avvia.sh"
Icon=$DIR/icon.png
Terminal=false
Categories=Game;ActionGame;
DESK
chmod +x "$APPS/ultima-lanterna.desktop"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "Fatto: cerca \"Ultima Lanterna\" nel menu delle applicazioni."
echo "Se sposti questa cartella, esegui di nuovo lo script."
