# Interfaces

Binding type names. Do not rename one without an entry in `docs/DECISIONS.md`. Owners fill in the signature when their milestone lands.

| Type | Owner | Status |
|---|---|---|
| `Command` | A0 | defined in M0 (`src/core/command.gd`) |
| `Team` | A0 | defined in M0 (`src/core/team.gd`) |
| `GameEvents` | A0 | defined in M0 |
| `GameConfig` | A0 | defined in M0 |
| `DebugService` | A0 | defined in M0 |
| `MovementProfile` | A3 | defined in M3 (`data/movement_profile.gd`, `data/movement_profiles/gladiator.tres`) |
| `MovementMotor` | A3 | defined in M3 (`src/sim/movement/movement_motor.gd`) |
| `MovementIntent` | A3 | defined in M3 (`src/sim/movement/movement_intent.gd`) |
| `PathFollower` | A3 | defined in M3 (`src/sim/movement/path_follower.gd`) |
| `PlaceholderUnitView` | A3 | defined in M3. M4 wraps it as `UnitView`. `bind(unit: CharacterBody3D)` |
| `HeroDefinition` | A5 (stub by A4) | planned (M5) |
| `Simulation` | A4 | planned (M4) |
| `SimUnit` | A4 | planned (M4) |
| `UnitState` | A4 | planned (M4) |
| `UnitView` | A4 | planned (M4) |
| `ArenaLayout` | A1 | defined in M1 (`data/arena_layout.gd`) |
| `PropPlacement` | A1 | defined in M1 (`data/prop_placement.gd`) |
| `ArenaBuilder` | A1 | defined in M1. `static func build(layout, include_props := true) -> Node3D`. Floor, walls, gates and props are children of `Navigation`. Gate doors are siblings of it. The match passes `include_props = false` |
| `ArenaInfo` | A1 | defined in M1. `get_spawn_slot(team, slot) -> Transform3D`, `get_bounds() -> AABB`, `get_octagon_polygon() -> PackedVector2Array`, `contains_xz(point) -> bool` |
| `TraversalClass` | A1 | defined in M1. `from_height(height) -> Kind`. Constants match the M3 movement defaults (0.4 / 1.2 / 2.0) |
| `CrowdRenderer` | A1 | defined in M1. `set_density(0..1)`, `set_excitement(0..1)` |
| `CameraProfile` | A2 | defined in M2 (`data/camera_profile.gd`) |
| `InputSettings` | A2 | defined in M2 (`data/input_settings.gd`) |
| `MobaCamera` | A2 | defined in M2 (`src/camera/moba_camera.gd`) |
| `CursorPicker` | A2 | defined in M2 (`src/input/cursor_picker.gd`) |
| `PlayerController` | A2 | defined in M2 (`src/input/player_controller.gd`) |
| `OcclusionFader` | A2 | defined in M2 (`src/camera/occlusion_fader.gd`) |
| `GroundRing` | A2 | defined in M2 (`src/camera/feedback/ground_ring.gd`) |

## Movement (M3)

`MovementProfile` is the resource in `docs/PLAN.md` §5 plus the fields in `docs/briefs/M3-movement.md`. Do not rename or remove one. Extra fields live in the same export groups (`floor_snap_length`, `floor_stick`, `floor_max_angle_deg`, probe heights, `vault_align_deg`, `vault_landing_reach`, `vault_top_inset`, `step_face_normal_y`, `blocked_speed_fraction`, `slide_tilt_deg`, `rise_stretch`).

`MovementIntent` keeps `has_move_target`, `steering` and the `*_held` flags until something changes them. `stop`, `jump_pressed`, `crouch_slide_pressed` and `dash_pressed` are edge flags. The owner clears those after each `step()`. The motor may set `has_move_target = false` when the goal is reached, dropped, or replaced by steering.

```gdscript
class_name MovementIntent extends RefCounted
var has_move_target := false
var move_target := Vector3.ZERO
var steering := false
var steer_point := Vector3.ZERO
var stop := false
var jump_pressed := false
var jump_held := false
var crouch_slide_pressed := false
var crouch_slide_held := false
func clear_edges() -> void
func clone() -> MovementIntent
```

