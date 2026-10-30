class_name DebugHud extends CanvasLayer

## Reads simulation state and events. Decorative controls ignore the mouse.

var _sim: Simulation
var _camera: MobaCamera
var _rings: Array[GroundRing] = []
var _plates: Array[Control] = []
var _units: Array[SimUnit] = []
var _help: Label
var _readout: Label
var _score_panel: PanelContainer
var _kda_numbers: Label
var _kda_detail: Label
var _clock_panel: PanelContainer
var _clock_label: Label
var _gold_a: Label
var _gold_b: Label
var _board: Control
var _rows_a: Array[HBoxContainer] = []
var _rows_b: Array[HBoxContainer] = []
var _team_a_gold: Label
var _team_b_gold: Label
var _player_bar: PanelContainer
var _hero_label: Label
var _hp_fill: ColorRect
var _hp_text: Label
var _pocket_gold: Label
var _ability_names: Array[Label] = []
var _ability_times: Array[Label] = []
var _ability_covers: Array[ColorRect] = []
var _result: PanelContainer
var _result_title: Label
var _result_body: Label
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
	_build_score_chip()
	_build_clock()
	_build_board()
	_build_player_bar()
	_build_result()
	for unit in sim.get_units():
		_add_unit(unit)
	GameEvents.damage_dealt.connect(_show_damage)
	GameEvents.gold_awarded.connect(_show_gold)
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
	var hide := Input.is_key_pressed(KEY_TAB) or _sim.get_match_state() == Match.State.FINISHED
	for index in _units.size():
		var unit := _units[index]
		var plate := _plates[index]
		if hide or not unit.state.alive:
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
	var human := _sim.get_human()
	if _score_panel != null:
		_score_panel.position = Vector2(view.x - 292, 14)
		if human == null:
			_kda_numbers.text = "0 / 0 / 0"
			_kda_detail.text = "0 gold    0 dmg"
		else:
			var state := human.state
			_kda_numbers.text = "%d / %d / %d" % [state.kills, state.deaths, state.assists]
			_kda_detail.text = "%d gold    %d dmg" % [state.gold, int(round(state.damage_dealt))]
	if _clock_panel != null:
		_clock_panel.position = Vector2(view.x * 0.5 - 210, 14)
		var left := _sim.get_clock_seconds()
		var total := maxi(int(ceil(left)), 0)
		var caption := "start" if _sim.get_match_state() == Match.State.COUNTDOWN else "left"
		if _sim.get_match_state() == Match.State.FINISHED:
			caption = "final"
		_clock_label.text = "%d:%02d  %s" % [int(total / 60.0), total % 60, caption]
		_gold_a.text = "A  %d" % _sim.team_gold(Team.Id.A)
		_gold_b.text = "%d  B" % _sim.team_gold(Team.Id.B)
	_place_player_bar(view, human)
	_fill_rows(_rows_a, Team.Id.A)
	_fill_rows(_rows_b, Team.Id.B)
	if _team_a_gold != null:
		_team_a_gold.text = "%d gold" % _sim.team_gold(Team.Id.A)
		_team_b_gold.text = "%d gold" % _sim.team_gold(Team.Id.B)
	if _board != null:
		_board.visible = Input.is_key_pressed(KEY_TAB)
		_board.size = view
		var card := _board.get_node_or_null("Card") as Control
		if card != null:
			card.position = Vector2(view.x * 0.5 - 470, view.y * 0.5 - 250)
	_update_result(view)


