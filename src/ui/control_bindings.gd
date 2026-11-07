class_name ControlBindings extends RefCounted

## Two shipped layouts, plus whatever the player rebinds.
## Mouse keeps right-click movement and abilities on Q and W.
## WASD moves like a shooter and puts the second ability on E, because W is forward.

const GAMEPLAY: PackedStringArray = [
	"move_forward", "move_back", "move_left", "move_right",
	"move_click", "fire", "jump", "crouch_slide", "dash", "stop",
	"ability_1", "ability_2", "camera_lock", "item",
]

const LABELS := {
	"move_forward": "Move forward",
	"move_back": "Move back",
	"move_left": "Move left",
	"move_right": "Move right",
	"move_click": "Move click",
	"fire": "Fire",
	"jump": "Jump",
	"crouch_slide": "Crouch / slide",
	"dash": "Dash",
	"stop": "Stop",
	"ability_1": "Ability 1",
	"ability_2": "Ability 2",
	"camera_lock": "Camera lock",
	"item": "Item active",
}


static func label(action: String) -> String:
	return str(LABELS.get(action, action))


static func apply_preset(scheme: String) -> void:
	for action in GAMEPLAY:
		_ensure(action)
		InputMap.action_erase_events(action)
	if scheme == "wasd":
		_bind("move_forward", _key(KEY_W))
		_bind("move_back", _key(KEY_S))
		_bind("move_left", _key(KEY_A))
		_bind("move_right", _key(KEY_D))
		_bind("fire", _mouse(MOUSE_BUTTON_LEFT))
		_bind("jump", _key(KEY_SPACE))
		_bind("crouch_slide", _key(KEY_CTRL))
		_bind("dash", _key(KEY_SHIFT))
		_bind("stop", _key(KEY_X))
		_bind("ability_1", _key(KEY_Q))
		_bind("ability_2", _key(KEY_E))
		_bind("camera_lock", _key(KEY_Y))
		_bind("item", _key(KEY_1))
		return
	_bind("move_click", _mouse(MOUSE_BUTTON_RIGHT))
	_bind("fire", _mouse(MOUSE_BUTTON_LEFT))
	_bind("jump", _key(KEY_SPACE))
	_bind("crouch_slide", _key(KEY_CTRL))
	_bind("dash", _key(KEY_SHIFT))
	_bind("stop", _key(KEY_S))
	_bind("ability_1", _key(KEY_Q))
	_bind("ability_2", _key(KEY_W))
	_bind("camera_lock", _key(KEY_Y))
	_bind("item", _key(KEY_1))


static func set_event(action: String, event: InputEvent) -> void:
	_ensure(action)
	var stored := _clean(event)
	for other in GAMEPLAY:
		if other == action:
			continue
		_drop_match(other, stored)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, stored)


static func text_for(action: String) -> String:
	if not InputMap.has_action(action):
		return "Unbound"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return _describe(events[0])


static func encode(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	var event := events[0]
	if event is InputEventKey:
		return "key:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


static func decode(encoded: String) -> InputEvent:
	if encoded.begins_with("key:"):
		return _key(int(encoded.substr(4)) as Key)
	if encoded.begins_with("mouse:"):
		return _mouse(int(encoded.substr(6)) as MouseButton)
	return null


static func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _bind(action: String, event: InputEvent) -> void:
	InputMap.action_add_event(action, event)


static func _drop_match(action: String, incoming: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if _same(event, incoming):
			InputMap.action_erase_event(action, event)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


static func _clean(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = (event as InputEventKey).physical_keycode
		return key
	var mouse := InputEventMouseButton.new()
	mouse.button_index = (event as InputEventMouseButton).button_index
	return mouse


static func _describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var code := (event as InputEventKey).physical_keycode
		var name := OS.get_keycode_string(code)
		return name if not name.is_empty() else "Key"
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Mouse left"
			MOUSE_BUTTON_RIGHT:
				return "Mouse right"
			MOUSE_BUTTON_MIDDLE:
				return "Mouse middle"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel down"
	return "Unbound"


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
