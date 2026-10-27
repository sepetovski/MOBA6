extends GutTest


func test_click_hold_steer_and_keys() -> void:
	var rig := _rig(false)
	var controller: PlayerController = rig.controller
	var got: Array = rig.got
	var cam: MobaCamera = rig.camera
	controller._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(960, 540)))
	assert_eq(got.size(), 1)
	_assert_cmd(got[0], Command.Kind.MOVE_TO, 7, 0, true)
	controller._physics_process(0.1)
	assert_eq(got.size(), 1, "under the hold threshold there is no STEER")
	controller._physics_process(0.1)
	assert_eq(got.size(), 2)
	_assert_cmd(got[1], Command.Kind.STEER, 7, 1, true)
	var away := _screen_past(cam, (got[1] as Command).point, 0.2)
	controller._unhandled_input(_motion(away))
	controller._physics_process(0.05)
	assert_eq(got.size(), 3)
	_assert_cmd(got[2], Command.Kind.STEER, 7, 2, true)
	assert_gt((got[2] as Command).point.distance_to((got[1] as Command).point), 0.2)
	controller._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false, away))
	assert_eq(got.size(), 4)
	_assert_cmd(got[3], Command.Kind.STEER, 7, 3, false)
	controller._unhandled_input(_key(KEY_S, true))
	_assert_cmd(got[4], Command.Kind.STOP, 7, 4, true)
	controller._unhandled_input(_key(KEY_SPACE, true))
	_assert_cmd(got[5], Command.Kind.JUMP, 7, 5, true)
	controller._unhandled_input(_key(KEY_SPACE, false))
	_assert_cmd(got[6], Command.Kind.JUMP, 7, 6, false)
	controller._unhandled_input(_key(KEY_CTRL, true))
	_assert_cmd(got[7], Command.Kind.CROUCH_SLIDE, 7, 7, true)
	controller._unhandled_input(_key(KEY_CTRL, false))
	_assert_cmd(got[8], Command.Kind.CROUCH_SLIDE, 7, 8, false)
	var before := got.size()
	var echo := _key(KEY_S, true)
	echo.echo = true
	controller._unhandled_input(echo)
	assert_eq(got.size(), before)


func test_release_before_the_hold_sends_no_steer() -> void:
	var rig := _rig(false)
	var controller: PlayerController = rig.controller
	controller._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(960, 540)))
	controller._physics_process(0.05)
	controller._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false, Vector2(960, 540)))
	assert_eq(rig.got.size(), 1)
	assert_eq((rig.got[0] as Command).kind, Command.Kind.MOVE_TO)


func test_crouch_toggle_ignores_release() -> void:
	var rig := _rig(true)
	var controller: PlayerController = rig.controller
	var got: Array = rig.got
	controller._unhandled_input(_key(KEY_CTRL, true))
	_assert_cmd(got[0], Command.Kind.CROUCH_SLIDE, 7, 0, true)
	controller._unhandled_input(_key(KEY_CTRL, false))
	assert_eq(got.size(), 1)
	controller._unhandled_input(_key(KEY_CTRL, true))
	_assert_cmd(got[1], Command.Kind.CROUCH_SLIDE, 7, 1, false)


func test_disabled_controller_is_silent() -> void:
	var rig := _rig(false)
	var controller: PlayerController = rig.controller
	controller.enabled = false
	controller._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(960, 540)))
	controller._physics_process(0.5)
	controller._unhandled_input(_key(KEY_SPACE, true))
	assert_eq(rig.got.size(), 0)


func test_ui_consumed_press_emits_nothing() -> void:
	var open := _rig(false)
	open.viewport.push_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(40, 40)), true)
	await get_tree().process_frame
	assert_eq(open.got.size(), 1, "a press the GUI does not consume still emits MOVE_TO")
	var blocked := _rig(false)
	var layer := CanvasLayer.new()
	blocked.viewport.add_child(layer)
	var panel := ColorRect.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.color = Color(1, 0, 0, 0.15)
	panel.position = Vector2.ZERO
	panel.size = Vector2(1920, 1080)
	layer.add_child(panel)
	await get_tree().process_frame
	blocked.viewport.push_input(_mouse(MOUSE_BUTTON_RIGHT, true, Vector2(40, 40)), true)
	await get_tree().process_frame
	assert_eq(blocked.got.size(), 0)
	assert_eq((blocked.controller as PlayerController).process_physics_priority, -10)


func _rig(toggle: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.handle_input_locally = true
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	var cam := MobaCamera.new()
	viewport.add_child(cam)
	cam._process(0.0)
	var settings := InputSettings.new()
	settings.hold_threshold = 0.15
	settings.steer_resend_distance = 0.2
	settings.crouch_toggle = toggle
	settings.confine_mouse = false
	var controller := PlayerController.new()
	controller.settings = settings
	viewport.add_child(controller)
	var got: Array[Command] = []
	controller.bind(7, cam, func(cmd: Command) -> void: got.append(cmd))
	return {"controller": controller, "camera": cam, "got": got, "viewport": viewport}


func _assert_cmd(cmd: Command, kind: Command.Kind, unit_id: int, seq: int, pressed: bool) -> void:
	assert_eq(cmd.kind, kind)
	assert_eq(cmd.unit_id, unit_id)
	assert_eq(cmd.seq, seq)
	assert_eq(cmd.tick, 0)
	assert_eq(cmd.pressed, pressed)


func _screen_past(cam: MobaCamera, origin: Vector3, distance: float) -> Vector2:
	var shifted := origin + Vector3(distance + 0.5, 0.0, 0.0)
	return cam.camera.unproject_position(shifted)


func _mouse(button: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	return event


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = false
	return event
