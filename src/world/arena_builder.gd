class_name ArenaBuilder extends RefCounted

## Builds the Octagon Ring from an ArenaLayout. Nothing is placed by hand.
## Floor, walls, gates and props live under Navigation so the default bake sees them.
## Gate doors are siblings of Navigation: the mesh is baked with the gates open.

const FLOOR_ALBEDO := 0.42
const WALL_ALBEDO := 0.28
const STAND_ALBEDO := 0.36

static func build(layout: ArenaLayout) -> Node3D:
	var root := Node3D.new()
	root.name = "Arena"
	root.set_script(load("res://src/world/arena_root.gd"))

	var info := ArenaInfo.new()
	info.name = "ArenaInfo"
	info.setup(layout)
	root.add_child(info)

	var region := _navigation_region()
	root.add_child(region)
	region.add_child(_floor(layout))
	root.add_child(_vista_ground())
	root.add_child(_grass_skin(layout))
	region.add_child(_walls(layout))
	region.add_child(_gates(layout))
	region.add_child(_props(layout))

	root.add_child(_stands(layout))
	var crowd := CrowdRenderer.new()
	crowd.build(layout)
	root.add_child(crowd)
	root.add_child(_spawns(layout))
	root.add_child(_doors(layout))
	root.add_child(_environment())
	root.add_child(_sun())
	return root

static func _grass_skin(layout: ArenaLayout) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := ArenaMath.vertices(layout.apothem)
	for index in verts.size():
		var a := verts[index]
		var b := verts[(index + 1) % verts.size()]
		_tri(tool, Vector3(0, 0.03, 0), Vector3(a.x, 0.03, a.y), Vector3(b.x, 0.03, b.y), Vector3.UP)
	var node := MeshInstance3D.new()
	node.name = "GrassSkin"
	node.mesh = tool.commit()
	node.material_override = GreyMaterials.meadow_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _vista_ground() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	plane.size = Vector2(240.0, 240.0)
	var node := MeshInstance3D.new()
	node.name = "VistaGround"
	node.mesh = plane
	node.position = Vector3(0.0, -0.05, 0.0)
	node.material_override = GreyMaterials.meadow_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _navigation_region() -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	var mesh := NavigationMesh.new()
	# 0.4 m is 2 cells. Godot ceils 0.45 m up to the next cell and reports an error (ADR-004).
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.4
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.2
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS
	region.navigation_mesh = mesh
	return region

static func _floor(layout: ArenaLayout) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK
	body.collision_mask = 0
	var verts := ArenaMath.vertices(layout.apothem)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape_points := PackedVector3Array()
	for index in verts.size():
		var a := verts[index]
		var b := verts[(index + 1) % verts.size()]
		_tri(tool, Vector3.ZERO, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3.UP)
		shape_points.append(Vector3(a.x, 0.0, a.y))
		shape_points.append(Vector3(a.x, -0.4, a.y))
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "MeadowFloor"
	var floor_mesh := tool.commit()
	floor_mesh.surface_set_material(0, GreyMaterials.meadow_material())
	mesh_node.mesh = floor_mesh
	mesh_node.material_override = GreyMaterials.meadow_material()
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = shape_points
	shape_node.shape = shape
	body.add_child(shape_node)
	return body

static func _walls(layout: ArenaLayout) -> Node3D:
	var walls := Node3D.new()
	walls.name = "Walls"
	var verts := ArenaMath.vertices(layout.apothem)
	var scale := (layout.apothem + layout.wall_thickness) / layout.apothem
	var half_gate := layout.gate_width * 0.5
	for index in verts.size():
		var inner_a: Vector2 = verts[index]
		var inner_b: Vector2 = verts[(index + 1) % verts.size()]
		var outer_a := inner_a * scale
		var outer_b := inner_b * scale
		var kind := _edge_kind(inner_a, inner_b, layout.apothem)
		if kind == "east" or kind == "west":
			var sign := 1.0 if kind == "east" else -1.0
			var low_z := minf(inner_a.y, inner_b.y)
			var high_z := maxf(inner_a.y, inner_b.y)
			_wall_span(walls, layout, inner_a, inner_b, outer_a, outer_b, low_z, -half_gate)
			_wall_span(walls, layout, inner_a, inner_b, outer_a, outer_b, half_gate, high_z)
			# Keep the sign used so an unused-variable warning cannot appear if a span is empty.
			if sign == 0.0:
				continue
		else:
			_add_wall_prism(walls, layout, inner_a, inner_b, outer_a, outer_b)
	return walls

