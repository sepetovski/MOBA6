# Interfaces

Binding type names. Do not rename one without an entry in `docs/DECISIONS.md`. Owners fill in the signature when their milestone lands.

| Type | Owner | Status |
|---|---|---|
| `Command` | A0 | defined in M0 (`src/core/command.gd`) |
| `Team` | A0 | defined in M0 (`src/core/team.gd`) |
| `GameEvents` | A0 | defined in M0 |
| `GameConfig` | A0 | defined in M0 |
| `DebugService` | A0 | defined in M0 |
| `MovementProfile` | A3 | planned (M3) |
| `MovementMotor` | A3 | planned (M3) |
| `MovementIntent` | A3 | planned (M3) |
| `HeroDefinition` | A5 (stub by A4) | planned (M5) |
| `Simulation` | A4 | planned (M4) |
| `SimUnit` | A4 | planned (M4) |
| `UnitState` | A4 | planned (M4) |
| `UnitView` | A4 | planned (M4) |
| `ArenaLayout` | A1 | defined in M1 (`data/arena_layout.gd`) |
| `PropPlacement` | A1 | defined in M1 (`data/prop_placement.gd`) |
| `ArenaBuilder` | A1 | defined in M1. `static func build(layout) -> Node3D`. Floor, walls, gates and props are children of `Navigation`. Gate doors are siblings of it |
| `ArenaInfo` | A1 | defined in M1. `get_spawn_slot(team, slot) -> Transform3D`, `get_bounds() -> AABB`, `get_octagon_polygon() -> PackedVector2Array`, `contains_xz(point) -> bool` |
| `TraversalClass` | A1 | defined in M1. `from_height(height) -> Kind`. Constants mirror the movement defaults until M3 |
| `CrowdRenderer` | A1 | defined in M1. `set_density(0..1)`, `set_excitement(0..1)` |
| `CameraProfile` | A2 | defined in M2 (`data/camera_profile.gd`) |
| `InputSettings` | A2 | defined in M2 (`data/input_settings.gd`) |
| `MobaCamera` | A2 | defined in M2 (`src/camera/moba_camera.gd`) |
| `CursorPicker` | A2 | defined in M2 (`src/input/cursor_picker.gd`) |
| `PlayerController` | A2 | defined in M2 (`src/input/player_controller.gd`) |
| `OcclusionFader` | A2 | defined in M2 (`src/camera/occlusion_fader.gd`) |
| `GroundRing` | A2 | defined in M2 (`src/camera/feedback/ground_ring.gd`) |

## M2 signatures

```gdscript
# data/camera_profile.gd
class_name CameraProfile extends Resource
@export var fov_deg := 40.0                  # vertical field of view
@export var pitch_deg := 55.0                # degrees below horizontal; tune within 45 to 65
@export var distance := 28.0                 # m, camera to focus point (initial)
@export var distance_min := 18.0             # m
@export var distance_max := 40.0             # m
@export var zoom_step := 2.0                 # m per wheel notch
@export var zoom_smooth := 12.0              # 1/s
@export var follow_smooth := 10.0            # 1/s, 0 = rigid
@export var follow_y_smooth := 3.0           # 1/s, vertical focus smoothing so jumps do not bob the camera
@export var edge_pan_margin_px := 12         # px
@export var edge_pan_speed := 30.0           # m/s
@export var key_pan_speed := 30.0            # m/s
@export var bounds_margin := 6.0             # m beyond the arena bounds for the focus point
@export var occluded_transparency := 0.75    # 0 = opaque, 1 = invisible
@export var occlusion_fade_speed := 6.0      # transparency per second
@export var sample_heights_m: PackedFloat32Array = PackedFloat32Array([0.2, 0.9, 1.7]) # m above the focus origin (feet)
@export var surface_lift := 0.02             # m, feedback meshes sit off the surface
@export var click_radius_start := 0.3        # m
@export var click_radius_end := 1.0          # m
@export var click_fade_seconds := 0.4        # s
@export var click_pool_size := 4
@export var reticle_radius := 0.4            # m
@export var ring_thickness := 0.1            # m
@export var selection_padding := 0.35        # m added to the unit radius
@export var default_unit_radius := 0.4       # m, used when the unit has no "radius" meta
@export var selection_color := Color(0.25, 0.55, 0.95, 1.0)
@export var hover_color := Color(0.75, 0.78, 0.82, 0.45)
@export var click_color := Color(0.92, 0.92, 0.92, 1.0)
@export var reticle_color := Color(0.88, 0.88, 0.88, 0.85)

# data/input_settings.gd
class_name InputSettings extends Resource
@export var hold_threshold := 0.15           # s of right-click held before steering starts
@export var steer_resend_distance := 0.2     # m the cursor ground point must move before STEER is sent again
@export var crouch_toggle := false           # false = hold, true = toggle
@export var confine_mouse := true
@export var pick_range := 200.0              # m
@export var ground_slope_deg := 40.0         # degrees from +Y that still counts as ground

# src/camera/moba_camera.gd
class_name MobaCamera extends Node3D
signal lock_changed(locked: bool)
var camera: Camera3D                         # the child camera
func follow(target: Node3D) -> void: pass
func set_locked(locked: bool) -> void: pass
func is_locked() -> bool: pass
func set_bounds(bounds: AABB) -> void: pass                    # from ArenaInfo.get_bounds()
func focus_on(world_point: Vector3, instant := false) -> void: pass
func screen_to_ground(screen_pos: Vector2) -> Variant: pass    # Vector3 on the y = 0 plane, or null

# src/input/cursor_picker.gd
class_name CursorPicker extends RefCounted

class PickResult:
	var hit := false
	var position := Vector3.ZERO
	var normal := Vector3.UP
	var collider: Object = null
	var is_ground := false       # surface normal within 40 degrees of up (walkable)
	var unit_id := -1            # set by pick_unit()

func _init(cam: Camera3D) -> void: pass
func pick(screen_pos: Vector2, mask := 0) -> PickResult: pass      # mask 0 = World | Props | Pick
func pick_unit(screen_pos: Vector2) -> PickResult: pass            # Units layer; unit id from the collider meta 'unit_id'

# src/input/player_controller.gd
class_name PlayerController extends Node
signal command_issued(cmd: Command)
@export var settings: InputSettings
@export var enabled := true
func bind(bound_unit_id: int, cam: MobaCamera, sink: Callable) -> void: pass   # sink(cmd: Command) receives every command

# src/camera/occlusion_fader.gd
class_name OcclusionFader extends Node
func bind(cam: Camera3D, focus: Node3D, profile: CameraProfile) -> void: pass
static func find_occluders(from: Vector3, sample_points: PackedVector3Array, instances: Array) -> Array: pass   # pure function, unit-tested

# src/camera/feedback/ground_ring.gd  (also used for team rings in M4)
class_name GroundRing extends Node3D
func configure(radius: float, thickness: float, color: Color, alpha := 1.0) -> void: pass
func attach_to(unit: Node3D) -> void: pass                          # becomes a child of the unit, snaps to the ground below it each physics tick
func place_at(point: Vector3, normal := Vector3.UP) -> void: pass   # free-standing
```

`InputFeedback` (`src/camera/feedback/input_feedback.gd`) is presentation only. It listens to `command_issued` and owns the click pool, reticle, hover ring and selection ring. It is not a binding type.
