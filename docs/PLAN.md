# Gladiator Arena MOBA — Agent Build Plan (Godot 4)

*Prepared by Claude · v0.1 · 26 Oct 2026 · Give this whole document to every agent, then assign each one a role (§6) and a task ID (§7–§9).*

## 0. How to use this document

**Human lead.** Export this doc as Markdown and commit it as `docs/PLAN.md`. To start an agent, paste the task brief template from §6.4 with a role and a task ID, for example ‘A3 Movement — M3-T2 Jump’. At the end of each milestone, review it against its acceptance checklist, then release the next one.

**Agents.** Read §1–§6 completely, then your milestone. Do not invent scope. If something is undecided, use the default written here, add one line to `docs/DECISIONS.md`, and keep going. Never block on the human over a tuning number.

**Order of work.** Do M0 first. After M0, M1 (arena), M2 (camera and input) and M3 (movement) can run in parallel, because their interfaces are fixed in §5. M4 pulls them together into the playable Phase 1 build. Art-pipeline prep (M8) can start any time after M3.

**Running agents in Cursor Cloud.** Give each agent exactly one brief (one role, one milestone). Cloud agent branches must be named `cursor/<task-id>-<run-id>` (for example `cursor/m3-t2-jump-2195`), not the bare `m3-t2-jump` form in `AGENTS.md`. Screenshots on a Linux agent VM use `xvfb-run -a` plus `--rendering-method gl_compatibility`, because that VM has no Vulkan driver. The look differs slightly from Forward+, and `GeometryInstance3D.transparency` fades will not appear in those shots. Review fades on a machine that runs Forward+.

**Before the first agent starts (human checklist).**

1. Install the standard (non-.NET) Godot build at the pinned version and make it callable from a shell: put it on PATH or set the `GODOT` environment variable. Agents must be able to run `godot --headless`.
2. Install Git and Git LFS, and create the repository.
3. Give every agent permission to run shell commands in the repo.
4. Install Blender 4.x (needed from M8).
5. For screenshots, use a machine with a display, or Linux with `xvfb`.

| Phase | Goal | Milestones |
| --- | --- | --- |
| 1 — Greybox playable (build now) | 12 gray gladiators (1 human, 11 bots) in the octagon ring with great movement, on an architecture that is ready for heroes | M0–M4 |
| 2 — Combat and multiplayer foundations | Hero and ability framework, HUD, server-authoritative networking | M5–M7 |
| 3 — Real content | Blender and AI-to-3D pipeline, first real hero, content loop | M8–M9 |

## 1. Mission, scope and non-goals

**Mission.** A 6v6 team arena game in MOBA style: fixed top-down 3D camera, mouse-driven control, and expressive movement (jump, crouch, slide, vault, mantle) over arena terrain. Custom heroes and abilities are added later by dropping in data and models. Core code must never need editing to add a hero.

**Phase 1 target: the Octagon Ring.**

- A regular octagon arena, 80 m flat-to-flat, surrounded by stepped stands filled with a gray crowd.
- Team A enters through the left (west) gate and Team B through the right (east) gate, six slots each.
- The floor is filled with crates, barrels, low walls, ramps, platforms and tunnels, mirror-symmetric so both sides are fair.
- Top-down camera, right-click movement, jump, crouch, slide, vault and mantle.
- One human-controlled unit and eleven bots, all driven through the same command pipeline.
- Everything is gray. Heroes are capsules with a ‘nose’ that shows which way they face.

**Non-goals for Phase 1:** minions, towers, lanes, jungle, items, shop, gold, XP, fog of war, real hero abilities, network transport, final art or audio, and any menu beyond a debug overlay. Put every idea outside this list in `docs/PARKING_LOT.md`.

**The greybox rule.** No task may wait on art. Every visual is a primitive or a generated mesh with a gray material, and every gameplay number lives in a data resource so it can be tuned later.

## 2. Outlook: what will go well and what will not

**Likely to go well.** Godot 4 is a strong fit: free, fast iteration in GDScript, first-class glTF import from Blender, built-in navigation, physics interpolation and Jolt physics. A greybox octagon, a MOBA camera and click-to-move are small, well-understood pieces, so Phase 1 should reach a playable state quickly. The data-driven hero and ability design in §5 is what keeps later content cheap.

**Where the real cost is, most dangerous first:**

1. **Movement feel.** No mainstream MOBA has jump, slide or crouch, and a fixed top-down camera hides height, so jumps and ledges are hard to read. *Mitigation:* a ground landing marker and blob shadow, a tuned camera pitch, a dedicated movement gym, and a human playtest gate at the end of M3.
2. **Mouse-driven control versus parkour.** Pathfinding does not know about vaults and mantles, and one hand is on the mouse. *Mitigation:* hybrid control (tap to pathfind, hold to steer), keyboard jump, crouch and slide, and vault and mantle triggered by context.
3. **Networking a 6v6.** Godot supplies transport and RPCs, not prediction, and reconciling a character that slides and vaults is hard. *Mitigation:* build the single-player game on a command plus fixed-tick simulation from day one, so networking later is a transport swap and not a rewrite (M4 → M7).
4. **Hero content volume.** Every hero is a rig, a set of animations and four or five abilities. *Mitigation:* data-driven abilities, one shared humanoid animation set through bone-map retargeting, and a hero scaffolding tool (M5, M8).
5. **AI 2D-to-3D models.** The output is usually a static mesh with messy topology, lighting baked into the texture, and no rig. *Mitigation:* an intake checklist, a validation script, and a cleanup then rig then retarget routine. Treat the AI tool as step one of the pipeline, not the whole pipeline (M8).
6. **Agents cannot see the game.** Agents edit text, and many Godot mistakes are visual. *Mitigation:* headless tests, a screenshot harness, validators and human review at each gate (M0).
7. **Scope creep.** MOBAs are enormous. *Mitigation:* phase gates, the parking lot, and no 6v6 networking until movement feels good.

**Rough effort**, with agents building and one human reviewing: M0–M2 are small. M3 and M4 are medium and decide how the game feels. M5 is medium. M7 (networking) is the largest single item in the plan. M8 is steady, repeatable work per hero. Treat these as relative sizes, not dates.

## 3. Locked decisions and defaults

These are decided. Change one only through an entry in `docs/DECISIONS.md` that the human lead approves.

