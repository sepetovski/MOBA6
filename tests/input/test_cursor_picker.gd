extends GutTest


func test_crate_top_and_floor() -> void:
	var floor := _body("Floor", Vector3(0.0, -0.1, 0.0), Vector3(30.0, 0.2, 30.0), GameConfig.LAYER_WORLD)
	var crate := _body("Crate", Vector3(2.0, 0.5, 0.0), Vector3.ONE, GameConfig.LAYER_PROPS)
	var cam := MobaCamera.new()
	add_child_autofree(cam)
	await wait_physics_frames(2)
	var picker := CursorPicker.new(cam.camera)
	var top_screen := cam.camera.unproject_position(Vector3(2.0, 1.0, 0.0))
	var top := picker.pick(top_screen)
	assert_true(top.hit)
	assert_almost_eq(top.position.y, 1.0, 0.05)
	assert_same(top.collider, crate)
	var floor_screen := cam.camera.unproject_position(Vector3(-4.0, 0.0, 0.0))
	var ground := picker.pick(floor_screen)
	assert_true(ground.hit)
	assert_almost_eq(ground.position.y, 0.0, 0.05)
	assert_true(ground.is_ground)
	assert_same(ground.collider, floor)


func test_miss_falls_back_to_the_ground_plane() -> void:
	var cam := MobaCamera.new()
	add_child_autofree(cam)
	cam._process(0.0)
	var picker := CursorPicker.new(cam.camera)
	var viewport := cam.camera.get_viewport().get_visible_rect().size
	var result := picker.pick(viewport * 0.5)
	assert_true(result.hit)
	assert_null(result.collider)
	assert_true(result.is_ground)
	assert_almost_eq(result.position.y, 0.0, 0.001)


func test_outside_the_viewport_is_a_miss() -> void:
	var cam := MobaCamera.new()
	add_child_autofree(cam)
	var picker := CursorPicker.new(cam.camera)
	var result := picker.pick(Vector2(-20.0, -20.0))
	assert_false(result.hit)


func test_pick_ignores_units_and_pick_unit_reads_the_meta() -> void:
	var floor := _body("Floor", Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 20.0), GameConfig.LAYER_WORLD)
	var unit := _body("Unit", Vector3(0.0, 0.9, 0.0), Vector3(0.8, 1.8, 0.8), GameConfig.LAYER_UNITS)
	unit.set_meta(&"unit_id", 4)
	var cam := MobaCamera.new()
	add_child_autofree(cam)
	await wait_physics_frames(2)
	var picker := CursorPicker.new(cam.camera)
	var screen := cam.camera.unproject_position(Vector3(0.0, 0.9, 0.0))
	var world := picker.pick(screen)
	assert_true(world.hit)
	assert_same(world.collider, floor)
	var picked := picker.pick_unit(screen)
	assert_true(picked.hit)
	assert_eq(picked.unit_id, 4)
	assert_same(picked.collider, unit)


func _body(node_name: String, at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child_autofree(body)
	return body
