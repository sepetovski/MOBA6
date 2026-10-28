# Gladiator Arena MOBA

Godot **4.7.2-stable** (standard, non-.NET). Tests use **GUT 9.7.1**.

Set `GODOT` to that binary (`tools/*.sh` fall back to `godot` on `PATH`). Git LFS is required: `git lfs install`.

Run: `$GODOT --path .` (F5 is the match: countdown, gates, twelve gray gladiators). The movement gym is `scenes/gyms/movement_gym.tscn` (F6).

Test: `tools/test.sh` then `tools/run_headless.sh scenes/main.tscn 120`.

Screenshots need a display. Linux without one: `xvfb-run -a tools/screenshot.sh scenes/main.tscn shots/main.png`. With no Vulkan driver the script adds `--rendering-method gl_compatibility`, so the image differs slightly from Forward+.

Plan and briefs: `docs/PLAN.md`, `docs/briefs/`.

Performance target machine: (fill in: CPU, GPU, 1080p).
