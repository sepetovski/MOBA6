class_name ForestLife extends Node3D

## Dust, petals and sun shafts. Presentation only, so it may use the wall clock.

var _motes: Array[MeshInstance3D] = []
var _origins: Array[Vector3] = []
var _shafts: Array[MeshInstance3D] = []
var _shaft_material: StandardMaterial3D


func _ready() -> void:
	_build_motes()
	_build_shafts()


func _process(_delta: float) -> void:
	var time := float(Time.get_ticks_msec()) * 0.001
	for index in _motes.size():
		var origin := _origins[index]
		var drift := Vector3(sin(time * 0.55 + float(index)), sin(time * 1.15 + float(index) * 0.37) * 0.45, cos(time * 0.42 + float(index) * 0.2))
		_motes[index].position = origin + drift
	if _shaft_material != null:
		var pulse := 0.055 + 0.03 * sin(time * 0.8)
		_shaft_material.albedo_color.a = pulse


func _build_motes() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.16
	mesh.radial_segments = 6
	mesh.rings = 3
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	paint.albedo_color = Color(1.0, 0.93, 0.62, 0.55)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for index in 26:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = paint
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spot := Vector3(rng.randf_range(-28.0, 28.0), rng.randf_range(0.35, 2.4), rng.randf_range(-26.0, 26.0))
		if absf(spot.z) < 2.2:
			spot.z += 4.0 * signf(spot.z + 0.01)
		mote.position = spot
		add_child(mote)
		_motes.append(mote)
		_origins.append(spot)


func _build_shafts() -> void:
	_shaft_material = StandardMaterial3D.new()
	_shaft_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shaft_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shaft_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shaft_material.albedo_color = Color(1.0, 0.96, 0.78, 0.11)
	_shaft_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shaft_material.disable_receive_shadows = true
	var spots: Array[Vector3] = [
		Vector3(-18.0, 11.0, -8.0),
		Vector3(-6.0, 12.0, 6.0),
		Vector3(8.0, 11.5, -14.0),
		Vector3(20.0, 10.5, 4.0),
		Vector3(2.0, 13.0, 16.0),
		Vector3(-26.0, 10.0, 14.0),
	]
	for spot in spots:
		var quad := BoxMesh.new()
		quad.size = Vector3(2.2, 26.0, 0.04)
		var shaft := MeshInstance3D.new()
		shaft.mesh = quad
		shaft.material_override = _shaft_material
		shaft.position = spot
		shaft.rotation_degrees = Vector3(-58.0, -24.0, 8.0)
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shaft)
		_shafts.append(shaft)
