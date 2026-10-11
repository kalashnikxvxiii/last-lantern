#!/usr/bin/env bash
# Importa il progetto Godot (registra le class_name) ed esegue i test.
# Uso: tools/test.sh [--only=filtro]
set -euo pipefail
cd "$(dirname "$0")/../godot"
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
# gli avvisi di Godot all'uscita (variabili statiche ancora vive) non riguardano i test
timeout 600 godot --headless --path . res://tests/test_main.tscn -- "$@" 2>&1 \
	| sed -e '/leaked at exit/,+1d' -e '/resources still in use at exit/,+1d'
