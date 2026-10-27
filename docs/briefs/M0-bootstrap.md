# Task brief M0 — Bootstrap

Start prompt (paste into the agent):

```text
You are A0 (Lead and Integrator), then A9 (QA). Read AGENTS.md, docs/PLAN.md §1–§6 and §7 (M0), then do everything in docs/briefs/M0-bootstrap.md. Report in the format at the end of that file.
```

| | |
|---|---|
| Roles | A0 Lead and Integrator (T1, T2), then A9 QA (T3, T4). One agent can do all four in order. With two agents, A9 starts once T1 is committed |
| Phase and size | Phase 1, size S |
| Depends on | Nothing |
| Read first | `AGENTS.md`, `docs/PLAN.md` §3, §5, §6, §7 (M0) |

## Goal

An empty but disciplined Godot project that every later agent can run, test and screenshot. No gameplay.

## Scope

In: project settings, folder layout, docs stubs, core skeleton scripts, test runner, screenshot runner. Out: arena, camera, units, input handling, UI. Stubs only.

## You own

Everything in M0: `project.godot`, `README.md`, `.gitignore`, `.gitattributes`, `docs/`, `src/core/`, `tools/`, `tests/`, `addons/gut/`, `scenes/main.tscn`. `AGENTS.md` and `docs/PLAN.md` are provided by the human: commit them unchanged.

## Before you start

Stop and report if any of these fail.

1. `$GODOT --version` prints a Godot 4 standard build. Record the full version string in `README.md`.
2. `git --version` and `git lfs version` work, and the folder is a git repository.
3. `AGENTS.md` and `docs/PLAN.md` are present.

## T1 — Project (A0)

**1. Create `project.godot`** at the repo root. Change the version in `config/features` to the pinned one.

```ini
config_version=5

[application]
config/name="Gladiator Arena MOBA"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080

[physics]
3d/physics_engine="Jolt Physics"
common/physics_ticks_per_second=60
common/physics_interpolation=true

[rendering]
renderer/rendering_method="forward_plus"
```

**2. Generate the rest of the settings with a script, not by hand.** Hand-written `InputEvent` entries in `project.godot` are error-prone. Write `tools/setup_project.gd` (a script that `extends SceneTree`) and run it with:

```bash
$GODOT --headless --path . -s tools/setup_project.gd
```

The script sets each value with `ProjectSettings.set_setting(...)`, then calls `ProjectSettings.save()` and `quit()`. Sketch for one action (verify it works, then repeat):

```gdscript
var ev := InputEventKey.new()
ev.physical_keycode = KEY_SPACE
ProjectSettings.set_setting('input/jump', {'deadzone': 0.5, 'events': [ev]})
```

Mouse actions use `InputEventMouseButton` with `button_index`. Commit both the script and the resulting `project.godot`. The script must be safe to run twice.

InputMap actions to create:

| Action | Default |
|---|---|
| `move_click` | Right mouse button |
| `select` | Left mouse button |
| `jump` | Space |
| `crouch_slide` | Left Ctrl |
| `stop` | S |
| `ability_1` to `ability_4` | Q, W, E, R |
| `camera_lock` | Y |
| `zoom_in`, `zoom_out` | Mouse wheel up, down |
| `camera_pan_left`, `camera_pan_right`, `camera_pan_up`, `camera_pan_down` | Arrow keys |
| `debug_help`, `debug_collision`, `debug_nav`, `debug_freecam` | F1, F2, F3, F4 |

Also set the 3D physics layer names through `layer_names/3d_physics/layer_1` … `layer_8`: World, Props, Units, Projectiles, Triggers, Pick, NavBlock, Occluders. Register the autoloads (`autoload/GameEvents` = `*res://src/core/game_events.gd`, and the same for `GameConfig` and `DebugService`).

**3. Check.** `$GODOT --headless --path . --import` exits 0 with no `ERROR` lines. `$GODOT --headless --path . --quit-after 5` exits 0.

## T2 — Repo skeleton (A0)

**Folders** (add a `.gitkeep` to each empty one): `addons/`, `art/source/`, `art/exports/`, `assets/{materials,textures,models,audio,fonts}/`, `data/{heroes,abilities,statuses,movement_profiles,arena_layouts}/`, `src/{core,sim,world,input,camera,ai,net,ui,tools}/`, `src/sim/{movement,abilities,statuses}/`, `scenes/{arena,units,gyms,ui}/`, `tests/{unit,sim,world,scenes,perf}/`, `tools/blender/`, `docs/{requests,briefs}/`.

**Files**

- `.gitignore`: `.godot/`, `.mono/`, `*.translation`, `/builds/`, `/shots/`, `.DS_Store`, `Thumbs.db`.
- `.gitattributes`: `* text=auto`, plus Git LFS for `*.blend`, `*.glb`, `*.png`, `*.ogg`, `*.wav`, `*.psd`. Run `git lfs install`.
- `README.md` (30 lines at most): pinned Godot version, GUT version, how to set `GODOT`, how to run the project, how to run the tests, where the plan and briefs live, the performance target machine (leave a placeholder for the human to fill in).
- `docs/DECISIONS.md` with first entries: ADR-001 Godot version, ADR-002 Jolt Physics set explicitly, ADR-003 GUT for tests. One line each: decision, date, why.
- `docs/INTERFACES.md`: a table of the binding type names from `AGENTS.md` with owner and status (all ‘planned’).
- `docs/TUNING.md` (empty table: value, unit, default, file, why), `docs/PARKING_LOT.md`, `docs/requests/.gitkeep`.

