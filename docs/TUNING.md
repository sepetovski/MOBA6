# Tuning

Every gameplay number lives in a `Resource` `@export` field. List it here when you add it.

| Value | Unit | Default | File | Why |
|---|---|---|---|---|
| Nav agent radius | m | 0.4 | `src/world/arena_builder.gd` | Brief asked for 0.45. Godot ceils that to a whole 0.2 m cell and errors. 0.4 is 2 cells. See ADR-004 |
| Wall-line gap | m | 1.5 | `src/world/layout_generator.gd` | Brief example was 1.2. PLAN §4 minimum corridor is 1.5 |
| Run speed | m/s | 6 | `data/movement_profile.gd` | PLAN §4 |
| Acceleration | m/s² | 40 | `data/movement_profile.gd` | Ground |
| Deceleration | m/s² | 50 | `data/movement_profile.gd` | Ground, and the horizontal part of an impulse |
| Turn rate | deg/s | 720 | `data/movement_profile.gd` | Facing. Slide uses this times `slide_turn_factor` |
| Crouch speed multiplier |  | 0.5 | `data/movement_profile.gd` | Crouch walk is 3 m/s |
| Floor snap length | m | 0.3 | `data/movement_profile.gd` | Keeps ramps from jittering |
| Floor stick | m/s | 2 | `data/movement_profile.gd` | Downward bias while grounded |
| Jump height | m | 1.3 | `data/movement_profile.gd` | Full-hold apex. Measured 1.30 m at 60 Hz |
| Min jump height | m | 0.6 | `data/movement_profile.gd` | Tap apex. Measured 0.60 m at 60 Hz |
| Gravity | m/s² | 24 | `data/movement_profile.gd` | Rising. Falling uses `fall_gravity_mult` |
| Fall gravity multiplier |  | 1.4 | `data/movement_profile.gd` | |
| Air control |  | 0.4 | `data/movement_profile.gd` | Fraction of acceleration. No bleed with an empty wish (ADR-007) |
| Coyote time | s | 0.10 | `data/movement_profile.gd` | After walking off, not after a jump |
| Jump buffer | s | 0.12 | `data/movement_profile.gd` | |
| Slide enter speed | m/s | 4 | `data/movement_profile.gd` | A 6 m/s run slides on Ctrl. Crouch walk stays at 3 m/s, under this line |
| Air jumps |  | 1 | `data/movement_profile.gd` | One extra jump after leaving the ground |
| Air jump height | m | 1.0, hero 1.35 | `data/movement_profile.gd` | Apex of that extra jump. The hero's second jump is a little higher |
| Wall jump height | m | 1.15, hero 1.3 | `data/movement_profile.gd` | Upward part of a wall kick |
| Wall jump push | m/s | 7, hero 9 | `data/movement_profile.gd` | Kick away from the wall, plus a sideways shove along it |
| Slide boost | m/s | 1.5 | `data/movement_profile.gd` | Added on a pressed entry, not on a landing entry |
| Slide friction | m/s² | 6 | `data/movement_profile.gd` | Flat ground. A 6 m/s entry travels about 4.04 m |
| Slide min speed | m/s | 2.5 | `data/movement_profile.gd` | |
| Slide cooldown | s | 0.6 | `data/movement_profile.gd` | Starts when the slide ends |
| Slide slope factor |  | 1 | `data/movement_profile.gd` | `gravity * sin(slope)` along the slide |
| Slide turn factor |  | 0.35 | `data/movement_profile.gd` | |
| Step height | m | 0.4 | `data/movement_profile.gd` | |
| Vault max height | m | 1.2 | `data/movement_profile.gd` | Above this, up to mantle max, is a mantle |
| Mantle max height | m | 2.0 | `data/movement_profile.gd` | Taller is a wall |
| Vault duration | s | 0.35 | `data/movement_profile.gd` | Exits at the entry speed |
| Mantle duration | s | 0.6 | `data/movement_profile.gd` | Up, then forward onto the top |
| Vault min speed | m/s | 3 | `data/movement_profile.gd` | |
| Vault reach | m | 1.2 | `data/movement_profile.gd` | From the capsule to the face |
| Floor max angle | deg | 40 | `data/movement_profile.gd` | Steeper is a wall |
| Vault align | deg | 60 | `data/movement_profile.gd` | |
| Vault landing reach | m | 2 | `data/movement_profile.gd` | Farther than this mounts instead of vaulting (ADR-006) |
| Vault top inset | m | 0.3 | `data/movement_profile.gd` | Also sampled at 0.05 m and half inset (ADR-008) |
| Probe knee / chest / head | m | 0.4 / 1.0 / 1.6 | `data/movement_profile.gd` | |
| Step face normal Y |  | 0.3 | `data/movement_profile.gd` | Steeper than this can step; shallower is a slope |
| Arrive distance | m | 0.3 | `data/movement_profile.gd` | |
| Repath blocked time | s | 0.5 | `data/movement_profile.gd` | One repath |
| Stuck time | s | 1.0 | `data/movement_profile.gd` | After that repath |
| Blocked speed fraction |  | 0.1 | `data/movement_profile.gd` | Of run speed |
| Max speed cap | m/s | 12 | `data/movement_profile.gd` | Horizontal |
| Body radius | m | 0.4 | `data/movement_profile.gd` | |
| Height stand / crouch / slide | m | 1.8 / 1.1 / 0.8 | `data/movement_profile.gd` | |
| Slide tilt | deg | 25 | `data/movement_profile.gd` | Placeholder view |
| Rise stretch |  | 1.1 | `data/movement_profile.gd` | Placeholder view while rising |
| Dash speed | m/s | 11, hero 12.5 | `data/movement_profile.gd` | Shift burst. Run is 4.5, so the dash is the fast move. Cap stays 16 |
| Dash duration | s | 0.18 | `data/movement_profile.gd` | How long the burst holds its speed |
| Dash charges |  | 2 | `data/movement_profile.gd` | Shift spends one |
| Dash recharge | s | 2.6, hero 4.6 | `data/movement_profile.gd` | Restore one charge while the other is ready. The hero waits longer so the dash stays special |
| Dash recharge, both spent | s | 1.15, hero 2.5 | `data/movement_profile.gd` | Per charge once both are empty. Still faster than two slow charges |
| Dash slide grace | s | 0.34, hero 0.28 | `data/movement_profile.gd` | After the burst, Ctrl still starts the slide |
| Dash slide hold | s | 0.9, hero 0.36 | `data/movement_profile.gd` | Longest dash-slide. A slower entry is shorter. The slide holds `dash_slide_keep` of dash speed, not the full burst |
| Dash slide keep |  | 0.55 | `data/movement_profile.gd` | Fraction of dash speed the slide may hold. It never speeds you up |
| Hero run speed | m/s | 4.5 | `data/movement_profiles/gladiator.tres` | Slower than the 6 m/s default so the dash reads as the fast move. Tests still use 6 |
| Profile name length | characters | 16 | `src/profile/player_profile.gd` | Display name on the human unit |
| Profile history | matches | 20 | `src/profile/player_profile.gd` | Newest first. Career totals still count every match |
| Hero acceleration | m/s² | 64 | `data/movement_profiles/gladiator.tres` | Snappier than the 40 default. Tests still use the script default |
| Melee magazine | swings | 8 and 10 | `src/sim/abilities/hero_catalog.gd` | Gladiator 8, Skirmisher 10. Reload 1.7 s and 1.45 s |
| Ranged magazine | shots | 18 | `src/sim/abilities/hero_catalog.gd` | Slinger. Faster interval 0.22 s, 7 damage, reload 1.35 s |
| Cover fade |  | 0.5 | `data/camera_profile.gd` | Trees and boxes hiding an enemy. 0 is solid, 1 is invisible. Halfway between 40% and 60% |
| Tree shot cover width |  | 0.7 | `src/world/art_dressing.gd` | Fraction of the canopy that stops a shot |
| Tree shot cover height |  | 0.88 | `src/world/art_dressing.gd` | Fraction of the tree height that stops a shot |
| Hero air control |  | 0.68 | `data/movement_profiles/gladiator.tres` | Steerable jumps |
| Hero vault / mantle time | s | 0.26 / 0.4 | `data/movement_profiles/gladiator.tres` | Quicker grab onto rocks |
| Hero vault reach | m | 1.65 | `data/movement_profiles/gladiator.tres` | Easier to catch a ledge |
| Hero vault min speed | m/s | 2.2 | `data/movement_profiles/gladiator.tres` | A short run can still vault |
| Hero step height | m | 0.45 | `data/movement_profiles/gladiator.tres` | Small lips on rocks |
| Largest running jump | m | 3.5 | measured | Gap between lips the default profile clears, searched in 0.25 m steps. 3.75 m does not |
| Largest slide-jump | m | 4.5 | measured | Same search. A slide from 6 m/s, jump on the second tick. 4.75 m does not |
| Camera vertical FOV | deg | 40 | `data/camera_profiles/default.tres` | M2 brief. Keep aspect on height |
| Camera pitch | deg below horizontal | 50 | `data/camera_profiles/default.tres` | A little lower than 55 so the forest reads. Still inside 45–65. Fixed yaw, camera on the +Z side |
| Camera distance | m | 32 | `data/camera_profiles/default.tres` | Initial rig length. Min 18, max 40 |
| Zoom step | m / notch | 2 | `data/camera_profiles/default.tres` | Wheel `zoom_in` / `zoom_out` |
| Zoom smoothing | 1/s | 12 | `data/camera_profiles/default.tres` | `1 - exp(-k dt)`. 0 snaps |
| Follow smoothing | 1/s | 10 | `data/camera_profiles/default.tres` | Horizontal focus. 0 is rigid |
| Follow Y smoothing | 1/s | 3 | `data/camera_profiles/default.tres` | Slower, so jumps do not bob the camera |
| Edge-pan margin | px | 12 | `data/camera_profiles/default.tres` | Unlocked camera only |
| Edge-pan speed | m/s | 30 | `data/camera_profiles/default.tres` | Unlocked camera. Screen up, down, left and right follow the current camera yaw |
| Key-pan speed | m/s | 30 | `data/camera_profiles/default.tres` | Arrow actions `camera_pan_*` |
| Orbit | deg / pixel | 0.22 | `data/camera_profile.gd` | Middle-mouse yaw. Hold Y and the pivot is the character |
| Bounds margin | m | 6 | `data/camera_profiles/default.tres` | Focus XZ may leave `ArenaInfo` bounds by this much |
| Occluded transparency | 0 opaque, 1 invisible | 0.75 | `data/camera_profiles/default.tres` | Forward+ `GeometryInstance3D.transparency` |
| Occlusion fade speed | transparency / s | 6 | `data/camera_profiles/default.tres` | Linear ease. Fully visible snaps to exactly 0 |
| Occlusion sample heights | m above feet | 0.2, 0.9, 1.7 | `data/camera_profile.gd` | ADR-012 |
| Surface lift | m | 0.02 | `data/camera_profile.gd` | Rings and the click marker, along the normal |
| Click ring radii | m | 0.3 → 1.0 | `data/camera_profile.gd` | Fades over 0.4 s. Pool of 4 |
| Reticle radius | m | 0.4 | `data/camera_profile.gd` | Flat ring under the cursor |
| Ring thickness | m | 0.1 | `data/camera_profile.gd` | Annulus width for reticle, selection, hover, click |
| Selection padding | m | 0.35 | `data/camera_profile.gd` | Selection radius = unit `radius` meta + this |
| Default unit radius | m | 0.4 | `data/camera_profile.gd` | Used when the unit has no `radius` meta |
| Right-click hold | s | 0.15 | `data/input_settings_default.tres` | Then `STEER` pressed |
| Steer resend distance | m | 0.2 | `data/input_settings_default.tres` | y = 0 cursor travel since the last `STEER` |
| Crouch toggle | bool | false | `data/input_settings_default.tres` | Hold. Release sends `CROUCH_SLIDE` released |
| Confine mouse | bool | true | `data/input_settings_default.tres` | Confined while the window is focused. Skipped headless |
| Pick range | m | 200 | `data/input_settings.gd` | Physics ray before the y = 0 fallback |
| Ground slope | deg from +Y | 40 | `data/input_settings.gd` | `PickResult.is_ground`. Matches the walkable slope |
