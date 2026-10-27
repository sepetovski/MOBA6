# Task brief M3 — Movement core

Start prompt (paste into the agent):

```text
You are A3 (Movement). Read AGENTS.md, docs/PLAN.md §1–§6 and §7 (M3), then do everything in docs/briefs/M3-movement.md. Report in the format at the end of that file.
```

| | |
|---|---|
| Roles | A3 Movement (T1–T9). A9 QA writes T10 using the harness A3 provides |
| Phase and size | Phase 1, size L. This is the heart of the game |
| Depends on | M0 merged. Runs in parallel with M1 and M2. M4 builds on your interfaces |
| Read first | `AGENTS.md`, `docs/PLAN.md` §3, §4, §5, §7 (M3) |

## Goal

Movement that feels great in a test gym before anything else is built on top of it.

## Scope

In: the motor, path following, jump, crouch, slide, step-up, vault and mantle, the forced-motion API, a placeholder view, the gym, the test harness. Out: `Simulation`, `SimUnit` and controllers (M4), `MobaCamera` and the real input layer (M2), abilities (M5).

## You own

`src/sim/movement/`, `data/movement_profile.gd`, `data/movement_profiles/`, `scenes/gyms/`. Pre-approved exception: you may create `tests/sim/movement/movement_harness.gd` (the harness only). A9 writes the tests.

## Temporary scaffolding (delete when M2 and M4 land)

Mark all of it `# TEMP`. `GymUnit` (a `CharacterBody3D` with a capsule, a `motor` property and the placeholder view). `GymDriver` (raw mouse and keyboard turned into `MovementIntent`, with a minimal ray pick onto the gym floor). A fixed 55° follow camera. Rule 1 of `AGENTS.md` (commands only) applies once M4 lands; until then the driver builds intents directly.

## Interfaces to provide

Write these into `docs/INTERFACES.md` in your first commit so A4 can build against them.

**`MovementProfile`.** Create `data/movement_profile.gd` exactly as in `docs/PLAN.md` §5. You may add fields inside the matching export groups, but never rename or remove one. Add these:

```gdscript
@export var slide_slope_factor := 1.0   # Slide: multiplier on gravity along the slope
@export var slide_turn_factor := 0.35   # Slide: fraction of turn_rate_deg while sliding
@export var vault_duration := 0.35      # Traversal: s
@export var mantle_duration := 0.6      # Traversal: s
@export var vault_min_speed := 3.0      # Traversal: m/s needed to vault
@export var vault_reach := 1.2          # Traversal: m from the obstacle face to start a vault or mantle
@export var arrive_distance := 0.3      # Pathing: m
@export var repath_blocked_time := 0.5  # Pathing: s
@export var stuck_time := 1.0           # Pathing: s
@export var max_speed_cap := 12.0       # Safety: m/s, hard cap on horizontal speed
```

**`MovementIntent`, `MovementMotor`, `PathFollower`:**

```gdscript
# src/sim/movement/movement_intent.gd
# Persistent state (has_move_target, steering, the *_held flags) stays until changed.
# Edge flags (stop, jump_pressed, crouch_slide_pressed) are cleared by the owner after each step().
class_name MovementIntent extends RefCounted
var has_move_target := false         # MOVE_TO active: the motor latches the goal and clears this on arrival
var move_target := Vector3.ZERO
var steering := false                # STEER active: move straight toward steer_point
var steer_point := Vector3.ZERO
var stop := false                    # clear target and steering this tick
var jump_pressed := false            # true only on the tick the key went down
var jump_held := false
var crouch_slide_pressed := false    # true only on the tick the key went down
var crouch_slide_held := false

# src/sim/movement/movement_motor.gd
class_name MovementMotor extends RefCounted
enum State { GROUNDED, CROUCHED, SLIDING, AIRBORNE, VAULTING, MANTLING, FORCED }
signal landed(fall_speed: float)
signal stuck()
signal state_changed(old_state: State, new_state: State)
signal forced_motion_ended(hit_wall: bool)
signal arrived()
var state: State = State.GROUNDED
var can_move := true                 # statuses set these in Phase 2
var can_jump := true
var can_crouch := true
func _init(body: CharacterBody3D, profile: MovementProfile, nav_map: RID) -> void: pass
func step(intent: MovementIntent, dt: float) -> void: pass
func apply_impulse(impulse: Vector3) -> void: pass
func start_forced_motion(displacement: Vector3, duration: float, ease_curve: Curve = null, ignore_gravity := true) -> void: pass
func get_horizontal_speed() -> float: pass
func has_goal() -> bool: pass

# src/sim/movement/path_follower.gd
class_name PathFollower extends RefCounted
func set_goal(map: RID, from: Vector3, to: Vector3) -> void: pass    # NavigationServer3D.map_get_path(map, from, to, true)
func next_direction(position: Vector3) -> Vector3: pass               # horizontal unit vector to the next waypoint, ZERO when arrived
func is_arrived(position: Vector3, arrive_distance: float) -> bool: pass
func clear() -> void: pass
```