| Topic | Decision |
| --- | --- |
| Engine | Godot 4.7.2-stable (standard, non-.NET). Pinned in `README.md` and `docs/DECISIONS.md`. Upgrade only between milestones |
| Language | GDScript with static typing everywhere. No C# (simpler headless runs and tests for agents) |
| Renderer | Forward+ (desktop) |
| Physics | Jolt Physics, set explicitly in Project Settings. Never switch mid-project |
| Simulation tick | Fixed 60 Hz physics tick. Physics interpolation ON so visuals are smooth |
| Units | Metres, seconds, kilograms. 1 Blender unit = 1 m |
| Camera | Perspective, about 55° pitch, fixed yaw, identical for both teams (no flipping) |
| Move control | Right-click tap = move (pathfound). Right-click hold = steer toward the cursor. Left-click = select and confirm targeting |
| Mobility keys | Space = jump. Ctrl = slide when moving fast, crouch otherwise. Space near a ledge = vault or mantle. All are InputMap actions and rebindable |
| Other keys | Q W E R = abilities (Phase 2). S = stop. Y = camera lock. Mouse wheel = zoom. Edge-pan when unlocked |
| World physics | Static colliders only. No RigidBody3D gameplay props (crates and barrels are static) |
| Unit vs unit | No hard collision between units, soft separation only. No RVO avoidance in v1 |
| Netcode (Phase 2) | Server-authoritative, command-based, client prediction for the local hero, interpolation for everyone else. The structure is built in Phase 1 |
| Tests | GUT 9.7.1, run headless |
| Version control | Git. Git LFS for `.blend`, `.glb`, `.png`, `.ogg`. Commit `.import` and `*.uid` files. Ignore `.godot/` |
| Team identity | Models stay gray. Team colour appears only in the ring under each unit and in the HUD |

**Open decisions.** Agents proceed with the default. The human may overrule at any milestone gate.

| Question | Default | Alternative |
| --- | --- | --- |
| Which button moves? | Right-click (League and Dota style) | Left-click |
| Crouch input | Hold, with a settings toggle | Toggle only |
| Game mode in Phase 1 | Free roam, no scoring | Team deathmatch (after M5) |
| Can units body-block each other? | No, soft separation | Yes, hard collision |

## 4. Scale bible and coordinates

**World axes.** +X = east = right on screen = Team B side. −X = west = left = Team A side. −Z = north = up on screen. +Z = south = toward the camera. +Y = up. The floor is at y = 0. A unit’s forward direction is −Z.

**Facing convention for models.** Gameplay nodes face −Z. A glTF model exported from Blender faces +Z after import (if it was modelled facing Blender’s front, −Y), so every hero visual sits inside a `ModelRoot` node rotated 180° about Y. Verify this on day one with the calibration model (M8-T1) and correct the rotation in that one place only.

**Body and movement defaults** (live in `MovementProfile`; all are tunable)

| Item | Value |
| --- | --- |
| Standing height and radius | 1.8 m and 0.4 m |
| Crouch height | 1.1 m |
| Slide height | 0.8 m |
| Run speed | 6 m/s |
| Crouch-walk speed | 3 m/s |
| Slide | Starts at 5 m/s or more, boosted by 1.5 m/s, decays about 6 m/s² to a 2.5 m/s floor |
| Jump apex | 1.3 m with full hold, 0.6 m for a tap. Gravity 24 m/s², fall multiplier 1.4 |
| Coyote time and jump buffer | 0.10 s and 0.12 s |

**Traversal table.** Every prop, ramp and gap must obey these rules.

| Obstacle | What the unit does |
| --- | --- |
| Up to 0.4 m | Auto-steps, no input |
| 0.4–1.2 m | Jumps onto it, or vaults over it at speed |
| 1.2–2.0 m | Mantles (grabs the edge and climbs) |
| Above 2.0 m | Solid wall |
| Gap with 1.0 m clearance | Slide-only passage (slide height 0.8 m fits, crouch height 1.1 m does not) |
| Gap with 1.2 m clearance | Crouch passage |
| Slope up to 40° | Walkable. A slide gains speed downhill and loses it uphill |
| Slope above 40° | Treated as a wall |
| Corridors | Main lanes at least 6 m wide, side routes at least 2.5 m, absolute minimum 1.5 m |

**Arena defaults** (live in `ArenaLayout`)

| Item | Value |
| --- | --- |
| Shape | Regular octagon with flats facing east, west, north and south and diagonals between |
| Size | 80 m flat-to-flat: apothem 40 m, side about 33.1 m, circumradius about 43.3 m |
| Outer wall | 3.0 m high, 1.0 m thick, solid |
| Gates | One per team on the west and east flats, 8 m wide, opening into a roofless tunnel 8 m deep |
| Spawn slots | Six per team in a 2 × 3 grid inside the gate tunnel, 2 m apart, facing the arena centre |
| Stands | Eight stepped rows, each 1.0 m deep and 0.5 m higher than the last, starting at the top of the wall, offset by apothem so spacing stays even |
| Crowd | Gray capsule spectators in one MultiMesh (`CapsuleMesh` radial segments 6, rings 2, about 100 triangles each), about 0.8 m apart along each row, roughly 2,000–3,000 in total, vertical bob in the vertex shader |
| Symmetry | Generate one quadrant from a seed, then mirror it across X = 0 and Z = 0 |

## 5. Architecture contract

The most important rule: **gameplay state changes only through commands into the simulation.** That keeps the human, the bots and, later, network clients on one code path.

**Layers**

1. **Input** (`src/input`, `src/camera`): reads mouse and keys and turns them into `Command` objects. Never moves a unit directly.
2. **Simulation** (`src/sim`): one `Simulation` node ticks at the fixed physics rate. It consumes commands, steps every `SimUnit` in ascending unit-id order, and owns all gameplay state: position, velocity, movement state, health, cooldowns, statuses. It never reads the camera, mouse, UI, audio or visuals.
3. **Presentation** (`UnitView`, VFX, HUD, crowd, audio): reads simulation state and draws it. Never writes state back.
4. **Data** (`data/*.tres`): `HeroDefinition`, `AbilityDefinition`, `StatusDefinition`, `MovementProfile`, `ArenaLayout`. All tuning lives here.
5. **Events** (`GameEvents` autoload): typed signals such as `unit_spawned`, `unit_died`, `damage_dealt`, `ability_cast`, `status_applied`, `match_state_changed`. The simulation emits; presentation and UI listen.

