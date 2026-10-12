#!/bin/sh
# Starts Last Lantern. --no-sandbox avoids problems with Chromium's sandbox
# on distributions that restrict user namespaces.
DIR="$(cd "$(dirname "$0")" && pwd)"
unset ELECTRON_RUN_AS_NODE
exec "$DIR/last-lantern" --no-sandbox "$@"