static func _wall_span(walls: Node3D, layout: ArenaLayout, inner_a: Vector2, inner_b: Vector2, outer_a: Vector2, outer_b: Vector2, z0: float, z1: float) -> void:
	if z1 - z0 < 0.05:
		return
	var a_z := inner_a.y
	var b_z := inner_b.y
	var t0 := (z0 - a_z) / (b_z - a_z)
	var t1 := (z1 - a_z) / (b_z - a_z)
	_add_wall_prism(walls, layout, inner_a.lerp(inner_b, t0), inner_a.lerp(inner_b, t1), outer_a.lerp(outer_b, t0), outer_a.lerp(outer_b, t1))

static func _add_wall_prism(parent: Node3D, layout: ArenaLayout, inner_a: Vector2, inner_b: Vector2, outer_a: Vector2, outer_b: Vector2) -> void:
	var h := layout.wall_height
	var a0 := Vector3(inner_a.x, 0, inner_a.y)
	var b0 := Vector3(inner_b.x, 0, inner_b.y)
	var c0 := Vector3(outer_b.x, 0, outer_b.y)
	var d0 := Vector3(outer_a.x, 0, outer_a.y)
	var a1 := a0 + Vector3.UP * h
	var b1 := b0 + Vector3.UP * h
	var c1 := c0 + Vector3.UP * h
	var d1 := d0 + Vector3.UP * h
	var inward := Vector3(-(inner_a.x + inner_b.x), 0, -(inner_a.y + inner_b.y)).normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(tool, a0, b0, b1, a1, inward)
	_quad(tool, d0, d1, c1, c0, -inward)
	_quad(tool, a1, b1, c1, d1, Vector3.UP)
	_quad(tool, a0, a1, d1, d0, (d0 - a0).cross(a1 - a0).normalized())
	_quad(tool, b0, c0, c1, b1, (b1 - b0).cross(c0 - b0).normalized())
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = tool.commit()
	mesh_node.material_override = GreyMaterials.get_material(WALL_ALBEDO)
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([a0, b0, c0, d0, a1, b1, c1, d1])
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)

static func _gates(layout: ArenaLayout) -> Node3D:
	var gates := Node3D.new()
	gates.name = "Gates"
	for sign in [-1.0, 1.0]:
		_tunnel(gates, layout, sign)
	return gates

static func _tunnel(gates: Node3D, layout: ArenaLayout, sign: float) -> void:
	var inner := layout.apothem
	var outer := layout.apothem + layout.wall_thickness + layout.stand_rows * layout.stand_row_depth
	var half := layout.gate_width * 0.5
	var x0 := sign * inner
	var x1 := sign * outer
	_floor_quad(gates, x0, x1, -half, half)
	_stepped_side(gates, layout, sign, half)
	_stepped_side(gates, layout, sign, -half)
	_back_wall(gates, layout, sign, outer, half)

