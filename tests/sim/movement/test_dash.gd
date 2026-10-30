extends GutTest

## Shift spends one of two charges. One missing charge refills slowly.
## Both missing refill faster. Crouch during the burst slides without losing that speed.


func test_two_dashes_refill_faster_than_one() -> void:
	var one := await _recover_after(1)
	var two := await _recover_after(2)
	assert_between(one, 26, 40, "one dash back in %d frames" % one)
	assert_lt(two, one, "two dashes came back at frame %d, one at %d" % [two, one])


func test_dash_then_crouch_keeps_speed() -> void:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(40, 0.4, 8)}])
	var profile := _profile()
	profile.dash_speed = 10.0
	profile.dash_duration = 0.3
	profile.dash_slide_seconds = 1.0
	profile.max_speed_cap = 16.0
	var unit := harness.spawn_unit(world, Vector3(-6, 0.05, 0), RID(), profile)
	unit.rotation.y = -PI * 0.5
	var dash := MovementIntent.new()
	dash.dash_pressed = true
	var slide := MovementIntent.new()
	slide.crouch_slide_pressed = true
	slide.crouch_slide_held = true
	harness.run(unit, [[0, dash], [4, slide]], 36)
	await harness.wait_done()
	var saw_slide := false
	for sample in harness.trace:
		var frame := int(sample["frame"])
		if frame < 8 or frame > 24:
			continue
		var velocity: Vector3 = sample["velocity"]
		var speed := Vector2(velocity.x, velocity.z).length()
		assert_gte(speed, 9.0, "coast speed %.2f at frame %d" % [speed, frame])
		assert_eq(int(sample["state"]), int(MovementMotor.State.SLIDING), "frame %d" % frame)
		saw_slide = true
	assert_true(saw_slide, "the dash should have become a slide")
	world.free()


func test_shift_emits_dash() -> void:
	var controller := PlayerController.new()
	add_child_autofree(controller)
	var got: Array[Command] = []
	controller.bind(3, null, func(cmd: Command) -> void: got.append(cmd))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.pressed = true
	controller._unhandled_input(event)
	assert_eq(got.size(), 1)
	assert_eq(got[0].kind, Command.Kind.DASH)
	assert_true(got[0].pressed)


func _recover_after(presses: int) -> int:
	var world := _world()
	var harness := _harness()
	harness.build_boxes(world, [{"center": Vector3(0, -0.2, 0), "size": Vector3(12, 0.4, 8)}])
	var unit := harness.spawn_unit(world, Vector3(0, 0.05, 0), RID(), _profile())
	var script: Array = []
	for press in presses:
		var intent := MovementIntent.new()
		intent.dash_pressed = true
		script.append([press, intent])
	# A lambda assigning outer locals does not write back, so the mark lives in a Dictionary.
	var mark := {"recovered": -1, "spent": false, "low": 2}
	harness.hook = func(frame: int, body: GymUnit, _intent: MovementIntent) -> void:
		var charges := body.motor.dash_charges
		mark["low"] = mini(int(mark["low"]), charges)
		if charges < 2:
			mark["spent"] = true
		elif bool(mark["spent"]) and int(mark["recovered"]) < 0:
			mark["recovered"] = frame
	harness.run(unit, script, 90)
	await harness.wait_done()
	world.free()
	if int(mark["recovered"]) < 0:
		push_error("dash never refilled, lowest charges %s" % str(mark["low"]))
	return int(mark["recovered"])


func _profile() -> MovementProfile:
	var profile := MovementProfile.new()
	profile.dash_recharge = 0.5
	profile.dash_recharge_fast = 0.2
	profile.dash_charges = 2
	profile.max_speed_cap = 16.0
	return profile


func _world() -> Node3D:
	var world := Node3D.new()
	add_child(world)
	return world


func _harness() -> MovementHarness:
	var harness := MovementHarness.new()
	add_child_autofree(harness)
	return harness
