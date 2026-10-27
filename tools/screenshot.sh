#!/usr/bin/env bash
# Usage: tools/screenshot.sh <scene> <out.png> [frames]
# Needs a renderer. Without a display, wraps xvfb-run. Without Vulkan, uses gl_compatibility
# (the look differs slightly from Forward+; transparency fades will not match).
set -u
cd "$(dirname "$0")/.."
if [[ $# -lt 2 ]]; then
	echo "usage: tools/screenshot.sh <scene> <out.png> [frames]" >&2
	exit 2
fi
GODOT_BIN="${GODOT:-godot}"
scene="$1"
out="$2"
frames="${3:-60}"
mkdir -p "$(dirname "$out")"

render_flag=()
if ! command -v vulkaninfo >/dev/null 2>&1 || ! vulkaninfo --summary >/dev/null 2>&1; then
	render_flag=(--rendering-method gl_compatibility)
fi

runner=("$GODOT_BIN" --path . "${render_flag[@]}" -s tools/screenshot_runner.gd -- "$scene" "$out" "$frames")
if [[ -z "${DISPLAY:-}" ]]; then
	if ! command -v xvfb-run >/dev/null 2>&1; then
		echo "no DISPLAY and xvfb-run is not installed" >&2
		exit 1
	fi
	xvfb-run -a "${runner[@]}"
else
	"${runner[@]}"
fi
status=$?
if [[ $status -ne 0 ]]; then
	exit "$status"
fi
if [[ ! -s "$out" ]]; then
	echo "screenshot was not written: $out" >&2
	exit 1
fi
exit 0
