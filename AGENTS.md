# AGENTS.md

Rules for every agent working on **Gladiator Arena MOBA** (Godot 4). Read this file completely, then `docs/PLAN.md` §1–§6 and the section for your milestone. If this file and the plan disagree, the plan wins: say so in your report and carry on with the plan.

## 1. The game in one paragraph

A 6v6 MOBA-style team arena game with a fixed top-down 3D camera, mouse-driven control (right-click to move) and rich movement (jump, crouch, slide, vault, mantle). Phase 1 is a gray-box ‘Octagon Ring’: an 80 m octagon arena full of crates and barrels, a gate on the left for Team A and one on the right for Team B, a gray crowd in the stands, one human and eleven bots. Custom heroes and abilities arrive later as data plus models, so core code must never need editing to add a hero.

## 2. Fixed decisions

| Topic | Decision |
|---|---|
| Engine | Godot 4.7.2-stable, standard (non-.NET) build. Pinned in `README.md`. Never upgrade on your own |
| Language | GDScript, statically typed everywhere. No C# |
| Rendering and physics | Forward+ renderer. Jolt Physics set explicitly (`physics/3d/physics_engine` = `Jolt Physics`). 60 Hz physics tick, physics interpolation on |
| Units | Metres, seconds, kilograms. 1 Blender unit = 1 m |
| Axes | +X = east = right on screen = Team B side. −X = west = left = Team A side. −Z = north = up on screen. +Z = south = toward the camera. +Y = up. Floor at y = 0. A unit’s forward is −Z |
| Teams | `Team.Id.A` = 0 (west, left). `Team.Id.B` = 1 (east, right) |
| Look | Everything gray. Team colour appears only in the ring under each unit and in the HUD |
| World physics | Static colliders only. No `RigidBody3D` gameplay props |
| Collision layers | 1 World, 2 Props, 3 Units, 4 Projectiles, 5 Triggers, 6 Pick, 7 NavBlock, 8 Occluders (bit masks are constants in `GameConfig`) |

## 3. Architecture rules (hard)

1. **Gameplay state changes only through `Command`s into `Simulation`.** Humans, bots and (later) network clients use the same path.
2. **Layers.** Input (`src/input`, `src/camera`) builds commands and never moves units. Simulation (`src/sim`) ticks at the fixed physics rate, owns all gameplay state, and never touches camera, mouse, UI, audio or visuals. Presentation (`UnitView`, VFX, HUD, crowd) reads state and never writes it back. Data lives in `Resource` files. Events go through the `GameEvents` autoload: the simulation emits, presentation and UI listen.
3. Units have no `_physics_process` of their own. `Simulation` calls `sim_step(dt)` on every unit in ascending unit-id order.
4. Commands are stamped with the next tick and applied at the start of that tick.
5. No gameplay numbers in scripts. Put them in `Resource` classes as `@export` fields with the unit in a comment, and list them in `docs/TUNING.md`.
6. No wall-clock time, `await`, timers or global randomness in simulation code. Use `Simulation.tick` and `Simulation.rng`.
7. Hit detection and area effects use physics-server shape queries, not `Area3D` signals.
8. Never reach into UI or camera nodes by node path. Use signals or autoloads.
9. Movement must be *reconcilable*: the same code runs on client and server, and small errors are corrected smoothly. Bit-exact determinism is not required.

Binding type names (definitions in `docs/PLAN.md` §5 and the task briefs): `Command`, `Team`, `MovementProfile`, `MovementMotor`, `MovementIntent`, `HeroDefinition`, `Simulation`, `SimUnit`, `UnitState`, `UnitView`, `ArenaLayout`, `ArenaBuilder`, `ArenaInfo`, `CursorPicker`, `MobaCamera`, `GameEvents`. Public interfaces are written in `docs/INTERFACES.md`. Do not rename them without an entry in `docs/DECISIONS.md`.

## 4. Commands

Set the `GODOT` environment variable to the Godot executable, or put `godot` on PATH. Scripts in `tools/` read `$GODOT` and fall back to `godot`. They are created in M0; until then use the raw commands.

```bash
$GODOT --headless --path . --import              # refresh class cache and imports
tools/test.sh                                    # all tests, headless; non-zero exit on failure
tools/run_headless.sh <scene> <frames>           # run a scene for N frames; fails on any ERROR line
tools/screenshot.sh <scene> <out.png> [frames]   # needs a renderer (not --headless)
```

Raw GUT call (what `tools/test.sh` wraps):

