class_name HealingGrove extends Node3D

## A patch of growing grass. The simulation heals units standing inside it.

var team := -1
var radius := 6.0
var heal_per_second := 16.0

var _blades: MultiMesh
var _motes: MultiMesh
var _spots: Array[Vector3] = []
var _mote_spots: Array[Vector3] = []
var _disc: MeshInstance3D


func configure(at: Vector3, zone_radius: float, team_id: int, rate: float) -> void:
	position = at
	radius = zone_radius
	team = team_id
	heal_per_second = rate
	name = "Grove%s" % ("All" if team_id < 0 else ("A" if team_id == Team.Id.A else "B"))
	_dress()


func covers(point: Vector3) -> bool:
	var flat := point - global_position
	flat.y = 0.0
	return flat.length() <= radius


func _dress() -> void:
	var tint := Color(0.22, 0.78, 0.28)
	if team == Team.Id.A:
		tint = Color(0.28, 0.86, 0.48)
	elif team == Team.Id.B:
		tint = Color(0.45, 0.82, 0.22)
	else:
		tint = Color(0.55, 0.95, 0.28)
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 0.92
	disc.height = 0.06
	_disc.mesh = disc
	_disc.position = Vector3(0, 0.04, 0)
	var fill := StandardMaterial3D.new()
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = Color(tint.r, tint.g, tint.b, 0.38)
	_disc.material_override = fill
	add_child(_disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.28
	torus.outer_radius = radius + 0.05
	ring.mesh = torus
	ring.position = Vector3(0, 0.07, 0)
	var edge := StandardMaterial3D.new()
	edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge.albedo_color = Color(tint.r * 1.1, minf(tint.g + 0.12, 1.0), tint.b, 0.9)
	ring.material_override = edge
	add_child(ring)
	_blades = _field(48, radius * 0.92, tint, 0.08, 0.95, _spots)
	_motes = _field(14, radius * 0.75, Color(0.75, 1.0, 0.55), 0.12, 0.12, _mote_spots)


func _field(count: int, reach: float, color: Color, wide: float, tall: float, spots: Array[Vector3]) -> MultiMesh:
	var box := BoxMesh.new()
	box.size = Vector3(wide, tall, wide)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = color
	box.material = paint
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = count
	var view := MultiMeshInstance3D.new()
	view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.multimesh = multi
	add_child(view)
	for index in count:
		var angle := TAU * float(index) / float(count) + float(index) * 0.17
		var dist := reach * (0.18 + 0.78 * fposmod(float(index) * 0.37, 1.0))
		var spot := Vector3(sin(angle) * dist, 0.0, cos(angle) * dist)
		spots.append(spot)
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, spot))
	return multi


func _process(_delta: float) -> void:
	if _blades == null:
		return
	var time := float(Time.get_ticks_msec()) * 0.001
	if _disc != null and _disc.material_override is StandardMaterial3D:
		var paint := _disc.material_override as StandardMaterial3D
		var pulse := 0.32 + 0.1 * sin(time * 1.6)
		paint.albedo_color.a = pulse
	for index in _spots.size():
		var growth := fposmod(time * 0.45 + float(index) * 0.13, 1.0)
		var height := lerpf(0.12, 1.25, growth)
		var spot := _spots[index]
		var basis := Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0))
		_blades.set_instance_transform(index, Transform3D(basis, Vector3(spot.x, height * 0.42, spot.z)))
	for index in _mote_spots.size():
		var rise := fposmod(time * 0.35 + float(index) * 0.2, 1.0)
		var spot := _mote_spots[index]
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * lerpf(0.35, 1.0, 1.0 - rise))
		_motes.set_instance_transform(index, Transform3D(basis, Vector3(spot.x, 0.2 + rise * 1.8, spot.z)))
