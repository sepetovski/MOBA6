extends GutTest

## M3-T10 movement checks. The harness is the production tick; these assert the brief.

const APEX_TOLERANCE := 0.065


func test_double_jump_is_once() -> void:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(8, 0.4, 8)}])
	var unit := harness.spawn_unit(world, Vector3(0, 0.05, 0))
	var first := MovementIntent.new()
	first.jump_pressed = true
	first.jump_held = true
	var second := MovementIntent.new()
	second.jump_pressed = true
	second.jump_held = true
	var third := MovementIntent.new()
	third.jump_pressed = true
	third.jump_held = true
	harness.run(unit, [[0, first], [18, second], [28, third]], 90)
	await harness.wait_done()
	assert_between(harness.max_height(), 1.9, 3.2, "one extra jump should lift past the single apex")
	world.free()


func test_wall_jump_kicks_away() -> void:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [
		{"center": Vector3(0, -0.2, 0), "size": Vector3(12, 0.4, 8)},
		{"center": Vector3(1.3, 1.6, 0), "size": Vector3(0.4, 3.2, 4)},
	])
	var unit := harness.spawn_unit(world, Vector3(0.2, 0.05, 0))
	harness.hook = func(frame: int, body: GymUnit, _intent: MovementIntent) -> void:
		if frame < 8:
			body.velocity.x = 6.0
	var hop := MovementIntent.new()
	hop.jump_pressed = true
	hop.jump_held = true
	var kick := MovementIntent.new()
	kick.jump_pressed = true
	kick.jump_held = true
	harness.run(unit, [[0, hop], [8, kick]], 24)
	await harness.wait_done()
	var kicked := false
	for sample in harness.trace:
		var velocity: Vector3 = sample["velocity"]
		if int(sample["frame"]) > 8 and velocity.x < -1.0:
			kicked = true
	assert_true(kicked, "jumping against the wall should kick back to the left")
	world.free()


func test_full_hold_jump_apex() -> void:
	var height := await _jump_apex(true)
	assert_almost_eq(height, 1.3, APEX_TOLERANCE, "full hold apex")


func test_tap_jump_apex() -> void:
	var height := await _jump_apex(false)
	assert_almost_eq(height, 0.6, APEX_TOLERANCE, "tap apex")


func test_slide_flat_distance() -> void:
	var distance := await _slide_on(0.0, 1.0)
	assert_between(distance, 3.5, 5.0, "flat slide distance %.3f" % distance)


func test_slide_slope_changes_distance() -> void:
	var flat := await _slide_on(0.0, 1.0)
	# On this rotated box, +X runs downhill and −X runs uphill.
	var down := await _slide_on(20.0, 1.0)
	var up := await _slide_on(20.0, -1.0)
	assert_gt(down, flat, "downhill %.3f should beat flat %.3f" % [down, flat])
	assert_lt(up, flat, "uphill %.3f should lose to flat %.3f" % [up, flat])


func test_crouch_passes_1_2_and_blocks_on_1_0() -> void:
	var through := await _gap(1.2, false)
	var blocked := await _gap(1.0, false)
	assert_true(through, "crouch should pass a 1.2 m gap")
	assert_false(blocked, "crouch should stop at a 1.0 m gap")


func test_slide_passes_1_0_gap() -> void:
	assert_true(await _gap(1.0, true), "slide should pass a 1.0 m gap")


func test_vault_keeps_speed_and_block_is_mounted() -> void:
	var vault := await _traverse(1.0, 0.3, 6.0)
	assert_true(vault["vaulted"], "thin 1.0 m wall should vault")
	assert_gte(vault["exit_ratio"], 0.9, "vault should keep entry speed")
	var mount := await _traverse(1.0, 4.0, 6.0)
	assert_false(mount["vaulted"], "4 m block is not a vault")
	assert_true(mount["mounted"], "4 m block should be mounted")


func test_mantle_and_wall() -> void:
	var mantle := await _traverse(1.5, 0.3, 4.0)
	assert_true(mantle["mantled"], "1.5 m wall should mantle")
	assert_gt(float(mantle["top_y"]), 1.3, "mantle ends on top")
	var wall := await _traverse(2.2, 0.3, 6.0)
	assert_false(wall["vaulted"], "2.2 m wall is not a vault")
	assert_false(wall["mantled"], "2.2 m wall is not a mantle")
	assert_lt(float(wall["max_x"]), float(wall["face"]) - 0.2, "2.2 m wall blocks")


