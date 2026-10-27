#!/usr/bin/env bash
# Runs the GUT suite headless. Exits non-zero when import fails or any test fails.
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"

import_log="$("$GODOT_BIN" --headless --path . --import 2>&1)"
import_status=$?
if [[ $import_status -ne 0 ]]; then
	printf '%s\n' "$import_log"
	exit "$import_status"
fi

"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit $?
