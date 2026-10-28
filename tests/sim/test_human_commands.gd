extends GutTest

func test_commands_drive_the_human_and_wait_for_the_whistle() -> void:
	var layout := load("res://data/arena_layouts/octagon_ring_v1.tres") as ArenaLayout
	var arena := ArenaBuilder.build(layout)
	add_child_autofree(arena)
	await arena.navigation_ready
	var config := MatchConfig.new()
	config.countdown_seconds = 0.4
	config.human_team = Team.Id.A
	config.human_slot = 0
	config.bot_difficulty = BotController.Difficulty.OFF
	var simulation := Simulation.new()
	add_child(simulation)
	simulation.start_match(config, arena)
	var gates := GateController.new()
	add_child(gates)
	gates.bind(arena, 0.2)
	var human := simulation.get_human()
	var origin := human.global_position
	_send(simulation, human.unit_id, Command.Kind.MOVE_TO, Vector3(0, 0, 0), true)
	for _i in 10:
		await get_tree().physics_frame
	assert_lt(human.global_position.distance_to(origin), 0.5, "movement is ignored before RUNNING")
	var guard := 0
	while simulation.get_match_state() != Match.State.RUNNING and guard < 90:
		await get_tree().physics_frame
		guard += 1
	assert_eq(simulation.get_match_state(), Match.State.RUNNING)
	_send(simulation, human.unit_id, Command.Kind.JUMP, human.global_position, true)
	var jumped := false
	for _i in 8:
		await get_tree().physics_frame
		if human.motor.state == MovementMotor.State.AIRBORNE:
			jumped = true
	assert_true(jumped, "JUMP should leave the ground")
	for _i in 40:
		await get_tree().physics_frame
		if human.is_on_floor():
			break
	human.velocity = Vector3(6.0, 0.0, 0.0)
	_send(simulation, human.unit_id, Command.Kind.CROUCH_SLIDE, human.global_position, true)
	var slid := false
	for _i in 6:
		await get_tree().physics_frame
		if human.motor.state == MovementMotor.State.SLIDING:
			slid = true
	assert_true(slid, "CROUCH_SLIDE at speed should slide")
	_send(simulation, human.unit_id, Command.Kind.MOVE_TO, Vector3(0, 0, 0), true)
	var arrived := false
	for _i in 900:
		await get_tree().physics_frame
		if human.global_position.distance_to(Vector3(0, 0.5, 0)) < 2.0 or not human.motor.has_goal() and human.global_position.length() < 4.0:
			arrived = human.global_position.length() < 6.0
			if arrived:
				break
	assert_true(arrived, "MOVE_TO should reach the middle, at %s" % human.global_position)
	var before := human.global_position
	_send(simulation, human.unit_id, Command.Kind.STOP, before, true)
	for _i in 20:
		await get_tree().physics_frame
	assert_lt(human.global_position.distance_to(before), 1.2, "STOP should halt the unit")
	assert_false(human.motor.has_goal())


func _send(simulation: Simulation, unit_id: int, kind: Command.Kind, point: Vector3, pressed: bool) -> void:
	var cmd := Command.new()
	cmd.unit_id = unit_id
	cmd.kind = kind
	cmd.point = point
	cmd.pressed = pressed
	simulation.submit_command(cmd)
