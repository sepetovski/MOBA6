class_name MovementIntent extends RefCounted

## Persistent state (has_move_target, steering, the *_held flags) stays until changed.
## Edge flags (stop, jump_pressed, crouch_slide_pressed) are cleared by the owner after each step().

var has_move_target := false         # MOVE_TO active: the motor latches the goal and clears this on arrival
var move_target := Vector3.ZERO
var steering := false                # STEER active: move straight toward steer_point
var steer_point := Vector3.ZERO
var stop := false                    # clear target and steering this tick
var jump_pressed := false            # true only on the tick the key went down
var jump_held := false
var crouch_slide_pressed := false    # true only on the tick the key went down
var crouch_slide_held := false


func clear_edges() -> void:
	stop = false
	jump_pressed = false
	crouch_slide_pressed = false


func clone() -> MovementIntent:
	var copy := MovementIntent.new()
	copy.has_move_target = has_move_target
	copy.move_target = move_target
	copy.steering = steering
	copy.steer_point = steer_point
	copy.stop = stop
	copy.jump_pressed = jump_pressed
	copy.jump_held = jump_held
	copy.crouch_slide_pressed = crouch_slide_pressed
	copy.crouch_slide_held = crouch_slide_held
	return copy
