extends GutTest

## 120 simulated seconds of bots. Headless, so this is the long test.

func test_bots_survive_two_minutes() -> void:
	var packed := load("res://tests/scenes/soak_bot_match.tscn") as PackedScene
	var scene := packed.instantiate()
	add_child_autofree(scene)
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 8
	var simulation: Simulation = null
	var started := Time.get_ticks_msec()
	while simulation == null and Time.get_ticks_msec() - started < 20000:
		await get_tree().process_frame
		simulation = scene.get_node_or_null("Simulation") as Simulation
	assert_not_null(simulation, "simulation should exist after the navmesh bakes")
	var travelled := {}
	var last_pos := {}
	var stuck_from := {}
	GameEvents.unit_stuck.connect(func(id: int) -> void:
		if not stuck_from.has(id):
			stuck_from[id] = {"tick": simulation.tick, "at": simulation.get_unit(id).global_position}
	)
	for unit in simulation.get_units():
		travelled[unit.unit_id] = 0.0
		last_pos[unit.unit_id] = unit.global_position
	var frames := 0
	var tick_at_start := simulation.tick
	while simulation.tick < 7200 and Time.get_ticks_msec() - started < 180000:
		await get_tree().physics_frame
		frames += 1
		if simulation.tick % 30 != 0:
			continue
		for unit in simulation.get_units():
			var previous: Vector3 = last_pos[unit.unit_id]
			var moved := Vector2(unit.global_position.x - previous.x, unit.global_position.z - previous.z).length()
			travelled[unit.unit_id] = float(travelled[unit.unit_id]) + moved
			last_pos[unit.unit_id] = unit.global_position
			assert_true(_inside(scene, unit.global_position), "unit %d left the arena at %s" % [unit.unit_id, unit.global_position])
			if stuck_from.has(unit.unit_id):
				var info: Dictionary = stuck_from[unit.unit_id]
				var origin: Vector3 = info["at"]
				var escaped := Vector2(unit.global_position.x - origin.x, unit.global_position.z - origin.z).length()
				if escaped > 1.0:
					stuck_from.erase(unit.unit_id)
	Engine.time_scale = 1.0
	assert_gte(simulation.tick, 7200, "ran out of time at tick %d" % simulation.tick)
	# The nav bake and the first await can land one tick off the counter. A gap bigger than that is a skipped tick.
	assert_lte(absi((simulation.tick - tick_at_start) - frames), 1, "a tick was skipped")
	var far := 0
	for id in travelled.keys():
		if float(travelled[id]) > 20.0:
			far += 1
	assert_gte(far, 10, "only %d units travelled 20 m" % far)
	var trapped := 0
	for id in stuck_from.keys():
		var info: Dictionary = stuck_from[id]
		if simulation.tick - int(info["tick"]) > 180:
			trapped += 1
	assert_lte(trapped, 2, "%d units stayed stuck" % trapped)
	var listed := simulation.get_units()
	for i in listed.size():
		for j in range(i + 1, listed.size()):
			if not listed[i].state.alive or not listed[j].state.alive:
				continue
			var delta := listed[j].global_position - listed[i].global_position
			delta.y = 0.0
			assert_gte(delta.length(), 0.4, "units %d and %d overlap" % [listed[i].unit_id, listed[j].unit_id])
	var samples := simulation.take_tick_times()
	if samples.size() > 0:
		var total := 0
		var worst := 0
		for sample in samples:
			total += sample
			worst = maxi(worst, sample)
		var average_ms := float(total) / float(samples.size()) / 1000.0
		gut.p("tick avg %.2f ms worst %.2f ms" % [average_ms, float(worst) / 1000.0])
		assert_lte(average_ms, 3.0, "average tick")
		assert_lte(float(worst) / 1000.0, 6.0, "worst tick")


func _inside(scene: Node, point: Vector3) -> bool:
	if point.y < -1.0 or point.y > 10.0:
		return false
	if absf(point.z) <= 4.2 and absf(point.x) >= 40.0 and absf(point.x) <= 49.2:
		return true
	var info := scene.get_node("Arena/ArenaInfo") as ArenaInfo
	return info.contains_xz(Vector2(point.x, point.z))