**Hard rules**

- Units do not run their own `_physics_process`. `Simulation` calls `sim_step(dt)` on each unit.
- Commands are stamped with the next tick and applied at the start of that tick. Controllers (`PlayerController`, `BotController`) only build `Command`s and call `Simulation.submit_command()`.
- Gameplay code never reaches into UI or camera nodes by path. Use signals or autoloads.
- No gameplay numbers in scripts. Use `@export` fields on resources, with the unit in a comment.
- Hit detection and area effects use physics-server shape queries, not `Area3D` signals.
- Movement must be *reconcilable* (the same code runs on client and server, and small errors are corrected smoothly). Bit-exact determinism is not required.
- `UnitView` is a child of its unit so physics interpolation smooths it automatically.

**Binding type names.** Agents code against these so they can work in parallel.

```gdscript
# src/core/command.gd
class_name Command extends RefCounted
enum Kind { MOVE_TO, STEER, STOP, JUMP, CROUCH_SLIDE, CAST, ATTACK_TARGET }
var tick: int             # simulation tick the command applies to
var seq: int              # per-player sequence number (network ack and replay)
var unit_id: int
var kind: Kind
var point: Vector3        # MOVE_TO, STEER, ground-targeted CAST
var target_id: int = -1   # unit-targeted CAST, ATTACK_TARGET
var slot: int = -1        # ability slot for CAST
var pressed: bool = true  # held inputs: STEER, CROUCH_SLIDE
```

```gdscript
# data/movement_profile.gd
class_name MovementProfile extends Resource
@export_group('Ground')
@export var run_speed := 6.0           # m/s
@export var acceleration := 40.0       # m/s²
@export var deceleration := 50.0       # m/s²
@export var turn_rate_deg := 720.0     # degrees/s, facing
@export var crouch_speed_mult := 0.5
@export_group('Air')
@export var jump_height := 1.3         # m, full-hold apex
@export var min_jump_height := 0.6     # m, tap
@export var gravity := 24.0            # m/s²
@export var fall_gravity_mult := 1.4
@export var air_control := 0.4         # 0..1
@export var coyote_time := 0.10        # s
@export var jump_buffer := 0.12        # s
@export_group('Slide')
@export var slide_enter_speed := 5.0   # m/s needed to start a slide
@export var slide_boost := 1.5         # m/s added on entry
@export var slide_friction := 6.0      # m/s² on flat ground
@export var slide_min_speed := 2.5     # m/s, slide ends below this
@export var slide_cooldown := 0.6      # s
@export_group('Traversal')
@export var step_height := 0.4         # m
@export var vault_max_height := 1.2    # m
@export var mantle_max_height := 2.0   # m
@export_group('Body')
@export var radius := 0.4              # m
@export var height_stand := 1.8        # m
@export var height_crouch := 1.1       # m
@export var height_slide := 0.8        # m
```

```gdscript
# data/hero_definition.gd
class_name HeroDefinition extends Resource
@export var id: StringName
@export var display_name: String
@export var model_scene: PackedScene              # visuals only, no gameplay scripts
@export var stats: UnitStats                      # health, regen, resource, armor, attack
@export var movement: MovementProfile
@export var abilities: Array[AbilityDefinition]   # slots 0–3 = Q W E R
@export var passive: AbilityDefinition
@export var animation_map: Dictionary             # state name -> animation name
```

Other binding names: `Simulation` (`tick`, `submit_command()`, `spawn_unit()`, `get_unit()`), `SimUnit` (a CharacterBody3D with `state: UnitState`, `motor: MovementMotor`, `sim_step(dt)`), `UnitView` (`bind(unit)`, read-only), `ArenaBuilder` (`build(layout)`), `ArenaInfo` (`get_spawn_slot(team, slot)`, `get_bounds()`), `CursorPicker` (`pick(screen_pos)`), `MobaCamera` (`follow()`, `set_locked()`), and the `Team` enum (`A` = 0 west, `B` = 1 east).

**Collision layers.** 1 World, 2 Props, 3 Units, 4 Projectiles, 5 Triggers, 6 Pick (cursor ray), 7 NavBlock, 8 Occluders.

**Repository layout**

```text
project.godot
AGENTS.md              rules for agents (condensed from §3–§6)
README.md              pinned Godot version, how to run, how to test
docs/                  PLAN.md, DECISIONS.md, INTERFACES.md, TUNING.md, PARKING_LOT.md, requests/
addons/                third-party only (GUT first)
art/source/            .blend files and source images (Git LFS)
art/exports/           .glb exported from Blender (Git LFS)
assets/                materials, textures, models, audio, fonts
data/                  heroes, abilities, statuses, movement_profiles, arena_layouts (.tres)
src/core/              autoloads, Command, Team, ids
src/sim/               simulation, units, movement/, abilities/, statuses/
src/world/             arena builder, props, crowd, navigation
src/input/ src/camera/ input glue, cursor picker, player controller, MobaCamera
src/ai/                bots
src/net/               Phase 2 networking
src/ui/                HUD and debug overlay
src/tools/             @tool editor scripts and validators
scenes/                main.tscn, arena/, units/, gyms/, ui/
tests/                 unit/, sim/, scenes/, perf/
tools/                 test.sh, run_headless.sh, screenshot.sh, blender/
```

## 6. Agents, ownership and working rules

### 6.1 Roster

Run as many agents in parallel as you like, but give each one a single role and keep every folder owned by exactly one role.

| Role | Owns | Starts at |
| --- | --- | --- |
| A0 Lead and Integrator | `docs/`, `project.godot`, `src/core/`, merges, integration tests | M0 |
| A1 World | `src/world/`, `scenes/arena/`, `data/arena_layouts/` | M1 |
| A2 Camera and Input | `src/camera/`, `src/input/` | M2 |
| A3 Movement | `src/sim/movement/`, `scenes/gyms/` | M3 |
| A4 Sim Core and AI | `src/sim/` (except `movement/`, `abilities/`, `statuses/`), `src/ai/`, `data/heroes/` | M4 |
| A5 Combat and Abilities | `src/sim/abilities/`, `src/sim/statuses/`, `data/abilities/`, `data/statuses/` | M5 |
| A6 UI | `src/ui/`, `scenes/ui/` | M4 (debug HUD), M6 |
| A7 Network | `src/net/` | M7 |
| A8 Tech Art | `tools/blender/`, `src/tools/`, `art/`, `assets/` | M8 |
| A9 QA | `tests/`, `tools/` (except `tools/blender/`), performance and screenshot harness | M0 |

