class_name ArtDressing extends RefCounted

## Places the exported environment models around the ring.
## Trees stand near the wall, off the gates. The fridge is one breakable piece north of centre.

const TREE := "res://art/exports/environment/tree.glb"
const BIRCH := "res://art/exports/environment/birtch_winter.glb"
const FRIDGE := "res://art/exports/environment/fridge.glb"
const TREE_HEIGHT := 6.5
const BIRCH_HEIGHT := 5.2
const FRIDGE_HEIGHT := 2.2


static func attach(arena: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Dressing"
	arena.add_child(root)
	var index := 0
	for radius in [34.0, 22.0]:
		var count := 10 if radius > 30.0 else 8
		for step in count:
			var angle := TAU * float(step) / float(count) + (0.2 if radius < 30.0 else 0.0)
			var spot := Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
			if absf(spot.x) > 26.0 and absf(spot.z) < 8.0:
				continue
			var birch := index % 2 == 1
			var visual := _visual(BIRCH if birch else TREE, BIRCH_HEIGHT if birch else TREE_HEIGHT, true)
			index += 1
			if visual == null:
				continue
			visual.position = spot
			visual.rotation.y = angle
			root.add_child(visual)
			_trunk(root, spot)
	var fridge_spots := [Vector3(0, 0, -16), Vector3(16, 0, 14), Vector3(-16, 0, 12)]
	for spot in fridge_spots:
		var fridge := _visual(FRIDGE, FRIDGE_HEIGHT, false)
		if fridge == null:
			continue
		fridge.position = spot
		fridge.rotation.y = spot.x * 0.05
		fridge.set_meta("destructible", true)
		fridge.set_meta("health", 50.0)
		root.add_child(fridge)


static func _visual(path: String, height: float, visual_only: bool) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var box := _bounds(model)
	var scale := height / maxf(box.size.y, 0.001)
	var root := StaticBody3D.new() if not visual_only else Node3D.new()
	root.name = path.get_file().get_basename()
	if root is StaticBody3D:
		(root as StaticBody3D).collision_layer = GameConfig.LAYER_PROPS
		(root as StaticBody3D).collision_mask = 0
	model.scale = Vector3.ONE * scale
	model.position = Vector3(0, -box.position.y * scale, 0)
	root.add_child(model)
	if not visual_only:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(box.size.x, 0.4) * scale, height, maxf(box.size.z, 0.4) * scale)
		shape_node.shape = shape
		shape_node.position = Vector3(0, height * 0.5, 0)
		root.add_child(shape_node)
	return root


static func _trunk(parent: Node3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 2.2
	shape_node.shape = shape
	shape_node.position = Vector3(0, 1.1, 0)
	body.add_child(shape_node)
	parent.add_child(body)


static func _bounds(node: Node) -> AABB:
	var found := {"ok": false}
	return _walk(node, Transform3D.IDENTITY, AABB(), found)


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
