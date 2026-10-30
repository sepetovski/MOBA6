class_name InputFeedback extends Node

## Local presentation for the pointer: click pool, reticle, hover ring, selection ring.
## Listens to commands. Does not move units and does not run in the simulation.

const DEFAULT_PROFILE := "res://data/camera_profiles/default.tres"

var _profile: CameraProfile
var _camera: MobaCamera
var _picker: CursorPicker
var _unit: Node3D
var _unit_id := -1
var _markers: Array[ClickMarker] = []
var _reticle: GroundRing
var _hover: GroundRing
var _selection: GroundRing
var _beacon: Node3D
var _beacon_ring: GroundRing
var _beacon_dot: MeshInstance3D
var _beacon_on := false
var _beacon_point := Vector3.ZERO


func bind(controller: PlayerController, cam: MobaCamera, unit: Node3D, profile: CameraProfile) -> void:
	_camera = cam
	_unit = unit
	_profile = profile if profile != null else load(DEFAULT_PROFILE) as CameraProfile
	_unit_id = -1
	if unit != null and unit.has_meta(&"unit_id"):
		_unit_id = int(unit.get_meta(&"unit_id"))
	if cam != null and cam.camera != null:
		_picker = CursorPicker.new(cam.camera)
	process_priority = 10
	_build_pool()
	_build_reticle()
	_build_hover()
	_build_selection()
	_build_beacon()
	if controller != null and not controller.command_issued.is_connected(_on_command):
		controller.command_issued.connect(_on_command)


func _process(_delta: float) -> void:
	_update_reticle()
	_update_hover()
	_update_beacon()


func _on_command(cmd: Command) -> void:
	if cmd.kind != Command.Kind.MOVE_TO:
		return
	var normal := Vector3.UP
	if _picker != null and is_inside_tree():
		var result := _picker.pick(_pointer())
		if result.hit:
			normal = result.normal
	_spawn(cmd.point, normal)
	_show_beacon(cmd.point)


func _spawn(point: Vector3, normal: Vector3) -> void:
	if _markers.is_empty():
		return
	var marker := _markers[0]
	var oldest := -1.0
	for candidate in _markers:
		if not candidate.active:
			marker = candidate
			oldest = -2.0
			break
		if candidate.age() > oldest:
			oldest = candidate.age()
			marker = candidate
	var tuned := _tuned()
	marker.play(point, normal, tuned.click_fade_seconds, tuned.click_radius_start, tuned.click_radius_end, tuned.click_color, tuned.surface_lift)


func _update_reticle() -> void:
	if _reticle == null or _picker == null:
		return
	if _pointer_over_ui():
		_reticle.visible = false
		return
	var result := _picker.pick(_pointer())
	if not result.hit:
		_reticle.visible = false
		return
	_reticle.visible = true
	_reticle.place_at(result.position, result.normal)


func _update_hover() -> void:
	if _hover == null or _picker == null:
		return
	if _pointer_over_ui():
		_hover.visible = false
		return
	var result := _picker.pick_unit(_pointer())
	if not result.hit or result.unit_id == _unit_id or result.collider == null:
		_hover.visible = false
		return
	if not result.collider is Node3D:
		_hover.visible = false
		return
	var body := result.collider as Node3D
	var feet := body.global_position
	feet.y = 0.0
	_hover.visible = true
	_hover.place_at(feet, Vector3.UP)


func _build_pool() -> void:
	for child in _markers:
		if is_instance_valid(child):
			child.queue_free()
	_markers.clear()
	var count := maxi(_tuned().click_pool_size, 1)
	for index in count:
		var marker := ClickMarker.new()
		marker.name = "ClickMarker%d" % index
		add_child(marker)
		_markers.append(marker)


func _build_reticle() -> void:
	if _reticle != null:
		return
	var tuned := _tuned()
	_reticle = GroundRing.new()
	_reticle.name = "Reticle"
	add_child(_reticle)
	_reticle.set_surface_lift(tuned.surface_lift)
	_reticle.configure(tuned.reticle_radius, tuned.ring_thickness, tuned.reticle_color, tuned.reticle_color.a)
	_reticle.visible = false


func _build_hover() -> void:
	if _hover != null:
		return
	var tuned := _tuned()
	_hover = GroundRing.new()
	_hover.name = "HoverRing"
	add_child(_hover)
	_hover.set_surface_lift(tuned.surface_lift)
	_hover.configure(tuned.default_unit_radius + tuned.selection_padding, tuned.ring_thickness, tuned.hover_color, tuned.hover_color.a)
	_hover.visible = false


func _build_selection() -> void:
	if _selection != null or _unit == null:
		return
	var tuned := _tuned()
	var radius := tuned.default_unit_radius
	if _unit.has_meta(&"radius"):
		radius = float(_unit.get_meta(&"radius"))
	_selection = GroundRing.new()
	_selection.name = "SelectionRing"
	_selection.set_surface_lift(tuned.surface_lift)
	_selection.configure(radius + tuned.selection_padding, tuned.ring_thickness, tuned.selection_color, tuned.selection_color.a)
	_selection.attach_to(_unit)


func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "Destination"
	_beacon.visible = false
	_beacon.top_level = true
	add_child(_beacon)
	_beacon_ring = GroundRing.new()
	_beacon_ring.name = "BeaconRing"
	_beacon.add_child(_beacon_ring)
	_beacon_ring.configure(1.15, 0.16, Color(1.0, 0.82, 0.22), 0.95)
	var dot := CylinderMesh.new()
	dot.top_radius = 0.18
	dot.bottom_radius = 0.18
	dot.height = 0.04
	_beacon_dot = MeshInstance3D.new()
	_beacon_dot.mesh = dot
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(1.0, 0.9, 0.45)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon_dot.material_override = paint
	_beacon_dot.position = Vector3(0, 0.04, 0)
	_beacon_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(_beacon_dot)


func _show_beacon(point: Vector3) -> void:
	_beacon_on = true
	_beacon_point = Vector3(point.x, 0.06, point.z)
	_beacon.visible = true
	_beacon.global_position = _beacon_point


func _update_beacon() -> void:
	if not _beacon_on or _beacon == null:
		return
	if _unit != null and is_instance_valid(_unit):
		var flat := _unit.global_position - _beacon_point
		flat.y = 0.0
		if flat.length() < 1.25:
			_beacon_on = false
			_beacon.visible = false
			return
	var pulse := 1.0 + 0.16 * sin(float(Time.get_ticks_msec()) * 0.007)
	_beacon_ring.scale = Vector3(pulse, 1.0, pulse)
	_beacon.rotate_y(0.01)


func _pointer() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	return get_viewport().get_mouse_position()


func _pointer_over_ui() -> bool:
	if not is_inside_tree():
		return false
	return get_viewport().gui_get_hovered_control() != null


func _tuned() -> CameraProfile:
	if _profile == null:
		_profile = load(DEFAULT_PROFILE) as CameraProfile
	return _profile
