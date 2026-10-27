extends GutTest

## Projection uses a 1920x1080 SubViewport so the rays do not depend on the test window.


func test_centre_ray_hits_the_focus_on_the_ground() -> void:
	var rig := _viewport_camera()
	var hit: Variant = rig.camera.screen_to_ground(Vector2(960, 540))
	assert_true(hit is Vector3, "centre ray should meet y = 0")
	var point := hit as Vector3
	assert_almost_eq(point.x, 0.0, 0.05)
	assert_almost_eq(point.y, 0.0, 0.001)
	assert_almost_eq(point.z, 0.0, 0.05)


func test_corner_rays_are_symmetric() -> void:
	var rig := _viewport_camera()
	var tl := rig.camera.screen_to_ground(Vector2(0, 0)) as Vector3
	var tr := rig.camera.screen_to_ground(Vector2(1919, 0)) as Vector3
	var bl := rig.camera.screen_to_ground(Vector2(0, 1079)) as Vector3
	var br := rig.camera.screen_to_ground(Vector2(1919, 1079)) as Vector3
	assert_almost_eq(tl.x, -tr.x, 0.15)
	assert_almost_eq(tl.z, tr.z, 0.15)
	assert_almost_eq(bl.x, -br.x, 0.15)
	assert_almost_eq(bl.z, br.z, 0.15)
	assert_almost_eq(tl.y, 0.0, 0.001)
	assert_gt(absf(tl.z - bl.z), 0.5)


func test_zoom_clamps_to_the_profile() -> void:
	var cam := _camera()
	var tuned := cam.profile
	for _step in 30:
		cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	cam._process(2.0)
	assert_almost_eq(cam.camera.position.length(), tuned.distance_min, 0.05)
	for _step in 40:
		cam._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	cam._process(2.0)
	assert_almost_eq(cam.camera.position.length(), tuned.distance_max, 0.05)


func test_bounds_clamp_the_focus_xz_only() -> void:
	var cam := _camera()
	cam.set_locked(false)
	cam.set_bounds(AABB(Vector3(-10.0, 0.0, -10.0), Vector3(20.0, 2.0, 20.0)))
	cam.focus_on(Vector3(100.0, 3.0, -80.0), true)
	assert_almost_eq(cam.global_position.x, 16.0, 0.01)
	assert_almost_eq(cam.global_position.z, -16.0, 0.01)
	assert_almost_eq(cam.global_position.y, 3.0, 0.01)


func test_missing_bounds_and_missing_target_are_safe() -> void:
	var cam := _camera()
	cam.focus_on(Vector3(12.0, 1.0, -3.0), true)
	assert_almost_eq(cam.global_position.x, 12.0, 0.01)
	cam.follow(null)
	cam._process(0.1)
	var target := Node3D.new()
	add_child_autofree(target)
	target.position = Vector3(4.0, 0.0, 4.0)
	cam.follow(target)
	target.queue_free()
	await get_tree().process_frame
	cam._process(0.1)
	assert_true(cam.is_locked())


func test_lock_starts_on_and_y_toggles_it() -> void:
	var cam := _camera()
	assert_true(cam.is_locked())
	var seen: Array[bool] = []
	cam.lock_changed.connect(func(locked: bool) -> void: seen.append(locked))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Y
	event.keycode = KEY_Y
	event.pressed = true
	cam._unhandled_input(event)
	assert_false(cam.is_locked())
	assert_eq(seen.size(), 1)
	assert_false(seen[0])
	cam.set_locked(true)
	assert_true(cam.is_locked())


func test_arrow_pan_moves_only_when_unlocked() -> void:
	var cam := _camera()
	Input.action_press(&"camera_pan_left")
	cam._process(0.5)
	Input.action_release(&"camera_pan_left")
	assert_almost_eq(cam.global_position.x, 0.0, 0.02)
	cam.set_locked(false)
	Input.action_press(&"camera_pan_left")
	cam._process(0.5)
	Input.action_release(&"camera_pan_left")
	assert_lt(cam.global_position.x, -10.0)


func test_follow_eases_toward_the_target() -> void:
	var cam := _camera()
	var target := Node3D.new()
	add_child_autofree(target)
	target.position = Vector3(10.0, 2.0, -4.0)
	cam.follow(target)
	cam._process(1.0)
	assert_almost_eq(cam.global_position.x, 10.0, 0.2)
	assert_almost_eq(cam.global_position.z, -4.0, 0.2)
	assert_almost_eq(cam.global_position.y, 1.9, 0.2)


func _camera() -> MobaCamera:
	var cam := MobaCamera.new()
	add_child_autofree(cam)
	return cam


func _viewport_camera() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(viewport)
	var cam := MobaCamera.new()
	viewport.add_child(cam)
	cam._process(0.0)
	cam.camera.force_update_transform()
	return {"camera": cam, "viewport": viewport}


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = Vector2(960, 540)
	return event
