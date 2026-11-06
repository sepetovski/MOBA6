class_name ArtDressing extends RefCounted

## Three dirt lanes, forest between them, and climbable wood.
## Camp pads are empty clearings. Gold camps come later. No large rocks.

const KIT := "res://art/exports/Stylized Nature MegaKit[Standard]/glTF"
const WOOD := Color(0.46, 0.32, 0.18)
const WOOD_DARK := Color(0.34, 0.24, 0.14)
const ENV_SCALE := 1.14
const SHOT_COVER_WIDTH := 0.7 # fraction of the canopy, so the outer leaves are not a solid cube
const SHOT_COVER_HEIGHT := 0.88 # fraction of the tree height kept as a shot wall
const SHOT_COVER_MIN_WIDTH := 1.2 # m, a thin trunk still stops a shot

static var _reach := 36.0
static var _lane_z := 18.0
static var _pads: Array[Vector2] = []


static func attach(arena: Node3D) -> void:
	var parent: Node = arena.get_node_or_null("Navigation")
	if parent == null:
		parent = arena
	var info := arena.get_node_or_null("ArenaInfo") as ArenaInfo
	_reach = 36.0
	if info != null:
		_reach = info.get_apothem() - 4.0
	_lane_z = _reach * 0.46
	_pads = [
		Vector2(-20.0, -_lane_z * 0.5),
		Vector2(16.0, -_lane_z * 0.5),
		Vector2(0.0, -_lane_z * 0.5),
		Vector2(-16.0, _lane_z * 0.5),
		Vector2(20.0, _lane_z * 0.5),
		Vector2(0.0, _lane_z * 0.5),
	]
	var root := Node3D.new()
	root.name = "Dressing"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_lanes(root)
	_camps(root)
	_routes(root)
	_jungle(root)
	_vista(root)
	_scatter(root, rng)
	var life := ForestLife.new()
	life.name = "ForestLife"
	root.add_child(life)


static func _lanes(root: Node3D) -> void:
	for lane_z in [-_lane_z, 0.0, _lane_z]:
		var lane := MeshInstance3D.new()
		lane.name = "Lane"
		var plane := PlaneMesh.new()
		plane.orientation = PlaneMesh.FACE_Y
		plane.size = Vector2(_reach * 1.7, 6.4)
		lane.mesh = plane
		lane.position = Vector3(0.0, 0.02, lane_z)
		lane.material_override = GreyMaterials.lane_material()
		lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lane)


static func _camps(root: Node3D) -> void:
	for pad in _pads:
		var patch := MeshInstance3D.new()
		patch.name = "CampPad"
		var disc := CylinderMesh.new()
		disc.top_radius = 4.2
		disc.bottom_radius = 4.2
		disc.height = 0.05
		patch.mesh = disc
		patch.position = Vector3(pad.x, 0.04, pad.y)
		patch.material_override = GreyMaterials.lane_material()
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(patch)


static func _routes(root: Node3D) -> void:
	# Bridges sit in the jungle, off the lanes. The deck matches its collider.
	_bridge(root, Vector3(-28.0, 0.0, -_lane_z * 0.5))
	_bridge(root, Vector3(26.0, 0.0, _lane_z * 0.5))
	# Wide tops you can stand on and walk off. 1.65 m needs the second jump. 1.9 m is a mantle.
	_platform(root, Vector3(-16.0, 0.0, _lane_z * 0.42), Vector3(2.8, 1.65, 2.8), 1.65, WOOD)
	_platform(root, Vector3(20.0, 0.0, -_lane_z * 0.42), Vector3(2.8, 1.65, 2.8), 1.65, WOOD)
	_platform(root, Vector3(6.0, 0.0, _lane_z * 0.55), Vector3(1.6, 1.9, 1.5), 1.9, WOOD_DARK)
	_platform(root, Vector3(-22.0, 0.0, -_lane_z * 0.62), Vector3(1.6, 1.9, 1.5), 1.9, WOOD_DARK)
	var crate_z: Array[float] = [-_lane_z, 0.0, _lane_z]
	for lane_z in crate_z:
		_crate(root, Vector3(-8.0, 0.0, lane_z + 5.4), Vector3(1.4, 0.45, 1.4))
		_crate(root, Vector3(12.0, 0.0, lane_z - 5.2), Vector3(1.2, 0.45, 1.2))


static func _bridge(root: Node3D, at: Vector3) -> void:
	_platform(root, at, Vector3(8.0, 0.22, 2.3), 0.86, WOOD)
	_crate(root, at + Vector3(-4.8, 0.0, 0.0), Vector3(1.3, 0.42, 1.4))
	_crate(root, at + Vector3(4.6, 0.0, 1.6), Vector3(1.1, 0.7, 1.1))