If you need a change in a folder you do not own, write a short request in `docs/requests/` (date, from, to, what, why) and carry on with a stub. Do not edit another role’s files, except to fix a build-breaking error, and say so in your report.

### 6.2 Working rules

- One branch per task, named like `m3-t2-jump`. Small commits. A0 merges.
- Typed GDScript everywhere. One class per file, `class_name` for shared types, snake\_case file names.
- After adding or renaming a `class_name` script, run `godot --headless --path . --import` once, or types may not resolve in headless runs. If they still do not, run `godot --headless --path . --editor --quit` once.
- Do not hand-edit `.tscn` files beyond small local changes. Prefer scenes built by code (runtime builders or `@tool` scripts) so changes are reviewable and merge cleanly. One owner per scene.
- Never commit `.godot/`. Always commit `.import` and `*.uid` files.
- Every gameplay number lives in a `Resource` as an `@export` field with its unit in a comment, and is listed in `docs/TUNING.md`.
- When a design question is open, implement the default from this plan, leave a `TODO(decision)` comment and log it. Do not stop and wait.
- Scripts read the Godot executable from the `GODOT` environment variable and fall back to `godot`.

### 6.3 Definition of Done (applies to every task)

1. Runs with no errors or warnings in the Godot output.
2. Tests are added for the logic, and `tools/test.sh` passes headless.
3. The task’s acceptance checklist is ticked in the report.
4. Public interfaces are in `docs/INTERFACES.md`; decisions are in `docs/DECISIONS.md`.
5. Performance stays inside the budgets in §10.
6. A report is posted: files changed, tests added, known issues, follow-ups, and a screenshot or a one-paragraph ‘how to see it’.

### 6.4 Task brief template

Paste this to an agent and fill it in.

```text
ROLE:          A3 Movement
TASK:          M3-T2 Jump
READ FIRST:    PLAN §3, §4, §5 and §7 (M3)
YOU OWN:       src/sim/movement/, scenes/gyms/
DO NOT TOUCH:  everything else (file a request instead)
INTERFACES:    MovementMotor.step(), MovementProfile, Command.Kind.JUMP
STEPS:         (copy the task bullet from the plan)
DONE WHEN:     (copy the acceptance checklist) plus Definition of Done §6.3
VERIFY:        tools/test.sh ; open scenes/gyms/movement_gym.tscn
REPORT:        files changed, tests, known issues, decisions logged
```

## 7. Phase 1 milestones (build now)

Every task names its owner, what to build, and what proves it works. The acceptance checklists are what the human reviews.

### M0 — Bootstrap (size S)

**Goal.** An empty but disciplined project that agents can run, test and screenshot.

