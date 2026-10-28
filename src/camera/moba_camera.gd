class_name MobaCamera extends Node3D

## Pivot at the focus point. The child camera sits on the +Z side, looking north and down.
## Moves in _process only. Physics interpolation is off so it does not fight the unit's interpolated pose.

signal lock_changed(locked: bool)

const DEFAULT_PROFILE := "res://data/camera_profiles/default.tres"

var camera: Camera3D

@export var profile: CameraProfile

var _locked := true
var _target: Node3D
var _focus := Vector3.ZERO
var _goal := Vector3.ZERO
var _distance := 28.0
var _distance_target := 28.0
var _bounds := AABB()
var _has_bounds := false
var _drag := false
var _drag_from := Vector2.ZERO


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.current = true
	camera.physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	var tuned := _profile()
	_distance = tuned.distance
	_distance_target = tuned.distance
	_apply_rig()
	global_position = _focus


func follow(target: Node3D) -> void:
	_target = target


func set_locked(locked: bool) -> void:
	if _locked == locked:
		return
	_locked = locked
	if not _locked:
		_goal = _focus
	lock_changed.emit(_locked)


func is_locked() -> bool:
	return _locked


func set_bounds(bounds: AABB) -> void:
	_bounds = bounds
	_has_bounds = true


func focus_on(world_point: Vector3, instant := false) -> void:
	_goal = _clamp_xz(world_point)
	if instant:
		_focus = _goal
		global_position = _focus


func screen_to_ground(screen_pos: Vector2) -> Variant:
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	return _plane_y0(origin, direction)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_lock"):
		set_locked(not _locked)
		_mark_handled()
	elif _is_zoom_in(event):
		_nudge_zoom(-1.0)
		_mark_handled()
	elif _is_zoom_out(event):
		_nudge_zoom(1.0)
		_mark_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		_drag = (event as InputEventMouseButton).pressed
		_drag_from = (event as InputEventMouseButton).position
		if _drag:
			set_locked(false)
		_mark_handled()
	elif _drag and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var before: Variant = screen_to_ground(_drag_from)
		var after: Variant = screen_to_ground(motion.position)
		_drag_from = motion.position
		if before is Vector3 and after is Vector3:
			var shift := (before as Vector3) - (after as Vector3)
			shift.y = 0.0
			_goal += shift
			_focus += shift
		_mark_handled()


func _process(delta: float) -> void:
	var tuned := _profile()
	_distance = _approach(_distance, _distance_target, tuned.zoom_smooth, delta)
	_apply_rig()
	if _locked and _edge_velocity() != Vector3.ZERO:
		set_locked(false)
	if not _locked:
		var velocity := _pan_velocity()
		if velocity != Vector3.ZERO:
			var step := velocity * delta
			_goal += step
			_focus += step
	if _locked and _has_target():
		var origin := _target.get_global_transform_interpolated().origin
		_goal.x = origin.x
		_goal.y = origin.y
		_goal.z = origin.z
	_goal = _clamp_xz(_goal)
	# Horizontal lag uses follow_smooth. Unlocked pan moves _focus and _goal together, so this is a no-op while dragging.
	# Vertical lag is slower only while locked, so a jump does not bob the view.
	var y_rate := tuned.follow_y_smooth if _locked else tuned.follow_smooth
	_focus.x = _approach(_focus.x, _goal.x, tuned.follow_smooth, delta)
	_focus.z = _approach(_focus.z, _goal.z, tuned.follow_smooth, delta)
	_focus.y = _approach(_focus.y, _goal.y, y_rate, delta)
	_focus = _clamp_xz(_focus)
	global_position = _focus


func _profile() -> CameraProfile:
	if profile == null:
		profile = load(DEFAULT_PROFILE) as CameraProfile
	return profile


func _apply_rig() -> void:
	if camera == null:
		return
	var tuned := _profile()
	var pitch := deg_to_rad(tuned.pitch_deg)
	camera.fov = tuned.fov_deg
	camera.position = Vector3(0.0, _distance * sin(pitch), _distance * cos(pitch))
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _nudge_zoom(sign: float) -> void:
	var tuned := _profile()
	_distance_target = clampf(_distance_target + sign * tuned.zoom_step, tuned.distance_min, tuned.distance_max)


func _pan_velocity() -> Vector3:
	var tuned := _profile()
	var key := Vector3.ZERO
	if Input.is_action_pressed(&"camera_pan_left"):
		key.x -= 1.0
	if Input.is_action_pressed(&"camera_pan_right"):
		key.x += 1.0
	if Input.is_action_pressed(&"camera_pan_up"):
		key.z -= 1.0
	if Input.is_action_pressed(&"camera_pan_down"):
		key.z += 1.0
	var velocity := Vector3.ZERO
	if key != Vector3.ZERO:
		velocity += key.normalized() * tuned.key_pan_speed
	velocity += _edge_velocity()
	return velocity


func _edge_velocity() -> Vector3:
	if DisplayServer.get_name() == "headless":
		return Vector3.ZERO
	if not DisplayServer.window_is_focused():
		return Vector3.ZERO
	var viewport := get_viewport()
	if viewport == null:
		return Vector3.ZERO
	var mouse := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return Vector3.ZERO
	var margin := float(_profile().edge_pan_margin_px)
	var direction := Vector3.ZERO
	if mouse.x <= margin:
		direction.x -= 1.0
	elif mouse.x >= size.x - margin:
		direction.x += 1.0
	if mouse.y <= margin:
		direction.z -= 1.0
	elif mouse.y >= size.y - margin:
		direction.z += 1.0
	if direction == Vector3.ZERO:
		return Vector3.ZERO
	return direction.normalized() * _profile().edge_pan_speed


func _clamp_xz(point: Vector3) -> Vector3:
	if not _has_bounds:
		return point
	var expanded := _bounds.grow(_profile().bounds_margin)
	var min_corner := expanded.position
	var max_corner := expanded.position + expanded.size
	point.x = clampf(point.x, min_corner.x, max_corner.x)
	point.z = clampf(point.z, min_corner.z, max_corner.z)
	return point


func _has_target() -> bool:
	return _target != null and is_instance_valid(_target)


func _approach(current: float, target: float, rate: float, delta: float) -> float:
	if rate <= 0.0:
		return target
	return lerpf(current, target, 1.0 - exp(-rate * delta))


func _mark_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _is_zoom_in(event: InputEvent) -> bool:
	return event.is_action_pressed(&"zoom_in")


func _is_zoom_out(event: InputEvent) -> bool:
	return event.is_action_pressed(&"zoom_out")


static func _plane_y0(origin: Vector3, direction: Vector3) -> Variant:
	if absf(direction.y) < 0.000001:
		return null
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return null
	return origin + direction * distance
