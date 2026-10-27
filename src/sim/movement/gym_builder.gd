class_name GymBuilder extends Node3D

## Builds the movement gym from code. Stations run west to east with flat floor between them.
## Navigation uses the arena bake settings (agent radius 0.4 m, see ADR-004 / ADR-005).

const FLOOR_ALBEDO := 0.42
const PROP_ALBEDO := 0.62
const WALL_ALBEDO := 0.28
const GAP := 4.0
const FLOOR_Z := 18.0

var unit: GymUnit
var driver: GymDriver
var nav_map: RID
var start_position := Vector3(2.0, 0.05, 0.0)
var bypass_start := Vector3.ZERO
var bypass_goal := Vector3.ZERO
var accept_input := true
var is_ready := false
var nav_polygons := 0

signal ready_for_play

var _region: NavigationRegion3D
var _props: Node3D


func _ready() -> void:
	_build()
	_finish_setup()


func _finish_setup() -> void:
	# Colliders have to reach the physics server before the navmesh can see them.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_bake()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Upload after the region has joined the map. Doing it in the same call as the bake does not stick.
	var baked := _region.navigation_mesh.duplicate() as NavigationMesh
	_region.navigation_mesh = baked
	nav_map = get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav_map)
	await get_tree().physics_frame
	await get_tree().physics_frame
	unit = GymUnit.new()
	unit.name = "GymUnit"
	unit.position = start_position
	add_child(unit)
	var profile := load("res://data/movement_profiles/gladiator.tres") as MovementProfile
	if profile == null:
		profile = MovementProfile.new()
	unit.setup(profile, nav_map)
	driver = GymDriver.new()
	driver.name = "GymDriver"
	add_child(driver)
	driver.setup(unit, start_position, nav_map)
	driver.enabled = accept_input
	is_ready = true
	ready_for_play.emit()


func _build() -> void:
	_environment()
	_region = NavigationRegion3D.new()
	_region.name = "Navigation"
	var mesh := NavigationMesh.new()
	# 0.45 m rounds up to a whole cell and Godot reports an error (ADR-004).
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.4
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.2
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS
	_region.navigation_mesh = mesh
	add_child(_region)
	_props = Node3D.new()
	_props.name = "Props"
	_region.add_child(_props)

	var cursor := 0.0
	cursor = _station(cursor, "1  Start", 3.0)
	cursor = _stairs(cursor)
	cursor = _ramps(cursor)
	cursor = _walls(cursor)
	cursor = _gaps(cursor)
	var jump_x := cursor
	cursor = _jumps(cursor)
	var jump_end := cursor - GAP
	cursor = _slope(cursor)
	cursor = _ceiling(cursor)
	_floors(jump_x, jump_end, cursor)
	_sign("End", Vector3(cursor - GAP, 2.2, 0.0))


func _station(cursor: float, title: String, width: float) -> float:
	_sign(title, Vector3(cursor + width * 0.5, 2.4, 0.0))
	return cursor + width + GAP


func _stairs(cursor: float) -> float:
	_sign("2  Stairs 0.2", Vector3(cursor + 1.2, 2.6, 0.0))
	for i in 5:
		var height := 0.2 * float(i + 1)
		_box(Vector3(cursor + 0.25 + float(i) * 0.5, height * 0.5, 0.0), Vector3(0.5, height, 3.0), PROP_ALBEDO, "Step")
	return cursor + 2.5 + GAP


func _ramps(cursor: float) -> float:
	_sign("3  Ramps", Vector3(cursor + 2.0, 3.2, 0.0))
	var angles: Array[float] = [15.0, 25.0, 35.0, 45.0]
	var lanes: Array[float] = [-9.0, -3.0, 3.0, 9.0]
	for i in angles.size():
		_ramp(cursor, lanes[i], angles[i], 4.0, 2.4)
		_sign("%d°" % int(angles[i]), Vector3(cursor, 0.4, lanes[i]))
	return cursor + 4.0 + GAP


