extends SceneTree

## Builds scenes/main.tscn: an empty gray world for the M0 screenshot. M4 replaces it.

func _init() -> void:
	var root := Node3D.new()
	root.name = "Main"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.78, 0.78, 0.8)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_adopt(root, root, world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	_adopt(root, root, sun)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	mesh_instance.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.42, 0.42)
	material.albedo_texture = _grid_texture()
	material.uv1_scale = Vector3(40, 40, 1)
	mesh_instance.material_override = material
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	shape_node.shape = box
	shape_node.position = Vector3(0, -0.1, 0)
	_adopt(root, root, floor_body)
	_adopt(root, floor_body, mesh_instance)
	_adopt(root, floor_body, shape_node)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 40.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var pitch := deg_to_rad(55.0)
	var distance := 22.0
	camera.position = Vector3(0.0, distance * sin(pitch), distance * cos(pitch))
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	_adopt(root, root, camera)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("pack failed: %s" % error_string(pack_err))
		quit(1)
		return
	var save_err := ResourceSaver.save(packed, "res://scenes/main.tscn")
	if save_err != OK:
		push_error("save failed: %s" % error_string(save_err))
		quit(1)
		return
	print("build_placeholder_main: saved")
	root.free()
	quit(0)

func _grid_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.42, 0.42, 0.42))
	var line := Color(0.28, 0.28, 0.28)
	for i in 64:
		image.set_pixel(i, 0, line)
		image.set_pixel(i, 1, line)
		image.set_pixel(0, i, line)
		image.set_pixel(1, i, line)
	return ImageTexture.create_from_image(image)

func _adopt(scene_root: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root
