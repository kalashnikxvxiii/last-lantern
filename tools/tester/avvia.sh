#!/bin/sh
# Avvia Ultima Lanterna. --no-sandbox evita problemi con la sandbox di
# Chromium sulle distribuzioni che limitano i namespace utente.
DIR="$(cd "$(dirname "$0")" && pwd)"
unset ELECTRON_RUN_AS_NODE
exec "$DIR/ultima-lanterna" --no-sandbox "$@"
