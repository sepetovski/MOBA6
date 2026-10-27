# Task brief M1 — Greybox arena

Start prompt (paste into the agent):

```text
You are A1 (World). Read AGENTS.md, docs/PLAN.md §1–§6 and §7 (M1), then do everything in docs/briefs/M1-arena.md. Report in the format at the end of that file.
```

| | |
|---|---|
| Roles | A1 World (T1–T6, T8). A9 QA (T7), or A1 does it |
| Phase and size | Phase 1, size M |
| Depends on | M0 merged (project, `tools/test.sh`, `GameConfig`). Runs in parallel with M2 and M3 |
| Read first | `AGENTS.md`, `docs/PLAN.md` §3, §4, §5, §7 (M1), §10 |

## Goal

The Octagon Ring exists: symmetric, navigable, and reading as a gladiator ring, all in gray. It is built from one data resource so the human can edit it later.

## Scope

In: arena geometry, prop kit, layout generator, stands and crowd, look and lighting, navmesh, validators, review scene. Out: units, camera (use a free-fly debug camera), input, movement, HUD.

## You own

`src/world/`, `scenes/arena/`, `data/arena_layouts/`, `data/arena_layout.gd`, `data/prop_placement.gd`, `tests/world/` (shared with A9). No pre-approved exceptions.

## Rules for this task

- The layout resource is the single source of truth. `ArenaBuilder.build(layout)` creates everything from it. Nothing is hand-placed in the editor.
- Stands and crowd have no collision. The outer wall is the boundary.
- Floor and walls are static bodies on layer 1 (World), and the floor is also on layer 6 (Pick). Props are static bodies on layer 2 (Props). Use the masks from `GameConfig`.
- No `RigidBody3D`, no `Area3D`.
- Build scenes with code. The review scene may be a tiny `.tscn` that only instances the builder’s output.

## Interfaces to provide

Write these signatures into `docs/INTERFACES.md` in your first commit.

```gdscript
# data/prop_placement.gd
class_name PropPlacement extends Resource
@export var prop_type: StringName       # for example &'crate_s'
@export var position := Vector3.ZERO    # m, y = base height
@export var yaw_deg := 0.0
@export var scale := Vector3.ONE

# data/arena_layout.gd
class_name ArenaLayout extends Resource
@export var apothem := 40.0             # m, centre to flat side
@export var wall_height := 3.0          # m
@export var wall_thickness := 1.0       # m
@export var gate_width := 8.0           # m
@export var gate_depth := 8.0           # m
@export var stand_rows := 8
@export var stand_row_depth := 1.0      # m
@export var stand_row_rise := 0.5       # m
@export var crowd_spacing := 0.8        # m
@export var layout_seed := 1
@export var props: Array[PropPlacement] = []

# src/world/arena_builder.gd
class_name ArenaBuilder extends RefCounted
static func build(layout: ArenaLayout) -> Node3D: pass

# src/world/arena_info.gd  (a Node attached to the root that build() returns)
class_name ArenaInfo extends Node
func get_spawn_slot(team: int, slot: int) -> Transform3D: pass    # world transform, facing the arena centre
func get_bounds() -> AABB: pass                                   # arena interior at floor level, for camera clamping
func get_octagon_polygon() -> PackedVector2Array: pass            # x and z of the 8 inner wall vertices
func contains_xz(point: Vector2) -> bool: pass

# src/world/traversal_class.gd
class_name TraversalClass extends RefCounted
enum Kind { STEP, VAULT, MANTLE, WALL, SLIDE_GAP, CROUCH_GAP }
const STEP_MAX := 0.4      # mirrors MovementProfile.step_height default
const VAULT_MAX := 1.2     # mirrors MovementProfile.vault_max_height default
const MANTLE_MAX := 2.0    # mirrors MovementProfile.mantle_max_height default
static func from_height(height: float) -> Kind: pass
```

The root node returned by `build()` has these children: `Floor`, `Walls`, `Gates`, `Props`, `Stands`, `Crowd`, `Navigation` (a `NavigationRegion3D`), `Spawns`, and the `ArenaInfo` node. When M3 lands, replace the `TraversalClass` constants with the values from `MovementProfile` and add a test that they match.

## Geometry spec

Numbers come from `docs/PLAN.md` §4. Derived values are worked out here so you do not have to guess.

