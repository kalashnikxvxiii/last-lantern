#!/usr/bin/env bash
# Imports the Godot project (registers the class_names) and runs the tests.
# Usage: tools/test.sh [--only=filter]
set -euo pipefail
cd "$(dirname "$0")/../godot"
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
# Godot's exit warnings (static variables still alive) are not about the tests
timeout 600 godot --headless --path . res://tests/test_main.tscn -- "$@" 2>&1 \
	| sed -e '/leaked at exit/,+1d' -e '/resources still in use at exit/,+1d'