func test_no_stand_under_low_ceiling() -> void:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [
		{"center": Vector3(0, -0.2, 0), "size": Vector3(12, 0.4, 6)},
		{"center": Vector3(3.5, 1.7, 0), "size": Vector3(4, 1.0, 4)},
	])
	var unit := harness.spawn_unit(world, Vector3(0, 0.05, 0))
	unit.rotation.y = PI * 0.5
	var intent := MovementIntent.new()
	intent.steering = true
	intent.steer_point = Vector3(8, 0, 0)
	intent.crouch_slide_held = true
	var let_go := [false]
	harness.hook = func(_frame: int, body: GymUnit, step_intent: MovementIntent) -> void:
		if body.global_position.x > 2.6:
			let_go[0] = true
		if not let_go[0]:
			step_intent.crouch_slide_held = true
			step_intent.steering = true
			step_intent.steer_point = Vector3(8, 0, 0)
	harness.run(unit, [[0, intent]], 120)
	await harness.wait_done()
	var stood := false
	for sample in harness.trace:
		var position: Vector3 = sample["position"]
		if position.x > 2.0 and position.x < 5.0 and int(sample["state"]) == MovementMotor.State.GROUNDED:
			stood = true
	assert_false(stood, "standing under the low ceiling is refused")
	world.free()


func test_no_tunnel_at_max_speed() -> void:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [
		{"center": Vector3(0, -0.2, 0), "size": Vector3(20, 0.4, 6)},
		{"center": Vector3(4.0, 1.0, 0), "size": Vector3(0.3, 2.0, 4)},
	])
	var unit := harness.spawn_unit(world, Vector3(0, 0.05, 0))
	harness.use_prime = true
	harness.prime = Vector3(12, 0, 0)
	var intent := MovementIntent.new()
	intent.crouch_slide_pressed = true
	intent.crouch_slide_held = true
	harness.run(unit, [[0, intent]], 40)
	await harness.wait_done()
	var wall := AABB(Vector3(3.85, 0.0, -2.0), Vector3(0.3, 2.0, 4.0))
	assert_false(harness.passed_through(wall), "max speed must not tunnel a 0.3 m wall")
	world.free()


func test_coyote_and_jump_buffer() -> void:
	var coyote := await _leave_and_jump(3)
	var late := await _leave_and_jump(12)
	assert_gt(coyote, 0.8, "coyote jump should still reach a full hop")
	assert_lt(late, 0.3, "a late jump is not a coyote jump")
	var buffered := await _buffer_jump(true)
	var early := await _buffer_jump(false)
	assert_gt(buffered, 0.8, "jump buffer should fire on landing")
	assert_lt(early, 0.3, "a press outside the buffer should not jump")


func test_path_around_gym_wall() -> void:
	var gym := (load("res://scenes/gyms/movement_gym.tscn") as PackedScene).instantiate() as GymBuilder
	add_child_autofree(gym)
	if not gym.is_ready:
		await gym.ready_for_play
	gym.driver.enabled = false
	var unit: GymUnit = gym.unit
	unit.global_position = gym.bypass_start
	unit.motor.reset_motion()
	unit.motor.set_nav_map(gym.nav_map)
	var harness := _harness()
	var intent := MovementIntent.new()
	intent.has_move_target = true
	intent.move_target = gym.bypass_goal
	var stuck := [0]
	unit.motor.stuck.connect(func() -> void: stuck[0] += 1)
	harness.run(unit, [[0, intent]], 360)
	await harness.wait_done()
	var end: Vector3 = harness.trace[harness.trace.size() - 1]["position"]
	var flat := Vector2(end.x - gym.bypass_goal.x, end.z - gym.bypass_goal.z).length()
	assert_lt(flat, 0.3, "path should arrive, ended %.2f m away" % flat)
	assert_eq(stuck[0], 0, "stuck should not fire on a clear path")


func test_measure_clearable_gaps() -> void:
	var jump_gap := await _largest_gap(false)
	var slide_gap := await _largest_gap(true)
	print("largest jump gap %.2f m, slide-jump gap %.2f m" % [jump_gap, slide_gap])
	assert_gt(jump_gap, 2.0, "a run jump should clear more than 2 m")
	assert_gte(slide_gap, jump_gap, "a slide-jump should clear at least as far as a run jump")


