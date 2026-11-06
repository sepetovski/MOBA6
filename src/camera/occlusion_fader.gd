class_name OcclusionFader extends Node

## Fades GeometryInstance3D nodes in the occluder_fade group when they cross the
## camera-to-unit segment. Trees and boxes in cover_fade fade when any character,
## including you, is behind their solid core. Outer branches do not count.
## The opening camera sweep does not fade anything. Alpha hash keeps the leaves
## in the opaque pass so overlapping branches do not sort against each other.
## Stencil silhouettes are skipped (ADR-010).

var _camera: Camera3D
var _focus: Node3D
var _profile: CameraProfile
var _sim: Simulation
## Tests fill this with character sample points. The match leaves it empty.
var _forced_samples := PackedVector3Array()
var _cover_hold: Dictionary = {}


func bind(cam: Camera3D, focus: Node3D, profile: CameraProfile) -> void:
	_camera = cam
	_focus = focus
	_profile = profile
	# After the camera, so this frame's focus pose is the one we test.
	process_priority = 10


func watch(sim: Simulation) -> void:
	_sim = sim


func _process(delta: float) -> void:
	if _camera == null or _focus == null or _profile == null:
		return
	if not is_instance_valid(_camera) or not is_instance_valid(_focus):
		return
	var samples := _samples(_focus.global_position, _profile)
	var nodes := get_tree().get_nodes_in_group(&"occluder_fade")
	var instances: Array = []
	for node in nodes:
		if node is GeometryInstance3D:
			instances.append(node)
	var blocking := find_occluders(_camera.global_position, samples, instances)
	var blocking_ids := {}
	for item in blocking:
		blocking_ids[(item as Object).get_instance_id()] = true
	for instance in instances:
		var geo := instance as GeometryInstance3D
		var target := 0.0
		if blocking_ids.has(geo.get_instance_id()):
			target = _profile.occluded_transparency
		var next := move_toward(geo.transparency, target, _profile.occlusion_fade_speed * delta)
		if target == 0.0 and next <= 0.0001:
			geo.transparency = 0.0
		else:
			geo.transparency = next
	_fade_covers(delta)


func _fade_covers(delta: float) -> void:
	var covers := get_tree().get_nodes_in_group(&"cover_fade")
	if covers.is_empty():
		return
	var blocking_ids := {}
	if _rig_is_presenting():
		_cover_hold.clear()
	else:
		var samples := _character_samples()
		if _camera != null and not samples.is_empty():
			for item in find_cover(_camera.global_position, samples, covers):
				blocking_ids[(item as Object).get_instance_id()] = true
	var amount := _profile.cover_transparency
	var hold := _profile.cover_hold_seconds
	for cover in covers:
		if cover == null or not is_instance_valid(cover):
			continue
		var id := (cover as Object).get_instance_id()
		var target := 0.0
		if blocking_ids.has(id):
			_cover_hold[id] = hold
			target = amount
		elif _cover_hold.has(id):
			var left := float(_cover_hold[id]) - delta
			if left > 0.0:
				_cover_hold[id] = left
				target = amount
			else:
				_cover_hold.erase(id)
		for geo in geometries(cover):
			_fade_geometry(geo, target, delta)


func _rig_is_presenting() -> bool:
	if _camera == null or not is_instance_valid(_camera):
		return false
	var rig := _camera.get_parent()
	return rig is MobaCamera and (rig as MobaCamera).is_presenting()


func _fade_geometry(geo: GeometryInstance3D, amount: float, delta: float) -> void:
	if geo is MeshInstance3D and (geo as MeshInstance3D).has_meta(&"cover_ready"):
		_fade_material(geo as MeshInstance3D, amount, delta)
		# Leave the instance on the opaque instance path. The material is already blended.
		if geo.transparency != 0.0:
			geo.transparency = 0.0
		return
	var next := move_toward(geo.transparency, amount, _profile.cover_fade_speed * delta)
	if amount == 0.0 and next <= 0.0001:
		geo.transparency = 0.0
	else:
		geo.transparency = next


func _fade_material(mesh_node: MeshInstance3D, amount: float, delta: float) -> void:
	var mesh := mesh_node.mesh
	if mesh == null:
		return
	var speed := _profile.cover_fade_speed
	for surface in mesh.get_surface_count():
		var mat := mesh_node.get_surface_override_material(surface) as BaseMaterial3D
		if mat == null:
			continue
		var base := float(mat.get_meta(&"cover_base_alpha", 1.0))
		var target := base * (1.0 - amount)
		var color := mat.albedo_color
		var next := move_toward(color.a, target, speed * delta)
		if is_equal_approx(next, color.a):
			continue
		color.a = next
		mat.albedo_color = color


