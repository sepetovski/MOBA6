# Task brief M2 — Camera and mouse input

Start prompt (paste into the agent):

```text
You are A2 (Camera and Input). Read AGENTS.md, docs/PLAN.md §1–§6 and §7 (M2), then do everything in docs/briefs/M2-camera-input.md. Report in the format at the end of that file.
```

| | |
|---|---|
| Role | A2 Camera and Input (T1–T6) |
| Phase and size | Phase 1, size M |
| Depends on | M0 merged. Runs in parallel with M1 and M3. M4 wires your pieces into the match |
| Read first | `AGENTS.md`, `docs/PLAN.md` §3, §4, §5, §7 (M2) |

## Goal

A League and Dota style camera and cursor. Right-click moves a unit around obstacles, holding right-click steers, and walls fade when they hide your unit.

## Scope

In: camera rig, cursor picker, player controller (commands only), feedback visuals, occlusion fade, an input sandbox scene. Out: `Simulation` and units (M4), the motor and pathing (M3), the arena (M1), the HUD (M4, M6).

## You own

`src/camera/`, `src/input/`, `data/camera_profile.gd`, `data/camera_profiles/`, `data/input_settings.gd`, `tests/camera/`, `tests/input/`. Pre-approved exception: you may create `scenes/gyms/input_sandbox.tscn` (this one file).

## Requests to file on day one

Write these in `docs/requests/` before you start, then carry on with your own stubs.

1. **To A1:** tag every `GeometryInstance3D` that can hide a unit (the south-side wall, the stand rows nearest the camera, and any prop taller than 2.2 m) with the group `occluder_fade`, and build the walls and stands in chunks of at most 6 m, so only the pieces that block the view fade, not a whole 30 m wall.
2. **To A6 and A4:** decorative HUD controls must use `mouse_filter = IGNORE`, or they swallow clicks meant for the world.

## Rules for this task

- Controllers only emit `Command`s. Nothing in `src/input` or `src/camera` moves, damages or spawns a unit.
- Feedback visuals are local presentation. They are not part of the simulation, and they must not crash a headless run.
- Read input in `_unhandled_input` so clicks consumed by UI never reach the controller. Use InputMap actions only, no hard-coded keys.
- The camera runs in `_process` with its own smoothing and never influences the simulation.
- Follow the physics-interpolation rules under Pitfalls.

## Interfaces to provide

Write these signatures into `docs/INTERFACES.md` in your first commit.

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

# data/input_settings.gd
class_name InputSettings extends Resource
@export var hold_threshold := 0.15           # s of right-click held before steering starts
@export var steer_resend_distance := 0.2     # m the cursor ground point must move before STEER is sent again
@export var crouch_toggle := false           # false = hold, true = toggle
@export var confine_mouse := true

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

## T1 — `MobaCamera`

- **Rig.** A top-level `Node3D` at the focus point with a child `Camera3D` at local position `(0, d·sin(pitch), d·cos(pitch))` and rotation X = −pitch. The camera sits on the +Z (south) side looking north and down. Perspective, `fov_deg` as the vertical FOV (keep aspect on height), fixed yaw. All numbers come from a `CameraProfile` resource (`data/camera_profiles/default.tres`).
- **Follow.** When locked and a target is set, the focus XZ follows the target’s **interpolated** position with `follow_smooth` (use `1 − exp(−k·dt)` smoothing). Focus Y follows far more slowly (`follow_y_smooth`) so jumps and vaults do not bob the camera, while climbing a crate still raises it gradually.
- **Zoom.** `zoom_in` and `zoom_out` change the target distance by `zoom_step`, clamped to the min and max, with smoothing.
- **Lock.** `camera_lock` (Y) toggles. Start locked. Emit `lock_changed`.
- **Pan (unlocked only).** Edge-pan when the cursor is within `edge_pan_margin_px` of the window edge, the window has focus and the cursor is inside it. Arrow keys (`camera_pan_*`) also pan. Pan in world axes (north is −Z).
- **Bounds.** Clamp the focus XZ to the bounds AABB grown by `bounds_margin`. The camera must not fail when no target or bounds is set.
- **`screen_to_ground`.** Intersect the camera ray with the plane y = 0.
- **Mouse confinement.** When `settings.confine_mouse` is on, use confined mouse mode while the game window has focus.

## T2 — `CursorPicker`

- Ray from `camera.project_ray_origin` along `project_ray_normal`, 200 m long, against `PhysicsRayQueryParameters3D` with bodies only. Default mask is World + Props + Pick (use `GameConfig`).
- If the physics ray misses, fall back to the y = 0 plane (`hit` true, `collider` null, `is_ground` true). If neither hits, `hit` is false. Return `hit = false` when the position is outside the viewport.
- `is_ground` means the surface normal is within 40° of up.
- `pick_unit` queries only the Units layer and reads `unit_id` from the collider’s metadata.
- In M2, clicks on units are treated as ground clicks: `pick()` ignores the Units layer.

## T3 — `PlayerController`

Emits only `Command`s through the `sink` callable. Leave `tick` at 0 (`Simulation.submit_command` stamps it). Set `unit_id` and an incrementing `seq` per command. Run at `process_physics_priority` −10, so it runs before `Simulation`.