static func _floor_quad(parent: Node3D, x0: float, x1: float, z0: float, z1: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK
	body.collision_mask = 0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(x0, 0, z0)
	var b := Vector3(x1, 0, z0)
	var c := Vector3(x1, 0, z1)
	var d := Vector3(x0, 0, z1)
	_quad(tool, a, b, c, d, Vector3.UP)
	var mesh_node := MeshInstance3D.new()
	var floor_mesh := tool.commit()
	floor_mesh.surface_set_material(0, GreyMaterials.meadow_material())
	mesh_node.mesh = floor_mesh
	mesh_node.material_override = GreyMaterials.meadow_material()
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(absf(x1 - x0), 0.4, absf(z1 - z0))
	shape_node.shape = shape
	shape_node.position = Vector3((x0 + x1) * 0.5, -0.2, (z0 + z1) * 0.5)
	body.add_child(shape_node)
	parent.add_child(body)

static func _stepped_side(parent: Node3D, layout: ArenaLayout, sign: float, z_edge: float) -> void:
	var spans: Array[Vector3] = []
	spans.append(Vector3(layout.apothem, layout.apothem + layout.wall_thickness, layout.wall_height))
	for row in layout.stand_rows:
		var start := layout.apothem + layout.wall_thickness + float(row) * layout.stand_row_depth
		var height := layout.wall_height + layout.stand_row_rise * (float(row) + 1.0)
		spans.append(Vector3(start, start + layout.stand_row_depth, height))
	for span in spans:
		var x_a := sign * span.x
		var x_b := sign * span.y
		var height := span.z
		var body := StaticBody3D.new()
		body.collision_layer = GameConfig.LAYER_WORLD
		body.collision_mask = 0
		var center := Vector3((x_a + x_b) * 0.5, height * 0.5, z_edge + signf(z_edge) * 0.15)
		var size := Vector3(absf(x_b - x_a), height, 0.3)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_node.mesh = mesh
		mesh_node.position = center
		mesh_node.material_override = GreyMaterials.get_material(WALL_ALBEDO)
		body.add_child(mesh_node)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		shape_node.position = center
		body.add_child(shape_node)
		parent.add_child(body)

static func _back_wall(parent: Node3D, layout: ArenaLayout, sign: float, outer: float, half: float) -> void:
	var height := layout.wall_height + layout.stand_row_rise * float(layout.stand_rows)
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var size := Vector3(0.4, height, layout.gate_width)
	var center := Vector3(sign * (outer + 0.2), height * 0.5, 0.0)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = center
	mesh_node.material_override = GreyMaterials.get_material(WALL_ALBEDO)
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = center
	body.add_child(shape_node)
	parent.add_child(body)
	# half is the tunnel half-width; the back wall spans the full gate, so it is part of the signature.
	if half < 0.0:
		body.position.z = half

static func _props(layout: ArenaLayout) -> Node3D:
	var props := Node3D.new()
	props.name = "Props"
	for placement in layout.props:
		props.add_child(PropKit.build(placement))
	return props

static func _stands(layout: ArenaLayout) -> Node3D:
	var stands := Node3D.new()
	stands.name = "Stands"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_gate := layout.gate_width * 0.5
	for row in layout.stand_rows:
		var inner_a := layout.apothem + layout.wall_thickness + float(row) * layout.stand_row_depth
		var outer_a := inner_a + layout.stand_row_depth
		var top := layout.wall_height + layout.stand_row_rise * (float(row) + 1.0)
		var inner := ArenaMath.vertices(inner_a)
		var outer := ArenaMath.vertices(outer_a)
		for edge in inner.size():
			var kind := _edge_kind(inner[edge], inner[(edge + 1) % inner.size()], inner_a)
			if kind == "east" or kind == "west":
				_stand_clipped(tool, inner[edge], inner[(edge + 1) % 8], outer[edge], outer[(edge + 1) % 8], top, half_gate)
			else:
				_stand_prism(tool, inner[edge], inner[(edge + 1) % 8], outer[edge], outer[(edge + 1) % 8], top)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Mesh"
	mesh_node.mesh = tool.commit()
	mesh_node.material_override = GreyMaterials.get_material(STAND_ALBEDO)
	stands.add_child(mesh_node)
	return stands

static func _stand_clipped(tool: SurfaceTool, inner_a: Vector2, inner_b: Vector2, outer_a: Vector2, outer_b: Vector2, top: float, half_gate: float) -> void:
	var low_z := minf(inner_a.y, inner_b.y)
	var high_z := maxf(inner_a.y, inner_b.y)
	_stand_span(tool, inner_a, inner_b, outer_a, outer_b, top, low_z, -half_gate)
	_stand_span(tool, inner_a, inner_b, outer_a, outer_b, top, half_gate, high_z)

static func _stand_span(tool: SurfaceTool, inner_a: Vector2, inner_b: Vector2, outer_a: Vector2, outer_b: Vector2, top: float, z0: float, z1: float) -> void:
	if z1 - z0 < 0.05:
		return
	var t0 := (z0 - inner_a.y) / (inner_b.y - inner_a.y)
	var t1 := (z1 - inner_a.y) / (inner_b.y - inner_a.y)
	_stand_prism(tool, inner_a.lerp(inner_b, t0), inner_a.lerp(inner_b, t1), outer_a.lerp(outer_b, t0), outer_a.lerp(outer_b, t1), top)

static func _stand_prism(tool: SurfaceTool, inner_a: Vector2, inner_b: Vector2, outer_a: Vector2, outer_b: Vector2, top: float) -> void:
	var a0 := Vector3(inner_a.x, 0, inner_a.y)
	var b0 := Vector3(inner_b.x, 0, inner_b.y)
	var c0 := Vector3(outer_b.x, 0, outer_b.y)
	var d0 := Vector3(outer_a.x, 0, outer_a.y)
	var a1 := Vector3(inner_a.x, top, inner_a.y)
	var b1 := Vector3(inner_b.x, top, inner_b.y)
	var c1 := Vector3(outer_b.x, top, outer_b.y)
	var d1 := Vector3(outer_a.x, top, outer_a.y)
	var inward := Vector3(-(inner_a.x + inner_b.x), 0, -(inner_a.y + inner_b.y)).normalized()
	_quad(tool, a1, b1, c1, d1, Vector3.UP)
	_quad(tool, d0, d1, c1, c0, -inward)
	_quad(tool, a0, b0, b1, a1, inward)
	_quad(tool, a0, a1, d1, d0, (d0 - a0).cross(Vector3.UP).normalized())
	_quad(tool, b0, c0, c1, b1, (c0 - b0).cross(Vector3.UP).normalized())

static func _spawns(layout: ArenaLayout) -> Node3D:
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	var info := ArenaInfo.new()
	info.setup(layout)
	for team in [Team.Id.A, Team.Id.B]:
		var letter := "A" if team == Team.Id.A else "B"
		for slot in 6:
			var marker := Marker3D.new()
			marker.name = "Spawn_%s_%d" % [letter, slot]
			var transform := info.get_spawn_slot(team, slot)
			marker.position = transform.origin
			marker.basis = transform.basis
			spawns.add_child(marker)
	info.free()
	return spawns

static func _doors(layout: ArenaLayout) -> Node3D:
	var doors := Node3D.new()
	doors.name = "GateDoors"
	for team in [Team.Id.A, Team.Id.B]:
		var sign := -1.0 if team == Team.Id.A else 1.0
		var body := StaticBody3D.new()
		body.name = "Gate_A_Door" if team == Team.Id.A else "Gate_B_Door"
		body.collision_layer = GameConfig.LAYER_WORLD
		body.collision_mask = 0
		var size := Vector3(0.5, layout.wall_height, layout.gate_width)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_node.mesh = mesh
		mesh_node.material_override = GreyMaterials.get_material(WALL_ALBEDO)
		body.add_child(mesh_node)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = Vector3(sign * (layout.apothem + layout.wall_thickness * 0.5), layout.wall_height * 0.5, 0.0)
		doors.add_child(body)
	return doors

static func _environment() -> WorldEnvironment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.78, 0.92)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.5)
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	return world

static func _sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.15
	return sun

static func _edge_kind(a: Vector2, b: Vector2, apothem: float) -> String:
	if absf(a.x - apothem) < 0.25 and absf(b.x - apothem) < 0.25:
		return "east"
	if absf(a.x + apothem) < 0.25 and absf(b.x + apothem) < 0.25:
		return "west"
	if absf(a.y - apothem) < 0.25 and absf(b.y - apothem) < 0.25:
		return "south"
	if absf(a.y + apothem) < 0.25 and absf(b.y + apothem) < 0.25:
		return "north"
	return "diagonal"

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var facing := (b - a).cross(c - a)
	if facing.dot(normal) < 0.0:
		var swap := b
		b = c
		c = swap
	tool.set_normal(normal)
	tool.set_uv(Vector2(a.x, a.z) / 4.0)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.set_uv(Vector2(b.x, b.z) / 4.0)
	tool.add_vertex(b)
	tool.set_normal(normal)
	tool.set_uv(Vector2(c.x, c.z) / 4.0)
	tool.add_vertex(c)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_tri(tool, a, b, c, normal)
	_tri(tool, a, c, d, normal)