static func _crate(root: Node3D, at: Vector3, size: Vector3) -> void:
	_platform(root, at, size, size.y, WOOD_DARK)


static func _platform(root: Node3D, at: Vector3, size: Vector3, top: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_PROPS | GameConfig.LAYER_OCCLUDERS
	body.collision_mask = 0
	body.set_meta("shot_cover", true)
	body.position = Vector3(at.x, top - size.y * 0.5, at.z)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = GreyMaterials.flat_material(color)
	visual.add_to_group(&"cover_fade")
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var shape_node := CollisionShape3D.new()
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)


static func _jungle(root: Node3D) -> void:
	var trees: Array = [
		["Pine_1", -30.0, -_lane_z * 0.55, 11.0],
		["Pine_3", -18.0, _lane_z * 0.72, 10.0],
		["CommonTree_1", -34.0, _lane_z * 0.35, 8.4],
		["CommonTree_3", -8.0, -_lane_z * 0.8, 8.0],
		["Pine_5", -26.0, _lane_z * 0.2, 9.5],
		["DeadTree_1", 6.0, -_lane_z * 0.65, 6.2],
	]
	for entry in trees:
		_place(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), float(entry[3]), true, 0.4, true)
	_place(root, "CommonTree_2", Vector3(10.0, 0.0, -_lane_z * 0.55), 9.2, true, 0.4, false, Color(0.95, 0.36, 0.08, 1.0))


static func _vista(root: Node3D) -> void:
	var names: Array[String] = ["Pine_4", "CommonTree_4", "Pine_1", "CommonTree_1", "Pine_5", "TwistedTree_2"]
	for index in 16:
		var angle := TAU * float(index) / 16.0
		var radius := _reach + 6.0 + float(index % 3) * 1.5
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if absf(spot.x) > _reach - 2.0 and absf(spot.z) < 10.0:
			continue
		_place(root, names[index % names.size()], spot, 14.0, false, 0.0, false)


static func _scatter(root: Node3D, rng: RandomNumberGenerator) -> void:
	_field(root, rng, "Grass_Common_Short", 260, 1.15, "grass")
	_field(root, rng, "Grass_Wispy_Short", 120, 1.05, "grass")
	_field(root, rng, "Grass_Common_Tall", 36, 1.0, "edge")
	_field(root, rng, "Clover_1", 40, 0.9, "grass")
	_field(root, rng, "Fern_1", 28, 1.0, "edge")
	_field(root, rng, "Flower_3_Single", 24, 0.85, "edge")
	_field(root, rng, "Flower_4_Single", 16, 0.85, "edge")
	_field(root, rng, "Mushroom_Common", 18, 1.0, "edge")
	_field(root, rng, "Pebble_Round_1", 28, 0.45, "road")
	_field(root, rng, "Pebble_Round_4", 16, 0.35, "road")
	_field(root, rng, "Plant_7", 30, 1.0, "grass")


static func _field(root: Node3D, rng: RandomNumberGenerator, file_name: String, count: int, scale: float, kind: String) -> void:
	var info := _mesh_info(file_name)
	if info.is_empty():
		return
	var mesh: Mesh = info["mesh"]
	var min_y := float(info["min_y"])
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	multi.visible_instance_count = 0
	var view := MultiMeshInstance3D.new()
	view.name = file_name
	view.multimesh = multi
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(view)
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 40:
		guard += 1
		var spot := _square(rng)
		if not _accepts(spot, kind):
			continue
		var yaw := rng.randf() * TAU
		var size := scale * ENV_SCALE * rng.randf_range(0.85, 1.15)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
		multi.set_instance_transform(placed, Transform3D(basis, Vector3(spot.x, -min_y * size, spot.z)))
		placed += 1
	multi.visible_instance_count = placed


static func _place(root: Node3D, file_name: String, spot: Vector3, target_height: float, solid: bool, trunk: float, mirror := true, leaf := Color(0, 0, 0, 0), bulk := 0.62, wide := 1.0) -> void:
	var spots: Array[Vector3] = []
	if mirror:
		spots = _sides(spot)
	else:
		spots.append(spot)
	for side in spots:
		var node := _instance(file_name)
		if node == null:
			return
		var box := _bounds(node)
		var scale := 1.0
		if target_height > 0.1 and box.size.y > 0.001:
			scale = target_height / box.size.y
		scale *= ENV_SCALE
		node.scale = Vector3(scale * wide, scale, scale * wide)
		node.position = Vector3(side.x, -box.position.y * scale, side.z)
		node.rotation.y = fmod(side.x * 0.37 + side.z * 0.21, TAU)
		if leaf.a > 0.5:
			_tint_leaves(node, leaf)
		_shadows(node, false)
		root.add_child(node)
		if solid:
			_collider(root, node.position, box, scale, trunk * ENV_SCALE, bulk, wide)
			_shot_wall(root, node)
			node.add_to_group(&"cover_fade")