- **Octagon.** Circumradius R = apothem ÷ cos 22.5° ≈ 43.295 m. Vertices at angle θ = 22.5° + 45°·k (k = 0…7), position (x, z) = (R·cos θ, R·sin θ). The flats face east, west, north and south. The floor must face up: Godot front faces are clockwise when seen from the front, so check the winding with a test.
- **Wall.** A ring from apothem 40 m to 41 m, 3 m high, with collision. Openings 8 m wide on the west and east flats, centred on z = 0.
- **Gate tunnel** (one per team). A roofless corridor outside the wall: x from ±41 to ±49 m, z from −4 to +4 m. The floor is continuous with the arena floor. Its side walls rise with the stand profile so no gaps show. Back wall at x = ±49.
- **Gate door.** A static box 8 × 3 × 0.5 m centred in the wall opening at x = ±40.5 m, named `Gate_A_Door` and `Gate_B_Door`. It stays closed in this scene. M4 animates it.
- **Spawn slots.** Six per team. For slot s from 0 to 5: row = s ÷ 3 (0 is the front row), col = s mod 3. Team A at x = −44 − 2·row, z = (col − 1)·2. Team B mirrored at x = +44 + 2·row. Team A faces east (rotation about Y of −90°). Team B faces west (+90°). Markers are `Marker3D` nodes named `Spawn_A_0` to `Spawn_A_5` and `Spawn_B_0` to `Spawn_B_5`.
- **Stands.** For row i from 0 to 7: footprint from apothem 41 + i to 42 + i, top height 3.0 + 0.5·(i + 1) m (so 3.5 m for the first row, 7.0 m for the last). Skip the gate tunnel openings. Each row’s circumradius is its apothem ÷ cos 22.5°.
- **Crowd.** Seats on each row’s centre line (apothem 41.5 + i) at the row’s top height, every 0.8 m, facing the arena centre, none inside the tunnel cut-outs. Expect about 2,800 instances. Each spectator is a `CapsuleMesh` with `radial_segments` 6 and `rings` 2 (about 100 triangles). A default capsule is about 2,000 triangles and would blow the triangle budget.

## T1 — `ArenaLayout` and `ArenaBuilder`

Build the floor (one mesh, one collision shape), eight wall segments with collision, the two gates and tunnels, the twelve spawn markers, the two gate doors, and `ArenaInfo`. Everything is gray and uses simple primitives or generated meshes.

## T2 — Prop kit

Gray primitives with matching collision. Classes are derived from height by `TraversalClass.from_height`, except the gap types, which are tagged explicitly. Store `traversal_class` as node metadata.

| `prop_type` | Size (m) | Collision | Class |
|---|---|---|---|
| `crate_s` | 1 × 1 × 1 | box | VAULT |
| `crate_m` | 1.5 × 1.5 × 1.5 | box | MANTLE |
| `crate_l` | 2 × 2 × 2 | box | MANTLE |
| `crate_flat` | 2 × 0.5 × 1 | box | VAULT |
| `barrel` | radius 0.45, height 1.0 | cylinder | VAULT |
| `barrel_cluster` | three barrels touching | 3 cylinders | VAULT |
| `wall_low` | 4 × 0.3 × 1.0 | box | VAULT |
| `wall_mid` | 4 × 0.3 × 1.6 | box | MANTLE |
| `wall_high` | 4 × 0.3 × 2.5 | box | WALL |
| `pillar` | radius 0.6, height 4 | cylinder | WALL |
| `platform` | 6 × 0.8 × 6 | box | VAULT |
| `platform_center` | 14 × 0.8 × 14 | box | VAULT |
| `ramp_15`, `ramp_25`, `ramp_35` | 6 m wide, rise 0.8 m (run 2.99, 1.72 and 1.14 m) | wedge (convex shape) | walkable |
| `tunnel_slide` | 4 long, 4 wide, clearance 1.0 | two blocks and a lintel | SLIDE_GAP |
| `tunnel_crouch` | 4 long, 4 wide, clearance 1.2 | two blocks and a lintel | CROUCH_GAP |
| `stack_stair` | crates with tops at 1.0, 2.0 and 3.0 m | boxes | VAULT chain |

## T3 — Layout generator

An editor-only tool, also runnable headless:

```bash
$GODOT --headless --path . -s src/tools/generate_layout.gd -- <seed>
```

It writes `data/arena_layouts/octagon_ring_v1.tres` with `ResourceSaver.save`. Algorithm:

1. Work in the north-east quadrant (x ≥ 0, z ≤ 0). Exclusion zones: the lane strip |z| < 3 m; an 8 m radius around the gate centre (40, 0); the central platform footprint (|x| and |z| ≤ 7 m) plus its ramps; a 1.5 m margin from the wall’s inner face.
2. Place 8–12 cover clusters from these patterns: L (3–5 crates), line (3–6 crates), stack (2–3 crates plus a `stack_stair`), barrel ring (4–6 barrels around one crate), wall line (2–3 `wall_low` with 1.2 m gaps), tunnel pair (`tunnel_slide` plus `tunnel_crouch`).
3. Each quadrant must contain at least: two `wall_low` lines, two `wall_mid`, one `tunnel_slide`, one `tunnel_crouch`.
4. Reject any placement that overlaps another (compare AABBs grown by 0.3 m) or leaves a corridor narrower than §4 allows (1.5 m absolute minimum, side routes at least 2.5 m, main lanes at least 6 m). Retry with new draws. Use a seeded `RandomNumberGenerator` so a seed always gives the same layout.
5. Mirror the quadrant across X = 0 and Z = 0. Yaw follows the reflection, compared modulo 360°: across X = 0, `yaw' = -yaw`; across Z = 0, `yaw' = 180° - yaw`; across both, `yaw' = yaw + 180°`. Never use a negative scale on a physics body (Jolt and collision shapes misbehave). Every kit prop is bilaterally symmetric, so a pure rotation is enough: an L, line or ring is mirrored by reflecting each member’s position and applying this yaw rule.
6. Add the central platform with ramps: 15° on the east and west sides (the lanes), 25° on the north and south sides.
7. Aim for props covering about 12–20% of the floor area. Tune by eye.

