# Task brief M4 — Simulation spine, teams and the 6v6 match

Start prompt (paste into each agent, filling in the role and tasks from the table):

```text
You are <ROLE>. Read AGENTS.md, docs/PLAN.md §1–§6 and §7 (M4), then do <TASKS> in docs/briefs/M4-match.md. Report in the format at the end of that file.
```

| Role | Tasks |
|---|---|
| A0 Lead and Integrator | Contract checks first, then T9 at the end |
| A4 Sim Core and AI | T1, T2, T3, T4, T6 |
| A6 UI | T5 |
| A1 World | T8 |
| A9 QA | T7 |

| | |
|---|---|
| Phase and size | Phase 1, size M. Finishing M4 completes Phase 1 |
| Depends on | M0, M1, M2 and M3 merged |
| Read first | `AGENTS.md`, `docs/PLAN.md` §3, §4, §5, §7 (M4), §10 |

## Goal

Twelve gray gladiators come out of the gates and one of them is yours.

## Scope

In: `Simulation` and `Match`, `SimUnit` and `UnitView`, the placeholder hero, controllers (human and bots), soft separation, the debug HUD, the main scene, the gate controller, soak tests. Out: damage and abilities (M5), networking (M7), real art (M8), scoreboard and minimap (M6).

## Order of work

1. A0 runs the contract checks below. Any failure becomes a request to the owner.
2. A4 does T1 and T2 first (everything else needs a unit to exist).
3. In parallel: A4 T3 and T4, A6 T5, A1 T8, A9 starts T7 against the interfaces.
4. A4 does T6 (the main scene) once T1–T3 and T5 are in.
5. A9 finishes T7. A0 does T9.

## Contract checks (A0, before anyone starts)

1. `ArenaBuilder.build(layout)` returns a root with an `ArenaInfo` child. `get_spawn_slot`, `get_bounds` and `contains_xz` work. The gate doors are not under the `NavigationRegion3D`. A path exists from a spawn slot to the arena centre.
2. `MovementMotor` has `step`, `has_goal`, `apply_impulse`, `start_forced_motion`, the signals `landed`, `stuck`, `arrived`, `state_changed`, `forced_motion_ended`, and the flags `can_move`, `can_jump`, `can_crouch`. `MovementIntent` follows the persistent-state and edge-flag rules in its header. `PlaceholderUnitView.bind(unit)` exists.
3. `MobaCamera`, `CursorPicker`, `PlayerController`, `OcclusionFader` and `GroundRing` match `docs/INTERFACES.md`.
4. `Command`, `Team`, `GameEvents` and `GameConfig` from M0 are present.

If a check fails, file a request to the owner and note the failure in your report. Do not patch another role’s code.

## You own

A4: `src/sim/` (except `movement/`, `abilities/`, `statuses/`), `src/ai/`, `data/heroes/`, `data/match_config.gd`, `data/bot_config.gd`, `scenes/main.tscn`, `scenes/units/`. A6: `src/ui/`, `scenes/ui/`. A1: `src/world/gate_controller.gd`. A9: `tests/sim/soak/`, `tests/perf/`, `tests/scenes/`. A0: integration and docs.

Pre-approved exceptions: A4 may create the stubs `data/hero_definition.gd` (exactly as in `docs/PLAN.md` §5), `data/unit_stats.gd` (just `max_health`) and `data/ability_definition.gd` (just `id` and `display_name`). A5 takes them over in M5. A6 may add the debug actions listed in T5 to `tools/setup_project.gd` and re-run it.

## Rules for this task

- The simulation never touches the camera, HUD or visuals. Presentation never writes simulation state. Controllers only call `Simulation.submit_command`.
- **Cheats are the one sanctioned exception to rule 1.** They go through `Simulation.debug_*`, which do nothing unless `OS.is_debug_build()`.
- Process priorities (`process_physics_priority`): `PlayerController` and every `BotController` −10, `Simulation` 0, presentation and HUD 10.
- No wall-clock time, `await` or global randomness in simulation code. Use `Simulation.tick` and `Simulation.rng`. Profiling timers in tests are fine.
- Call `reset_physics_interpolation()` after every spawn and teleport.
- Never store node references in `UnitState`.

