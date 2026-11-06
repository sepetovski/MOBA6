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


func test_cover_fades_when_an_enemy_is_behind_it() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 8.0)
	var focus := Node3D.new()
	var tree := Node3D.new()
	tree.position = Vector3(0.0, 0.0, 2.0)
	var leaves := MeshInstance3D.new()
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(2.0, 4.0, 1.0)
	leaves.mesh = leaf_mesh
	leaves.position = Vector3(0.0, 2.0, 0.0)
	tree.add_child(leaves)
	tree.add_to_group(&"cover_fade")
	var beside := Node3D.new()
	beside.position = Vector3(8.0, 0.0, 2.0)
	var other := MeshInstance3D.new()
	var other_mesh := BoxMesh.new()
	other_mesh.size = Vector3(1.0, 2.0, 1.0)
	other.mesh = other_mesh
	other.position = Vector3(0.0, 1.0, 0.0)
	beside.add_child(other)
	beside.add_to_group(&"cover_fade")
	var fader := OcclusionFader.new()
	add_child_autofree(camera)
	add_child_autofree(focus)
	add_child_autofree(tree)
	add_child_autofree(beside)
	add_child_autofree(fader)
	var profile := CameraProfile.new()
	profile.occlusion_fade_speed = 100.0
	profile.cover_transparency = 0.5
	fader.bind(camera, focus, profile)
	fader._forced_samples = PackedVector3Array([Vector3(0.0, 1.2, -3.0)])
	fader._process(1.0)
	assert_almost_eq(leaves.transparency, 0.5, 0.001)
	assert_eq(other.transparency, 0.0)


func test_you_fade_the_cover_in_front_of_the_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 8.0)
	var focus := Node3D.new()
	focus.position = Vector3(0.0, 0.0, -2.0)
	var box := _box("Cover", Vector3(0.0, 1.5, 2.0), Vector3(2.0, 3.0, 1.0))
	box.add_to_group(&"cover_fade")
	var beside := _box("Beside", Vector3(8.0, 1.5, 2.0), Vector3(1.0, 2.0, 1.0))
	beside.add_to_group(&"cover_fade")
	beside.transparency = 0.5
	var fader := OcclusionFader.new()
	add_child_autofree(camera)
	add_child_autofree(focus)
	add_child_autofree(fader)
	var profile := CameraProfile.new()
	profile.cover_fade_speed = 100.0
	profile.cover_transparency = 0.5
	profile.sample_heights_m = PackedFloat32Array([1.0])
	fader.bind(camera, focus, profile)
	fader._process(1.0)
	assert_almost_eq(box.transparency, 0.5, 0.001)
	assert_eq(beside.transparency, 0.0)


func test_prepared_cover_fades_alpha_without_a_pipeline_switch() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 8.0)
	var focus := Node3D.new()
	focus.position = Vector3(0.0, 0.0, -2.0)
	var leaves := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 4.0, 1.0)
	leaves.mesh = mesh
	leaves.position = Vector3(0.0, 2.0, 2.0)
	var cutout := StandardMaterial3D.new()
	cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cutout.alpha_scissor_threshold = 0.2
	cutout.albedo_color = Color(0.2, 0.55, 0.2, 1.0)
	leaves.material_override = cutout
	leaves.add_to_group(&"cover_fade")
	OcclusionFader.prepare_cover(leaves)
	var faded := leaves.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(faded)
	assert_eq(faded.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH)
	assert_eq(faded.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY)
	assert_almost_eq(faded.albedo_color.a, 1.0, 0.001)
	var fader := OcclusionFader.new()
	add_child_autofree(camera)
	add_child_autofree(focus)
	add_child_autofree(leaves)
	add_child_autofree(fader)
	var profile := CameraProfile.new()
	profile.cover_fade_speed = 100.0
	profile.cover_transparency = 0.5
	profile.sample_heights_m = PackedFloat32Array([1.2])
	fader.bind(camera, focus, profile)
	fader._process(1.0)
	assert_almost_eq(faded.albedo_color.a, 0.5, 0.001)
	assert_eq(leaves.transparency, 0.0)


func test_outer_branches_do_not_count_as_behind() -> void:
	var tree := Node3D.new()
	add_child_autofree(tree)
	tree.set_meta(&"cover_bounds", AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 5.0, 1.2)))
	var wide := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(10.0, 6.0, 10.0)
	wide.mesh = mesh
	wide.position = Vector3(0.0, 3.0, 0.0)
	tree.add_child(wide)
	var grazed := OcclusionFader.find_cover(Vector3(3.0, 2.0, 8.0), PackedVector3Array([Vector3(3.0, 1.0, -8.0)]), [tree])
	var through := OcclusionFader.find_cover(Vector3(0.0, 2.0, 8.0), PackedVector3Array([Vector3(0.0, 1.0, -8.0)]), [tree])
	assert_eq(grazed.size(), 0)
	assert_eq(through.size(), 1)


func test_flyover_does_not_fade_cover() -> void:
	var rig := MobaCamera.new()
	var focus := Node3D.new()
	focus.position = Vector3(0.0, 0.0, -2.0)
	var box := _box("Cover", Vector3(0.0, 1.5, 2.0), Vector3(2.0, 3.0, 1.0))
	box.add_to_group(&"cover_fade")
	var fader := OcclusionFader.new()
	add_child_autofree(rig)
	add_child_autofree(focus)
	add_child_autofree(fader)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 4.0, 8.0)
	rig.add_child(cam)
	var profile := CameraProfile.new()
	profile.cover_fade_speed = 100.0
	profile.cover_transparency = 0.75
	profile.sample_heights_m = PackedFloat32Array([1.0])
	fader.bind(cam, focus, profile)
	rig.present(Vector3.ZERO, 40.0, true)
	fader._process(1.0)
	assert_eq(box.transparency, 0.0)
	rig.set_presenting(false)
	fader._process(1.0)
	assert_almost_eq(box.transparency, 0.75, 0.001)


func _box(node_name: String, at: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = at
	add_child_autofree(mesh_node)
	return mesh_node
