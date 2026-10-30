class_name ArtDressing extends RefCounted

## Dresses the ring with the stylized nature kit.
## The east-west lane, the gates, and the centre pit stay clear so the match still plays.
## Placements on the west side are mirrored to the east so neither team gets extra cover.

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
	_landmarks(root)
	_scatter(root, rng)


static func _landmarks(root: Node3D) -> void:
	# name, x, z, target height. 0 keeps the mesh's own height.
	var trees: Array = [
		["CommonTree_1", -30.0, 22.0, 0.0],
		["CommonTree_3", -20.0, 31.0, 0.0],
		["CommonTree_5", -33.0, -22.0, 0.0],
		["Pine_2", -24.0, -30.0, 0.0],
		["Pine_5", -14.0, 28.0, 0.0],
		["DeadTree_1", -16.0, -20.0, 8.5],
		["TwistedTree_5", -12.0, 16.0, 11.0],
	]
	for entry in trees:
		_place_scene(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), float(entry[3]), true, 0.42)
	var rocks: Array = [
		["Rock_Medium_1", -22.0, 14.0, 0.0],
		["Rock_Medium_3", -28.0, -12.0, 0.0],
	]
	for entry in rocks:
		_place_scene(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), float(entry[3]), true, 0.0)
	var bushes: Array = [
		["Bush_Common", -27.0, 18.0],
		["Bush_Common_Flowers", -18.0, 26.0],
		["Bush_Common", -29.0, -26.0],
		["Fern_1", -14.0, 20.0],
		["Flower_4_Group", -26.0, 26.0],
		["Flower_3_Group", -20.0, -24.0],
		["Mushroom_Laetiporus", -32.0, 16.0],
	]
	for entry in bushes:
		_place_scene(root, str(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), 0.0, false, 0.0)


static func _scatter(root: Node3D, rng: RandomNumberGenerator) -> void:
	_field(root, rng, "Grass_Common_Short", 170, 0.0, 1.0, 0.8, true)
	_field(root, rng, "Grass_Wispy_Short", 90, 0.0, 1.0, 0.7, true)
	_field(root, rng, "Plant_7", 40, 0.0, 1.0, 1.0, true)
	_field(root, rng, "Clover_2", 28, 0.0, 1.0, 0.65, true)
	_field(root, rng, "Grass_Common_Short", 90, 11.0, 34.0, 0.9)
	_field(root, rng, "Grass_Wispy_Short", 50, 12.0, 33.0, 0.85)
	_field(root, rng, "Grass_Common_Tall", 28, 16.0, 32.0, 0.8)
	_field(root, rng, "Clover_1", 36, 12.0, 30.0, 0.75)
	_field(root, rng, "Plant_1", 24, 14.0, 31.0, 0.9)
	_field(root, rng, "Plant_7", 30, 13.0, 32.0, 1.0)
	_field(root, rng, "Fern_1", 16, 18.0, 33.0, 0.85)
	_field(root, rng, "Pebble_Round_1", 22, 12.0, 34.0, 3.2)
	_field(root, rng, "Pebble_Round_4", 18, 14.0, 33.0, 3.0)
	_field(root, rng, "Petal_2", 20, 11.0, 28.0, 1.3)
	_field(root, rng, "Mushroom_Common", 14, 15.0, 31.0, 1.0)
	_field(root, rng, "Flower_3_Single", 12, 16.0, 30.0, 0.7)
	_paths(root)


static func _paths(root: Node3D) -> void:
	var along := [-18.0, -6.0]
	for x in along:
		_place_scene(root, "RockPath_Round_Wide", Vector3(x, 0.0, 18.0), 0.0, false, 0.0)
		_place_scene(root, "RockPath_Round_Thin", Vector3(x, 0.0, -18.0), 0.0, false, 0.0)


static func _field(root: Node3D, rng: RandomNumberGenerator, file_name: String, count: int, inner: float, outer: float, scale: float, cover_floor := false) -> void:
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
	while placed < count and guard < count * 30:
		guard += 1
		var spot := _square(rng) if cover_floor else _point(rng, inner, outer)
		if cover_floor:
			if not _on_grass(spot):
				continue
		elif _blocked(spot):
			continue
		var yaw := rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
		multi.set_instance_transform(placed, Transform3D(basis, Vector3(spot.x, -min_y * scale, spot.z)))
		placed += 1
	multi.visible_instance_count = placed


static func _place_scene(root: Node3D, file_name: String, spot: Vector3, target_height: float, solid: bool, trunk: float) -> void:
	for side in _sides(spot):
		var node := _instance(file_name)
		if node == null:
			return
		var box := _bounds(node)
		var scale := 1.0
		if target_height > 0.1 and box.size.y > 0.001:
			scale = target_height / box.size.y
		node.scale = Vector3.ONE * scale
		node.position = Vector3(side.x, -box.position.y * scale, side.z)
		node.rotation.y = side.x * 0.15 + side.z * 0.05
		_shadows(node, solid)
		root.add_child(node)
		if solid:
			_collider(root, node.position, box, scale, trunk)


static func _collider(root: Node3D, at: Vector3, box: AABB, scale: float, trunk: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_PROPS
	body.collision_mask = 0
	body.position = Vector3(at.x, 0.0, at.z)
	var shape_node := CollisionShape3D.new()
	if trunk > 0.0:
		var shape := CylinderShape3D.new()
		shape.radius = trunk
		shape.height = 2.2
		shape_node.shape = shape
		shape_node.position = Vector3(0.0, 1.1, 0.0)
	else:
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.size.x * scale * 0.62, box.size.y * scale * 0.75, box.size.z * scale * 0.62)
		shape_node.shape = shape
		shape_node.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	body.add_child(shape_node)
	root.add_child(body)


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


static func _on_grass(spot: Vector3) -> bool:
	if not ArenaMath.contains(Vector2(spot.x, spot.z), 37.0):
		return false
	if absf(spot.x) > 34.0 and absf(spot.z) < 4.5:
		return false
	return true


static func _point(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	var radius := rng.randf_range(inner, outer)
	var angle := rng.randf() * TAU
	return Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)


static func _blocked(spot: Vector3) -> bool:
	if not ArenaMath.contains(Vector2(spot.x, spot.z), 36.0):
		return true
	if absf(spot.z) < 5.5:
		return true
	if spot.length() < 8.0:
		return true
	if absf(spot.x) > 30.0 and absf(spot.z) < 9.0:
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
