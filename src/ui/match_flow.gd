class_name MatchFlow extends CanvasLayer

## Menu, map flyover, roster, countdown and the end card. It never writes simulation state
## except to start the countdown once the flyover has finished.

signal play_requested
signal again_requested
signal menu_requested

enum Phase { MENU, WAIT, FLYOVER, WEST, EAST, COUNTDOWN, PLAY, RESULTS }

const FLY_SECONDS := 6.2
const SIDE_SECONDS := 2.5

var _camera: MobaCamera
var _sim: Simulation
var _phase := Phase.MENU
var _time := 0.0
var _go_left := 0.0
var _counted := false

var _menu: Control
var _options: Control
var _busy: Label
var _banner: Label
var _roster: Control
var _roster_a: Label
var _roster_b: Label
var _count_root: Control
var _count_label: Label
var _results: Control
var _result_title: Label
var _result_body: Label


func open_menu(camera: MobaCamera) -> void:
	_camera = camera
	layer = 30
	if _menu == null:
		_build()
	_phase = Phase.MENU
	_time = 0.0
	_show_menu()


func hold(message: String) -> void:
	_phase = Phase.WAIT
	_time = 0.0
	_hide_panels()
	_busy.text = message
	_busy.visible = true


func start_intro(sim: Simulation, camera: MobaCamera) -> void:
	_sim = sim
	_camera = camera
	_counted = false
	_phase = Phase.FLYOVER
	_time = 0.0
	_hide_panels()
	_banner.text = "The ring"
	_banner.visible = true


func on_running() -> void:
	_phase = Phase.PLAY
	_go_left = 0.5
	_hide_panels()
	_count_root.visible = true
	_count_label.text = "GO"
	_count_label.modulate.a = 0.8


func show_results(sim: Simulation) -> void:
	_sim = sim
	_phase = Phase.RESULTS
	_fill_results()
	_hide_panels()
	_results.visible = true


func _process(delta: float) -> void:
	if _camera == null:
		return
	_time += delta
	match _phase:
		Phase.MENU:
			var sway := sin(float(Time.get_ticks_msec()) * 0.00018)
			_camera.present(Vector3(sway * 16.0, 0.0, 5.0), 40.0, false)
		Phase.WAIT:
			_camera.present(Vector3(0.0, 0.0, 4.0), 42.0, false)
		Phase.FLYOVER:
			var t := clampf(_time / FLY_SECONDS, 0.0, 1.0)
			var eased := t * t * (3.0 - 2.0 * t)
			_camera.present(Vector3(lerpf(-34.0, 34.0, eased), 0.0, 2.0), 46.0, false)
			if _time >= FLY_SECONDS:
				_enter_side(true)
		Phase.WEST:
			_camera.present(Vector3(-41.0, 0.0, 0.0), 22.0, false)
			if _time >= SIDE_SECONDS:
				_enter_side(false)
		Phase.EAST:
			_camera.present(Vector3(41.0, 0.0, 0.0), 22.0, false)
			if _time >= SIDE_SECONDS:
				_enter_countdown()
		Phase.COUNTDOWN:
			_camera.present(Vector3(0.0, 0.0, 3.0), 32.0, false)
			_paint_count()
		Phase.PLAY:
			if _go_left > 0.0:
				_go_left = maxf(_go_left - delta, 0.0)
				_count_label.modulate.a = clampf(_go_left / 0.5, 0.0, 0.8)
				if _go_left <= 0.0:
					_count_root.visible = false
		Phase.RESULTS:
			var drift := sin(float(Time.get_ticks_msec()) * 0.00012)
			_camera.present(Vector3(drift * 8.0, 0.0, 6.0), 40.0, false)


func _enter_side(west: bool) -> void:
	_phase = Phase.WEST if west else Phase.EAST
	_time = 0.0
	_hide_panels()
	_banner.text = "Team A" if west else "Team B"
	_banner.visible = true
	_roster.visible = true
	if _sim != null:
		_roster_a.text = _side_text(Team.Id.A)
		_roster_b.text = _side_text(Team.Id.B)


