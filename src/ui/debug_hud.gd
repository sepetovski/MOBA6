class_name DebugHud extends CanvasLayer

## Reads simulation state and events. Decorative controls ignore the mouse.

var _sim: Simulation
var _camera: MobaCamera
var _rings: Array[GroundRing] = []
var _plates: Array[Control] = []
var _units: Array[SimUnit] = []
var _help: Label
var _readout: Label
var _kda: Label
var _board: Control
var _team_a: Label
var _team_b: Label
var _last_hit: Dictionary = {}
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
	_kda = Label.new()
	_kda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kda.add_theme_font_size_override("font_size", 28)
	_kda.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	add_child(_kda)
	_build_board()
	for unit in sim.get_units():
		_add_unit(unit)
	GameEvents.damage_dealt.connect(_show_damage)
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
	name_label.text = "%s %s" % [unit.state.display_name, unit.hero_name]
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
	var hit := Label.new()
	hit.name = "Hit"
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.position = Vector2(0, 28)
	hit.add_theme_font_size_override("font_size", 15)
	hit.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	hit.visible = false
	plate.add_child(hit)
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
	_update_score()
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
			_update_hit(plate, unit)
		else:
			plate.visible = false


func _status() -> String:
	var human := _sim.get_human()
	var state_name := "countdown"
	if _sim.get_match_state() == Match.State.RUNNING:
		state_name = "running"
	elif _sim.get_match_state() == Match.State.SETUP:
		state_name = "setup"
	var camera_mode := "LOCKED" if _camera.is_locked() else "FREE"
	var camera_hint := "Y lock" if _camera.is_locked() else "edge or middle-mouse pans, Y locks"
	var body := "FPS %.0f\ntick %d\n%s  %.1f s\nCamera %s  (%s)\nTAB scoreboard" % [
		Engine.get_frames_per_second(), _sim.tick, state_name, _sim.get_countdown_seconds(), camera_mode, camera_hint
	]
	if human != null:
		body += "\n%s  %s\n%s  speed %.1f  grounded %s\n%s" % [
			human.hero_name,
			human.combat.ability_line() if human.combat != null else "",
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


func _show_damage(source_id: int, target_id: int, amount: float, _damage_type: int) -> void:
	if _camera == null or _camera.camera == null:
		return
	var unit := _sim.get_unit(target_id)
	if unit == null:
		return
	var human := _sim.get_human()
	var mine := human != null and source_id == human.unit_id
	if mine:
		_last_hit[target_id] = amount
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mine:
		var total := int(round(_sim.damage_from(source_id, target_id)))
		label.text = "%d\n%d total" % [int(round(amount)), total]
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	else:
		label.text = str(int(round(amount)))
		label.add_theme_font_size_override("font_size", 18)
	label.position = _camera.camera.unproject_position(unit.global_position + Vector3(0, 2.4, 0))
	add_child(label)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.1 if mine else 0.6
	timer.timeout.connect(label.queue_free)
	label.add_child(timer)
	timer.start()


func _update_hit(plate: Control, unit: SimUnit) -> void:
	var hit := plate.get_node("Hit") as Label
	var human := _sim.get_human()
	if human == null or hit == null:
		return
	var total := _sim.damage_from(human.unit_id, unit.unit_id)
	if total <= 0.0:
		hit.visible = false
		return
	var last := float(_last_hit.get(unit.unit_id, 0.0))
	hit.visible = true
	hit.text = "%d hit   %d total" % [int(round(last)), int(round(total))]


func _update_score() -> void:
	var view := get_viewport().get_visible_rect().size
	if _kda != null:
		_kda.size = Vector2(280, 72)
		_kda.position = Vector2(view.x - 296, 12)
		var human := _sim.get_human()
		if human == null:
			_kda.text = "K / D / A"
		else:
			var state := human.state
			_kda.text = "%d / %d / %d\n%d dmg" % [
				state.kills, state.deaths, state.assists, int(round(state.damage_dealt))
			]
	if _board == null:
		return
	var show := Input.is_key_pressed(KEY_TAB)
	_board.visible = show
	if not show:
		return
	_board.size = view
	_team_a.text = _team_lines(Team.Id.A)
	_team_b.text = _team_lines(Team.Id.B)
	_team_a.position = Vector2(view.x * 0.12, view.y * 0.16)
	_team_b.position = Vector2(view.x * 0.54, view.y * 0.16)


func _team_lines(team: int) -> String:
	var title := "Team A" if team == Team.Id.A else "Team B"
	var lines: PackedStringArray = ["%s" % title, "Name     K    D    A     Damage"]
	for unit in _sim.get_units():
		if unit.team != team:
			continue
		var state := unit.state
		var name := state.display_name
		if state.controller == UnitState.Controller.HUMAN:
			name += " you"
		lines.append("%-8s %3d  %3d  %3d   %6d" % [
			name, state.kills, state.deaths, state.assists, int(round(state.damage_dealt))
		])
	return "\n".join(lines)


func _build_board() -> void:
	_board = Control.new()
	_board.name = "Scoreboard"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(dim)
	_team_a = _board_column(Color(0.65, 0.78, 1.0))
	_team_b = _board_column(Color(1.0, 0.62, 0.58))
	_board.add_child(_team_a)
	_board.add_child(_team_b)
	add_child(_board)


func _board_column(color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	return label


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