func _place_player_bar(view: Vector2, human: SimUnit) -> void:
	if _player_bar == null:
		return
	_player_bar.position = Vector2(view.x * 0.5 - 380, view.y - 168)
	if human == null:
		return
	_hero_label.text = "%s   %s" % [human.state.display_name, human.hero_name]
	var fraction := clampf(human.state.health / maxf(human.state.max_health, 1.0), 0.0, 1.0)
	_hp_fill.size.x = 248.0 * fraction
	_hp_fill.color = Color(lerpf(0.86, 0.18, fraction), lerpf(0.22, 0.78, fraction), 0.22)
	_hp_text.text = "%d / %d" % [int(round(human.state.health)), int(round(human.state.max_health))]
	_pocket_gold.text = "%d gold" % human.state.gold
	if human.combat == null:
		return
	for slot in _ability_covers.size():
		var ready := slot >= human.combat.ability_count()
		var cd := 0.0 if ready else human.combat.ability_cooldown(slot)
		var limit := 1.0 if ready else human.combat.ability_cooldown_max(slot)
		var cooled := clampf(cd / limit, 0.0, 1.0)
		_ability_covers[slot].size.y = 68.0 * cooled
		_ability_times[slot].text = "ready" if cd <= 0.05 else "%.1f" % cd
		if slot < human.combat.ability_count():
			_ability_names[slot].text = human.combat.ability_name(slot)


func _fill_rows(rows: Array[HBoxContainer], team: int) -> void:
	var listed: Array[SimUnit] = []
	for unit in _sim.get_units():
		if unit.team == team:
			listed.append(unit)
	for index in rows.size():
		var row := rows[index]
		if index >= listed.size():
			row.visible = false
			continue
		row.visible = true
		var unit := listed[index]
		var state := unit.state
		var name := state.display_name
		if state.controller == UnitState.Controller.HUMAN:
			name += "  you"
		var cells := [name, str(state.kills), str(state.deaths), str(state.assists), str(int(round(state.damage_dealt))), str(state.gold)]
		for cell in row.get_child_count():
			(row.get_child(cell) as Label).text = cells[cell]


func _update_result(view: Vector2) -> void:
	if _result == null:
		return
	var finished := _sim.get_match_state() == Match.State.FINISHED
	_result.visible = finished
	if not finished:
		return
	_result.position = Vector2(view.x * 0.5 - 280, view.y * 0.5 - 160)
	var winner := _sim.winning_team()
	if winner < 0:
		_result_title.text = "DRAW"
	else:
		_result_title.text = "TEAM %s WINS" % ("A" if winner == Team.Id.A else "B")
	var mvp := _sim.mvp_unit()
	var who := "nobody"
	var line := ""
	if mvp != null:
		who = "%s %s" % [mvp.state.display_name, mvp.hero_name]
		line = "%d kills  ·  %d assists  ·  %d damage  ·  %d deaths\nMVP score %d" % [
			mvp.state.kills, mvp.state.assists, int(round(mvp.state.damage_dealt)), mvp.state.deaths, _sim.mvp_score(mvp)
		]
	_result_body.text = "Gold   A %d    B %d\n\nMVP  %s\n%s\n\nKills count most, then damage, then assists. Deaths come off." % [
		_sim.team_gold(Team.Id.A), _sim.team_gold(Team.Id.B), who, line
	]


func _show_gold(unit_id: int, amount: int) -> void:
	var human := _sim.get_human()
	if human == null or unit_id != human.unit_id or _camera == null or _camera.camera == null:
		return
	var label := Label.new()
	label.text = "+%d" % amount
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	label.position = _camera.camera.unproject_position(human.global_position + Vector3(0.6, 2.6, 0))
	add_child(label)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.0
	timer.timeout.connect(label.queue_free)
	label.add_child(timer)
	timer.start()


func _build_score_chip() -> void:
	_score_panel = _framed(Vector2(268, 92), Color(0.05, 0.06, 0.08, 0.92), Color(0.95, 0.8, 0.32), 3)
	var caption := _text("K  /  D  /  A", 16, Color(0.78, 0.74, 0.6))
	caption.position = Vector2(16, 8)
	caption.size = Vector2(236, 22)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_panel.get_child(0).add_child(caption)
	_kda_numbers = _text("0 / 0 / 0", 32, Color(0.98, 0.95, 0.84))
	_kda_numbers.position = Vector2(12, 28)
	_kda_numbers.size = Vector2(240, 36)
	_kda_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_panel.get_child(0).add_child(_kda_numbers)
	_kda_detail = _text("0 gold    0 dmg", 15, Color(1.0, 0.86, 0.35))
	_kda_detail.position = Vector2(12, 64)
	_kda_detail.size = Vector2(240, 20)
	_kda_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_panel.get_child(0).add_child(_kda_detail)
	add_child(_score_panel)


