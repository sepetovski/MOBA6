class_name MovementProfile extends Resource

## Tunable movement. Every gameplay number for the motor lives here.
## Units are metres, seconds and degrees. See docs/TUNING.md.

@export_group("Ground")
@export var run_speed := 6.0            # m/s
@export var acceleration := 40.0        # m/s²
@export var deceleration := 50.0        # m/s²
@export var turn_rate_deg := 720.0      # degrees/s, facing
@export var crouch_speed_mult := 0.5
@export var floor_snap_length := 0.3    # m, CharacterBody3D floor snap
@export var floor_stick := 2.0          # m/s, downward bias while grounded so ramps stay attached

@export_group("Air")
@export var jump_height := 1.3          # m, full-hold apex
@export var min_jump_height := 0.6      # m, tap
@export var gravity := 24.0             # m/s²
@export var fall_gravity_mult := 1.4
@export var air_control := 0.4          # 0..1
@export var coyote_time := 0.10         # s
@export var jump_buffer := 0.12         # s

@export_group("Slide")
@export var slide_enter_speed := 5.0    # m/s needed to start a slide
@export var slide_boost := 1.5          # m/s added on entry
@export var slide_friction := 6.0       # m/s² on flat ground
@export var slide_min_speed := 2.5      # m/s, slide ends below this
@export var slide_cooldown := 0.6       # s
@export var slide_slope_factor := 1.0   # Slide: multiplier on gravity along the slope
@export var slide_turn_factor := 0.35   # Slide: fraction of turn_rate_deg while sliding

@export_group("Traversal")
@export var step_height := 0.4          # m
@export var vault_max_height := 1.2     # m
@export var mantle_max_height := 2.0    # m
@export var vault_duration := 0.35      # Traversal: s
@export var mantle_duration := 0.6      # Traversal: s
@export var vault_min_speed := 3.0      # Traversal: m/s needed to vault
@export var vault_reach := 1.2          # Traversal: m from the obstacle face to start a vault or mantle
@export var floor_max_angle_deg := 40.0 # degrees, slopes steeper than this are walls
@export var vault_align_deg := 60.0     # degrees, velocity (and facing, for a mantle) must be this close to the face
@export var vault_landing_reach := 2.0  # m, a vault landing must be this close to the near face
@export var vault_top_inset := 0.3      # m, how far past the face the top probe looks
@export var probe_knee := 0.4           # m
@export var probe_chest := 1.0          # m
@export var probe_head := 1.6           # m
@export var step_face_normal_y := 0.3   # a blocker flatter than this is a slope, not a stair

@export_group("Pathing")
@export var arrive_distance := 0.3      # Pathing: m
@export var repath_blocked_time := 0.5  # Pathing: s
@export var stuck_time := 1.0           # Pathing: s
@export var blocked_speed_fraction := 0.1 # fraction of run_speed that still counts as blocked

@export_group("Safety")
@export var max_speed_cap := 12.0       # Safety: m/s, hard cap on horizontal speed

@export_group("Body")
@export var radius := 0.4               # m
@export var height_stand := 1.8         # m
@export var height_crouch := 1.1        # m
@export var height_slide := 0.8         # m

@export_group("Readability")
@export var slide_tilt_deg := 25.0      # degrees, placeholder view leans back while sliding
@export var rise_stretch := 1.1         # placeholder view height scale while rising