## Interfaces to provide

Write these signatures into `docs/INTERFACES.md` in your first commit.

```gdscript
# data/match_config.gd
class_name MatchConfig extends Resource
@export var countdown_seconds := 5.0         # s
@export var gate_open_seconds := 1.0         # s
@export var match_seed := 1
@export var human_team := 0                  # Team.Id
@export var human_slot := 0                  # 0 to 5
@export var bot_difficulty := 3              # BotController.Difficulty, 3 = CHASE
@export var separation_speed := 2.0          # m/s, maximum push between overlapping units
@export var separation_radius_scale := 1.0   # multiplier on the sum of the two radii

# data/bot_config.gd
class_name BotConfig extends Resource
@export var think_interval := 0.25           # s between decisions
@export var reaction_jitter := 0.15          # s, random extra delay per bot
@export var wander_radius := 15.0            # m
@export var wander_pause_min := 0.5          # s
@export var wander_pause_max := 2.0          # s
@export var chase_range := 20.0              # m
@export var chase_stop_distance := 3.0       # m
@export var jump_rate := 0.10                # jumps per second while moving
@export var slide_rate := 0.05               # slides per second while moving
@export var slide_hold_min := 0.5            # s
@export var slide_hold_max := 1.0            # s

# src/sim/match.gd
class_name Match extends RefCounted
enum State { SETUP, COUNTDOWN, RUNNING }

# src/sim/unit_state.gd
class_name UnitState extends RefCounted
enum Controller { NONE, HUMAN, BOT }
var unit_id := 0
var team := 0
var hero_id: StringName
var display_name := ''             # A1 to A6, B1 to B6
var controller := Controller.NONE
var alive := true
var health := 100.0                # placeholder until M5
var max_health := 100.0
var move_state := 0                # MovementMotor.State
var velocity := Vector3.ZERO
var facing_yaw := 0.0

# src/sim/simulation.gd
class_name Simulation extends Node           # process_physics_priority = 0
signal ticked(tick: int)
var tick := 0
var rng := RandomNumberGenerator.new()
func start_match(config: MatchConfig, arena: Node3D) -> void: pass    # arena = root returned by ArenaBuilder.build()
func submit_command(cmd: Command) -> void: pass                       # stamps cmd.tick = tick + 1, queues it, logs it
func spawn_unit(hero: HeroDefinition, team: int, slot: int, controller: int) -> int: pass   # returns unit_id (1, 2, 3 ...)
func get_unit(unit_id: int) -> SimUnit: pass
func get_units() -> Array[SimUnit]: pass                              # ascending unit_id
func get_match_state() -> int: pass                                   # Match.State
func debug_teleport(unit_id: int, point: Vector3) -> void: pass       # debug builds only
func debug_respawn_all() -> void: pass                                # debug builds only
func debug_damage(unit_id: int, amount: float) -> void: pass          # debug builds only

# src/sim/sim_unit.gd
class_name SimUnit extends CharacterBody3D
var unit_id := 0
var team := 0
var state: UnitState
var motor: MovementMotor
var intent := MovementIntent.new()
func setup(id: int, hero: HeroDefinition, team_id: int, slot: int, nav_map: RID) -> void: pass
func apply_command(cmd: Command) -> void: pass        # command-to-intent table from the M3 brief
func sim_step(dt: float) -> void: pass                # motor.step, clear edge flags, refresh state

# src/sim/unit_view.gd
class_name UnitView extends Node3D
func bind(unit: SimUnit) -> void: pass                # read-only; wraps PlaceholderUnitView

# src/ai/bot_controller.gd
class_name BotController extends Node
enum Difficulty { OFF, IDLE, WANDER, CHASE }
func bind(bound_unit_id: int, sim: Simulation, config: BotConfig, difficulty: int) -> void: pass
```