static func _collider(root: Node3D, at: Vector3, box: AABB, scale: float, trunk: float, bulk: float, wide: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_PROPS
	body.collision_mask = 0
	body.position = Vector3(at.x, 0.0, at.z)
	var shape_node := CollisionShape3D.new()
	if trunk > 0.0:
		var shape := CylinderShape3D.new()
		shape.radius = trunk
		shape.height = 2.25
		shape_node.shape = shape
		shape_node.position = Vector3(0.0, 1.12, 0.0)
	else:
		var shape := BoxShape3D.new()
		var height := box.size.y * scale * 0.9
		shape.size = Vector3(maxf(box.size.x * scale * wide * bulk, 0.9), height, maxf(box.size.z * scale * wide * bulk, 0.9))
		shape_node.shape = shape
		shape_node.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	body.add_child(shape_node)
	root.add_child(body)


static func _shot_wall(root: Node3D, visual: Node3D) -> void:
	var box := _bounds(visual)
	if box.size.y < 1.5:
		return
	var size := box.size
	size.x = maxf(size.x * SHOT_COVER_WIDTH, SHOT_COVER_MIN_WIDTH)
	size.z = maxf(size.z * SHOT_COVER_WIDTH, SHOT_COVER_MIN_WIDTH)
	size.y = maxf(size.y * SHOT_COVER_HEIGHT, 2.4)
	var body := StaticBody3D.new()
	body.name = "ShotCover"
	body.collision_layer = GameConfig.LAYER_OCCLUDERS
	body.collision_mask = 0
	body.set_meta("shot_cover", true)
	var center := box.get_center()
	body.position = Vector3(center.x, box.position.y + size.y * 0.5, center.z)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)


static func _tint_leaves(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var mat := mesh_node.get_active_material(surface)
				if mat == null or not mat is StandardMaterial3D:
					continue
				var mat_name := mat.resource_name.to_lower()
				if mat_name.is_empty():
					mat_name = str(mat.resource_path).to_lower()
				if not mat_name.contains("leaf"):
					continue
				var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_texture = null
				copy.albedo_color = color
				copy.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mesh_node.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_tint_leaves(child, color)


static func _shadows(node: Node, cast: bool) -> void:
	if node is GeometryInstance3D and not cast:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_shadows(child, cast)


static func _sides(spot: Vector3) -> Array[Vector3]:
	var spots: Array[Vector3] = [spot]
	if absf(spot.x) > 1.5:
		spots.append(Vector3(-spot.x, spot.y, spot.z))
	return spots


static func _square(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-_reach, _reach), 0.0, rng.randf_range(-_reach, _reach))


static func _accepts(spot: Vector3, kind: String) -> bool:
	if not ArenaMath.contains(Vector2(spot.x, spot.z), _reach - 1.5):
		return false
	if absf(spot.x) > _reach - 6.0 and absf(spot.z) < 6.0:
		return false
	if _near_pad(spot):
		return false
	var lane_gap := _lane_gap(spot)
	var on_lane := lane_gap < 3.3 and absf(spot.x) < _reach - 2.0
	if kind == "road":
		return on_lane
	if on_lane:
		return false
	if kind == "edge":
		return lane_gap < 9.0
	return true


static func _lane_gap(spot: Vector3) -> float:
	var best := absf(spot.z)
	best = minf(best, absf(spot.z - _lane_z))
	best = minf(best, absf(spot.z + _lane_z))
	return best


static func _near_pad(spot: Vector3) -> bool:
	for pad in _pads:
		if Vector2(spot.x, spot.z).distance_to(pad) < 5.0:
			return true
	return false


static func _instance(file_name: String) -> Node3D:
	var path := "%s/%s.gltf" % [KIT, file_name]
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


static func _mesh_info(file_name: String) -> Dictionary:
	var node := _instance(file_name)
	if node == null:
		return {}
	var mesh := _find_mesh(node)
	var box := _bounds(node)
	node.free()
	if mesh == null:
		return {}
	return {"mesh": mesh, "min_y": box.position.y}


static func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


static func _bounds(node: Node) -> AABB:
	return _walk(node, Transform3D.IDENTITY, AABB(), {"ok": false})


static func _walk(node: Node, parent: Transform3D, box: AABB, found: Dictionary) -> AABB:
	var here := parent
	if node is Node3D:
		here = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var world := here * (node as MeshInstance3D).mesh.get_aabb()
		if not found["ok"]:
			box = world
			found["ok"] = true
		else:
			box = box.merge(world)
	for child in node.get_children():
		box = _walk(child, here, box, found)
	return box
