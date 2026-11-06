extends GutTest

## A move order on top of a box walks off the edge. It does not stick to the navmesh below.


func test_right_click_walks_off_a_box() -> void:
	var world := Node3D.new()
	add_child(world)
	var harness := MovementHarness.new()
	add_child_autofree(harness)
	harness.build_boxes(world, [
		{"center": Vector3(0, -0.2, 0), "size": Vector3(30, 0.4, 12)},
		{"center": Vector3(0, 0.8, 0), "size": Vector3(2.4, 1.6, 2.4)},
	])
	var unit := harness.spawn_unit(world, Vector3(0, 1.65, 0))
	var go := MovementIntent.new()
	go.has_move_target = true
	go.move_target = Vector3(6, 0, 0)
	harness.run(unit, [[0, go]], 90)
	await harness.wait_done()
	var left := false
	for sample in harness.trace:
		var position: Vector3 = sample["position"]
		if position.y < 1.0 and position.x > 1.2:
			left = true
	assert_true(left, "should have walked off the box toward the click, last %s" % unit.global_position)
	world.free()