- **M0-T1 (A0) Project.** Create the Godot project with the pinned version. Set Forward+, Jolt 3D physics, 60 physics ticks, physics interpolation on, and a resizable 1920×1080 window. Name the collision layers from §5. Create InputMap actions: `move_click` (right mouse), `select` (left mouse), `jump` (Space), `crouch_slide` (Ctrl), `stop` (S), `ability_1` to `ability_4` (Q W E R), `camera_lock` (Y), `zoom_in`, `zoom_out`, and debug actions on F1–F4.
- **M0-T2 (A0) Repo.** Create the folder layout from §5, `.gitignore`, `.gitattributes` (LFS), `README.md`, `AGENTS.md`, the empty docs, and autoload skeletons: `GameEvents`, `GameConfig`, `DebugService`.
- **M0-T3 (A9) Tests.** Install GUT. Create `tools/test.sh`, which runs the suite headless and exits non-zero on failure (typical call: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`; confirm the flags against the installed GUT version). Add one passing smoke test. Create `tools/run_headless.sh <scene> <frames>` using `--quit-after`, which counts frames, not seconds.
- **M0-T4 (A9) Screenshots.** Create `tools/screenshot.sh <scene> <out.png> [frames]`. It runs the scene with a real renderer (a display, or `xvfb-run` on Linux CI, because `--headless` has no rendering), waits N frames, saves the viewport image and quits. Document how to run it on the human’s OS.

**Acceptance**

- [ ] A fresh clone, then `godot --headless --path . --import`, then `tools/test.sh` is green.
- [ ] `scenes/main.tscn` opens a window showing an empty gray world.
- [ ] The screenshot script produces a PNG.

### M1 — Greybox arena (size M, owner A1, validators by A9)

**Goal.** The Octagon Ring exists, is symmetric and navigable, and reads as a gladiator ring, all in gray.

- **M1-T1 `ArenaLayout` and `ArenaBuilder`.** `ArenaLayout` is a resource holding the octagon size, wall height, gate size and an explicit list of prop placements (type, position, rotation, scale). `ArenaBuilder.build(layout)` creates everything from that resource and nothing else. Octagon vertices sit at angles 22.5° + k·45° on the circumradius, mapped to x = R·cos θ and z = R·sin θ, so the flats face east, west, north and south. Build the floor (one mesh, one collision shape), eight wall segments with collision, the two gates and their tunnels, twelve spawn `Marker3D`s (`Spawn_A_0` to `Spawn_A_5`, `Spawn_B_0` to `Spawn_B_5`) and the gate doors (static boxes for now). Provide `ArenaInfo`.
- **M1-T2 Prop kit.** Gray primitives with matching collision, each tagged with a traversal class (STEP, VAULT, MANTLE, WALL, SLIDE\_GAP, CROUCH\_GAP):
  - Crate S 1×1×1 m, crate M 1.5×1.5×1.5 m, crate L 2×2×2 m, flat crate 2×0.5×1 m
  - Barrel (radius 0.45 m, height 1.0 m) and barrel cluster
  - Low wall (height 1.0 m), mid wall (1.6 m), high wall (2.5 m), pillar (radius 0.6 m, height 4 m)
  - Platform 6×0.8×6 m with ramps at 15°, 25° and 35°
  - Slide tunnel (1.0 m clearance) and crouch tunnel (1.2 m clearance)
  - Crate stair-stack with levels at 1.0, 2.0 and 3.0 m
- **M1-T3 Layout generator.** An editor-only tool that generates one quadrant from a seed using cover clusters (3–7 crates and 1–3 barrels in L, line and stack patterns), mirrors it across X = 0 and Z = 0, and writes `data/arena_layouts/octagon_ring_v1.tres`. Yaw follows the reflection: across X = 0, `yaw' = -yaw`; across Z = 0, `yaw' = 180° − yaw`; across both, `yaw' = yaw + 180°`. Do not use a negative scale on a physics body. Rules: a clear lane at least 6 m wide from each gate to the centre; an 8 m radius kept clear in front of each gate; a central platform 14 m wide and 0.8 m high with ramps on four sides; per quadrant at least two vault-wall lines, two mantle walls, one slide tunnel and one crouch tunnel; no overlapping props; props at least 1.5 m from the outer wall unless deliberately wall-hugging; every corridor obeys §4.
- **M1-T4 Stands and crowd.** Eight stepped rows around the wall, with the gate tunnels cut through the west and east sections. Generated meshes without collision (the wall stays the collider). `CrowdRenderer` uses one `MultiMeshInstance3D` of gray capsule spectators with a vertex-shader bob (phase from the instance id). Expose `set_density()` and `set_excitement(0..1)` for later events. Budget: at most 3 draw calls.
- **M1-T5 Look and light.** Gray albedo values: floor 0.42, walls 0.28, props 0.62, stands 0.36, crowd 0.50, heroes 0.82 (brightest, so they read). Generate a 1 m prototype grid texture by script and apply it triplanar. One `DirectionalLight3D` with shadows (max distance about 120 m) and a neutral `WorldEnvironment` (flat sky, filmic tonemap, no global illumination).
- **M1-T6 Navigation.** Bake a `NavigationRegion3D` at load from the floor and static colliders (agent radius 0.45, height 1.8, max climb 0.4, max slope 40°). `bake_navigation_mesh()` is asynchronous: wait for `bake_finished`, then two physics frames, before spawning units or querying paths. The gate tunnels must connect to the floor. Tops of tall props stay disconnected islands; clicking one moves the unit to the nearest reachable point.
- **M1-T7 (A9) Validators.** Tests for: every prop inside the octagon and wall; no overlaps; symmetry under both mirrors within 1 cm; all twelve spawn slots on the navmesh; a path from every Team A slot to every Team B slot; lane and corridor clearances; draw-call and triangle budgets (§10).
- **M1-T8 Review scene.** `scenes/arena/octagon_ring.tscn` with a free-fly camera (WASD plus mouse look) so the human can inspect the arena.

**Acceptance**

- [ ] `octagon_ring.tscn` shows gates on the left and right, stands with a crowd, and a prop-filled floor. A screenshot is attached.
- [ ] The layout is identical when mirrored across X and across Z.
- [ ] Validator tests pass.
- [ ] 60 FPS or better at 1080p, with the measured number reported.
- [ ] Changing the layout resource changes the arena with no code edits.

### M2 — Camera and mouse input (size M, owner A2)

**Goal.** A League and Dota style camera and cursor. Right-click moves a unit around obstacles.

- **M2-T1 `MobaCamera`.** A pivot `Node3D` plus `Camera3D`, perspective, vertical FOV 40° (tunable), pitch 55° (range 45°–65°), fixed yaw. Smooth follow of a target; zoom with the wheel (18–40 m); lock and unlock with Y; edge-pan (cursor within 12 px of the window edge) and arrow keys when unlocked; focus clamped to the arena bounds plus a margin. All numbers live in a `CameraProfile` resource.
- **M2-T2 `CursorPicker`.** Casts a ray from the camera through the mouse position against the World, Props and Pick layers. Returns point, normal, collider and `is_ground`. Falls back to the y = 0 plane. Ignores clicks over UI and outside the viewport. Unit-test it with a known camera transform.
- **M2-T3 `PlayerController`.** Right-click press sends `MOVE_TO` at the picked point. Right-click held for more than 0.15 s sends `STEER` every tick toward the cursor’s ground point and ends on release. S sends `STOP`. Space sends `JUMP`. Ctrl sends `CROUCH_SLIDE` as pressed or released. It only emits `Command`s. Until M4 lands, test in `scenes/gyms/input_sandbox.tscn` (A2 may create this one file) with a stub that moves a capsule.
- **M2-T4 Feedback.** A click ring that fades over 0.4 s, a ground reticle under the cursor, hover highlight, and a selection ring under the controlled unit.
- **M2-T5 Occlusion.** (a) A dithered fade material for the south-side wall, the stand rows nearest the camera, and any prop taller than 2.2 m, active when it sits between the camera and a friendly unit. (b) Optional: draw a unit silhouette through occluders using stencil materials; skip this if (a) is enough. (c) Hooks for the blob shadow and landing marker (built in M3).

**Acceptance**

- [ ] The camera follows, zooms, pans and locks, and never shows beyond the arena bounds plus margin.
- [ ] The picker returns the correct point on the ground and on crate tops (test).
- [ ] The click ring and reticle appear, and walls fade when they hide the unit.
- [ ] 60 FPS or better.

### M3 — Movement core (size L, owner A3): the heart of the game

**Goal.** Movement that feels great in a test gym before anything else is built on top of it.

- **M3-T1 Motor and pathing.** `MovementMotor.step(input, dt)` drives the unit’s `CharacterBody3D`. Ground movement with acceleration, deceleration and a facing turn rate. `PathFollower` takes paths from `NavigationServer3D.map_get_path()`, advances waypoints, arrives within 0.3 m, re-paths if blocked for 0.5 s, and supports a steering mode (direct toward a point). Stuck detection raises a `unit_stuck` event after 1 s without progress.
- **M3-T2 Jump.** Variable height (hold for the full jump), coyote time, jump buffer, air control, fall gravity multiplier, and a `landed` event carrying the fall speed.
- **M3-T3 Crouch.** Shrink the capsule to the crouch height with the feet fixed. Check headroom (a `ShapeCast3D` or `test_move`) before standing. Apply the crouch speed multiplier.
- **M3-T4 Slide.** Enter on Ctrl at or above the entry speed while grounded. Boost, friction, slope influence (faster downhill, slower uphill), limited steering (turn rate × 0.35), exit rules, a jump-cancel that keeps momentum, and a cooldown. The slide height lets the unit pass 1.0 m gaps.
- **M3-T5 Steps and slopes.** `CharacterBody3D` has no built-in step climbing, so write a step-up helper with `test_move` for obstacles up to 0.4 m. Floor max angle 40°. Tune floor snap so ramps do not jitter.
- **M3-T6 Vault and mantle.** Probe ahead with a `ShapeCast3D` or rays at knee, chest and head height plus a top-surface check. Classify with the traversal table (§4). A vault (about 0.35 s) keeps momentum. A mantle (about 0.6 s) climbs. Both trigger on Space while moving toward the obstacle. Refuse when the destination capsule does not fit. Document the cancel rules.
- **M3-T7 Forced motion API.** `apply_impulse(v)` and `start_forced_motion(curve, duration, ignore_gravity)` for future dashes and knockbacks, plus flags a status can set: `can_move`, `can_jump`, `can_crouch`.
- **M3-T8 Placeholder view.** `UnitView` with a capsule and a nose. Squash for crouch, tilt for slide, stretch for jump. A blob shadow and a ground landing marker (the main aid for reading height from a top-down camera).
- **M3-T9 `scenes/gyms/movement_gym.tscn`.** A gray course: stairs with 0.2 m steps; ramps at 15°, 25°, 35° and 45°; walls at 0.3, 0.8, 1.2, 1.6 and 2.2 m; a 1.0 m slide gap and a 1.2 m crouch gap; jump gaps of 2, 3, 4, 5 and 6 m over a pit; a slide slope; a low-ceiling slope. `Label3D` signs name the obstacle.
- **M3-T10 (A9) Movement tests.** Fixed-step headless simulations with a ±5% tolerance:
  - Full-hold jump apex 1.3 m, tap jump 0.6 m.
  - A slide from 6 m/s on flat ground travels 3.5–5 m; downhill farther; uphill shorter.
  - Crouch passes the 1.2 m gap and is blocked by the 1.0 m gap; a slide passes the 1.0 m gap.
  - Vault succeeds on a 1.0 m obstacle and fails on 1.5 m; mantle succeeds on 1.5 m and fails on 2.2 m.
  - Standing up under a low ceiling is refused.
  - No tunnelling through walls at maximum speed (slide boost plus downhill).
  - Path following crosses the gym and `unit_stuck` never fires.
  - Measure the largest gap a normal jump clears and the largest a slide-jump clears, and record both in `docs/TUNING.md`.

**State transitions.** Implement exactly as written; tune only through `MovementProfile`.

| From | Condition | To |
| --- | --- | --- |
| Grounded | Jump pressed or buffered, and on floor or within coyote time | Airborne |
| Grounded | Crouch/slide pressed, speed at or above slide entry speed, cooldown ready | Sliding |
| Grounded | Crouch/slide held, speed below slide entry speed | Crouched |
| Crouched | Released and headroom clear | Grounded |
| Sliding | Speed below the floor, or released and headroom clear | Crouched or Grounded |
| Sliding | Jump pressed | Airborne, momentum kept |
| Airborne | Lands | Grounded, or Sliding if crouch/slide is held and fast enough |
| Grounded or Airborne | Jump pressed, moving toward a VAULT obstacle | Vaulting |
| Grounded or Airborne | Jump pressed, facing a MANTLE obstacle | Mantling |
| Any | Forced motion started by an ability | Forced |

**Acceptance**

- [ ] All M3-T10 tests pass.
- [ ] The human completes the feel checklist: Can I read where I will land? Does a slide feel like momentum rather than a stutter? Do vaults happen when I expect them and never when I do not? Can I get stuck anywhere in the gym? Does a right-click start moving within 100 ms? Do the crouch and slide gaps feel fair?
- [ ] Tuning changes from that playtest are made in `MovementProfile` only.

M4 may start in parallel against the `MovementMotor` interface. The human’s playtest verdict on M3 changes numbers, not structure.

### M4 — Simulation spine, teams and the 6v6 match (size M, owners A4, A6, A1)

**Goal.** Twelve gladiators come out of the gates and one of them is yours. This completes Phase 1.

- **M4-T1 `Simulation` and `Match`.** Tick counter, unit registry with stable integer ids, command queue, `spawn_unit(hero, team, slot, controller)`, fixed step order. A `Match` state machine: SETUP → COUNTDOWN (5 s) → RUNNING. The gate doors tween open (1 s) when RUNNING starts.
- **M4-T2 `SimUnit`.** A `CharacterBody3D` with a capsule (collides with World and Props only), `UnitState` (team, health placeholder, movement state, velocity), `MovementMotor` and `UnitStats`. Create the placeholder hero `data/heroes/gray_gladiator.tres`, wired to a `MovementProfile`.
- **M4-T3 Controllers.** The human controller binds to one unit. `BotController` v0 is a state machine: IDLE → WANDER (random reachable point within 15 m) → CHASE (nearest enemy within 20 m, stopping at 3 m) → back to WANDER. Bots jump or slide when a vaultable obstacle blocks the path. Each bot has a random reaction jitter so they do not move in lockstep. A difficulty switch: off, idle, wander, chase.
- **M4-T4 Soft separation.** Units push apart gently and never block each other.
- **M4-T5 (A6) Debug HUD.** A team ring under each unit (blue for A, red for B; the only colour in the game), nameplates A1–A6 and B1–B6, floating placeholder health bars (screen-space controls placed with `Camera3D.unproject_position()`), and an F1 help overlay listing the controls. F2 shows collision shapes, F3 the navmesh, F4 a free camera. A top-left readout shows FPS, tick, unit state, speed, grounded flag and the last commands. Cheats: teleport to cursor, toggle bots, time scale 0.25×–4×, respawn all.
- **M4-T6 `scenes/main.tscn`.** Arena, simulation, twelve units, camera and HUD, starting in COUNTDOWN.
- **M4-T7 (A9) Soak and smoke tests.** A headless bot match for 120 simulated seconds with raised `Engine.time_scale` and `Engine.max_physics_steps_per_frame`: no script errors, no unit outside the octagon, no `unit_stuck` event lasting longer than 3 s, and an average simulation tick inside the budget (§10). Plus a scripted human-command test.

**Acceptance: Phase 1 is done when**

- [ ] `main.tscn` shows a countdown, the gates open, and six gray gladiators walk out of each gate.
- [ ] I can control one unit with right-click, Space and Ctrl, and I can vault and mantle on the crates.
- [ ] Bots roam and chase without getting stuck.
- [ ] Every input reaches a unit through a `Command`. A0 confirms with a code search and a test that no controller moves a unit directly.
- [ ] All tests are green, the frame rate meets §10, and screenshots are attached.

## 8. Phase 2 milestones (combat and multiplayer foundations)

### M5 — Hero and ability framework (size M, owner A5 with A4)

**Goal.** Prove that a new hero is data plus a model, with no core code changes.

**Data model.** The names are binding.

- `UnitStats`: max health, health regen, resource type (mana, energy or none), max resource, resource regen, attack damage, attack range, attack speed, armor, magic resist, cooldown reduction. Move speed comes from `MovementProfile`.
- `StatModifier` stack: base, then flat, then percent-add, then percent-multiply, each with a source id and an expiry. Every stat read goes through `UnitStatBlock.get_stat()`.
- `AbilityDefinition`: id, name, icon, cast type (INSTANT, TARGET\_UNIT, TARGET\_POINT, TARGET\_DIRECTION, TOGGLE, CHANNELED), targeting (range, radius, shape CIRCLE, LINE or CONE, team filter), cost, cooldown per level, cast time, backswing, allowed states (flags for moving, airborne, sliding, crouched, silenced), effects, indicator style, max level.
- `AbilityEffect` resources: `DamageEffect`, `HealEffect`, `ApplyStatusEffect`, `DisplaceEffect` (dash, knockback and leap, using the M3 forced-motion API), `ProjectileEffect`, `AreaEffect`, `SpawnEffect` (summons and ground zones), and `ScriptedEffect` (a GDScript class with `execute(ctx: AbilityContext)` for anything custom).
- `StatusDefinition`: id, duration, stacking rule (refresh, stack or independent), tick effects, stat modifiers, control flags (stun, root, silence, disarm, knock-up), cleanse tags.
- `AbilityRunner` per unit: IDLE → WINDUP → ACTIVE or CHANNEL → BACKSWING. It validates cooldown, cost, range and the unit’s state, emits events, and handles cancels.
- Projectiles are simulation-owned kinematic objects stepped in the fixed tick with swept shape queries (no `RigidBody3D`). Area effects use `PhysicsDirectSpaceState3D.intersect_shape()`.
- Damage pipeline: raw, then modifiers, then mitigation, then shield absorb, then apply. It emits `damage_dealt` and `unit_died`. Respawn rules live in `Match`.

**Tasks**

- **M5-T1** Data classes, stat block and tests.
- **M5-T2** `AbilityRunner`, cooldowns, costs, cast states and tests.
- **M5-T3** Effects and the status system, with a test for every effect type.
- **M5-T4** Projectiles and area queries.
- **M5-T5** Damage, death, respawn and events.
- **M5-T6 (A2, A6)** Targeting indicators: circle, line and cone decals on the ground, cast on key release or on click (a setting), cancel with right-click or Esc, optional quick-cast.
- **M5-T7** Two gray sandbox heroes that exist only to exercise every effect type. *Brute:* Q dash-strike with knockback, W ground slam (area stun), E shield, R leap with a landing slam. *Marksman:* Q skillshot, W slowing trap (ground zone), E short blink, R long line nuke. They are test content, not final designs.
- **M5-T8** A `tools/new_hero` scaffolder that generates the `HeroDefinition`, four `AbilityDefinition` stubs, `StatusDefinition` stubs and an empty animation map, plus `docs/HOW_TO_ADD_A_HERO.md`.

**Acceptance**

- [ ] A third hero is created using only the scaffolder, resources and at most one `ScriptedEffect` file, with zero edits to the core of `src/sim`.
- [ ] Every effect type has a passing test.
- [ ] State rules hold: a stunned unit cannot cast, and abilities restricted to grounded states are refused while sliding.

### M6 — HUD and settings (size M, owner A6)

Hero portrait, health and resource bars, an ability bar with cooldown sweeps and level pips, status icons, a scoreboard on Tab, a minimap (a top-down camera rendered through a `SubViewport`, with unit dots by team), floating damage numbers, a kill feed, and a settings menu with key rebinding (saved under `user://`) and toggles for hold or toggle crouch and quick-cast. The UI reads simulation state and events only.

### M7 — Networking (size XL, owner A7)

**Approach.** A dedicated, server-authoritative game. The Phase 1 command pipeline is the contract.

- **M7-T0 Spike (time-boxed).** Compare (a) custom input prediction on Godot’s high-level multiplayer (ENet) with (b) a community prediction or rollback addon, for example netfox. Check that the addon supports the pinned Godot version and fits the command plus fixed-tick design. Record the decision in `docs/DECISIONS.md`.
- **M7-T1 Transport and lobby.** `ENetMultiplayerPeer`; a dedicated server build using Godot’s dedicated-server export mode with `--headless`; a lobby for connect, team and slot choice, ready, and a server-started match. Keep a listen-server mode (the human’s PC hosts) for development.
- **M7-T2 Command transport.** Clients send `Command`s with tick and seq. Movement and steer inputs go unreliable-ordered with redundancy (the last 3–5 commands per packet). One-shot commands such as casts go reliable. The server validates cooldowns, range and speed, and rate-limits clients.
- **M7-T3 Snapshots.** The server sends world snapshots at 20–30 Hz, delta-compressed per client, with positions quantised to 1 cm and yaw quantised. Slow-changing data (cooldowns, stats, statuses) uses `MultiplayerSynchronizer` or reliable events.
- **M7-T4 Prediction and reconciliation.** The client predicts its own hero by running the same `MovementMotor`. On each snapshot it compares against its predicted state for that tick; if the error is above epsilon it resets to the server state and replays unacknowledged commands. Visual error is smoothed over about 100 ms, with a hard snap above a threshold.
- **M7-T5 Remote interpolation.** Render other units about 100 ms in the past, interpolating between snapshots, with extrapolation capped at 150 ms.
- **M7-T6 Abilities over the network.** The client shows cast start immediately (animation, local cooldown), but results (damage, status, displacement) come from the server. Projectiles are server-owned and replicated by a spawn event plus a deterministic path.
- **M7-T7 Network debug.** A latency, jitter and loss simulator, and an overlay for RTT, snapshot rate, prediction error and bandwidth.
- **M7-T8 Tests.** Twelve headless bot clients against one headless server for 10 minutes. Downstream bandwidth below 40 KB/s per client. A reconnect restores state with no drift above 0.3 m.

**Acceptance**

- [ ] Two humans on a LAN plus ten bots feel responsive at 100 ms simulated latency and 2% loss.
- [ ] The server rejects out-of-range casts and speed hacks.

## 9. Phase 3 milestones (real content)

### M8 — Art pipeline: Blender and AI-to-3D into Godot (size M, owner A8 with the human artist; start prep after M3)

**Why early.** This is the biggest unknown for the project. Prove one hero and one prop end to end before producing more.

**Hero intake checklist.** A model enters `assets/models/heroes/` only when it passes all of these:

- **Scale and origin.** 1 Blender unit = 1 m. Origin at the feet, centred. The collision capsule comes from `MovementProfile`, so keep visuals within ±15% of the capsule unless a hero is deliberately large.
- **Facing.** Modelled facing Blender’s front (−Y). It exports facing +Z, and `ModelRoot` corrects it (§4).
- **Mesh hygiene.** Transforms applied, normals consistent, no loose geometry or interior shells, clean topology around joints.
- **Budgets.** Hero 15–30k triangles, props up to 2k, crowd members up to 300. One or two PBR materials per hero, textures up to 2048² (props up to 1024²).
- **Readability.** At this camera a hero is only about 40–60 px tall. Design for silhouette, not fine detail.
- **Rig.** Humanoid heroes use a standard humanoid skeleton (Rigify basic human, or Mixamo-compatible names) so Godot’s importer can retarget through a `SkeletonProfileHumanoid` bone map and all humanoids share one animation library. Non-humanoid heroes get custom rigs and animations.
- **Animation names (fixed).** `idle`, `run`, `crouch_idle`, `crouch_walk`, `slide_start`, `slide_loop`, `slide_end`, `jump_start`, `fall`, `land`, `vault`, `mantle`, `death`, `cast_1` to `cast_4`, `attack`, `stun`. All in place; movement comes from the simulation, not root motion.
- **Export.** Binary glTF 2.0 (`.glb`), modifiers applied, Y-up, animations included. Keep the `.blend` in `art/source/`.

**AI 2D-to-3D models.** Feed the tool a clean front-view concept in a neutral A or T pose on a plain background. Treat the result as a starting mesh and plan these steps for every hero: decimate or retopologise, delete interior geometry, fix normals, bake textures down to one or two materials, scale and orient to this spec, rig (Rigify or an auto-rigger), check weights at the shoulders and hips, then retarget animations. Keep one style sheet (camera angle, proportions, palette) so every hero looks like part of the same game. Read the tool’s licence for commercial use of its output and of the source images you give it.

**Tasks**

- **M8-T1 Calibration and validator.** `calibration_mannequin.glb` (1.8 m, arrow on the chest, origin at the feet) and `tools/validate_model`, which checks height, origin, facing, triangle count, material count, bone names and animation names and prints a pass or fail report.
- **M8-T2 Blender export script.** `tools/blender/export_glb.py`, run headless as `blender -b art/source/x.blend --python tools/blender/export_glb.py -- out.glb`, so exports are repeatable.
- **M8-T3 `HeroViewFactory`.** Builds a `UnitView` from `HeroDefinition.model_scene`, with an `AnimationTree` state-machine template driven by `UnitState` through `animation_map`. It falls back to the placeholder capsule when animations are missing.
- **M8-T4 First real hero.** Replace the Gray Gladiator’s capsule with your first model with zero simulation changes. Compare before and after screenshots.
- **M8-T5 Props and crowd.** Swap the gray crates and barrels for art props, keeping the colliders. Upgrade the crowd to low-poly spectators with vertex animation.

**Acceptance**

- [ ] A model that passes the validator can be set on a hero definition and plays the right animation for every movement state, with no edits under `src/sim`.

### M9 — Content loop and polish (ongoing)

Per-hero loop: concept, AI 2D-to-3D, cleanup, rig, validate, scaffold, abilities, balance. Then VFX and audio, a gate-opening intro, crowd reactions through `crowd_excitement`, arena variants and hazards, game modes (team deathmatch, objectives), bot difficulty, a performance pass and packaging.

## 10. Cross-cutting rules

**Performance budgets.** Target 60 FPS at 1080p on a mid-range PC. Adjust to the human’s machine and record the target in `README.md`.

- Frame time 16.6 ms. Simulation tick at most 3 ms on average and 6 ms worst case with 12 units.
- At most 800 draw calls and 1.5 million triangles in view. One shadowed directional light and at most 8 other lights.
- The crowd is one MultiMesh: at most 3 draw calls and 3,000 instances. Any prop type used more than 20 times uses a `MultiMeshInstance3D`.

**Test strategy**

1. Unit tests (GUT): math helpers, stat stack, cooldowns, cursor projection.
2. Simulation tests: fixed-step headless scenes (movement gym, bot soak) with tolerances.
3. Scene smoke tests: load every scene for N frames and fail on any error or warning in the output.
4. Validators: arena layout and model intake.
5. Screenshots for human review at each gate (these need a renderer, so not `--headless`).
6. Performance tests record frame and tick time and fail if a budget is exceeded by more than 20%.
7. Network tests (M7): latency and loss simulator, bot-client soak.

`--headless` has no rendering, so use it for logic only, never for shaders or screenshots.

**Parking lot (do not build until asked).** Minions, towers, lanes, jungle, items, gold, XP, shop, fog of war, spectator mode, replays, matchmaking, accounts, cosmetics, arena hazards, destructible props, voice lines.

**Glossary.** *Greybox:* gray placeholder art used to test gameplay. *Gym:* a test scene built only to exercise one system. *Tick:* one fixed simulation step (1/60 s). *Command:* a small message that asks the simulation to do something for a unit. *Snapshot:* the server’s picture of the world at a tick. *Reconcile:* correct the client’s prediction when the server disagrees. *Forced motion:* movement imposed by an ability (dash, knockback, leap). *Traversal class:* how a prop can be crossed (STEP, VAULT, MANTLE, WALL, SLIDE\_GAP, CROUCH\_GAP).
