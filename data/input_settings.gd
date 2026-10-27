class_name InputSettings extends Resource

## Pointer and hold tuning for PlayerController. Units are in the comments.

@export var hold_threshold := 0.15           # s of right-click held before steering starts
@export var steer_resend_distance := 0.2     # m the cursor ground point must move before STEER is sent again
@export var crouch_toggle := false           # false = hold, true = toggle
@export var confine_mouse := true
@export var pick_range := 200.0              # m
@export var ground_slope_deg := 40.0         # degrees from +Y that still counts as ground