**Command to intent mapping** (A4 implements this in M4; document it in `docs/INTERFACES.md`):

| Command | Effect on `MovementIntent` for that tick |
|---|---|
| `MOVE_TO` | `has_move_target` = true, `move_target` = point, `steering` = false |
| `STEER`, pressed | `steering` = true, `steer_point` = point, `has_move_target` = false |
| `STEER`, released | `steering` = false |
| `STOP` | `stop` = true |
| `JUMP`, pressed | `jump_pressed` = true for that tick, `jump_held` = true until released |
| `JUMP`, released | `jump_held` = false |
| `CROUCH_SLIDE`, pressed | `crouch_slide_pressed` = true for that tick, `crouch_slide_held` = true until released |
| `CROUCH_SLIDE`, released | `crouch_slide_held` = false |

## Order of work inside `step(intent, dt)`

1. Tick timers: coyote, jump buffer, slide cooldown, state timers.
2. Apply the intent: `stop` clears the goal and steering. A new move target asks `PathFollower` for a path. Steering overrides the path.
3. Resolve state transitions (table below).
4. Compute the desired horizontal velocity for the current state: ground and crouch from path or steering, slide from friction and slope, air from air control, vault and mantle from the scripted path, forced from the forced motion.
5. Vertical: gravity (half-step), jump takeoff, early-release cut.
6. Step-up helper (grounded only).
7. Set `body.velocity`, call `body.move_and_slide()` once, read the results back.
8. Post: landing detection (emit `landed`), facing update, stuck detection, `state_changed`.

## T1 — Motor and pathing

- **Body setup.** `floor_max_angle` 40° (as radians), `floor_snap_length` 0.3, `floor_stop_on_slope` true, `floor_constant_speed` true, `up_direction` up, grounded motion mode. One capsule `CollisionShape3D` placed so the body origin is at the feet (`position.y` = height ÷ 2).
- **Ground movement.** Accelerate the horizontal velocity toward the desired direction × `run_speed` with `acceleration`, decelerate with `deceleration`. Project the desired velocity onto the floor plane (use the floor normal) so ramps do not slow the unit.
- **Facing.** Rotate the body yaw toward the movement direction at `turn_rate_deg`, clamping each step. While sliding, face the slide direction.
- **Path following.** The motor latches the goal. Call `PathFollower.set_goal` only when `has_move_target` is true and `move_target` differs from the latched goal (or on a rising edge), never every tick. If the target is off the navmesh use `NavigationServer3D.map_get_closest_point`. Advance waypoints within `arrive_distance`. If the unit is blocked (horizontal speed below 10% of `run_speed` for `repath_blocked_time`), re-path once. On arrival, an unreachable target, `stop`, or a new `steering` intent, clear the latched goal and set `intent.has_move_target = false` (the motor may change the intent it is given). Emit `arrived` when the goal was reached.
- **Steering.** Move straight toward `steer_point` on the XZ plane and stop within `arrive_distance`.
- **Stuck detection.** With a goal active and horizontal speed below 10% of `run_speed` for `stuck_time` after the one re-path, emit `stuck` once per episode.
- Cap horizontal speed at `max_speed_cap`.

## T2 — Jump

- Takeoff speed `v0 = sqrt(2 × gravity × jump_height)`.
- Early release while rising: cut the vertical speed so the apex equals `min_jump_height`: `v_y = min(v_y, sqrt(2 × gravity × max(min_jump_height − (y − jump_start_y), 0)))`.
- Gravity is `gravity` while rising and `gravity × fall_gravity_mult` while falling.
- Integrate gravity in half steps (half the velocity change before `move_and_slide`, half after). Plain Euler at 60 Hz undershoots the apex by about 5%, which would break the ±5% test.
- Coyote time: a jump is allowed for `coyote_time` after walking off an edge (not after jumping). Jump buffer: a press within `jump_buffer` before landing triggers a jump on landing.
- Air control: horizontal acceleration × `air_control`. Horizontal speed may not be pushed above `max(run_speed, takeoff speed)`.
- Emit `landed(fall_speed)` when the unit touches the floor after being airborne.
- A jump from crouch stands up first if there is headroom, otherwise it is ignored.

## T3 — Crouch

- Change the capsule height to `height_crouch` with the feet fixed (shape height and `position.y` together, no popping through the floor).
- Headroom check before standing: `PhysicsDirectSpaceState3D.intersect_shape` with the standing capsule at the current position (mask World + Props, exclude the body). Clear when the result is empty.
- Crouch speed is `run_speed × crouch_speed_mult`. Respect `can_crouch`.