## T4 — Stands and crowd

Eight stepped rows per the geometry spec, with the tunnel openings cut through. Generated meshes, no collision. `CrowdRenderer` uses one `MultiMeshInstance3D` with gray capsule spectators and a spatial shader whose vertex function bobs the instance up and down, with the phase taken from `INSTANCE_ID`. Expose `set_density(0..1)` and `set_excitement(0..1)` (a material uniform is enough; no global shader parameters). Budget: at most 3 draw calls and 3,000 instances.

## T5 — Look and light

- Albedo values: floor 0.42, walls 0.28, props 0.62, stands 0.36, crowd 0.50, heroes 0.82 (brightest so they read).
- Generate a 1 m prototype grid texture by script (an `Image`) and apply it triplanar in world space (`StandardMaterial3D` with `uv1_triplanar` and `uv1_world_triplanar`).
- One `DirectionalLight3D` with shadows (`directional_shadow_max_distance` about 120 m). A neutral `WorldEnvironment`: flat colour background, filmic tonemap, no global illumination.

## T6 — Navigation

Make the `NavigationRegion3D` the parent of the floor, walls, gates and props so the default ‘root node children’ geometry mode picks them up. Navigation mesh settings: agent radius 0.45, height 1.8, max climb 0.4, max slope 40°, cell size 0.2, cell height 0.1, parsed geometry from static colliders, collision mask World + Props. Bake at load. `bake_navigation_mesh()` is asynchronous: wait for the `bake_finished` signal (do not poll a tight loop), then two physics frames, before querying paths or spawning units. The gate tunnels must connect to the floor. Tops of tall props stay disconnected islands (clicking one later moves the unit to the nearest reachable point). The two gate doors are the exception to the parenting rule above: keep them outside the region’s subtree (as siblings of it), because the navmesh is baked with the gates open and units must be able to path through the gate once the doors sink (M4). The doors still collide (layer 1).

## T7 — Validators (A9)

GUT tests in `tests/world/`. After baking, wait two physics frames before querying the navigation server.

- `test_props_inside_arena`: every prop footprint is inside the inner octagon and outside the lane, gate and platform exclusion zones.
- `test_no_overlaps`: no two prop AABBs overlap, except intentional stacks (props with `position.y` above 0).
- `test_mirror_symmetry`: every prop has a counterpart under each mirror, within 1 cm. Yaw matches the reflection rule in T3 step 5 (modulo 360°, within 0.5°). Do not expect a plain negation on the Z mirror.
- `test_spawn_slots`: 12 slots exist, are inside the tunnels, are within 0.2 m of the navmesh, and face the right way.
- `test_paths`: a navmesh path exists from every Team A slot to every Team B slot, and ends within 1 m of the target.
- `test_clearances`: sample the floor on a grid; no walkable point sits in a corridor narrower than 1.5 m; the lane strip |z| < 3 m is empty from x = ±7 to ±40.
- `test_budget`: crowd at most 3 draw calls and 3,000 instances; total estimated draw calls at most 800; triangles in view at most 1.5 million.
- `test_traversal_classes`: `TraversalClass.from_height` returns the expected class for every prop type.

## T8 — Review scene

`scenes/arena/octagon_ring.tscn` with a free-fly camera (WASD plus mouse look, Shift to go faster) so the human can inspect the arena. Add a label that shows the layout seed and FPS.

## Acceptance

- [ ] `octagon_ring.tscn` shows gates on the left and right, stands with a crowd, and a prop-filled floor. Attach screenshots from three angles (high, a 55° pitch like the final camera, and low).
- [ ] The layout is identical when mirrored across X and across Z.
- [ ] All validator tests pass with `tools/test.sh`.
- [ ] 60 FPS or better at 1080p. Report the measured number and the machine.
- [ ] Changing the layout resource (or running the generator with another seed) changes the arena with no code edits.

## Verify

```bash
tools/test.sh
$GODOT --path . scenes/arena/octagon_ring.tscn
tools/screenshot.sh scenes/arena/octagon_ring.tscn shots/arena.png 90
```

## Pitfalls

- Mirroring uses the yaw rule in T3 step 5, not a plain negation, and never a negative scale. Check ramps visually, not only by position.
- Check triangle winding on every generated mesh, or faces will be invisible from above.
- Bake the navmesh only after the bodies are in the scene tree. Wait for `bake_finished`, then two physics frames, before querying paths.
- Keep the crowd as one `MultiMesh`. Do not create a node per spectator.
- Do not add collision to stands or crowd.
- If a number in this brief conflicts with `docs/PLAN.md` §4, the plan wins. Log the conflict in your report.

## Report

Use the report template in `AGENTS.md` §10. Also include the measured FPS and draw-call count, the layout seed used, and the screenshot paths.
