class_name PlaceholderUnitView extends Node3D

## Read-only stand-in for UnitView. M4 wraps this. Grey capsule, nose on −Z,
## squash for crouch and slide, tilt for slide, stretch while rising.
## The blob shadow and landing marker are how a top-down camera reads height.

var _body: CharacterBody3D
var _motor: MovementMotor
var _pivot: Node3D
var _mesh: MeshInstance3D
var _capsule: CapsuleMesh
var _nose: MeshInstance3D
var _shadow: MeshInstance3D
var _marker: MeshInstance3D


func bind(unit: CharacterBody3D) -> void:
	_body = unit
	_motor = unit.get("motor") as MovementMotor
	_build()


func _build() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Visual"
	add_child(_pivot)
	_capsule = CapsuleMesh.new()
	_capsule.radial_segments = 16
	_capsule.rings = 4
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _capsule
	_mesh.material_override = _mat(Color(0.82, 0.82, 0.82))
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_pivot.add_child(_mesh)
	_nose = MeshInstance3D.new()
	_nose.mesh = BoxMesh.new()
	(_nose.mesh as BoxMesh).size = Vector3(0.16, 0.16, 0.28)
	_nose.material_override = _mat(Color(0.45, 0.45, 0.45))
	_pivot.add_child(_nose)
	_shadow = _disc(0.42, Color(0.0, 0.0, 0.0, 0.45))
	add_child(_shadow)
	_marker = _ring()
	add_child(_marker)


func _process(_delta: float) -> void:
	if _motor == null or _body == null:
		return
	var profile := _motor.profile
	var height := profile.height_stand
	if _motor.state == MovementMotor.State.CROUCHED:
		height = profile.height_crouch
	elif _motor.state == MovementMotor.State.SLIDING:
		height = profile.height_slide
	if _motor.state == MovementMotor.State.AIRBORNE and _body.velocity.y > 0.0:
		height *= profile.rise_stretch
	_capsule.radius = profile.radius
	_capsule.height = maxf(height, profile.radius * 2.0)
	_mesh.position = Vector3(0.0, _capsule.height * 0.5, 0.0)
	_nose.position = Vector3(0.0, _capsule.height * 0.62, -(profile.radius + 0.12))
	_pivot.rotation.x = deg_to_rad(-profile.slide_tilt_deg) if _motor.state == MovementMotor.State.SLIDING else 0.0
	_place_aids(profile)


func _place_aids(profile: MovementProfile) -> void:
	var below := _ray_down(_body.global_position)
	if below.is_empty():
		_shadow.visible = false
	else:
		_shadow.visible = true
		var hit: Vector3 = below.position
		_shadow.global_position = hit + Vector3.UP * 0.03
		var drop := maxf(_body.global_position.y - hit.y, 0.0)
		var scale := clampf(1.0 - drop / 8.0, 0.28, 1.0)
		_shadow.scale = Vector3(scale, 1.0, scale)
	var landing := _landing_point(profile)
	var ground := _ray_down(landing)
	if ground.is_empty():
		_marker.visible = false
		return
	_marker.visible = true
	_marker.global_position = ground.position + Vector3.UP * 0.04


func _landing_point(profile: MovementProfile) -> Vector3:
	var origin := _body.global_position
	var velocity := _body.velocity
	if Vector2(velocity.x, velocity.z).length() < 0.15:
		return origin
	if _motor.state != MovementMotor.State.AIRBORNE and _motor.state != MovementMotor.State.VAULTING and _motor.state != MovementMotor.State.MANTLING:
		return origin
	var point := origin
	var speed := velocity
	var step := 0.03
	for _i in 50:
		var gravity := profile.gravity * (profile.fall_gravity_mult if speed.y <= 0.0 else 1.0)
		speed.y -= gravity * step
		point += speed * step
		if speed.y <= 0.0:
			var hit := _ray_down(point)
			if not hit.is_empty() and hit.position.y >= point.y - 0.35 and hit.position.y <= point.y + 0.05:
				return hit.position
	return origin


func _ray_down(from: Vector3) -> Dictionary:
	var space := _body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.05, from + Vector3.DOWN * 40.0, GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS)
	query.exclude = [_body.get_rid()]
	return space.intersect_ray(query)


func _disc(radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := _mat(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _ring() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.34
	mesh.outer_radius = 0.46
	mesh.rings = 8
	mesh.ring_segments = 24
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := _mat(Color(0.92, 0.92, 0.92, 0.9))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
