#!/usr/bin/env bash
# Importa il progetto Godot (registra le class_name) ed esegue i test.
# Uso: tools/test.sh [--only=filtro]
set -euo pipefail
cd "$(dirname "$0")/../godot"
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
exec timeout 600 godot --headless --path . res://tests/test_main.tscn -- "$@"
