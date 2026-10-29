class_name TeamTower extends StaticBody3D

## A lane tower. It shoots the nearest enemy in range and can be broken.

var team := 0
var health := 500.0
var max_health := 500.0
var attack_range := 16.0
var attack_damage := 14.0
var attack_interval := 1.15
var _wait := 0.6


func build(team_id: int, at: Vector3) -> void:
	team = team_id
	name = "Tower%s" % ("A" if team_id == Team.Id.A else "B")
	position = at
	collision_layer = GameConfig.LAYER_PROPS
	collision_mask = 0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.8
	mesh.bottom_radius = 1.05
	mesh.height = 4.2
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position = Vector3(0, 2.1, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.55, 0.55)
	body.material_override = material
	add_child(body)
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.05
	shape.height = 4.2
	shape_node.shape = shape
	shape_node.position = Vector3(0, 2.1, 0)
	add_child(shape_node)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.35
	disc.bottom_radius = 1.35
	disc.height = 0.08
	ring.mesh = disc
	ring.position = Vector3(0, 0.06, 0)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(0.25, 0.45, 0.95) if team_id == Team.Id.A else Color(0.85, 0.2, 0.2)
	ring.material_override = paint
	add_child(ring)


func step(dt: float, sim: Simulation) -> void:
	if health <= 0.0:
		return
	_wait -= dt
	if _wait > 0.0:
		return
	var target := _nearest(sim)
	if target == null:
		return
	_wait = attack_interval
	var aim := target.global_position - global_position
	var tint := Color(0.35, 0.55, 1.0) if team == Team.Id.A else Color(1.0, 0.28, 0.22)
	sim.launch_projectile_from(global_position + Vector3(0, 3.2, 0), team, -1, aim, 16.0, attack_damage, tint)


func hurt(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	set_meta("health", health)
	if health <= 0.0:
		visible = false
		collision_layer = 0


func _nearest(sim: Simulation) -> SimUnit:
	var best: SimUnit = null
	var best_distance := attack_range
	for unit in sim.get_units():
		if not unit.state.alive or unit.team == team:
			continue
		var flat := unit.global_position - global_position
		flat.y = 0.0
		var distance := flat.length()
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best
