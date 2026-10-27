#!/usr/bin/env bash
# Usage: tools/run_headless.sh <scene> <frames>
# --quit-after counts frames. Godot exits 0 even after script errors, so this scans the log.
set -u
cd "$(dirname "$0")/.."
if [[ $# -lt 2 ]]; then
	echo "usage: tools/run_headless.sh <scene> <frames>" >&2
	exit 2
fi
GODOT_BIN="${GODOT:-godot}"
scene="$1"
frames="$2"

log="$("$GODOT_BIN" --headless --path . "$scene" --quit-after "$frames" 2>&1)"
status=$?
printf '%s\n' "$log"
if [[ $status -ne 0 ]]; then
	exit "$status"
fi
if printf '%s\n' "$log" | grep -E 'SCRIPT ERROR|(^|[^A-Za-z])ERROR:' >/dev/null; then
	exit 1
fi
exit 0