func _jump_apex(held: bool) -> float:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(8, 0.4, 8)}])
	var unit := harness.spawn_unit(world, Vector3(0, 0.05, 0))
	var intent := MovementIntent.new()
	intent.jump_pressed = true
	intent.jump_held = held
	harness.run(unit, [[0, intent]], 90)
	await harness.wait_done()
	var height := harness.max_height()
	world.free()
	return height


func _slide_on(angle_deg: float, direction: float) -> float:
	var world := _world()
	var harness := _harness()
	if is_zero_approx(angle_deg):
		harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(30, 0.4, 8)}])
		var flat := harness.spawn_unit(world, Vector3(-8, 0.05, 0))
		harness.use_prime = true
		harness.prime = Vector3(6.0 * direction, 0, 0)
		var intent := MovementIntent.new()
		intent.crouch_slide_pressed = true
		intent.crouch_slide_held = true
		harness.run(flat, [[0, intent]], 120)
		await harness.wait_done()
		var distance := harness.slide_distance()
		world.free()
		return distance
	var angle := deg_to_rad(angle_deg)
	var length := 20.0
	harness.build_boxes(world, [{
		"center": Vector3(0, 0, 0),
		"size": Vector3(length, 0.3, 6),
		"rotation_degrees": Vector3(0, 0, angle_deg),
	}])
	var surface_y := 0.15 * cos(angle)
	var unit := harness.spawn_unit(world, Vector3(0, surface_y + 0.15, 0))
	harness.use_prime = true
	harness.prime = Vector3(6.0 * direction, 0, 0)
	var slide := MovementIntent.new()
	slide.crouch_slide_pressed = true
	slide.crouch_slide_held = true
	harness.run(unit, [[0, slide]], 150)
	await harness.wait_done()
	var travelled := harness.slide_distance()
	world.free()
	return travelled


func _gap(clearance: float, slide: bool) -> bool:
	var world := _world()
	var harness := _harness()
	var length := 2.5
	harness.build_boxes(world, [
		{"center": Vector3(0, -0.2, 0), "size": Vector3(16, 0.4, 6)},
		{"center": Vector3(2.0, clearance + 0.4, 0), "size": Vector3(length, 0.8, 4)},
	])
	var unit := harness.spawn_unit(world, Vector3(-1.0, 0.05, 0))
	unit.rotation.y = PI * 0.5
	var intent := MovementIntent.new()
	intent.steering = true
	intent.steer_point = Vector3(10, 0, 0)
	intent.crouch_slide_held = true
	if slide:
		harness.use_prime = true
		harness.prime = Vector3(6, 0, 0)
		intent.crouch_slide_pressed = true
	harness.run(unit, [[0, intent]], 150)
	await harness.wait_done()
	var passed := false
	for sample in harness.trace:
		var position: Vector3 = sample["position"]
		if position.x > 2.0 + length * 0.5 + 0.5:
			passed = true
	world.free()
	return passed


func _traverse(height: float, depth: float, speed: float) -> Dictionary:
	var world := _world()
	var harness := _harness()
	var face := 3.0
	harness.build_boxes(world, [
		{"center": Vector3(0, -0.2, 0), "size": Vector3(24, 0.4, 8)},
		{"center": Vector3(face + depth * 0.5, height * 0.5, 0), "size": Vector3(depth, height, 4)},
	])
	var unit := harness.spawn_unit(world, Vector3(face - 0.8, 0.05, 0))
	unit.rotation.y = PI * 0.5
	harness.use_prime = true
	harness.prime = Vector3(speed, 0, 0)
	var intent := MovementIntent.new()
	intent.jump_pressed = true
	intent.jump_held = true
	harness.run(unit, [[0, intent]], 80)
	await harness.wait_done()
	var entry := speed
	var exit := 0.0
	var vaulted := false
	var mantled := false
	var top_y := 0.0
	var max_x := -INF
	var was_vault := false
	var was_mantle := false
	for sample in harness.trace:
		var state := int(sample["state"])
		var position: Vector3 = sample["position"]
		var velocity: Vector3 = sample["velocity"]
		max_x = maxf(max_x, position.x)
		if state == MovementMotor.State.VAULTING:
			was_vault = true
		elif was_vault and not vaulted:
			vaulted = true
			exit = Vector2(velocity.x, velocity.z).length()
		if state == MovementMotor.State.MANTLING:
			was_mantle = true
		elif was_mantle and not mantled:
			mantled = true
			top_y = position.y
		if was_mantle:
			top_y = maxf(top_y, position.y)
	var mounted := was_mantle and top_y > height - 0.25 and max_x < face + depth + 0.3
	var result := {
		"vaulted": was_vault and max_x > face + depth + 0.3,
		"exit_ratio": exit / entry if entry > 0.0 else 0.0,
		"mounted": mounted,
		"mantled": was_mantle and top_y > height - 0.3,
		"top_y": top_y,
		"max_x": max_x,
		"face": face,
	}
	world.free()
	return result


