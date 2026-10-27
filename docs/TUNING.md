# Tuning

Every gameplay number lives in a `Resource` `@export` field. List it here when you add it.

| Value | Unit | Default | File | Why |
|---|---|---|---|---|
| Nav agent radius | m | 0.4 | `src/world/arena_builder.gd` | Brief asked for 0.45. Godot ceils that to a whole 0.2 m cell and errors. 0.4 is 2 cells. See ADR-004 |
| Wall-line gap | m | 1.5 | `src/world/layout_generator.gd` | Brief example was 1.2. PLAN §4 minimum corridor is 1.5 |
| Camera vertical FOV | deg | 40 | `data/camera_profiles/default.tres` | M2 brief. Keep aspect on height |
| Camera pitch | deg below horizontal | 55 | `data/camera_profiles/default.tres` | Tune within 45–65. Fixed yaw, camera on the +Z side |
| Camera distance | m | 28 | `data/camera_profiles/default.tres` | Initial rig length. Min 18, max 40 |
| Zoom step | m / notch | 2 | `data/camera_profiles/default.tres` | Wheel `zoom_in` / `zoom_out` |
| Zoom smoothing | 1/s | 12 | `data/camera_profiles/default.tres` | `1 - exp(-k dt)`. 0 snaps |
| Follow smoothing | 1/s | 10 | `data/camera_profiles/default.tres` | Horizontal focus. 0 is rigid |
| Follow Y smoothing | 1/s | 3 | `data/camera_profiles/default.tres` | Slower, so jumps do not bob the camera |
| Edge-pan margin | px | 12 | `data/camera_profiles/default.tres` | Unlocked camera only |
| Edge-pan speed | m/s | 30 | `data/camera_profiles/default.tres` | World axes. Screen-up is north (−Z) |
| Key-pan speed | m/s | 30 | `data/camera_profiles/default.tres` | Arrow actions `camera_pan_*` |
| Bounds margin | m | 6 | `data/camera_profiles/default.tres` | Focus XZ may leave `ArenaInfo` bounds by this much |
| Occluded transparency | 0 opaque, 1 invisible | 0.75 | `data/camera_profiles/default.tres` | Forward+ `GeometryInstance3D.transparency` |
| Occlusion fade speed | transparency / s | 6 | `data/camera_profiles/default.tres` | Linear ease. Fully visible snaps to exactly 0 |
| Occlusion sample heights | m above feet | 0.2, 0.9, 1.7 | `data/camera_profile.gd` | ADR-007 |
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
