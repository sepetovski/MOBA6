class_name CameraProfile extends Resource

## Tuning for MobaCamera, OcclusionFader and the click feedback. Units are in the comments.

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