## T1 — `Simulation` and `Match` (A4)

- **Tick.** `Simulation._physics_process(delta)` does, in this order: (1) `tick += 1`; (2) apply queued commands whose `tick` equals the new tick, sorted by unit id then `seq`; (3) update `Match`; (4) call `sim_step(dt)` on each unit in ascending id order, with `dt = 1.0 / GameConfig.TICK_RATE`; (5) soft separation (T4); (6) emit `ticked`.
- **Commands.** `submit_command` sets `cmd.tick = tick + 1`, queues it and calls `DebugService.log_command`. Drop commands for unknown or dead units. Before RUNNING, drop everything except `STOP`.
- **Registry.** A dictionary of `unit_id` to `SimUnit`. Ids start at 1.
- **RNG.** `start_match` seeds `rng` from `MatchConfig.match_seed`. Each bot gets its own `RandomNumberGenerator` seeded from `rng.randi()` at spawn, so one bot’s decisions never change another’s.
- **Match.** SETUP spawns twelve units (Team A slots 0–5 at the west gate, Team B slots 0–5 at the east gate) at `ArenaInfo.get_spawn_slot`, facing the arena centre. The human is `MatchConfig.human_team` and `human_slot`; everyone else is a bot. COUNTDOWN lasts `countdown_seconds` and sets every motor’s `can_move`, `can_jump` and `can_crouch` to false. RUNNING sets them to true. Every state change emits `GameEvents.match_state_changed`.
- **Navmesh readiness.** Spawn only after the arena’s navmesh has baked and two physics frames have passed.

## T2 — `SimUnit`, `UnitView` and the placeholder hero (A4)

- `scenes/units/sim_unit.tscn` (build it by code if you prefer): a `CharacterBody3D` on the Units layer that collides with World and Props only, a capsule from the hero’s `MovementProfile`, the metadata `unit_id`, and a `UnitView` child.
- `setup(...)` creates the `UnitState`, the `MovementMotor` (using `get_world_3d().navigation_map`), and forwards the motor signals: `landed` to `GameEvents.unit_landed`, `stuck` to `GameEvents.unit_stuck`.
- `apply_command` follows the command-to-intent table in `M3-movement.md`. `sim_step` calls `motor.step(intent, dt)`, then clears the edge flags (`stop`, `jump_pressed`, `crouch_slide_pressed`), then refreshes `UnitState` from the motor. The motor clears `has_move_target` itself on arrival.
- `UnitView` wraps A3’s `PlaceholderUnitView`. M8 swaps it for real models without touching the simulation.
- `data/heroes/gray_gladiator.tres`: id `gray_gladiator`, display name ‘Gray Gladiator’, no model scene yet, stats with `max_health` 100, the default `MovementProfile`, no abilities.

## T3 — Controllers (A4)

- **Human.** In the main scene, bind `PlayerController` to the human unit with `sink = simulation.submit_command`, and make `MobaCamera` follow it.
- **Bots.** `BotController` is a state machine driven every `think_interval` plus a per-bot `reaction_jitter`. It uses only commands.
  - IDLE: do nothing.
  - WANDER: sample a point within `wander_radius` using the bot’s own RNG, snap it with `NavigationServer3D.map_get_closest_point`, send `MOVE_TO`. After arriving, pause between `wander_pause_min` and `wander_pause_max`, then pick another.
  - CHASE: if an enemy is within `chase_range`, send `MOVE_TO` at its position each think step while farther than `chase_stop_distance`, and `STOP` when closer. With no enemy in range, WANDER.
  - Mobility: while moving, jump taps at `jump_rate` per second, and slides at `slide_rate` per second (`CROUCH_SLIDE` pressed, held between `slide_hold_min` and `slide_hold_max`, then released).
  - Unstick: on `unit_stuck` for its unit, pick a new target; if it sticks again within 2 s, send one `JUMP`.
