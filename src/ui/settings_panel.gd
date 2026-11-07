class_name SettingsPanel extends Control

## Graphics and rebinding. Built in code so the menu stays one owner.

signal back_requested

var _fps_buttons: Array[Button] = []
var _vsync_button: Button
var _shadow_button: Button
var _full_button: Button
var _cover_slider: HSlider
var _cover_label: Label
var _bind_buttons: Dictionary = {}
var _listen := ""
var _armed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 640)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameSettings.boot()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(540, 620)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(520, 0)
	scroll.add_child(box)
	box.add_child(_title("Settings", 40))
	box.add_child(_title("Graphics", 22))
	box.add_child(_title("Frame cap", 16))
	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 8)
	for value in GameSettings.FPS_CHOICES:
		var button := Button.new()
		button.text = GameSettings.fps_label(value)
		button.custom_minimum_size = Vector2(72, 36)
		button.pressed.connect(_on_fps.bind(value))
		fps_row.add_child(button)
		_fps_buttons.append(button)
	box.add_child(fps_row)
	_vsync_button = _toggle("VSync")
	_vsync_button.pressed.connect(_on_vsync)
	box.add_child(_vsync_button)
	_shadow_button = _toggle("Shadows")
	_shadow_button.pressed.connect(_on_shadows)
	box.add_child(_shadow_button)
	_full_button = _toggle("Fullscreen")
	_full_button.pressed.connect(_on_fullscreen)
	box.add_child(_full_button)
	var balance := Button.new()
	balance.text = "Balance    F10"
	balance.alignment = HORIZONTAL_ALIGNMENT_LEFT
	balance.custom_minimum_size = Vector2(240, 40)
	balance.pressed.connect(_open_balance)
	box.add_child(balance)
	box.add_child(_title("Cover see-through", 16))
	_cover_label = _title("How clear trees and boxes are when someone is behind them.", 14)
	box.add_child(_cover_label)
	_cover_slider = HSlider.new()
	_cover_slider.min_value = 20.0
	_cover_slider.max_value = 95.0
	_cover_slider.step = 1.0
	_cover_slider.custom_minimum_size = Vector2(420, 28)
	_cover_slider.value_changed.connect(_on_cover)
	box.add_child(_cover_slider)
	box.add_child(_title("Esc opens this during a match. Balance is F10. Godot uses F8 to stop the game.", 14))
	box.add_child(_title("Controls", 22))
	var schemes := HBoxContainer.new()
	schemes.add_theme_constant_override("separation", 8)
	var mouse := Button.new()
	mouse.text = "Mouse defaults"
	mouse.custom_minimum_size = Vector2(200, 40)
	mouse.pressed.connect(func() -> void: _on_scheme("mouse"))
	var wasd := Button.new()
	wasd.text = "WASD defaults"
	wasd.custom_minimum_size = Vector2(200, 40)
	wasd.pressed.connect(func() -> void: _on_scheme("wasd"))
	schemes.add_child(mouse)
	schemes.add_child(wasd)
	box.add_child(schemes)
	box.add_child(_title("Mouse: right-click moves, abilities on Q and W.\nWASD: move with WASD, abilities on Q and E.\nClick a binding, then press the new key.", 14))
	for action in ControlBindings.GAMEPLAY:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name := Label.new()
		name.text = ControlBindings.label(action)
		name.custom_minimum_size = Vector2(220, 32)
		name.add_theme_font_size_override("font_size", 16)
		var bind := Button.new()
		bind.custom_minimum_size = Vector2(180, 32)
		bind.pressed.connect(_on_listen.bind(action))
		row.add_child(name)
		row.add_child(bind)
		box.add_child(row)
		_bind_buttons[action] = bind
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(func() -> void: back_requested.emit())
	box.add_child(back)
	_refresh()


func is_listening() -> bool:
	return not _listen.is_empty()


func _process(_delta: float) -> void:
	if _listen.is_empty() or _armed:
		return
	_armed = true


func _unhandled_input(event: InputEvent) -> void:
	if _listen.is_empty() or not _armed:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.echo or not key.pressed:
			return
		if key.physical_keycode == KEY_ESCAPE:
			_listen = ""
			_refresh()
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
	else:
		return
	ControlBindings.set_event(_listen, event)
	GameSettings.scheme = "custom"
	GameSettings.save()
	_listen = ""
	_refresh()
	get_viewport().set_input_as_handled()


func _on_fps(value: int) -> void:
	GameSettings.set_fps(value)
	_refresh()


func _on_vsync() -> void:
	GameSettings.set_vsync(not GameSettings.vsync)
	_refresh()


func _on_shadows() -> void:
	GameSettings.set_shadows(not GameSettings.shadows)
	_refresh()


func _on_fullscreen() -> void:
	GameSettings.set_fullscreen(not GameSettings.fullscreen)
	_refresh()


func _open_balance() -> void:
	var panels := get_tree().get_nodes_in_group(&"balance_admin")
	if panels.is_empty():
		return
	var admin := panels[0] as BalanceAdmin
	if admin != null and not admin.is_open():
		admin.toggle()


func _on_cover(value: float) -> void:
	GameSettings.set_cover_see_through(value / 100.0)
	_cover_label.text = "See-through    %d%%" % int(round(value))


func _on_scheme(scheme: String) -> void:
	GameSettings.use_scheme(scheme)
	_listen = ""
	_refresh()


func _on_listen(action: String) -> void:
	_listen = action
	_armed = false
	var button: Button = _bind_buttons[action]
	button.text = "Press a key"


func _refresh() -> void:
	for index in _fps_buttons.size():
		var button := _fps_buttons[index]
		var selected := GameSettings.FPS_CHOICES[index] == GameSettings.fps
		button.modulate = Color(1.2, 1.15, 0.7) if selected else Color.WHITE
	_vsync_button.text = "VSync    %s" % ("On" if GameSettings.vsync else "Off")
	_shadow_button.text = "Shadows    %s" % ("On" if GameSettings.shadows else "Off")
	_full_button.text = "Fullscreen    %s" % ("On" if GameSettings.fullscreen else "Off")
	var shown := GameSettings.cover_see_through
	if shown < 0.0:
		shown = 0.75
	_cover_slider.set_value_no_signal(shown * 100.0)
	_cover_label.text = "See-through    %d%%" % int(round(shown * 100.0))
	for action in _bind_buttons:
		if action == _listen:
			continue
		var button: Button = _bind_buttons[action]
		button.text = ControlBindings.text_for(action)


func _title(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.84))
	return label


func _toggle(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(240, 36)
	return button