**Core scripts in `src/core/`**

- `command.gd`: exactly the `Command` class from `docs/PLAN.md` §5. One clarification: the `pressed` field also applies to `JUMP` (a `JUMP` command with `pressed = false` means the key was released; variable jump height needs it).
- `team.gd`: `class_name Team`, `enum Id { A = 0, B = 1 }`, `static func opposing(team: Id) -> Id`.
- `game_events.gd` (autoload `GameEvents`), signals: `unit_spawned(unit_id: int)`, `unit_died(unit_id: int, killer_id: int)`, `damage_dealt(source_id: int, target_id: int, amount: float, damage_type: int)`, `ability_cast(unit_id: int, slot: int)`, `status_applied(unit_id: int, status_id: StringName)`, `match_state_changed(state: int)`, `unit_stuck(unit_id: int)`, `unit_landed(unit_id: int, fall_speed: float)`.
- `game_config.gd` (autoload `GameConfig`): `TICK_RATE` and the collision layer bit masks as constants (`LAYER_WORLD` = 1, `LAYER_PROPS` = 2, `LAYER_UNITS` = 4, `LAYER_PROJECTILES` = 8, `LAYER_TRIGGERS` = 16, `LAYER_PICK` = 32, `LAYER_NAVBLOCK` = 64, `LAYER_OCCLUDERS` = 128). No gameplay numbers.
- `debug_service.gd` (autoload `DebugService`): `var show_overlay := false` and `func log_command(cmd: Command) -> void`, empty for now.

**Scene.** `scenes/main.tscn`: a `Node3D` root with a gray floor plane, a `DirectionalLight3D`, a `WorldEnvironment` with a flat gray background, and a static `Camera3D` looking down at about 55° so a screenshot shows something. Build it by script or keep the `.tscn` tiny. M4 replaces it.

## T3 — Tests (A9)

1. Install GUT from its official releases (github.com/bitwes/Gut, or the Godot asset store). Use the release line for Godot 4 (9.x). Copy it to `addons/gut/`, enable the plugin through `editor_plugins/enabled` in the setup script, and record the exact GUT version in `README.md`. If the newest release fails to load on the pinned Godot, report the error and try the previous release.
2. Create `tools/test.sh`: `cd` to the repo root, read `$GODOT` (fall back to `godot`), run `--import` first (print its output if it exits non-zero), then run the raw GUT call from `AGENTS.md` §4. The script must exit non-zero when any test fails.
3. Create `tools/run_headless.sh <scene> <frames>`: runs `$GODOT --headless --path . <scene> --quit-after <frames>`. `--quit-after` counts frames, not seconds. It must fail (exit 1) when the output contains `ERROR` or `SCRIPT ERROR`, because Godot exits 0 even after script errors.
4. Add `tests/unit/test_smoke.gd` (extends `GutTest`) that checks: `Engine.physics_ticks_per_second` is 60; the project setting `physics/3d/physics_engine` is `Jolt Physics`; every InputMap action in the T1 table exists; the three autoloads exist under `/root`.
5. Prove the exit code: temporarily add a failing test, confirm `tools/test.sh` exits non-zero, then remove it.

## T4 — Screenshots (A9)

Create `tools/screenshot.sh <scene> <out.png> [frames]` and `tools/screenshot_runner.gd`. The runner `extends SceneTree`, reads its arguments with `OS.get_cmdline_user_args()` (they come after `--`), loads the scene, waits N frames (default 60), saves `get_root().get_viewport().get_texture().get_image()` as a PNG, and quits. It needs a real renderer, so it cannot run with `--headless`:

- Windows and macOS: run it normally.
- Linux without a display: wrap it in `xvfb-run -a`. If there is no Vulkan driver, add `--rendering-method gl_compatibility` and note in the README that the look differs slightly from Forward+.

Document the exact command for the human’s OS in `README.md`.

## Acceptance

- [ ] A fresh clone, then `$GODOT --headless --path . --import`, then `tools/test.sh` is green.
- [ ] The deliberately failing test made `tools/test.sh` exit non-zero (then it was removed).
- [ ] `tools/run_headless.sh scenes/main.tscn 120` exits 0 with no `ERROR` lines.
- [ ] `scenes/main.tscn` opens a window showing an empty gray world.
- [ ] `tools/screenshot.sh scenes/main.tscn shots/main.png` creates a PNG (attach it).
- [ ] `git status` is clean, `.godot/` is not tracked, and LFS patterns are set.
- [ ] `README.md` explains setup, run and test in 30 lines or fewer.

## Pitfalls

- Godot exits 0 on script errors. Always scan the log.
- GUT options need `=` with no spaces, or Godot treats the value as a scene to run.
- Run `--import` after adding `class_name` scripts, or headless runs may not find them.
- Do not add any gameplay. If you are tempted, write it in `docs/PARKING_LOT.md`.

## Report

Use the report template in `AGENTS.md` §10. Also state the exact Godot and GUT versions you pinned and the OS you tested the screenshot command on.
