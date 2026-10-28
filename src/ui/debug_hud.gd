class_name DebugHud extends CanvasLayer

## Reads simulation state and events. Decorative controls ignore the mouse.

var _sim: Simulation
var _camera: MobaCamera
var _rings: Array[GroundRing] = []
var _plates: Array[Control] = []
var _units: Array[SimUnit] = []
var _help: Label
var _readout: Label
var _collision_root: Node3D
var _collision_on := false
var _freecam: Camera3D
var _freecam_on := false
var _yaw := 0.0
var _pitch := -20.0
var _time_scale := 1.0


func bind(sim: Simulation, camera: MobaCamera) -> void:
	_sim = sim
	_camera = camera
	layer = 10
	_help = Label.new()
	_help.position = Vector2(24, 220)
	_help.visible = false
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_font_size_override("font_size", 20)
	_help.text = _help_text()
	add_child(_help)
	_readout = Label.new()
	_readout.position = Vector2(16, 12)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.add_theme_font_size_override("font_size", 18)
	add_child(_readout)
	for unit in sim.get_units():
		_add_unit(unit)
	_collision_root = Node3D.new()
	_collision_root.name = "CollisionDebug"
	sim.get_parent().add_child(_collision_root)


func _add_unit(unit: SimUnit) -> void:
	var ring := GroundRing.new()
	var color := Color(0.25, 0.45, 0.95) if unit.team == Team.Id.A else Color(0.85, 0.2, 0.2)
	ring.configure(unit.motor.profile.radius + 0.25, 0.08, color, 0.9)
	ring.attach_to(unit)
	_rings.append(ring)
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = unit.state.display_name
	if unit.state.controller == UnitState.Controller.HUMAN:
		name_label.text += " (you)"
	name_label.add_theme_font_size_override("font_size", 16)
	plate.add_child(name_label)
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0, 20)
	bar.size = Vector2(48, 6)
	bar.color = color
	plate.add_child(bar)
	add_child(plate)
	_plates.append(plate)
	_units.append(unit)


func _process(delta: float) -> void:
	if _sim == null or _camera == null or _camera.camera == null:
		return
	_toggle_overlays()
	_cheats()
	_fly(delta)
	_update_plates()
	_readout.text = _status()


func _toggle_overlays() -> void:
	if Input.is_action_just_pressed("debug_help"):
		_help.visible = not _help.visible
	if Input.is_action_just_pressed("debug_collision"):
		_collision_on = not _collision_on
		_rebuild_collision()
	if Input.is_action_just_pressed("debug_nav"):
		var enabled := not _nav_debug
		_nav_debug = enabled
		NavigationServer3D.set_debug_enabled(enabled)
	if Input.is_action_just_pressed("debug_freecam"):
		_set_freecam(not _freecam_on)


var _nav_debug := false


func _update_plates() -> void:
	var cam := _camera.camera
	for index in _units.size():
		var unit := _units[index]
		var plate := _plates[index]
		if not unit.state.alive:
			plate.visible = false
			continue
		var head := unit.global_position + Vector3(0, unit.motor.profile.height_stand + 0.3, 0)
		if not cam.is_position_behind(head):
			plate.visible = true
			plate.position = cam.unproject_position(head)
			var bar := plate.get_node("Bar") as ColorRect
			var fraction := clampf(unit.state.health / maxf(unit.state.max_health, 1.0), 0.0, 1.0)
			bar.size.x = 48.0 * fraction
		else:
			plate.visible = false


func _status() -> String:
	var human := _sim.get_human()
	var state_name := "countdown"
	if _sim.get_match_state() == Match.State.RUNNING:
		state_name = "running"
	elif _sim.get_match_state() == Match.State.SETUP:
		state_name = "setup"
	var body := "FPS %.0f\ntick %d\n%s  %.1f s" % [Engine.get_frames_per_second(), _sim.tick, state_name, _sim.get_countdown_seconds()]
	if human != null:
		body += "\n%s  speed %.1f  grounded %s\n%s" % [
			MovementMotor.State.keys()[human.motor.state],
			human.motor.get_horizontal_speed(),
			"yes" if human.is_on_floor() else "no",
			human.global_position,
		]
	body += "\n" + _recent_commands()
	return body


func _recent_commands() -> String:
	var lines: PackedStringArray = []
	var start := maxi(DebugService.recent_commands.size() - 5, 0)
	for index in range(start, DebugService.recent_commands.size()):
		var cmd := DebugService.recent_commands[index]
		lines.append("%s u%d" % [Command.Kind.keys()[cmd.kind], cmd.unit_id])
	return "\n".join(lines)


func _help_text() -> String:
	var lines: PackedStringArray = ["F1 help"]
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		var events := InputMap.action_get_events(action)
		var names: PackedStringArray = []
		for event in events:
			names.append(event.as_text())
		lines.append("%s: %s" % [action, ", ".join(names)])
	return "\n".join(lines)


func _cheats() -> void:
	if not OS.is_debug_build():
		return
	var human := _sim.get_human()
	if human != null and Input.is_action_just_pressed("debug_teleport"):
		var ground: Variant = _camera.screen_to_ground(_camera.camera.get_viewport().get_mouse_position())
		if ground is Vector3:
			_sim.debug_teleport(human.unit_id, ground)
	if Input.is_action_just_pressed("debug_bots"):
		_cycle_bots()
	if Input.is_action_just_pressed("debug_time_slower"):
		_time_scale = maxf(_time_scale * 0.5, 0.25)
		Engine.time_scale = _time_scale
	if Input.is_action_just_pressed("debug_time_faster"):
		_time_scale = minf(_time_scale * 2.0, 4.0)
		Engine.time_scale = _time_scale
	if Input.is_action_just_pressed("debug_respawn"):
		_sim.debug_respawn_all()
	if human != null and Input.is_action_just_pressed("debug_damage"):
		_sim.debug_damage(human.unit_id, 25.0)


func _cycle_bots() -> void:
	for node in get_tree().get_nodes_in_group(&"bot_controller"):
		var bot := node as BotController
		if bot == null:
			continue
		bot.set_difficulty((int(bot.difficulty()) + 1) % 4)


func _rebuild_collision() -> void:
	for child in _collision_root.get_children():
		child.queue_free()
	if not _collision_on:
		return
	for body in _sim.get_parent().find_children("*", "CollisionObject3D", true, false):
		for shape_node in body.find_children("*", "CollisionShape3D", true, false):
			var shape := (shape_node as CollisionShape3D).shape
			if shape == null:
				continue
			var mesh := shape.get_debug_mesh()
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.global_transform = (shape_node as CollisionShape3D).global_transform
			_collision_root.add_child(instance)


func _set_freecam(on: bool) -> void:
	_freecam_on = on
	if _freecam == null:
		_freecam = Camera3D.new()
		_freecam.name = "FreeCamera"
		_freecam.fov = 70.0
		_sim.get_parent().add_child(_freecam)
	_freecam.global_position = _camera.camera.global_position
	_freecam.current = on
	_camera.camera.current = not on


func _fly(delta: float) -> void:
	if not _freecam_on or _freecam == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := Input.get_last_mouse_velocity()
		_yaw -= motion.x * 0.002
		_pitch = clampf(_pitch - motion.y * 0.002, -1.4, 1.4)
		_freecam.rotation = Vector3(_pitch, _yaw, 0.0)
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		wish.z += 1.0
	if Input.is_key_pressed(KEY_A):
		wish.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		wish.x += 1.0
	if wish != Vector3.ZERO:
		_freecam.global_position += _freecam.global_transform.basis * wish.normalized() * 18.0 * delta
