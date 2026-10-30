class_name GymDriver extends Node

## TEMP until M2 and M4. Raw mouse and keyboard become a MovementIntent.
## Right-click sets a move target on the press (so motion starts within one tick).
## Holding past 0.15 s steers toward the cursor. A fixed 55° camera follows the unit.

const PITCH_DEG := 55.0
const CAMERA_DISTANCE := 22.0
const KILL_Y := -6.0
const EDGE_MARGIN_PX := 28.0
const EDGE_PAN_SPEED := 26.0
const FOCUS_SMOOTH := 8.0
const PAN_SMOOTH := 10.0

var unit: GymUnit
var start_position := Vector3.ZERO
var nav_map: RID
var enabled := true

var _intent := MovementIntent.new()
var _camera: Camera3D
var _readout: Label
var _marker: MeshInstance3D
var _locked := true
var _focus := Vector3.ZERO
var _pan := Vector3.ZERO


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
	help.text = "Right-click once: move there\nSpace: jump, double jump, vault, grab a ledge\nShift: dash (two charges)\nCtrl after a dash: slide that keeps speed\nCtrl while fast: slide\nS: stop\nY or touch a screen edge: pan the camera"
	layer.add_child(help)
	_readout = Label.new()
	_readout.position = Vector2(16, 980)
	_readout.add_theme_font_size_override("font_size", 22)
	layer.add_child(_readout)
	_marker = _click_marker()
	add_child(_marker)
	_focus = spawn
	unit.motor.arrived.connect(_hide_marker)


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


func _process(dt: float) -> void:
	if unit == null or _camera == null:
		return
	if Input.is_action_just_pressed("camera_lock"):
		_locked = not _locked
	_pan_from_edges(dt)
	var hero := unit.global_position
	if _locked:
		_focus = _focus.lerp(hero, 1.0 - exp(-FOCUS_SMOOTH * dt))
	var pitch := deg_to_rad(PITCH_DEG)
	var look := _focus + Vector3(0.0, 1.0, 0.0)
	_camera.global_position = look + Vector3(0.0, sin(pitch) * CAMERA_DISTANCE, cos(pitch) * CAMERA_DISTANCE)
	_camera.look_at(look, Vector3.UP)


func _pan_from_edges(dt: float) -> void:
	var viewport := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var wish := Vector3.ZERO
	if mouse.x >= 0.0 and mouse.x <= viewport.x and mouse.y >= 0.0 and mouse.y <= viewport.y:
		if mouse.x <= EDGE_MARGIN_PX:
			wish.x -= 1.0
		elif mouse.x >= viewport.x - EDGE_MARGIN_PX:
			wish.x += 1.0
		if mouse.y <= EDGE_MARGIN_PX:
			wish.z -= 1.0
		elif mouse.y >= viewport.y - EDGE_MARGIN_PX:
			wish.z += 1.0
	if wish != Vector3.ZERO:
		_locked = false
	var target := wish.normalized() * EDGE_PAN_SPEED if wish != Vector3.ZERO else Vector3.ZERO
	_pan = _pan.lerp(target, 1.0 - exp(-PAN_SMOOTH * dt))
	if not _locked:
		_focus += _pan * dt


func _read_input(_dt: float) -> void:
	_intent.jump_held = Input.is_action_pressed("jump")
	_intent.jump_pressed = Input.is_action_just_pressed("jump")
	_intent.crouch_slide_held = Input.is_action_pressed("crouch_slide")
	_intent.crouch_slide_pressed = Input.is_action_just_pressed("crouch_slide")
	_intent.dash_pressed = Input.is_action_just_pressed("dash")
	_intent.stop = Input.is_action_just_pressed("stop")
	_intent.steering = false
	if Input.is_action_just_pressed("move_click"):
		var point := _pick()
		_intent.has_move_target = true
		_intent.move_target = point
		_show_marker(point)
	elif Input.is_action_just_pressed("stop"):
		_hide_marker()


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


func _click_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "ClickMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.55
	mesh.height = 0.04
	mesh.radial_segments = 24
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.9, 0.95)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	marker.visible = false
	return marker


func _show_marker(point: Vector3) -> void:
	_marker.global_position = Vector3(point.x, point.y + 0.06, point.z)
	_marker.visible = true


func _hide_marker() -> void:
	if _marker != null:
		_marker.visible = false


func _respawn() -> void:
	unit.global_position = start_position
	unit.velocity = Vector3.ZERO
	unit.rotation = Vector3.ZERO
	unit.reset_physics_interpolation()
	unit.motor.reset_motion()
	unit.motor.set_nav_map(nav_map)
	_intent = MovementIntent.new()
	_hide_marker()
	_focus = start_position
	_locked = true