func _leave_and_jump(delay: int) -> float:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(4, 0.4, 6)}])
	var unit := harness.spawn_unit(world, Vector3(0, 0.05, 0))
	var left := [-1]
	harness.hook = func(frame: int, body: GymUnit, intent: MovementIntent) -> void:
		if left[0] < 0 and frame > 0 and not body.is_on_floor():
			left[0] = frame
		if left[0] >= 0 and frame == left[0] + delay:
			intent.jump_pressed = true
			intent.jump_held = true
	var steer := MovementIntent.new()
	steer.steering = true
	steer.steer_point = Vector3(12, 0, 0)
	harness.use_prime = true
	harness.prime = Vector3(6, 0, 0)
	harness.run(unit, [[0, steer]], 100)
	await harness.wait_done()
	var height := harness.max_height()
	world.free()
	return height


func _buffer_jump(in_window: bool) -> float:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(8, 0.4, 8)}])
	var unit := harness.spawn_unit(world, Vector3(0, 2.2, 0))
	var fired := [false]
	harness.hook = func(_frame: int, body: GymUnit, intent: MovementIntent) -> void:
		if fired[0]:
			return
		var close := body.global_position.y < (0.2 if in_window else 1.6)
		if close and body.velocity.y < 0.0:
			intent.jump_pressed = true
			intent.jump_held = true
			fired[0] = true
	harness.run(unit, [], 100)
	await harness.wait_done()
	var landed := false
	var peak := 0.0
	for sample in harness.trace:
		var position: Vector3 = sample["position"]
		if position.y < 0.15:
			landed = true
		if landed:
			peak = maxf(peak, position.y)
	world.free()
	return peak


func _largest_gap(slide_jump: bool) -> float:
	var best := 0.0
	var width := 1.5
	while width <= 8.0:
		var cleared := await _clears_gap(width, slide_jump)
		if not cleared:
			break
		best = width
		width += 0.25
	return best


func _clears_gap(width: float, slide_jump: bool) -> bool:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [
		{"center": Vector3(-2, -0.2, 0), "size": Vector3(4, 0.4, 4)},
		{"center": Vector3(width * 0.5, -3.2, 0), "size": Vector3(width, 0.4, 4)},
		{"center": Vector3(width + 2.0, -0.2, 0), "size": Vector3(4, 0.4, 4)},
	])
	var unit := harness.spawn_unit(world, Vector3(-0.4, 0.05, 0))
	unit.rotation.y = PI * 0.5
	var intent := MovementIntent.new()
	intent.steering = true
	intent.steer_point = Vector3(width + 6.0, 0, 0)
	intent.jump_held = true
	if slide_jump:
		harness.use_prime = true
		harness.prime = Vector3(6, 0, 0)
		intent.crouch_slide_pressed = true
		intent.crouch_slide_held = true
		var jump := intent.clone()
		jump.crouch_slide_pressed = false
		jump.jump_pressed = true
		jump.jump_held = true
		harness.run(unit, [[0, intent], [2, jump]], 140)
	else:
		harness.use_prime = true
		harness.prime = Vector3(6, 0, 0)
		intent.jump_pressed = true
		harness.run(unit, [[0, intent]], 140)
	await harness.wait_done()
	var cleared := false
	for sample in harness.trace:
		var position: Vector3 = sample["position"]
		if position.x > width + 0.4 and position.y > -0.3 and bool(sample["grounded"]):
			cleared = true
	world.free()
	return cleared


func _steer_only(point: Vector3) -> MovementIntent:
	var intent := MovementIntent.new()
	intent.steering = true
	intent.steer_point = point
	return intent


func _world() -> Node3D:
	var world := Node3D.new()
	add_child(world)
	return world


func _harness() -> MovementHarness:
	var harness := MovementHarness.new()
	add_child_autofree(harness)
	return harness
