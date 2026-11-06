extends GutTest

## Mouse keeps the current keys. WASD moves and shifts the second ability to E.


func test_mouse_preset_uses_right_click_and_q_w() -> void:
	ControlBindings.apply_preset("mouse")
	assert_eq(_button("move_click"), MOUSE_BUTTON_RIGHT)
	assert_eq(_button("fire"), MOUSE_BUTTON_LEFT)
	assert_eq(_key("ability_1"), KEY_Q)
	assert_eq(_key("ability_2"), KEY_W)
	assert_eq(InputMap.action_get_events(&"move_forward").size(), 0)


func test_wasd_preset_moves_and_puts_ability_two_on_e() -> void:
	ControlBindings.apply_preset("wasd")
	assert_eq(_key("move_forward"), KEY_W)
	assert_eq(_key("move_left"), KEY_A)
	assert_eq(_key("move_back"), KEY_S)
	assert_eq(_key("move_right"), KEY_D)
	assert_eq(_key("ability_1"), KEY_Q)
	assert_eq(_key("ability_2"), KEY_E)
	assert_eq(_key("stop"), KEY_X)
	assert_eq(InputMap.action_get_events(&"move_click").size(), 0)
	ControlBindings.apply_preset("mouse")


func test_rebind_replaces_the_key_and_clears_the_old_owner() -> void:
	ControlBindings.apply_preset("mouse")
	ControlBindings.set_event("dash", _key_event(KEY_F))
	assert_eq(_key("dash"), KEY_F)
	ControlBindings.set_event("jump", _key_event(KEY_F))
	assert_eq(_key("jump"), KEY_F)
	assert_eq(InputMap.action_get_events(&"dash").size(), 0)
	ControlBindings.apply_preset("mouse")


func test_wasd_wish_follows_the_camera() -> void:
	var forward := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	var wish := _wish(forward, right, true, false, false, true)
	assert_almost_eq(wish.x, 0.707, 0.02)
	assert_almost_eq(wish.z, -0.707, 0.02)


func _wish(forward: Vector3, right: Vector3, north: bool, south: bool, west: bool, east: bool) -> Vector3:
	var wish := Vector3.ZERO
	if north:
		wish += forward
	if south:
		wish -= forward
	if east:
		wish += right
	if west:
		wish -= right
	return wish.normalized()


func _key(action: String) -> int:
	return (InputMap.action_get_events(action)[0] as InputEventKey).physical_keycode


func _button(action: String) -> int:
	return (InputMap.action_get_events(action)[0] as InputEventMouseButton).button_index


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event