## T4 — Slide

- **Enter** when grounded, `crouch_slide_pressed`, horizontal speed at or above `slide_enter_speed`, cooldown ready, and `can_crouch`. Set the slide direction to the current horizontal velocity direction. Set `slide_speed = min(speed + slide_boost, max_speed_cap)`. Capsule height becomes `height_slide`.
- **Each tick.** `slide_speed -= slide_friction × dt`. Slope effect: `slide_speed += gravity × sin(slope_angle) × slide_slope_factor × dot(downhill_dir, slide_dir) × dt`. Steering rotates the slide direction toward the desired direction at `turn_rate_deg × slide_turn_factor`. Clamp to `max_speed_cap`.
- **Exit.** Speed below `slide_min_speed` goes to CROUCHED (if the key is held or there is no headroom) or GROUNDED. Releasing the key goes to GROUNDED when headroom is clear, bleeding any speed above `run_speed` with `deceleration`. Jump goes to AIRBORNE and keeps the horizontal velocity (a slide-jump). The cooldown starts when the slide ends.
- A slide must pass under a 1.0 m gap. A unit that cannot stand because of a low ceiling stays crouched until there is room.

## T5 — Steps and slopes

- **Step-up** (`CharacterBody3D` has none). When grounded and horizontal motion is blocked: (1) `test_move` up by `step_height`; (2) `test_move` forward by the intended motion from the raised position; (3) if both are clear, move up, move forward, then snap down to the floor. Only for obstacles up to `step_height`.
- No jitter on ramps. Tune `floor_snap_length`. A unit at rest on a 40° slope must not creep. Slopes above 40° behave as walls.

## T6 — Vault and mantle

- **Trigger.** `jump_pressed`, moving toward an obstacle (velocity within 60° of the direction into its face), with the face within `vault_reach`. Space pressed farther away is a normal jump (the unit may land on top).
- **Probe.** Three horizontal shape casts or rays forward at knee (0.4 m), chest (1.0 m) and head (1.6 m) height. The nearest hit gives the face and its normal. Then cast down from the point 0.3 m past the face at `feet + mantle_max_height + 0.2` to find the top surface. `height = top − feet_y`.
- **Classify** with the traversal table (`docs/PLAN.md` §4). `step_height < height ≤ vault_max_height` is a vault candidate. `vault_max_height < height ≤ mantle_max_height` is a mantle. Anything higher is a wall.
- **Vault** needs horizontal speed of at least `vault_min_speed` and a free landing spot within 2.0 m beyond the far face (capsule shape query on the floor there). Otherwise it is a normal jump. **Mantle** needs the capsule to fit on top (shape query) and the unit to face the obstacle (within 60°).
- **Motion.** VAULTING follows a precomputed curve (start, apex at `top + 0.1`, landing) over `vault_duration` and exits with the entry speed. MANTLING moves up then forward onto the top over `mantle_duration`. Set the position along the validated path each tick, then resume normal movement.
- A stun, forced motion or `can_move = false` cancels either one. Write the cancel rules in the file header.

## T7 — Forced motion API

- `apply_impulse(v)` adds to the velocity once (the horizontal part decays with `deceleration`, the vertical part goes through gravity).
- `start_forced_motion(displacement, duration, ease_curve, ignore_gravity)` enters FORCED. It moves the body along `displacement` over `duration`, with progress shaped by `ease_curve` if given, stopping at walls (use `move_and_collide`). It ignores player intent while active, emits `forced_motion_ended(hit_wall)`, then goes to AIRBORNE or GROUNDED.
- `can_move`, `can_jump` and `can_crouch` gate the matching intent handling.

## T8 — Placeholder view

`PlaceholderUnitView` in `src/sim/movement/placeholder_unit_view.gd`, read-only, with `bind(unit)`. M4 wraps it as `UnitView`. A gray capsule (albedo 0.82) with a ‘nose’ (a small box on the −Z side). Squash to the stance height for crouch and slide, tilt back about 25° for slide, stretch to 1.1 while rising. A blob shadow (a dark disc on the ground below, shrinking with height) and a landing marker (a thin ring where the unit will land, or directly below when there is no horizontal velocity), both found by a downward ray against World + Props. These two are the main aid for reading height from a top-down camera.

## T9 — Movement gym

`scenes/gyms/movement_gym.tscn`, built by a `GymBuilder` script, all gray, about 80 m long. Bake a navmesh with the same settings as the arena (radius 0.45, height 1.8, max climb 0.4, max slope 40°). Stations from west to east, 6 m apart:

