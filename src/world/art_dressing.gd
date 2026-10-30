class_name ArtDressing extends RefCounted

## Forest dressing for the ring, laid out like a sunlit dirt road.
## The east-west lane stays open. West placements are mirrored so both teams share the same cover.
## Big rocks are solid and short enough to vault or mantle. Tree trunks block, canopies do not.

const KIT := "res://art/exports/Stylized Nature MegaKit[Standard]/glTF"


static func attach(arena: Node3D) -> void:
	var parent: Node = arena.get_node_or_null("Navigation")
	if parent == null:
		parent = arena
	var root := Node3D.new()
	root.name = "Dressing"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_road(root)
	_landmarks(root)
	_vista(root)
	_scatter(root, rng)
	var life := ForestLife.new()
	life.name = "ForestLife"
	root.add_child(life)


static func _road(root: Node3D) -> void:
	# A flat dirt ribbon, light like the reference, with kit stones scattered on it. No raised slabs.
	var lane := MeshInstance3D.new()
	lane.name = "Lane"
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	plane.size = Vector2(66.0, 5.6)
	lane.mesh = plane
	lane.position = Vector3(0.0, 0.025, 0.0)
	lane.material_override = GreyMaterials.lane_material()
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lane)


static func _landmarks(root: Node3D) -> void:
	var trees: Array = [
		["Pine_1", -30.0, 14.0, 12.0],
		["Pine_3", -22.0, 24.0, 11.0],
		["Pine_5", -15.0, -22.0, 10.5],
		["Pine_2", -33.0, -14.0, 12.5],
		["CommonTree_1", -24.0, -18.0, 9.0],
		["CommonTree_3", -16.0, 16.0, 8.6],
		["CommonTree_5", -28.0, 6.5, 8.2],
		["DeadTree_1", -20.0, -28.0, 6.5],
		["TwistedTree_1", -11.0, 27.0, 7.5],
	]
	for entry in trees:
		_place(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), float(entry[3]), true, 0.42, true)
	# One autumn tree, like the orange canopy in the reference. Not mirrored.
	_place(root, "CommonTree_2", Vector3(12.0, 0.0, -8.5), 9.6, true, 0.42, false, Color(0.95, 0.36, 0.08, 1.0))
	_place(root, "TwistedTree_5", Vector3(-4.0, 0.0, 22.0), 7.8, true, 0.36, false, Color(0.93, 0.4, 0.1, 1.0))
	# Heights stay under the 2 m mantle. Width is extra so the top is a platform you can jump onto.
	var rocks: Array = [
		["Rock_Medium_1", -6.5, -5.8, 1.95, 2.15],
		["Rock_Medium_2", 9.0, 8.5, 1.55, 1.9],
		["Rock_Medium_1", -16.0, 11.0, 1.85, 1.8],
		["Rock_Medium_2", -24.0, -12.5, 1.35, 1.65],
		["Rock_Medium_3", -10.5, -12.0, 0.9, 1.5],
		["Rock_Medium_1", -28.0, 17.5, 1.7, 1.85],
	]
	for entry in rocks:
		_place(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), float(entry[3]), true, 0.0, true, Color(0, 0, 0, 0), 0.82, float(entry[4]))
	var plants: Array = [
		["Bush_Common", -20.0, 8.0],
		["Bush_Common_Flowers", -12.0, 14.0],
		["Bush_Common", -26.0, -8.0],
		["Fern_1", -8.0, 7.5],
		["Fern_1", -22.0, -7.2],
		["Flower_4_Group", -11.0, -7.0],
		["Flower_3_Group", -19.0, 7.2],
		["Mushroom_Laetiporus", -29.0, 10.0],
		["Mushroom_Common", -6.5, 4.2],
		["Flower_4_Group", -14.0, 4.6],
		["Flower_3_Group", 0.0, -4.8],
		["Fern_1", -18.0, -4.4],
		["Plant_1_Big", -31.0, -22.0],
	]
	for entry in plants:
		_place(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), 0.0, false, 0.0, true)


static func _vista(root: Node3D) -> void:
	var names: Array[String] = ["Pine_4", "CommonTree_4", "Pine_1", "CommonTree_1", "Pine_5", "TwistedTree_2"]
	for index in 18:
		var angle := TAU * float(index) / 18.0
		var radius := 44.0 + float(index % 3) * 2.2
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if absf(spot.x) > 34.0 and absf(spot.z) < 12.0:
			continue
		_place(root, names[index % names.size()], spot, 15.0, false, 0.0, false)


static func _scatter(root: Node3D, rng: RandomNumberGenerator) -> void:
	_field(root, rng, "Grass_Common_Short", 220, 1.2, "grass")
	_field(root, rng, "Grass_Wispy_Short", 120, 1.1, "grass")
	_field(root, rng, "Grass_Common_Tall", 40, 1.05, "edge")
	_field(root, rng, "Clover_1", 48, 0.95, "grass")
	_field(root, rng, "Plant_1", 32, 1.05, "grass")
	_field(root, rng, "Plant_7", 36, 1.08, "grass")
	_field(root, rng, "Fern_1", 28, 1.0, "edge")
	_field(root, rng, "Flower_3_Single", 26, 0.9, "edge")
	_field(root, rng, "Flower_4_Single", 18, 0.9, "edge")
	_field(root, rng, "Mushroom_Common", 20, 1.05, "edge")
	_field(root, rng, "Pebble_Round_1", 22, 0.5, "road")
	_field(root, rng, "Pebble_Round_4", 14, 0.4, "road")
	_field(root, rng, "Petal_2", 22, 1.05, "edge")


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
		var size := scale * rng.randf_range(0.85, 1.15)
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
		node.scale = Vector3(scale * wide, scale, scale * wide)
		node.position = Vector3(side.x, -box.position.y * scale, side.z)
		node.rotation.y = fmod(side.x * 0.37 + side.z * 0.21, TAU)
		if leaf.a > 0.5:
			_tint_leaves(node, leaf)
		_shadows(node, solid)
		root.add_child(node)
		if solid:
			_collider(root, node.position, box, scale, trunk, bulk, wide)


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
	return Vector3(rng.randf_range(-36.0, 36.0), 0.0, rng.randf_range(-36.0, 36.0))


static func _accepts(spot: Vector3, kind: String) -> bool:
	if not ArenaMath.contains(Vector2(spot.x, spot.z), 36.2):
		return false
	if absf(spot.x) > 33.0 and absf(spot.z) < 5.5:
		return false
	var on_road := absf(spot.z) < 2.5 and absf(spot.x) < 33.0
	if kind == "road":
		return on_road
	if on_road:
		return false
	if kind == "edge":
		return absf(spot.z) < 14.0 or absf(spot.x) > 18.0
	return true


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
