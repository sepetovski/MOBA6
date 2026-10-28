class_name PropKit extends RefCounted

## Gray gameplay props. Collision matches the mesh. traversal_class is node metadata.
## Ramps are walkable slopes and carry no traversal class. Gaps are tagged, not derived from height.
## Wall-line gaps in the generator are 1.5 m: docs/PLAN.md §4 beats the 1.2 m example in the brief.

const PROP_ALBEDO := 0.62
const LINTEL := 0.4

static func build(placement: PropPlacement) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = String(placement.prop_type)
	body.position = placement.position
	body.rotation = Vector3(0.0, deg_to_rad(placement.yaw_deg), 0.0)
	body.scale = placement.scale
	body.collision_layer = GameConfig.LAYER_PROPS
	body.collision_mask = 0
	body.set_meta("prop_type", placement.prop_type)
	if placement.prop_type == &"crate_s" or placement.prop_type == &"crate_m" or placement.prop_type == &"crate_flat":
		body.set_meta("destructible", true)
		body.set_meta("health", 36.0 if placement.prop_type == &"crate_s" else 64.0)
	var traversal := traversal_for(placement.prop_type)
	if traversal >= 0:
		body.set_meta("traversal_class", traversal)
	_fill(body, placement.prop_type)
	return body

static func traversal_for(prop_type: StringName) -> int:
	match prop_type:
		&"tunnel_slide":
			return TraversalClass.Kind.SLIDE_GAP
		&"tunnel_crouch":
			return TraversalClass.Kind.CROUCH_GAP
		&"stack_stair":
			return TraversalClass.Kind.VAULT
		&"ramp_15", &"ramp_25", &"ramp_35":
			return -1
		_:
			return TraversalClass.from_height(height_of(prop_type))

static func height_of(prop_type: StringName) -> float:
	match prop_type:
		&"crate_s":
			return 1.0
		&"crate_m":
			return 1.5
		&"crate_l":
			return 2.0
		&"crate_flat":
			return 0.5
		&"barrel", &"barrel_cluster":
			return 1.0
		&"wall_low":
			return 1.0
		&"wall_mid":
			return 1.6
		&"wall_high":
			return 2.5
		&"pillar":
			return 4.0
		&"platform", &"platform_center":
			return 0.8
		&"ramp_15", &"ramp_25", &"ramp_35":
			return 0.8
		&"tunnel_slide":
			return 1.0
		&"tunnel_crouch":
			return 1.2
		&"stack_stair":
			return 3.0
		_:
			return 0.0

static func footprint(prop_type: StringName) -> Vector2:
	## Full local X and Z size of the prop's ground footprint.
	match prop_type:
		&"crate_s":
			return Vector2(1.0, 1.0)
		&"crate_m":
			return Vector2(1.5, 1.5)
		&"crate_l":
			return Vector2(2.0, 2.0)
		&"crate_flat":
			return Vector2(2.0, 1.0)
		&"barrel":
			return Vector2(0.9, 0.9)
		&"barrel_cluster":
			return Vector2(2.0, 2.0)
		&"wall_low", &"wall_mid", &"wall_high":
			return Vector2(4.0, 0.3)
		&"pillar":
			return Vector2(1.2, 1.2)
		&"platform":
			return Vector2(6.0, 6.0)
		&"platform_center":
			return Vector2(14.0, 14.0)
		&"ramp_15":
			return Vector2(6.0, ramp_run(15.0))
		&"ramp_25":
			return Vector2(6.0, ramp_run(25.0))
		&"ramp_35":
			return Vector2(6.0, ramp_run(35.0))
		&"tunnel_slide", &"tunnel_crouch":
			return Vector2(4.6, 4.0)
		&"stack_stair":
			return Vector2(6.0, 3.0)
		_:
			return Vector2.ONE

static func ramp_run(angle_deg: float) -> float:
	return 0.8 / tan(deg_to_rad(angle_deg))

static func world_aabb(placement: PropPlacement) -> AABB:
	var size := footprint(placement.prop_type)
	var half := Vector2(size.x * 0.5 * absf(placement.scale.x), size.y * 0.5 * absf(placement.scale.z))
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for corner in corners:
		var rotated: Vector3 = ArenaMath.rotate_xz(Vector3(corner.x, 0.0, corner.y), placement.yaw_deg)
		var world := placement.position + rotated
		min_x = minf(min_x, world.x)
		max_x = maxf(max_x, world.x)
		min_z = minf(min_z, world.z)
		max_z = maxf(max_z, world.z)
	var height := height_of(placement.prop_type) * absf(placement.scale.y)
	return AABB(
		Vector3(min_x, placement.position.y, min_z),
		Vector3(max_x - min_x, maxf(height, 0.05), max_z - min_z)
	)