func _walls(cursor: float) -> float:
	_sign("4  Walls", Vector3(cursor + 2.0, 3.4, -14.0))
	var heights: Array[float] = [0.3, 0.8, 1.2, 1.6, 2.2]
	var lanes: Array[float] = [-10.0, -5.0, 0.0, 5.0, 10.0]
	for i in heights.size():
		var height := heights[i]
		var at := Vector3(cursor + 0.15, height * 0.5, lanes[i])
		_box(at, Vector3(0.3, height, 2.2), WALL_ALBEDO, "Wall")
		_sign("%.1f m" % height, Vector3(cursor, height + 0.4, lanes[i]))
		if is_equal_approx(height, 2.2):
			bypass_start = Vector3(cursor - 3.0, 0.05, lanes[i])
			bypass_goal = Vector3(cursor + 3.5, 0.05, lanes[i])
	_box(Vector3(cursor + 2.0, 0.5, -14.0), Vector3(4.0, 1.0, 4.0), PROP_ALBEDO, "MountBlock")
	_sign("4x4 mount", Vector3(cursor + 2.0, 1.8, -14.0))
	return cursor + 4.0 + GAP


func _gaps(cursor: float) -> float:
	_sign("5  Gaps", Vector3(cursor + 2.0, 2.8, 0.0))
	_tunnel(cursor, -3.0, 1.0, "Slide 1.0")
	_tunnel(cursor, 3.0, 1.2, "Crouch 1.2")
	return cursor + 4.0 + GAP


func _tunnel(cursor: float, z: float, clearance: float, title: String) -> void:
	_box(Vector3(cursor + 2.0, clearance + 0.3, z), Vector3(4.0, 0.6, 2.6), WALL_ALBEDO, "Tunnel")
	_box(Vector3(cursor + 2.0, clearance * 0.5, z - 1.45), Vector3(4.0, clearance, 0.3), WALL_ALBEDO, "TunnelWall")
	_box(Vector3(cursor + 2.0, clearance * 0.5, z + 1.45), Vector3(4.0, clearance, 0.3), WALL_ALBEDO, "TunnelWall")
	_sign(title, Vector3(cursor + 2.0, clearance + 1.1, z))


func _jumps(cursor: float) -> float:
	_sign("6  Jump gaps", Vector3(cursor + 6.0, 2.6, 14.5))
	var widths: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
	var lanes: Array[float] = [-12.0, -6.0, 0.0, 6.0, 12.0]
	for i in widths.size():
		var gap := widths[i]
		var z := lanes[i]
		var land_start := cursor + 3.0 + gap
		var land_end := cursor + 12.0
		_box(Vector3(cursor + 1.5, -0.2, z), Vector3(3.0, 0.4, 2.4), FLOOR_ALBEDO, "JumpLip")
		_box(Vector3(cursor + 3.0 + gap * 0.5, -3.2, z), Vector3(gap, 0.4, 2.4), 0.3, "Pit")
		_box(Vector3((land_start + land_end) * 0.5, -0.2, z), Vector3(land_end - land_start, 0.4, 2.4), FLOOR_ALBEDO, "JumpLand")
		_sign("%d m" % int(gap), Vector3(cursor + 3.0 + gap * 0.5, 1.2, z))
	return cursor + 3.0 + 6.0 + 3.0 + GAP


func _slope(cursor: float) -> float:
	_sign("7  Slide 20°", Vector3(cursor + 6.0, 5.0, 0.0))
	_ramp(cursor, 0.0, 20.0, 12.0, 4.0)
	return cursor + 12.0 + GAP


func _ceiling(cursor: float) -> float:
	_sign("8  Low ceiling", Vector3(cursor + 5.0, 3.2, 0.0))
	var points := PackedVector3Array()
	var x0 := cursor
	var x1 := cursor + 10.0
	var z0 := -2.0
	var z1 := 2.0
	# Underside drops from 2.2 m to 1.0 m. The solid sits above that plane.
	var corners: Array[Vector3] = [
		Vector3(x0, 2.2, z0), Vector3(x0, 2.2, z1), Vector3(x1, 1.0, z0), Vector3(x1, 1.0, z1),
		Vector3(x0, 3.4, z0), Vector3(x0, 3.4, z1), Vector3(x1, 3.4, z0), Vector3(x1, 3.4, z1),
	]
	for corner in corners:
		points.append(corner)
	_hull("Ceiling", points, WALL_ALBEDO)
	return cursor + 10.0 + GAP