1. Start pad.
2. Stairs: five steps of 0.2 m rise.
3. Ramps at 15°, 25°, 35° and 45° (45° must act as a wall).
4. Thin walls (0.3 m thick) at 0.3, 0.8, 1.2, 1.6 and 2.2 m, plus a 4 × 4 m block 1.0 m high (the unit mounts instead of vaulting).
5. A 1.0 m slide gap and a 1.2 m crouch gap, each 4 m long.
6. Jump gaps of 2, 3, 4, 5 and 6 m over a 3 m pit.
7. A 20° slide slope, 12 m long.
8. A low-ceiling slope: the ceiling drops from 2.2 m to 1.0 m over 10 m.

Add a `Label3D` sign at each station, a kill plane at y = −6 that teleports the unit back to the start (call `reset_physics_interpolation()`), an on-screen control help, and a readout of state, speed, grounded flag and height.

## T10 — Movement tests (A9)

The harness (A3 writes it): `tests/sim/movement/movement_harness.gd`. It builds static geometry from simple box specs, spawns a `GymUnit`, runs a scripted list of `[frame, MovementIntent]` for N physics frames from a small driver node’s `_physics_process` (so timing matches production), and records a trace of frame, position, velocity and state. Helpers: `max_height()`, `distance_travelled()`, `final_state()`, `passed_through(aabb)`.

Tests, with a ±5% tolerance:

- Full-hold jump apex is 1.3 m. Tap jump apex is 0.6 m.
- A slide from 6 m/s on flat ground travels 3.5–5 m. Downhill goes farther, uphill shorter.
- Crouch passes the 1.2 m gap and is blocked by the 1.0 m gap. A slide passes the 1.0 m gap.
- A vault over a thin 1.0 m wall succeeds and exits with at least 90% of the entry speed. The 4 × 4 × 1.0 m block is mounted, not vaulted. A 1.5 m wall is mantled and the unit ends on top. A 2.2 m wall blocks.
- Standing up under a low ceiling is refused.
- No tunnelling through a 0.3 m wall at maximum speed (slide boost plus downhill).
- Coyote time and jump buffer behave as specified.
- Path following crosses the gym around obstacles, arrives within 0.3 m, and `stuck` never fires.
- Record the largest gap a normal jump clears and the largest a slide-jump clears, and write both into `docs/TUNING.md`.

## State transitions

Implement exactly as written. Tune only through `MovementProfile`.

| From | Condition | To |
|---|---|---|
| Grounded | Jump pressed or buffered, on floor or within coyote time | Airborne |
| Grounded | Crouch/slide pressed, speed at or above slide entry speed, cooldown ready | Sliding |
| Grounded | Crouch/slide held, speed below slide entry speed | Crouched |
| Crouched | Released and headroom clear | Grounded |
| Sliding | Speed below the floor, or released and headroom clear | Crouched or Grounded |
| Sliding | Jump pressed | Airborne, momentum kept |
| Airborne | Lands | Grounded, or Sliding if crouch/slide is held and fast enough |
| Grounded or Airborne | Jump pressed, moving toward a VAULT obstacle within reach | Vaulting |
| Grounded or Airborne | Jump pressed, facing a MANTLE obstacle within reach | Mantling |
| Any | Forced motion started | Forced |

## Acceptance

- [ ] All T10 tests pass with `tools/test.sh`.
- [ ] The human completes the feel checklist in the gym: Can I read where I will land? Does a slide feel like momentum rather than a stutter? Do vaults happen when I expect them and never when I do not? Can I get stuck anywhere in the gym? Does a right-click start moving within 100 ms? Do the crouch and slide gaps feel fair?
- [ ] Any tuning from that playtest is made in `MovementProfile` only, not in code.
- [ ] `docs/INTERFACES.md` holds the final signatures and the command-to-intent mapping.

## Verify

```bash
tools/test.sh
$GODOT --path . scenes/gyms/movement_gym.tscn
tools/screenshot.sh scenes/gyms/movement_gym.tscn shots/gym.png 90
```

## Pitfalls

- The motor never reads `Input`, wall-clock time or global randomness.
- Call `move_and_slide()` once per step.
- Resizing the capsule: keep the feet fixed or the unit pops through the floor.
- Physics interpolation: set transforms only inside physics ticks, and call `reset_physics_interpolation()` after any teleport.
- At 12 m/s a unit moves 0.2 m per tick. Test that thin walls still hold.
- If you suspect a Jolt-specific bug, write a minimal repro and log it in `docs/DECISIONS.md`. Do not switch engines.
- Do not wait for A1 or A2. The gym uses its own geometry, camera and driver.

## Report

Use the report template in `AGENTS.md` §10. Also include the measured numbers (jump apex, tap apex, slide distances, largest clearable gap for jump and slide-jump) and any `MovementProfile` fields you added.