```gdscript
class_name MovementMotor extends RefCounted
enum State { GROUNDED, CROUCHED, SLIDING, AIRBORNE, VAULTING, MANTLING, FORCED }
signal landed(fall_speed: float) # downward speed at impact, m/s, positive
signal stuck()
signal state_changed(old_state: State, new_state: State)
signal forced_motion_ended(hit_wall: bool)
signal arrived()
var state: State = State.GROUNDED
var can_move := true
var can_jump := true
var can_crouch := true
var profile: MovementProfile
func _init(body: CharacterBody3D, profile: MovementProfile, nav_map: RID) -> void
func set_nav_map(nav_map: RID) -> void
func step(intent: MovementIntent, dt: float) -> void
func apply_impulse(impulse: Vector3) -> void
func start_forced_motion(displacement: Vector3, duration: float, ease_curve: Curve = null, ignore_gravity: bool = true) -> void
func get_horizontal_speed() -> float
func has_goal() -> bool
func reset_motion() -> void # gym kill-plane and tests
```

`landed` reports the downward speed as a positive number. `start_forced_motion` uses `move_and_collide` (one physics move, not `move_and_slide`) and, when it ends, keeps the horizontal speed of `displacement / duration`. Vault and mantle cancel when `can_move` is false or a forced motion starts. While a unit is moving, mantle alignment uses the velocity direction; below 1 m/s it uses the body yaw.

```gdscript
class_name PathFollower extends RefCounted
var arrive_distance: float
func set_goal(map: RID, from: Vector3, to: Vector3) -> void
func next_direction(position: Vector3) -> Vector3
func is_arrived(position: Vector3, arrive_distance: float) -> bool
func is_unreachable() -> bool
func clear() -> void
```

`set_goal` calls `NavigationServer3D.map_get_closest_point` and then `map_get_path(..., true)`.

### Command to intent (A4 implements this in M4)

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
| `DASH`, pressed | `dash_pressed` = true for that tick. Shift. Two charges live on `MovementMotor` |

## Camera and input (M2)

`MobaCamera` follows a target when locked. Y toggles the lock. Unlocked, the cursor in the edge margin or the arrow keys pans the focus. `PlayerController` only emits `Command`s. `InputFeedback` listens to `command_issued` and owns the click pool, reticle, hover ring and selection ring. It is not a binding type.

```gdscript
class_name MobaCamera extends Node3D
signal lock_changed(locked: bool)
var camera: Camera3D
func follow(target: Node3D) -> void
func set_locked(locked: bool) -> void
func is_locked() -> bool
func set_bounds(bounds: AABB) -> void
func focus_on(world_point: Vector3, instant := false) -> void
func present(point: Vector3, distance: float, instant := false) -> void
func set_presenting(on: bool) -> void
func screen_to_ground(screen_pos: Vector2) -> Variant

class_name CursorPicker extends RefCounted
func _init(cam: Camera3D) -> void
func pick(screen_pos: Vector2, mask := 0) -> PickResult
func pick_unit(screen_pos: Vector2) -> PickResult

class_name PlayerController extends Node
signal command_issued(cmd: Command)
func bind(bound_unit_id: int, cam: MobaCamera, sink: Callable) -> void

class_name OcclusionFader extends Node
func bind(cam: Camera3D, focus: Node3D, profile: CameraProfile) -> void
static func find_occluders(from: Vector3, sample_points: PackedVector3Array, instances: Array) -> Array

class_name GroundRing extends Node3D
func configure(radius: float, thickness: float, color: Color, alpha := 1.0) -> void
func attach_to(unit: Node3D) -> void
func place_at(point: Vector3, normal := Vector3.UP) -> void
```

## Match (M4)

`Simulation` ticks at physics priority 0. Controllers use priority -10 and only call `submit_command`. `dt` is `1 / GameConfig.TICK_RATE`. Before `RUNNING`, every command except `STOP` is dropped.

`SimUnit.sim_step` is called by `Simulation` only. `UnitView` wraps `PlaceholderUnitView`. `GateController` sinks `Gate_A_Door` and `Gate_B_Door` when the match reaches `RUNNING`. `DebugHud` reads state and events.
