class_name CrowdRenderer extends Node3D

## One MultiMesh of low-poly capsules. Bob phase comes from INSTANCE_ID.
## set_density and set_excitement are for later match events.

const MAX_INSTANCES := 3000
const CAPSULE_RADIUS := 0.22
const CAPSULE_HEIGHT := 0.7

var _material: ShaderMaterial
var _multi: MultiMeshInstance3D
var _capacity := 0

func build(layout: ArenaLayout) -> void:
	name = "Crowd"
	_material = _make_material()
	var mesh := CapsuleMesh.new()
	mesh.radius = CAPSULE_RADIUS
	mesh.height = CAPSULE_HEIGHT
	mesh.radial_segments = 6
	mesh.rings = 2
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	var poses := _seats(layout)
	_capacity = poses.size()
	multi.instance_count = _capacity
	for index in _capacity:
		multi.set_instance_transform(index, poses[index])
	multi.visible_instance_count = _capacity
	_multi = MultiMeshInstance3D.new()
	_multi.multimesh = multi
	_multi.material_override = _material
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)

func set_density(density: float) -> void:
	if _multi == null or _multi.multimesh == null:
		return
	var clamped := clampf(density, 0.0, 1.0)
	_multi.multimesh.visible_instance_count = int(round(_capacity * clamped))

func set_excitement(excitement: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("excitement", clampf(excitement, 0.0, 1.0))

func instance_count() -> int:
	return _capacity

func _seats(layout: ArenaLayout) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	var spacing := layout.crowd_spacing
	for row in layout.stand_rows:
		var apothem := layout.apothem + layout.wall_thickness + layout.stand_row_depth * (float(row) + 0.5)
		var height := layout.wall_height + layout.stand_row_rise * (float(row) + 1.0)
		var ring := ArenaMath.vertices(apothem)
		for edge in ring.size():
			var start: Vector2 = ring[edge]
			var finish: Vector2 = ring[(edge + 1) % ring.size()]
			var length := start.distance_to(finish)
			var steps := maxi(int(floor(length / spacing)), 1)
			for step in steps:
				var t := (float(step) + 0.5) / float(steps)
				var xz := start.lerp(finish, t)
				if _in_tunnel(xz, layout):
					continue
				poses.append(_pose(xz, height))
	if poses.size() > MAX_INSTANCES:
		var stride := int(ceil(float(poses.size()) / float(MAX_INSTANCES)))
		var trimmed: Array[Transform3D] = []
		var index := 0
		while index < poses.size():
			trimmed.append(poses[index])
			index += stride
		return trimmed
	return poses

func _in_tunnel(xz: Vector2, layout: ArenaLayout) -> bool:
	var half_gate := layout.gate_width * 0.5
	var inner := layout.apothem
	return absf(xz.y) < half_gate and absf(xz.x) > inner - 0.05

func _pose(xz: Vector2, height: float) -> Transform3D:
	var look := Vector3(-xz.x, 0.0, -xz.y)
	if look.length_squared() < 0.001:
		look = Vector3(0, 0, -1)
	var basis := Basis.looking_at(look.normalized(), Vector3.UP)
	var origin := Vector3(xz.x, height + CAPSULE_HEIGHT * 0.5, xz.y)
	return Transform3D(basis, origin)

func _make_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform float excitement = 0.3;
uniform vec3 albedo = vec3(0.50);
void vertex() {
	float phase = float(INSTANCE_ID) * 0.37;
	VERTEX.y += sin(TIME * (1.5 + excitement * 3.0) + phase) * (0.02 + excitement * 0.06);
}
void fragment() {
	ALBEDO = albedo;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("excitement", 0.3)
	material.set_shader_parameter("albedo", Color(0.50, 0.50, 0.50))
	return material