func _enter_countdown() -> void:
	_phase = Phase.COUNTDOWN
	_time = 0.0
	_hide_panels()
	_count_root.visible = true
	if _sim != null and not _counted:
		_counted = true
		_sim.begin_countdown()


func _paint_count() -> void:
	if _sim == null:
		return
	var number := maxi(int(ceil(_sim.get_countdown_seconds() - 0.001)), 0)
	if number <= 0 or _sim.get_match_state() == Match.State.RUNNING:
		_count_label.text = "GO"
	else:
		_count_label.text = str(number)
	_count_label.modulate.a = 0.8


func _side_text(team: int) -> String:
	var lines: PackedStringArray = []
	for unit in _sim.get_units():
		if unit.team != team:
			continue
		var who := unit.state.display_name
		if unit.state.controller == UnitState.Controller.HUMAN:
			who += "   you"
		lines.append("%s    %s" % [who, unit.hero_name])
	return "\n".join(lines)


func _fill_results() -> void:
	if _sim == null:
		return
	var winner := _sim.winning_team()
	if winner < 0:
		_result_title.text = "Draw"
	else:
		_result_title.text = "Team %s wins" % ("A" if winner == Team.Id.A else "B")
	var lines: PackedStringArray = []
	lines.append("Gold    A %d     B %d" % [_sim.team_gold(Team.Id.A), _sim.team_gold(Team.Id.B)])
	var mvp := _sim.mvp_unit()
	if mvp != null:
		lines.append("MVP    %s %s    %d / %d / %d" % [
			mvp.state.display_name,
			mvp.hero_name,
			mvp.state.kills,
			mvp.state.deaths,
			mvp.state.assists,
		])
	lines.append("")
	for team in [Team.Id.A, Team.Id.B]:
		lines.append("Team %s" % ("A" if team == Team.Id.A else "B"))
		for unit in _sim.get_units():
			if unit.team != team:
				continue
			var state := unit.state
			var who := state.display_name
			if state.controller == UnitState.Controller.HUMAN:
				who += " you"
			lines.append("  %s    %d / %d / %d    %d dmg    %d gold" % [
				who, state.kills, state.deaths, state.assists, int(round(state.damage_dealt)), state.gold,
			])
		lines.append("")
	_result_body.text = "\n".join(lines)


func _show_menu() -> void:
	_hide_panels()
	_menu.visible = true


func _hide_panels() -> void:
	_menu.visible = false
	_options.visible = false
	_busy.visible = false
	_banner.visible = false
	_roster.visible = false
	_count_root.visible = false
	_results.visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_menu = _centered(root)
	_options = _centered(root)
	_results = _centered(root)
	_build_menu()
	_build_options()
	_build_banner(root)
	_build_roster(root)
	_build_count(root)
	_build_results()
	_busy = _text("", 28, Color(0.96, 0.94, 0.86))
	_busy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_busy.set_anchors_preset(Control.PRESET_CENTER)
	_busy.offset_left = -240.0
	_busy.offset_right = 240.0
	_busy.offset_top = -24.0
	_busy.offset_bottom = 24.0
	_busy.visible = false
	root.add_child(_busy)


func _build_menu() -> void:
	var box := _stack(_menu, 420.0)
	box.add_child(_text("Gladiator Arena", 52, Color(0.98, 0.95, 0.86)))
	var sub := _text("A forest ring. Six a side.", 20, Color(0.9, 0.88, 0.78))
	box.add_child(sub)
	box.add_child(_button("Play", func() -> void: play_requested.emit()))
	box.add_child(_button("Options", func() -> void:
		_menu.visible = false
		_options.visible = true
	))