- `Difficulty` comes from `MatchConfig.bot_difficulty`: OFF removes the bot’s decisions, IDLE stands still, WANDER never chases.

## T4 — Soft separation (A4)

Units do not collide with each other. After all units step, for each pair of alive units that are not VAULTING, MANTLING or FORCED, with horizontal distance `d` below `(r_a + r_b) × separation_radius_scale`, push both apart by half the overlap each, capped at `separation_speed × dt` per unit. Apply the push with `move_and_collide` so walls still stop it. When `d` is almost zero, pick a direction from the two unit ids so the result is deterministic. Units must never hard-block each other.

## T5 — Debug HUD (A6)

All of it reads simulation state and `GameEvents` only.

- **Team rings.** A `GroundRing` (from M2) under every unit: blue for Team A, red for Team B. This is the only colour in the game.
- **Nameplates and health bars.** Screen-space controls placed with `camera.unproject_position()` from the unit’s interpolated head position, hidden when behind the camera. Names A1–A6 and B1–B6 (the human is ‘A1 (you)’ or the equivalent). A small bar from `UnitState.health`. Every decorative control uses `mouse_filter = IGNORE`.
- **F1** help overlay listing the controls, built from the InputMap so it stays correct. **F2** collision shapes: build wireframes from `Shape3D.get_debug_mesh()` and toggle them (do not use `SceneTree.debug_collisions_hint` at run time, it is not designed to change after start). **F3** navmesh overlay (the navigation server’s debug drawing, or draw it yourself). **F4** free camera (reuse the one from M1’s review scene).
- **Readout (top left).** FPS, tick, match state and countdown, and for the controlled unit: movement state, speed, grounded flag, position, and the last five commands (from `DebugService`).
- **Cheats (debug builds only):** teleport the controlled unit to the cursor, cycle bot difficulty, time scale from 0.25× to 4× (`Engine.time_scale`), respawn all, damage the controlled unit by 25 (to see the health bar move). Add these InputMap actions to `tools/setup_project.gd`: `debug_teleport`, `debug_bots`, `debug_time_slower`, `debug_time_faster`, `debug_respawn`, `debug_damage`.

## T6 — `scenes/main.tscn` (A4, with A0)

Replace M0’s placeholder with a tiny scene that holds one node with a `MatchBootstrap` script. The script builds, in order: the arena from `data/arena_layouts/octagon_ring_v1.tres` with `ArenaBuilder.build`; the `Simulation` and its config resources; the twelve units; `MobaCamera` (bounds from `ArenaInfo.get_bounds()`, following the human unit); `PlayerController`; `OcclusionFader`; the `BotController`s; the HUD; the gate controller. The match starts in COUNTDOWN. Put the config resources in `data/match_configs/default.tres` and `data/bot_configs/default.tres`.

## T7 — Soak and smoke tests (A9)

- **Soak test** `tests/sim/soak/test_bot_match.gd` plus `tests/scenes/soak_bot_match.tscn`. Arena, `Simulation` and twelve bots, no human, camera or HUD. Raise `Engine.time_scale` and `Engine.max_physics_steps_per_frame`. Run until `tick` reaches 7,200 (120 simulated seconds) and assert:
  - Every unit stays inside the octagon or a gate tunnel (|z| ≤ 4.2 m and 40 m ≤ |x| ≤ 49.2 m) and between y = −1 and y = 10, checked every 30 ticks.
  - No `unit_stuck` episode lasts longer than 3 s without the unit moving again.
  - At least 10 of the 12 units travelled more than 20 m in total.
  - At the end, no two units are closer than 0.4 m.
  - The tick count equals the expected count (no skipped ticks).
  - Average simulation tick cost is at most 3 ms and worst case at most 6 ms (measured with a wall-clock timer around the tick, in the test only).
