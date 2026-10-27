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
| Air jump height | m | 1.0 | `data/movement_profile.gd` | Apex of that extra jump |
| Wall jump height | m | 1.15 | `data/movement_profile.gd` | Upward part of a wall kick |
| Wall jump push | m/s | 7 | `data/movement_profile.gd` | Horizontal kick away from the wall. Refreshes the air jump |
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
| Largest running jump | m | 3.5 | measured | Gap between lips the default profile clears, searched in 0.25 m steps. 3.75 m does not |
| Largest slide-jump | m | 4.5 | measured | Same search. A slide from 6 m/s, jump on the second tick. 4.75 m does not |
