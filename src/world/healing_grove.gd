class_name HealingGrove extends Node3D

## A pulsing ring. Presentation only, so the motion may use the wall clock.
## Standing inside still heals. The ring does not collide.

var team := -1
var radius := 6.0
var heal_per_second := 16.0

var _ring: MeshInstance3D
var _disc: MeshInstance3D
var _motes: MultiMesh
var _spots: Array[Vector3] = []


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


func _process(_delta: float) -> void:
	if _ring == null:
		return
	var time := float(Time.get_ticks_msec()) * 0.001
	var pulse := 0.55 + 0.45 * sin(time * 2.2)
	_ring.scale = Vector3(1.0, 1.0, 1.0) * (0.96 + 0.06 * pulse)
	_ring.position.y = 0.12 + 0.08 * pulse
	if _disc != null and _disc.material_override is StandardMaterial3D:
		var paint := _disc.material_override as StandardMaterial3D
		paint.albedo_color.a = 0.16 + 0.1 * pulse
	if _motes == null:
		return
	for index in _spots.size():
		var rise := fposmod(time * 0.35 + float(index) * 0.21, 1.0)
		var spot := _spots[index]
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * lerpf(0.45, 1.0, 1.0 - rise))
		_motes.set_instance_transform(index, Transform3D(basis, Vector3(spot.x, 0.25 + rise * 1.6, spot.z)))


func _dress() -> void:
	var tint := Color(0.45, 0.95, 0.55)
	if team == Team.Id.A:
		tint = Color(0.35, 0.7, 1.0)
	elif team == Team.Id.B:
		tint = Color(1.0, 0.45, 0.38)
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 0.92
	disc.height = 0.05
	_disc.mesh = disc
	_disc.position = Vector3(0.0, 0.04, 0.0)
	_disc.material_override = _glow(tint, 0.22)
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.28
	torus.outer_radius = radius + 0.08
	torus.rings = 24
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.position = Vector3(0.0, 0.16, 0.0)
	_ring.material_override = _glow(tint, 0.9)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 6
	mesh.rings = 3
	_motes = MultiMesh.new()
	_motes.transform_format = MultiMesh.TRANSFORM_3D
	_motes.mesh = mesh
	var count := 10
	_motes.instance_count = count
	var view := MultiMeshInstance3D.new()
	view.multimesh = _motes
	view.material_override = _glow(tint, 0.85)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	for index in count:
		var angle := TAU * float(index) / float(count)
		var spot := Vector3(cos(angle) * radius * 0.72, 0.3, sin(angle) * radius * 0.72)
		_spots.append(spot)
		_motes.set_instance_transform(index, Transform3D(Basis.IDENTITY, spot))


func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