- Also run the scene with `tools/run_headless.sh tests/scenes/soak_bot_match.tscn 8000`, which fails on any `ERROR` line.
- **Human-command test** `tests/sim/test_human_commands.gd`. Spawn a human unit, send `MOVE_TO` across the arena and assert arrival within a sensible time, `JUMP` goes airborne, `CROUCH_SLIDE` while moving fast goes to sliding, `STOP` halts it, and movement commands are ignored before RUNNING.
- **Main-scene smoke test.** Load `scenes/main.tscn` headless for 600 frames with no errors.

## T8 — Gate controller (A1)

`src/world/gate_controller.gd` listens to `GameEvents.match_state_changed`. On RUNNING it disables the door collision immediately and sinks both doors below the floor over `gate_open_seconds` with a tween. Optional: set the crowd excitement to 1.0 on RUNNING and decay it to 0.3 over five seconds. Confirm that the doors are not part of the navmesh (units must path out through the open gates).

## T9 — Integration pass (A0)

- Merge in this order: M0, then M1, M3 and M2 in any order, then M4. Resolve interface drift in `docs/INTERFACES.md`.
- Run the full acceptance list below and the human playtest checklist.
- Confirm nothing outside `Simulation` calls `sim_step`, and that no code in `src/input`, `src/ai`, `src/camera` or `src/ui` sets a unit’s position or velocity (a code search plus a test).
- Retire the temporary scaffolding (`GymDriver`, `GymUnit` and the input sandbox stub) or list them in `docs/PARKING_LOT.md` to migrate onto `SimUnit` and `PlayerController`.
- Record decisions, update `README.md` with the measured FPS and machine, and tag the commit `phase-1-greybox`.

## Acceptance: Phase 1 is done when

- [ ] `main.tscn` shows a countdown, the gates open, and six gray gladiators walk out of each gate.
- [ ] I can control one unit with right-click, Space and Ctrl, and I can vault and mantle on the crates.
- [ ] Bots roam and chase without getting stuck.
- [ ] Every input reaches a unit through a `Command`. A0 confirms with a code search and a test.
- [ ] All tests are green, the frame rate meets `docs/PLAN.md` §10, and screenshots are attached.

## Human playtest checklist (end of Phase 1)

1. The countdown shows, the gates open, and twelve units come out.
2. I can tell at a glance which unit is mine.
3. Right-click moves immediately, and holding right-click steers well near obstacles.
4. Jump, crouch and slide feel the way they did in the gym.
5. Vault and mantle work reliably on the crates, and never trigger by accident.
6. Walls fade when they hide me, and nothing else blocks my view.
7. Bots look alive: they roam and chase, none are stuck, none sit on top of each other.
8. The crowd is visible and adds atmosphere with no pop-in.
9. The frame rate is 60 or better at 1080p (note the machine).
10. Anything that looks broken or feels wrong goes into a list, one line each.

## Verify

```bash
tools/test.sh
tools/run_headless.sh scenes/main.tscn 600
$GODOT --path . scenes/main.tscn
tools/screenshot.sh scenes/main.tscn shots/main.png 300
```

## Pitfalls

- Spawn units only after the navmesh has baked and two physics frames have passed, or they have no path.
- Controllers leave `Command.tick` at 0. Only `Simulation.submit_command` stamps it.
- Respect the process priorities, or commands arrive one tick late in inconsistent ways.
- The countdown freeze uses the motor flags, not the doors.
- Soft separation must skip units in scripted motion.
- Free units and views properly on respawn, and call `reset_physics_interpolation()` after teleports.
- HUD controls that are decorative must ignore the mouse, or they swallow clicks.
- If a number here conflicts with `docs/PLAN.md`, the plan wins. Log the conflict in your report.

## Report

Use the report template in `AGENTS.md` §10. A0 also reports the contract-check results, the measured FPS and machine, the soak-test numbers (average and worst tick cost), and the completed human playtest checklist.