func _floors(jump_x: float, jump_end: float, end_x: float) -> void:
	_box(Vector3((-4.0 + jump_x) * 0.5, -0.2, 0.0), Vector3(jump_x + 4.0, 0.4, FLOOR_Z * 2.0), FLOOR_ALBEDO, "FloorWest")
	_box(Vector3((jump_end + end_x) * 0.5, -0.2, 0.0), Vector3(end_x - jump_end, 0.4, FLOOR_Z * 2.0), FLOOR_ALBEDO, "FloorEast")
	var span := jump_end - jump_x
	var mid := (jump_x + jump_end) * 0.5
	_box(Vector3(mid, -0.2, 16.0), Vector3(span, 0.4, 4.0), FLOOR_ALBEDO, "FloorNorth")
	_box(Vector3(mid, -0.2, -16.0), Vector3(span, 0.4, 4.0), FLOOR_ALBEDO, "FloorSouth")


func _ramp(origin_x: float, z: float, angle_deg: float, length: float, width: float) -> void:
	var angle := deg_to_rad(angle_deg)
	var body := StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK
	body.collision_mask = 0
	body.rotation.z = angle
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.25, width)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = GreyMaterials.get_material(PROP_ALBEDO)
	body.add_child(visual)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	shape_node.shape = shape
	body.add_child(shape_node)
	var lowest := INF
	var signs: Array[float] = [-1.0, 1.0]
	for sx in signs:
		for sy in signs:
			var local := Vector3(sx * length * 0.5, sy * 0.125, 0.0)
			var world_y := local.x * sin(angle) + local.y * cos(angle)
			lowest = minf(lowest, world_y)
	# Sit the downhill lip a centimetre into the floor so the seam does not catch.
	body.position = Vector3(origin_x + length * 0.5, -lowest - 0.01, z)
	_props.add_child(body)


func _box(center: Vector3, size: Vector3, albedo: float, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK
	body.collision_mask = 0
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = GreyMaterials.get_material(albedo)
	body.add_child(visual)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	_props.add_child(body)


func _hull(node_name: String, points: PackedVector3Array, albedo: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _convex_mesh(points)
	mesh_instance.material_override = GreyMaterials.get_material(albedo)
	body.add_child(mesh_instance)
	_props.add_child(body)


func _convex_mesh(points: PackedVector3Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A box-like hull: bottom quad, top quad, and four sides. Points are ordered
	# bottom-near, bottom-far, top-near, top-far as two pairs of four.
	var index := PackedInt32Array([
		0, 2, 1, 1, 2, 3,
		4, 5, 6, 6, 5, 7,
		0, 1, 4, 4, 1, 5,
		2, 6, 3, 3, 6, 7,
		0, 4, 2, 2, 4, 6,
		1, 3, 5, 5, 3, 7,
	])
	for i in range(0, index.size(), 3):
		var a := points[index[i]]
		var b := points[index[i + 1]]
		var c := points[index[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		tool.set_normal(normal)
		tool.add_vertex(a)
		tool.set_normal(normal)
		tool.add_vertex(b)
		tool.set_normal(normal)
		tool.add_vertex(c)
	return tool.commit()


func _sign(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.modulate = Color(0.9, 0.9, 0.9)
	label.outline_modulate = Color(0.12, 0.12, 0.12)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.pixel_size = 0.004
	_props.add_child(label)


func _environment() -> void:
	var env := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color(0.78, 0.78, 0.8)
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = world
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)


func _bake() -> void:
	var mesh := _region.navigation_mesh
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, _region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	nav_polygons = mesh.get_polygon_count()
