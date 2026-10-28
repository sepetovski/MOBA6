extends GutTest


func test_find_occluders_returns_only_the_segment_hits() -> void:
	var from := Vector3(0.0, 2.0, 5.0)
	var samples := PackedVector3Array([Vector3(0.0, 1.0, 0.0)])
	var blocker := _box("Blocker", Vector3(0.0, 1.5, 2.5), Vector3(1.0, 2.0, 1.0))
	var beside := _box("Beside", Vector3(6.0, 1.5, 2.5), Vector3(1.0, 1.0, 1.0))
	var behind := _box("Behind", Vector3(0.0, 1.5, 8.0), Vector3(1.0, 1.0, 1.0))
	var ignored := Node3D.new()
	add_child_autofree(ignored)
	var found := OcclusionFader.find_occluders(from, samples, [blocker, beside, behind, ignored])
	assert_eq(found.size(), 1)
	assert_same(found[0], blocker)


func test_clear_instance_returns_to_exact_zero() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 5.0)
	var focus := Node3D.new()
	var box := _box("Clear", Vector3(8.0, 1.0, 0.0), Vector3.ONE)
	box.transparency = 0.4
	box.add_to_group(&"occluder_fade")
	var fader := OcclusionFader.new()
	add_child_autofree(camera)
	add_child_autofree(focus)
	add_child_autofree(fader)
	var profile := CameraProfile.new()
	profile.occlusion_fade_speed = 100.0
	profile.occluded_transparency = 0.75
	fader.bind(camera, focus, profile)
	fader._process(1.0)
	assert_eq(box.transparency, 0.0)


func test_feedback_scripts_build_a_ring() -> void:
	var ring := GroundRing.new()
	add_child_autofree(ring)
	ring.configure(0.75, 0.1, Color(0.25, 0.55, 0.95), 1.0)
	var mesh := ring.get_node("Ring") as MeshInstance3D
	assert_not_null(mesh.mesh)
	var marker := ClickMarker.new()
	add_child_autofree(marker)
	marker.play(Vector3(1.0, 0.0, 2.0), Vector3.UP, 0.4, 0.3, 1.0, Color.WHITE, 0.02)
	assert_true(marker.active)
	var feedback := InputFeedback.new()
	add_child_autofree(feedback)
	feedback._process(0.016)


func test_blocking_instance_eases_toward_the_profile() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 5.0)
	var focus := Node3D.new()
	var box := _box("Blocker", Vector3(0.0, 1.2, 2.5), Vector3(2.0, 3.0, 1.0))
	box.add_to_group(&"occluder_fade")
	var fader := OcclusionFader.new()
	add_child_autofree(camera)
	add_child_autofree(focus)
	add_child_autofree(fader)
	var profile := CameraProfile.new()
	profile.occlusion_fade_speed = 0.2
	profile.occluded_transparency = 0.75
	profile.sample_heights_m = PackedFloat32Array([1.0])
	fader.bind(camera, focus, profile)
	fader._process(1.0)
	assert_almost_eq(box.transparency, 0.2, 0.001)


func _box(node_name: String, at: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = at
	add_child_autofree(mesh_node)
	return mesh_node
