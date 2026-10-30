class_name InputSandbox extends Node3D

## TEMP gym until M4. Builds the floor, crates, a gapped wall and chunked occluders.
## The stub that walks the navmesh lives in the scene file, not here, so this folder never moves a unit.

signal navigation_ready

var nav_is_ready := false

var _region: NavigationRegion3D


func _ready() -> void:
	_build_world()
	_build_units()
	_build_rig()
	_build_light()
	await _bake()
	nav_is_ready = true
	navigation_ready.emit()


func _build_world() -> void:
	_region = NavigationRegion3D.new()
	_region.name = "Navigation"
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.4
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.2
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS
	_region.navigation_mesh = mesh
	add_child(_region)

	_region.add_child(_box("Floor", Vector3(0.0, -0.1, 0.0), Vector3(48.0, 0.2, 48.0), GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK, 0.42))
	_region.add_child(_box("CrateA", Vector3(5.0, 0.5, 2.0), Vector3.ONE, GameConfig.LAYER_PROPS, 0.62))
	_region.add_child(_box("CrateB", Vector3(-6.0, 0.5, -3.0), Vector3.ONE, GameConfig.LAYER_PROPS, 0.62))
	_region.add_child(_box("CrateC", Vector3(4.0, 0.5, -5.0), Vector3.ONE, GameConfig.LAYER_PROPS, 0.62))
	# Gap is 2.5 m, wide enough for the 0.4 m nav agent. North of the spawn, so a click past it pathfinds through.
	_region.add_child(_box("WallWest", Vector3(-4.6, 0.5, -8.0), Vector3(6.7, 1.0, 0.6), GameConfig.LAYER_WORLD, 0.28))
	_region.add_child(_box("WallEast", Vector3(4.6, 0.5, -8.0), Vector3(6.7, 1.0, 0.6), GameConfig.LAYER_WORLD, 0.28))
	# South chunks sit on the camera-to-unit segment. Only the centre one should fade.
	_add_occluder("OccluderWest", Vector3(-2.4, 2.25, 1.6))
	_add_occluder("OccluderCentre", Vector3(0.0, 2.25, 1.6))
	_add_occluder("OccluderEast", Vector3(2.4, 2.25, 1.6))


func _add_occluder(node_name: String, center: Vector3) -> void:
	var body := _box(node_name, center, Vector3(2.0, 4.5, 0.5), GameConfig.LAYER_WORLD, 0.28)
	var mesh := body.get_node("Mesh") as MeshInstance3D
	mesh.add_to_group(&"occluder_fade")
	_region.add_child(body)


func _build_units() -> void:
	var unit := _capsule("Unit", 1, Vector3(0.0, 0.0, 0.0))
	add_child(unit)
	add_child(_capsule("OtherUnit", 2, Vector3(6.0, 0.0, -4.0)))


func _build_rig() -> void:
	var profile := load("res://data/camera_profiles/default.tres") as CameraProfile
	var camera := MobaCamera.new()
	camera.name = "MobaCamera"
	camera.profile = profile
	add_child(camera)
	var unit := get_node("Unit") as Node3D
	camera.follow(unit)
	camera.set_bounds(AABB(Vector3(-24.0, -1.0, -24.0), Vector3(48.0, 8.0, 48.0)))

	var controller := PlayerController.new()
	controller.name = "PlayerController"
	controller.settings = load("res://data/input_settings_default.tres") as InputSettings
	add_child(controller)
	var mover := get_node_or_null("StubMover")
	var sink := Callable()
	if mover != null and mover.has_method("receive"):
		sink = Callable(mover, "receive")
	controller.bind(1, camera, sink)

	var feedback := InputFeedback.new()
	feedback.name = "InputFeedback"
	add_child(feedback)
	feedback.bind(controller, camera, unit, profile)

	var fader := OcclusionFader.new()
	fader.name = "OcclusionFader"
	add_child(fader)
	fader.bind(camera.camera, unit, profile)

	var layer := CanvasLayer.new()
	layer.name = "Hint"
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "Right-click moves. Hold steers. S stop. Space jump. Shift dash. Ctrl crouch. Y unlocks the camera."
	layer.add_child(label)
	add_child(layer)


func _build_light() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.74, 0.75, 0.77)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.45, 0.45)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _bake() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var map := _region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, 0.2)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	var state := {"done": false}
	_region.bake_finished.connect(func() -> void: state["done"] = true)
	_region.bake_navigation_mesh(true)
	var started := Time.get_ticks_msec()
	while not state["done"] and Time.get_ticks_msec() - started < 20000:
		await get_tree().process_frame
	if not state["done"]:
		push_error("input sandbox navigation bake timed out")
		return
	await get_tree().physics_frame
	await get_tree().physics_frame


func _box(node_name: String, center: Vector3, size: Vector3, layer: int, albedo: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = GreyMaterials.get_material(albedo)
	body.add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	return body


func _capsule(node_name: String, unit_id: int, at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = node_name
	body.collision_layer = GameConfig.LAYER_UNITS
	body.collision_mask = 0
	body.position = at
	body.set_meta(&"unit_id", unit_id)
	body.set_meta(&"radius", 0.4)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.0
	mesh_node.mesh = mesh
	mesh_node.position = Vector3(0.0, 0.9, 0.0)
	mesh_node.material_override = GreyMaterials.get_material(0.82)
	body.add_child(mesh_node)
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.16, 0.16, 0.36)
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0, 1.25, -0.55)
	nose.material_override = GreyMaterials.get_material(0.7)
	body.add_child(nose)
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.0
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape_node)
	return body
