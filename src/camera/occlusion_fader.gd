class_name OcclusionFader extends Node

## Fades GeometryInstance3D nodes in the occluder_fade group when they cross the
## camera-to-unit segment. Transparency is per instance (Forward+). Any value
## above 0 leaves the opaque pipeline, so only the blocking chunks are faded.
## Stencil silhouettes are skipped (ADR-010).

var _camera: Camera3D
var _focus: Node3D
var _profile: CameraProfile


func bind(cam: Camera3D, focus: Node3D, profile: CameraProfile) -> void:
	_camera = cam
	_focus = focus
	_profile = profile
	# After the camera, so this frame's focus pose is the one we test.
	process_priority = 10


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


static func _samples(origin: Vector3, profile: CameraProfile) -> PackedVector3Array:
	var samples := PackedVector3Array()
	for height in profile.sample_heights_m:
		samples.append(origin + Vector3(0.0, height, 0.0))
	return samples