func _character_samples() -> PackedVector3Array:
	if not _forced_samples.is_empty():
		return _forced_samples
	var samples := PackedVector3Array()
	if _profile == null:
		return samples
	var seen: Dictionary = {}
	if _focus != null and is_instance_valid(_focus):
		for height in _profile.sample_heights_m:
			samples.append(_focus.global_position + Vector3(0.0, height, 0.0))
		seen[_focus.get_instance_id()] = true
	if _sim == null or not is_instance_valid(_sim):
		return samples
	for unit in _sim.get_units():
		if unit == null or not is_instance_valid(unit) or not unit.state.alive:
			continue
		if seen.has(unit.get_instance_id()):
			continue
		seen[unit.get_instance_id()] = true
		for height in _profile.sample_heights_m:
			samples.append(unit.global_position + Vector3(0.0, height, 0.0))
	return samples


## Turns cutout leaves into alpha-hash materials once, while the map is built.
## Hash stays in the opaque pass, so branches do not flicker, and fading only
## changes how many pixels are kept.
static func prepare_cover(root: Node) -> void:
	for geo in geometries(root):
		if not geo is MeshInstance3D:
			continue
		var mesh_node := geo as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh == null:
			continue
		var ready := false
		for surface in mesh.get_surface_count():
			var active := mesh_node.get_active_material(surface)
			if active == null or not active is BaseMaterial3D:
				continue
			var copy := (active as BaseMaterial3D).duplicate() as BaseMaterial3D
			var base_alpha := copy.albedo_color.a
			if base_alpha <= 0.001:
				base_alpha = 1.0
			copy.set_meta(&"cover_base_alpha", base_alpha)
			var color := copy.albedo_color
			color.a = base_alpha
			copy.albedo_color = color
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			copy.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
			copy.alpha_hash_scale = 1.0
			mesh_node.set_surface_override_material(surface, copy)
			ready = true
		if ready:
			mesh_node.set_meta(&"cover_ready", true)
	if root is Node3D and (root as Node3D).is_inside_tree():
		(root as Node3D).set_meta(&"cover_bounds", _core_bounds(root as Node3D))


## Pure segment test. instances are GeometryInstance3D nodes (or anything with global_transform and get_aabb).
static func find_occluders(from: Vector3, sample_points: PackedVector3Array, instances: Array) -> Array:
	var blocking: Array = []
	for instance in instances:
		if instance == null or not (instance is GeometryInstance3D):
			continue
		var geo := instance as GeometryInstance3D
		var bounds := geo.global_transform * geo.get_aabb()
		var blocks := false
		for sample in sample_points:
			if bounds.intersects_segment(from, sample):
				blocks = true
				break
		if blocks:
			blocking.append(geo)
	return blocking


## Covers are Node3D roots in the cover_fade group. A stored core box ignores outer branches.
static func find_cover(from: Vector3, sample_points: PackedVector3Array, covers: Array) -> Array:
	var blocking: Array = []
	for cover in covers:
		if cover == null or not (cover is Node):
			continue
		var blocks := false
		if (cover as Node).has_meta(&"cover_bounds"):
			var bounds: AABB = (cover as Node).get_meta(&"cover_bounds")
			for sample in sample_points:
				if bounds.intersects_segment(from, sample):
					blocks = true
					break
		else:
			for geo in geometries(cover):
				var bounds := geo.global_transform * geo.get_aabb()
				for sample in sample_points:
					if bounds.intersects_segment(from, sample):
						blocks = true
						break
				if blocks:
					break
		if blocks:
			blocking.append(cover)
	return blocking


## Trees use the middle of the canopy. A lone box uses almost its whole mesh.
static func _core_bounds(root: Node3D) -> AABB:
	var merged := AABB()
	var has := false
	for geo in geometries(root):
		var bounds := geo.global_transform * geo.get_aabb()
		if not has:
			merged = bounds
			has = true
		else:
			merged = merged.merge(bounds)
	if not has:
		return AABB(root.global_position, Vector3.ONE)
	var box_like := root is MeshInstance3D and root.get_child_count() == 0
	var xz := 0.9 if box_like else 0.36
	var y_scale := 0.94 if box_like else 0.7
	var size := merged.size
	size.x = minf(maxf(size.x * xz, 0.8), merged.size.x)
	size.z = minf(maxf(size.z * xz, 0.8), merged.size.z)
	size.y = minf(maxf(size.y * y_scale, 1.2), merged.size.y)
	var pos := merged.position
	pos.x += (merged.size.x - size.x) * 0.5
	pos.z += (merged.size.z - size.z) * 0.5
	pos.y += (merged.size.y - size.y) * 0.2
	return AABB(pos, size)


static func geometries(node: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		found.append(node as GeometryInstance3D)
	for child in node.get_children():
		found.append_array(geometries(child))
	return found


static func _samples(origin: Vector3, profile: CameraProfile) -> PackedVector3Array:
	var samples := PackedVector3Array()
	for height in profile.sample_heights_m:
		samples.append(origin + Vector3(0.0, height, 0.0))
	return samples
