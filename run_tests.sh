#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"

"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit "$@"