static func _fill(body: StaticBody3D, prop_type: StringName) -> void:
	var material := GreyMaterials.get_material(PROP_ALBEDO)
	var breakable := GreyMaterials.get_material(0.22)
	match prop_type:
		&"crate_s":
			_box(body, Vector3(1, 1, 1), breakable)
		&"crate_m":
			_box(body, Vector3(1.5, 1.5, 1.5), breakable)
		&"crate_l":
			_box(body, Vector3(2, 2, 2), material)
		&"crate_flat":
			_box(body, Vector3(2, 0.5, 1), breakable)
		&"barrel":
			_cylinder(body, 0.45, 1.0, Vector3.ZERO, material)
		&"barrel_cluster":
			_barrel_cluster(body, material)
		&"wall_low":
			_box(body, Vector3(4.0, 1.0, 0.3), material)
		&"wall_mid":
			_box(body, Vector3(4.0, 1.6, 0.3), material)
		&"wall_high":
			_box(body, Vector3(4.0, 2.5, 0.3), material)
		&"pillar":
			_cylinder(body, 0.6, 4.0, Vector3.ZERO, material)
		&"platform":
			_box(body, Vector3(6, 0.8, 6), material)
		&"platform_center":
			_box(body, Vector3(14, 0.8, 14), material)
		&"ramp_15":
			_ramp(body, 15.0, material)
		&"ramp_25":
			_ramp(body, 25.0, material)
		&"ramp_35":
			_ramp(body, 35.0, material)
		&"tunnel_slide":
			_tunnel(body, 1.0, material)
		&"tunnel_crouch":
			_tunnel(body, 1.2, material)
		&"stack_stair":
			_stack_stair(body, material)
		_:
			push_error("unknown prop %s" % prop_type)

static func _box(body: StaticBody3D, size: Vector3, material: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = mesh_node.position
	body.add_child(shape_node)

static func _cylinder(body: StaticBody3D, radius: float, height: float, center: Vector3, material: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = center + Vector3(0, height * 0.5, 0)
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	shape_node.shape = shape
	shape_node.position = mesh_node.position
	body.add_child(shape_node)

static func _barrel_cluster(body: StaticBody3D, material: Material) -> void:
	var orbit := 0.9 / sqrt(3.0)
	for k in 3:
		var angle := float(k) * TAU / 3.0
		var center := Vector3(cos(angle) * orbit, 0.0, sin(angle) * orbit)
		_cylinder(body, 0.45, 1.0, center, material)

static func _ramp(body: StaticBody3D, angle_deg: float, material: Material) -> void:
	## Slope runs along local +Z so a yaw mirror (which flips local X) does not reverse it.
	var run := ramp_run(angle_deg)
	var low := -run * 0.5
	var high := run * 0.5
	var half_w := 3.0
	var low_l := Vector3(-half_w, 0.0, low)
	var low_r := Vector3(half_w, 0.0, low)
	var high_l := Vector3(-half_w, 0.0, high)
	var high_r := Vector3(half_w, 0.0, high)
	var top_l := Vector3(-half_w, 0.8, high)
	var top_r := Vector3(half_w, 0.8, high)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ramp_tri(tool, low_l, high_r, low_r, Vector3.DOWN)
	_ramp_tri(tool, low_l, high_l, high_r, Vector3.DOWN)
	_ramp_tri(tool, low_l, low_r, top_r, Vector3.UP)
	_ramp_tri(tool, low_l, top_r, top_l, Vector3.UP)
	_ramp_tri(tool, high_l, high_r, top_r, Vector3.FORWARD)
	_ramp_tri(tool, high_l, top_r, top_l, Vector3.FORWARD)
	_ramp_tri(tool, low_l, top_l, high_l, Vector3.LEFT)
	_ramp_tri(tool, low_r, high_r, top_r, Vector3.RIGHT)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = tool.commit()
	mesh_node.material_override = material
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([low_l, low_r, high_l, high_r, top_l, top_r])
	shape_node.shape = shape
	body.add_child(shape_node)

static func _ramp_tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.add_vertex(b)
	tool.set_normal(normal)
	tool.add_vertex(c)

static func _tunnel(body: StaticBody3D, clearance: float, material: Material) -> void:
	var wall_h := clearance + LINTEL
	_box_at(body, Vector3(0.3, wall_h, 4.0), Vector3(-2.15, wall_h * 0.5, 0.0), material)
	_box_at(body, Vector3(0.3, wall_h, 4.0), Vector3(2.15, wall_h * 0.5, 0.0), material)
	_box_at(body, Vector3(4.6, LINTEL, 4.0), Vector3(0.0, clearance + LINTEL * 0.5, 0.0), material)

static func _box_at(body: StaticBody3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = center
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = center
	body.add_child(shape_node)

static func _stack_stair(body: StaticBody3D, material: Material) -> void:
	## Tops at 1, 2 and 3 m. Bases sit on the floor, side by side, so each face is a step.
	_box_at(body, Vector3(1, 1, 3), Vector3(-2.5, 0.5, 0.0), material)
	_box_at(body, Vector3(2, 2, 3), Vector3(-1.0, 1.0, 0.0), material)
	_box_at(body, Vector3(3, 3, 3), Vector3(1.5, 1.5, 0.0), material)