func _build_options() -> void:
	var box := _stack(_options, 560.0)
	box.add_child(_text("Options", 40, Color(0.98, 0.95, 0.86)))
	var body := _text("", 18, Color(0.93, 0.91, 0.84))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 180)
	body.text = "Right-click moves. Hold to steer.\nSpace jumps. Near a rock it grabs the ledge.\nShift dashes. You have two. One refills on its own. Spend both and they come back faster.\nCtrl after a dash slides and keeps that speed.\nCtrl while running also slides."
	box.add_child(body)
	box.add_child(_button("Back", func() -> void: _show_menu()))


func _build_banner(root: Control) -> void:
	_banner = _text("", 42, Color(0.98, 0.96, 0.9, 0.9))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -260.0
	_banner.offset_right = 260.0
	_banner.offset_top = 36.0
	_banner.offset_bottom = 96.0
	_banner.visible = false
	root.add_child(_banner)


func _build_roster(root: Control) -> void:
	_roster = Control.new()
	_roster.set_anchors_preset(Control.PRESET_FULL_RECT)
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.visible = false
	root.add_child(_roster)
	var west := _panel(Color(0.16, 0.28, 0.55, 0.45))
	west.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	west.offset_left = 36.0
	west.offset_top = -170.0
	west.offset_right = 340.0
	west.offset_bottom = 170.0
	_roster.add_child(west)
	var west_box := _stack(west, 280.0)
	west_box.add_child(_text("Team A", 26, Color(0.7, 0.82, 1.0)))
	_roster_a = _text("", 18, Color(0.95, 0.94, 0.9))
	west_box.add_child(_roster_a)
	var east := _panel(Color(0.55, 0.22, 0.18, 0.45))
	east.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	east.offset_left = -340.0
	east.offset_top = -170.0
	east.offset_right = -36.0
	east.offset_bottom = 170.0
	_roster.add_child(east)
	var east_box := _stack(east, 280.0)
	east_box.add_child(_text("Team B", 26, Color(1.0, 0.72, 0.64)))
	_roster_b = _text("", 18, Color(0.95, 0.94, 0.9))
	east_box.add_child(_roster_b)


func _build_count(root: Control) -> void:
	_count_root = Control.new()
	_count_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_root.visible = false
	root.add_child(_count_root)
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.set_anchors_preset(Control.PRESET_CENTER)
	disc.offset_left = -120.0
	disc.offset_top = -120.0
	disc.offset_right = 120.0
	disc.offset_bottom = 120.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.06, 0.38)
	style.set_corner_radius_all(120)
	disc.add_theme_stylebox_override("panel", style)
	_count_root.add_child(disc)
	_count_label = _text("3", 128, Color(1, 1, 1, 0.8))
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.set_anchors_preset(Control.PRESET_CENTER)
	_count_label.offset_left = -160.0
	_count_label.offset_top = -90.0
	_count_label.offset_right = 160.0
	_count_label.offset_bottom = 90.0
	_count_label.modulate.a = 0.8
	_count_root.add_child(_count_label)


func _build_results() -> void:
	var box := _stack(_results, 760.0)
	_result_title = _text("Result", 40, Color(0.98, 0.94, 0.8))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_body = _text("", 18, Color(0.94, 0.92, 0.86))
	_result_body.custom_minimum_size = Vector2(720, 280)
	box.add_child(_result_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_button("Play again", func() -> void: again_requested.emit()))
	row.add_child(_button("Main menu", func() -> void: menu_requested.emit()))
	box.add_child(row)


func _centered(parent: Control) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	parent.add_child(center)
	return center


func _stack(parent: Node, width: float) -> VBoxContainer:
	var panel := _panel(Color(0.07, 0.09, 0.07, 0.62))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	return box


func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.86, 0.78, 0.46, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(240, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.72))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.22, 0.13, 0.92)
	normal.border_color = Color(0.86, 0.78, 0.42)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.26, 0.34, 0.16, 0.96)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	return button


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
