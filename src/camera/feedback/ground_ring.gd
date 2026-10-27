class_name GroundRing extends Node3D

## Flat annulus. Unshaded, no collision, no shadows.
## attach_to snaps the local transform in _physics_process so interpolation can smooth it.
## The unit origin is treated as the feet (ADR-007).

var _material: StandardMaterial3D
var _mesh_node: MeshInstance3D
var _follow: Node3D
var _lift := 0.0
var _normal := Vector3.UP


func _ready() -> void:
	_assemble()
	set_physics_process(_follow != null)


func _assemble() -> void:
	if _mesh_node != null:
		return
	_mesh_node = MeshInstance3D.new()
	_mesh_node.name = "Ring"
	_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_receive_shadows = true
	_mesh_node.material_override = _material
	add_child(_mesh_node)


func configure(radius: float, thickness: float, color: Color, alpha := 1.0) -> void:
	_assemble()
	_mesh_node.mesh = _annulus(radius, thickness)
	_material.albedo_color = Color(color.r, color.g, color.b, alpha)


func set_alpha(alpha: float) -> void:
	if _material == null:
		return
	var color := _material.albedo_color
	color.a = alpha
	_material.albedo_color = color


func set_surface_lift(lift: float) -> void:
	_lift = lift


func attach_to(unit: Node3D) -> void:
	_follow = unit
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_INHERIT
	if get_parent() != unit:
		if get_parent() != null:
			get_parent().remove_child(self)
		unit.add_child(self)
	set_physics_process(true)


func place_at(point: Vector3, normal := Vector3.UP) -> void:
	_follow = null
	set_physics_process(false)
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	_normal = _safe_normal(normal)
	global_transform = Transform3D(_basis_from_normal(_normal), point + _normal * _lift)


func _physics_process(_delta: float) -> void:
	if _follow == null or not is_instance_valid(_follow):
		return
	var ground := _ground_under(_follow)
	var ground_position := ground.position as Vector3
	var ground_normal := ground.normal as Vector3
	var lifted := ground_position + ground_normal * _lift
	var local_point := _follow.to_local(lifted)
	var local_basis := _follow.global_transform.basis.inverse() * _basis_from_normal(ground_normal)
	transform = Transform3D(local_basis, local_point)


func _ground_under(unit: Node3D) -> Dictionary:
	var origin := unit.global_position
	var fallback := {
		"position": Vector3(origin.x, 0.0, origin.z),
		"normal": Vector3.UP,
	}
	var world := unit.get_world_3d()
	if world == null:
		return fallback
	var from := origin + Vector3.UP * 4.0
	var to := origin + Vector3.DOWN * 40.0
	var query := PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback
	return {"position": hit.position, "normal": _safe_normal(hit.normal)}


func _annulus(radius: float, thickness: float) -> ArrayMesh:
	var outer := maxf(radius, 0.01)
	var inner := clampf(outer - thickness, 0.0, outer)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 48
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var inner0 := Vector3(sin(a0) * inner, 0.0, cos(a0) * inner)
		var outer0 := Vector3(sin(a0) * outer, 0.0, cos(a0) * outer)
		var inner1 := Vector3(sin(a1) * inner, 0.0, cos(a1) * inner)
		var outer1 := Vector3(sin(a1) * outer, 0.0, cos(a1) * outer)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(inner0)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(outer0)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(outer1)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(inner0)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(outer1)
		tool.set_normal(Vector3.UP)
		tool.add_vertex(inner1)
	return tool.commit()


static func _basis_from_normal(normal: Vector3) -> Basis:
	var up := _safe_normal(normal)
	var helper := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis := helper.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	return Basis(x_axis, up, z_axis)


static func _safe_normal(normal: Vector3) -> Vector3:
	if normal.length_squared() < 0.0001:
		return Vector3.UP
	return normal.normalized()
