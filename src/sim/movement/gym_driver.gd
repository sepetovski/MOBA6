class_name GymDriver extends Node

## TEMP until M2 and M4. Raw mouse and keyboard become a MovementIntent.
## Right-click sets a move target on the press (so motion starts within one tick).
## Holding past 0.15 s steers toward the cursor. A fixed 55° camera follows the unit.

const STEER_AFTER := 0.15
const PITCH_DEG := 55.0
const CAMERA_DISTANCE := 22.0
const KILL_Y := -6.0

var unit: GymUnit
var start_position := Vector3.ZERO
var nav_map: RID
var enabled := true

var _intent := MovementIntent.new()
var _hold := 0.0
var _camera: Camera3D
var _readout: Label


func setup(gym_unit: GymUnit, spawn: Vector3, map: RID) -> void:
	unit = gym_unit
	start_position = spawn
	nav_map = map
	_camera = Camera3D.new()
	_camera.name = "GymCamera"
	_camera.fov = 40.0
	_camera.current = true
	add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var help := Label.new()
	help.position = Vector2(16, 16)
	help.add_theme_font_size_override("font_size", 22)
	help.text = "Right-click: move\nHold right-click: steer\nSpace: jump / vault / mantle\nCtrl: crouch / slide\nS: stop"
	layer.add_child(help)
	_readout = Label.new()
	_readout.position = Vector2(16, 980)
	_readout.add_theme_font_size_override("font_size", 22)
	layer.add_child(_readout)


func _physics_process(dt: float) -> void:
	if unit == null or unit.motor == null:
		return
	if enabled:
		_read_input(dt)
		unit.motor.step(_intent, dt)
		_intent.clear_edges()
		if unit.global_position.y < KILL_Y:
			_respawn()
	_readout.text = unit.motor.readout()


func _process(_dt: float) -> void:
	if unit == null or _camera == null:
		return
	var pitch := deg_to_rad(PITCH_DEG)
	var focus := unit.global_position + Vector3(0.0, 1.0, 0.0)
	_camera.global_position = focus + Vector3(0.0, sin(pitch) * CAMERA_DISTANCE, cos(pitch) * CAMERA_DISTANCE)
	_camera.look_at(focus, Vector3.UP)


func _read_input(dt: float) -> void:
	_intent.jump_held = Input.is_action_pressed("jump")
	_intent.jump_pressed = Input.is_action_just_pressed("jump")
	_intent.crouch_slide_held = Input.is_action_pressed("crouch_slide")
	_intent.crouch_slide_pressed = Input.is_action_just_pressed("crouch_slide")
	_intent.stop = Input.is_action_just_pressed("stop")
	if Input.is_action_just_pressed("move_click"):
		var point := _pick()
		_intent.has_move_target = true
		_intent.move_target = point
		_intent.steering = false
		_hold = 0.0
	elif Input.is_action_pressed("move_click"):
		_hold += dt
		if _hold >= STEER_AFTER:
			_intent.steering = true
			_intent.steer_point = _pick()
			_intent.has_move_target = false
	else:
		_hold = 0.0
		if _intent.steering:
			_intent.steering = false


func _pick() -> Vector3:
	var mouse := _camera.get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 400.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS | GameConfig.LAYER_PICK)
	query.exclude = [unit.get_rid()]
	var hit := unit.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	if absf(direction.y) < 0.0001:
		return unit.global_position
	var t := -origin.y / direction.y
	if t < 0.0:
		return unit.global_position
	return origin + direction * t


func _respawn() -> void:
	unit.global_position = start_position
	unit.velocity = Vector3.ZERO
	unit.rotation = Vector3.ZERO
	unit.reset_physics_interpolation()
	unit.motor.reset_motion()
	unit.motor.set_nav_map(nav_map)
	_intent = MovementIntent.new()