```bash
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

GUT options are written `-gname=value` with no spaces. GUT exits 0 when every test passes and 1 when any fail. Test files are `tests/**/test_*.gd` and extend `GutTest`.

## 5. Godot gotchas

- `--headless` has no rendering. Use it for logic only, never for screenshots or shader checks.
- Godot exits 0 even when scripts print errors. `tools/*.sh` must scan the output for `ERROR` and `SCRIPT ERROR` and fail on them.
- After adding or renaming a `class_name` script, run `$GODOT --headless --path . --import` once, or types may not resolve in headless runs. If they still do not, run `$GODOT --headless --path . --editor --quit` once.
- Commit `*.uid` and `*.import` files. Never commit `.godot/`. Never hand-edit `uid://` values.
- Prefer scenes built by code (runtime builders or `@tool` scripts) over hand-edited `.tscn` files. If you must edit a `.tscn`, keep the change small and local. One owner per scene.
- `CharacterBody3D` has no step climbing. Movement uses the custom step-up helper (M3).
- Physics interpolation: move bodies only inside physics ticks. After a teleport call `reset_physics_interpolation()`.
- If you suspect a Jolt-specific bug, write a minimal repro and log it in `docs/DECISIONS.md`. Never switch physics engines on your own.

## 6. Code conventions

- One class per file. `class_name` for shared types. snake_case file names, PascalCase classes, UPPER_SNAKE constants.
- Type every variable, parameter and return value. Do not shadow built-in names (for example do not name a variable `seed`).
- Upward communication by signal, downward by call.
- Comment the *why*, not the *what*. Keep functions short.
- Do not mass-reformat or rename files you do not own. Keep diffs small.

## 7. Ownership

| Role | Owns |
|---|---|
| A0 Lead and Integrator | `docs/`, `project.godot`, `src/core/`, merges |
| A1 World | `src/world/`, `scenes/arena/`, `data/arena_layouts/`, `data/arena_layout.gd`, `data/prop_placement.gd` |
| A2 Camera and Input | `src/camera/`, `src/input/` |
| A3 Movement | `src/sim/movement/`, `data/movement_profile.gd`, `data/movement_profiles/`, `scenes/gyms/` |
| A4 Sim Core and AI | `src/sim/` (except `movement/`, `abilities/`, `statuses/`), `src/ai/`, `data/heroes/` |
| A5 Combat and Abilities | `src/sim/abilities/`, `src/sim/statuses/`, `data/abilities/`, `data/statuses/` |
| A6 UI | `src/ui/`, `scenes/ui/` |
| A7 Network | `src/net/` |
| A8 Tech Art | `tools/blender/`, `src/tools/`, `art/`, `assets/` |
| A9 QA | `tests/`, `tools/` (except `tools/blender/`) |

Need a change in a folder you do not own? Write a short request in `docs/requests/YYYY-MM-DD-from-to.md` (what, why, proposed signature) and carry on with a stub. Do not edit another role’s files, except to fix a build-breaking error, and say so in your report. Exceptions pre-approved for a task are listed in its brief.

## 8. Workflow

- One branch per task. Cloud agents name branches `cursor/<task-id>-<run-id>` (for example `cursor/m3-t2-jump-2195`). Local agents may use the short form `m3-t2-jump`. Small commits with messages like `M3-T2: add coyote time`. Run `tools/test.sh` before every commit. A0 merges.
- Open design question? Implement the default from the plan, leave a `TODO(decision)` comment and add one line to `docs/DECISIONS.md`. Never stop and wait.
- Visual work needs a screenshot from `tools/screenshot.sh`, or a short ‘how to see it’ (scene and steps).
- Task briefs live in `docs/briefs/`. A brief is the contract for that task. Do the whole brief and nothing outside it.

## 9. Definition of done (every task)

1. Runs with no errors or warnings in the Godot output.
2. Tests added for the logic, and `tools/test.sh` passes headless.
3. The task’s acceptance checklist is ticked in your report.
4. Public interfaces are in `docs/INTERFACES.md` and decisions are in `docs/DECISIONS.md`.
5. Performance stays inside the budgets in `docs/PLAN.md` §10.
6. Report posted in the format below.

## 10. Report template

```text
TASK:               M3-T2
STATUS:             done | partial | blocked
FILES CHANGED:      ...
TESTS:              added or updated, and the result of tools/test.sh
HOW TO SEE IT:      scene and steps, or screenshot path
DECISIONS LOGGED:   ...
KNOWN ISSUES:       ...
REQUESTS FILED:     ...
```

## 11. Out of scope

Minions, towers, lanes, jungle, items, gold, XP, shop, fog of war, spectator mode, replays, matchmaking, accounts, cosmetics, arena hazards, destructible props, voice lines. Put ideas in `docs/PARKING_LOT.md` and do not build them.