func _build_clock() -> void:
	_clock_panel = _framed(Vector2(420, 58), Color(0.05, 0.06, 0.08, 0.92), Color(0.95, 0.8, 0.32), 3)
	_gold_a = _text("A  0", 22, Color(0.62, 0.78, 1.0))
	_gold_a.position = Vector2(16, 14)
	_clock_label = _text("5:00  left", 22, Color(0.96, 0.94, 0.86))
	_clock_label.position = Vector2(120, 14)
	_clock_label.size = Vector2(180, 30)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_b = _text("0  B", 22, Color(1.0, 0.62, 0.55))
	_gold_b.position = Vector2(300, 14)
	_gold_b.size = Vector2(100, 28)
	_gold_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var inner := _clock_panel.get_child(0)
	inner.add_child(_gold_a)
	inner.add_child(_clock_label)
	inner.add_child(_gold_b)
	add_child(_clock_panel)


func _build_player_bar() -> void:
	_player_bar = _framed(Vector2(760, 142), Color(0.05, 0.06, 0.08, 0.92), Color(0.95, 0.8, 0.32), 3)
	var inner := _player_bar.get_child(0)
	_hero_label = _text("Hero", 18, Color(0.95, 0.93, 0.86))
	_hero_label.position = Vector2(16, 10)
	inner.add_child(_hero_label)
	var track := ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.color = Color(0.12, 0.08, 0.08)
	track.position = Vector2(16, 40)
	track.size = Vector2(252, 22)
	inner.add_child(track)
	_hp_fill = ColorRect.new()
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.color = Color(0.2, 0.75, 0.28)
	_hp_fill.position = Vector2(18, 42)
	_hp_fill.size = Vector2(248, 18)
	inner.add_child(_hp_fill)
	_hp_text = _text("0 / 0", 14, Color(1, 1, 1))
	_hp_text.position = Vector2(16, 64)
	inner.add_child(_hp_text)
	_pocket_gold = _text("0 gold", 18, Color(1.0, 0.86, 0.28))
	_pocket_gold.position = Vector2(140, 62)
	inner.add_child(_pocket_gold)
	for slot in 2:
		var origin := Vector2(300 + slot * 92, 16)
		var plate := ColorRect.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.color = Color(0.16, 0.2, 0.28) if slot == 0 else Color(0.22, 0.16, 0.28)
		plate.position = origin
		plate.size = Vector2(78, 72)
		inner.add_child(plate)
		var cover := ColorRect.new()
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.color = Color(0.02, 0.02, 0.03, 0.72)
		cover.position = origin
		cover.size = Vector2(78, 0)
		inner.add_child(cover)
		var key := _text(["Q", "W"][slot], 22, Color(0.96, 0.94, 0.88))
		key.position = origin + Vector2(8, 6)
		inner.add_child(key)
		var time := _text("ready", 14, Color(0.9, 0.88, 0.7))
		time.position = origin + Vector2(8, 44)
		inner.add_child(time)
		var name := _text("", 13, Color(0.82, 0.8, 0.72))
		name.position = Vector2(origin.x, 92)
		name.size = Vector2(84, 36)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(name)
		_ability_covers.append(cover)
		_ability_times.append(time)
		_ability_names.append(name)
	var items := _text("Items", 14, Color(0.75, 0.72, 0.62))
	items.position = Vector2(500, 8)
	inner.add_child(items)
	for slot in 3:
		var slot_box := ColorRect.new()
		slot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_box.color = Color(0.1, 0.1, 0.12)
		slot_box.position = Vector2(500 + slot * 72, 32)
		slot_box.size = Vector2(60, 60)
		inner.add_child(slot_box)
		var rim := ColorRect.new()
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.color = Color(0.55, 0.48, 0.28)
		rim.position = slot_box.position - Vector2(2, 2)
		rim.size = slot_box.size + Vector2(4, 4)
		inner.add_child(rim)
		inner.move_child(rim, slot_box.get_index())
		var empty := _text("—", 20, Color(0.45, 0.42, 0.35))
		empty.position = slot_box.position + Vector2(18, 16)
		inner.add_child(empty)
	add_child(_player_bar)


