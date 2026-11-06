extends GutTest

## A ranged shot stops on a cover volume and keeps going when it misses.


func test_shot_stops_on_cover() -> void:
	var cover := _cover(Vector3(0.0, 1.1, 0.0), Vector3(2.0, 2.0, 1.0))
	var sim := Simulation.new()
	add_child_autofree(cover)
	add_child_autofree(sim)
	await get_tree().physics_frame
	sim.launch_projectile_from(Vector3(0.0, 1.1, 4.0), 0, 1, Vector3(0.0, 0.0, -1.0), 26.0, 7.0)
	sim._step_projectiles(0.2)
	assert_eq(sim._shots.size(), 0)


func test_shot_misses_cover_and_keeps_flying() -> void:
	var cover := _cover(Vector3(0.0, 1.1, 0.0), Vector3(2.0, 2.0, 1.0))
	var sim := Simulation.new()
	add_child_autofree(cover)
	add_child_autofree(sim)
	await get_tree().physics_frame
	sim.launch_projectile_from(Vector3(4.0, 1.1, 4.0), 0, 1, Vector3(0.0, 0.0, -1.0), 26.0, 7.0)
	sim._step_projectiles(0.05)
	assert_eq(sim._shots.size(), 1)


func _cover(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_OCCLUDERS
	body.collision_mask = 0
	body.set_meta("shot_cover", true)
	body.position = at
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	return body