| Input | Command emitted |
|---|---|
| Right-click press on the world | `MOVE_TO` at the picked point (a click on a crate top sends the top point; the motor handles unreachable targets) |
| Right-click held longer than `hold_threshold` | `STEER` pressed once, then again whenever the cursor ground point moved more than `steer_resend_distance` since the last send (checked each physics tick) |
| Right-click released after steering | `STEER` released |
| S | `STOP` |
| Space press, release | `JUMP` pressed, `JUMP` released |
| Ctrl press, release | `CROUCH_SLIDE` pressed, released. With `crouch_toggle`, each press flips the state and release sends nothing |

A press that was consumed by UI never starts a hold. `enabled = false` makes the controller silent (M4 uses this during the countdown if needed).

## T4 — Feedback

All of these are visual only: unshaded, no collision, no shadows, pooled where they repeat, raised 0.02 m off the surface to avoid z-fighting.

- **Click marker.** A flat ring spawned at the `MOVE_TO` point, aligned to the surface normal, scaling from 0.3 m to 1.0 m radius while fading over 0.4 s. At most four at once.
- **Cursor reticle.** A small ring at the cursor’s ground point, following the mouse every frame. Hidden when the pick fails or the cursor is over UI.
- **Hover highlight.** When `pick_unit` finds a unit, show a dim `GroundRing` under it.
- **Selection ring.** A bright `GroundRing` under the controlled unit (radius = unit radius + 0.35 m). It stays on the ground when the unit jumps, which also helps read height.

## T5 — Occlusion

- **`OcclusionFader`.** Each frame, take three sample points on the focus unit (feet + 0.2 m, 0.9 m, 1.7 m) and, for every `GeometryInstance3D` in the group `occluder_fade`, test whether the segment from the camera to any sample point crosses its world AABB (`AABB.intersects_segment`). Blocking instances ease toward `occluded_transparency`, others ease back to 0, using `GeometryInstance3D.transparency`. When an instance is fully visible set `transparency` to exactly 0.0 so it returns to the opaque pipeline.
- Keep the segment test a pure static function (`find_occluders`) so it can be unit-tested.
- **Optional:** draw the unit’s silhouette through occluders with stencil materials. Check the pinned Godot version’s docs first; skip it if it is not simple.
- The blob shadow and the landing marker are built by A3 in M3. Nothing to do here.

## T6 — Input sandbox and tests

- `scenes/gyms/input_sandbox.tscn` (TEMP, built by code): a flat floor, a few 1 m crates, a wall with a gap, a navmesh baked from them, a stub mover that follows `NavigationServer3D.map_get_path` at 6 m/s and logs the other commands, a few chunked boxes in the `occluder_fade` group, and a dummy body on the Units layer with `unit_id` metadata. Delete or retire it when M4 lands.
- Tests in `tests/camera/` and `tests/input/`:
  - **Projection.** In a 1920 × 1080 `SubViewport`, the centre ray with the camera at its default pose hits the focus point on y = 0. The four corner rays hit symmetric points.
  - **Picker.** A floor and a 1 m crate: a ray through the crate top returns y ≈ 1.0 and the crate as the collider. A ray through bare floor returns y ≈ 0 and `is_ground` true. Wait two physics frames after adding bodies.
  - **Controller.** Feed synthetic input events and assert the command sequence in the table above, including hold and toggle crouch, and that a UI-consumed press emits nothing.
  - **Occlusion.** `find_occluders` returns exactly the boxes that lie between the camera and the sample points.
  - **Camera.** Zoom clamps, bounds clamp, lock toggle, follow with a missing target.

## Acceptance

- [ ] The camera follows without jitter while the target moves and jumps. Zoom is clamped. Edge-pan and arrow keys work only when unlocked. Y toggles the lock. The focus point never leaves the bounds plus margin.
- [ ] The picker returns correct points on the ground and on crate tops (tests).
- [ ] The controller emits exactly the commands in the T3 table (tests).
- [ ] In the sandbox, right-click moves the stub unit around the wall, holding steers, and the click ring, reticle, selection ring and hover ring appear. Chunked walls in the `occluder_fade` group fade when they hide the unit.
- [ ] No code in `src/input` or `src/camera` moves a unit (a code search shows none).
- [ ] 60 FPS or better, tests green, screenshots attached.

## Verify

```bash
tools/test.sh
$GODOT --path . scenes/gyms/input_sandbox.tscn
tools/screenshot.sh scenes/gyms/input_sandbox.tscn shots/input.png 90
```

## Pitfalls

- **Physics interpolation is on for the project.** Move the camera in `_process`, set `physics_interpolation_mode` to Off on the camera rig, keep the rig a top-level node (not a child of a unit), and follow the target with `get_global_transform_interpolated()`. Use that call once per frame for the camera, not all over the code. Otherwise the camera jitters against the interpolated unit.
- A `GroundRing` attached to a unit must change its local transform only inside `_physics_process`, so interpolation smooths it.
- `GeometryInstance3D.transparency` works only in Forward+, and any value above 0 moves the instance to the transparent pipeline, which can show sorting artefacts. Fade only the pieces that block the view.
- Newly added physics bodies are not visible to ray queries until the next physics frame.
- Use event and viewport coordinates consistently. Do not mix window and viewport coordinates.
- Do not read `Input` state in the camera for anything except panning and zoom actions.

## Report

Use the report template in `AGENTS.md` §10. Also list the requests you filed, the `CameraProfile` values you tuned, and attach a screenshot of the sandbox with a wall faded.