func _build_board() -> void:
	_board = Control.new()
	_board.name = "Scoreboard"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.01, 0.02, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(dim)
	var card := _framed(Vector2(940, 500), Color(0.04, 0.05, 0.07, 0.94), Color(0.95, 0.8, 0.32), 4)
	card.name = "Card"
	var inner := card.get_child(0)
	var title := _text("Hold TAB     most gold after 5:00 wins", 18, Color(0.95, 0.9, 0.7))
	title.position = Vector2(24, 12)
	inner.add_child(title)
	var west := _team_card("Team A", Color(0.45, 0.62, 0.95), Vector2(20, 48), _rows_a)
	var east := _team_card("Team B", Color(0.95, 0.48, 0.42), Vector2(480, 48), _rows_b)
	inner.add_child(west)
	inner.add_child(east)
	_team_a_gold = west.get_child(0).get_node("Gold") as Label
	_team_b_gold = east.get_child(0).get_node("Gold") as Label
	_board.add_child(card)
	add_child(_board)


func _team_card(title: String, color: Color, at: Vector2, rows: Array[HBoxContainer]) -> Control:
	var card := _framed(Vector2(430, 420), Color(0.07, 0.08, 0.1, 0.96), color, 3)
	card.position = at
	var inner := card.get_child(0)
	var heading := _text(title, 26, color)
	heading.position = Vector2(16, 10)
	inner.add_child(heading)
	var gold := _text("0 gold", 18, Color(1.0, 0.86, 0.28))
	gold.name = "Gold"
	gold.position = Vector2(250, 16)
	inner.add_child(gold)
	var header := _stat_row(["Name", "K", "D", "A", "Dmg", "Gold"], Color(0.7, 0.68, 0.6))
	header.name = "Header"
	header.position = Vector2(12, 52)
	inner.add_child(header)
	for index in 6:
		var row := _stat_row(["", "", "", "", "", ""], Color(0.93, 0.92, 0.88))
		row.position = Vector2(12, 88 + index * 48)
		inner.add_child(row)
		rows.append(row)
	return card


func _stat_row(cells: Array, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var widths: Array[int] = [108, 36, 36, 36, 64, 64]
	for index in cells.size():
		var label := _text(str(cells[index]), 18, color)
		label.custom_minimum_size = Vector2(widths[index], 28)
		row.add_child(label)
	return row


func _build_result() -> void:
	_result = _framed(Vector2(560, 280), Color(0.04, 0.05, 0.07, 0.95), Color(0.95, 0.8, 0.32), 4)
	_result.visible = false
	var inner := _result.get_child(0)
	_result_title = _text("TEAM A WINS", 36, Color(0.98, 0.92, 0.62))
	_result_title.position = Vector2(24, 18)
	_result_title.size = Vector2(510, 46)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_result_title)
	_result_body = _text("", 18, Color(0.93, 0.92, 0.86))
	_result_body.position = Vector2(28, 78)
	_result_body.size = Vector2(500, 180)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_result_body)
	add_child(_result)


func _framed(size: Vector2, fill: Color, border: Color, width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(fill, border, width))
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.custom_minimum_size = size
	panel.add_child(inner)
	return panel


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(8)
	return box


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
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
