class_name OcclusionFader extends Node

## Fades GeometryInstance3D nodes in the occluder_fade group when they cross the
## camera-to-unit segment. Trees and boxes in cover_fade fade when an enemy is
## behind them. Transparency is per instance (Forward+). Any value above 0
## leaves the opaque pipeline, so only the blocking chunks are faded.
## Stencil silhouettes are skipped (ADR-010).

var _camera: Camera3D
var _focus: Node3D
var _profile: CameraProfile
var _sim: Simulation
## Tests fill this with enemy sample points. The match leaves it empty.
var _forced_samples := PackedVector3Array()


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
	var samples := _enemy_samples()
	var blocking: Array = []
	if _camera != null and not samples.is_empty():
		blocking = find_cover(_camera.global_position, samples, covers)
	var blocking_ids := {}
	for item in blocking:
		blocking_ids[(item as Object).get_instance_id()] = true
	var amount := _profile.cover_transparency
	for cover in covers:
		if cover == null or not is_instance_valid(cover):
			continue
		var target := amount if blocking_ids.has((cover as Object).get_instance_id()) else 0.0
		for geo in geometries(cover):
			var next := move_toward(geo.transparency, target, _profile.occlusion_fade_speed * delta)
			if target == 0.0 and next <= 0.0001:
				geo.transparency = 0.0
			else:
				geo.transparency = next


func _enemy_samples() -> PackedVector3Array:
	if not _forced_samples.is_empty():
		return _forced_samples
	var samples := PackedVector3Array()
	if _sim == null or _profile == null or not is_instance_valid(_sim):
		return samples
	var human := _sim.get_human()
	if human == null:
		return samples
	for unit in _sim.get_units():
		if unit == null or not is_instance_valid(unit) or not unit.state.alive:
			continue
		if unit.team == human.team:
			continue
		for height in _profile.sample_heights_m:
			samples.append(unit.global_position + Vector3(0.0, height, 0.0))
	return samples


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


## Covers are Node3D roots in the cover_fade group. A hit on any child mesh fades the whole object.
static func find_cover(from: Vector3, sample_points: PackedVector3Array, covers: Array) -> Array:
	var blocking: Array = []
	for cover in covers:
		if cover == null or not (cover is Node):
			continue
		var blocks := false
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
