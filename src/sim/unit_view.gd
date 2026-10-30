class_name UnitView extends Node3D

## Read-only. Wraps the gray capsule. M8 swaps the mesh without touching the simulation.

var _placeholder: PlaceholderUnitView
var _unit: SimUnit
var _model_root: Node3D


func bind(unit: SimUnit) -> void:
	_unit = unit
	_placeholder = PlaceholderUnitView.new()
	_placeholder.name = "Placeholder"
	add_child(_placeholder)
	_placeholder.bind(unit)
	var model_path := str(unit.get_meta("character_model", ""))
	if model_path.is_empty():
		return
	if _attach_character(model_path):
		var capsule := _placeholder.get_node_or_null("Visual")
		if capsule != null:
			capsule.visible = false


func _attach_character(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		return false
	var box := ArtDressing._bounds(model)
	var scale := 1.8 / maxf(box.size.y, 0.001)
	var root := Node3D.new()
	root.name = "ModelRoot"
	# glTF faces +Z. Gameplay faces −Z, so turn the visual around once.
	root.rotation.y = PI
	model.scale = Vector3.ONE * scale
	model.position = Vector3(0.0, -box.position.y * scale, 0.0)
	root.add_child(model)
	add_child(root)
	_model_root = root
	_enable_shadows(model)
	if _placeholder != null:
		_placeholder.hide_blob()
	return true


func _enable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_shadows(child)


func play_swing() -> void:
	var model := get_node_or_null("ModelRoot") as Node3D
	if model == null:
		return
	var rest := model.rotation.y
	var tween := create_tween()
	tween.tween_property(model, "rotation:y", rest + 1.15, 0.07)
	tween.tween_property(model, "rotation:y", rest - 0.35, 0.06)
	tween.tween_property(model, "rotation:y", rest, 0.1)


func _process(delta: float) -> void:
	if _unit == null:
		return
	visible = _unit.state.alive
	_pose(delta)


func _pose(delta: float) -> void:
	if _model_root == null or _unit.motor == null:
		return
	var squash := 1.0
	var tilt := 0.0
	var lift := 0.0
	var state := _unit.motor.state
	if state == MovementMotor.State.CROUCHED:
		squash = 0.62
		tilt = 0.22
	elif state == MovementMotor.State.SLIDING:
		squash = 0.46
		tilt = 0.62
	elif state == MovementMotor.State.AIRBORNE:
		if _unit.velocity.y > 0.35:
			squash = 1.16
			lift = 0.16
		else:
			squash = 0.88
	var blend := clampf(delta * 12.0, 0.0, 1.0)
	_model_root.scale.y = lerpf(_model_root.scale.y, squash, blend)
	_model_root.rotation.x = lerpf(_model_root.rotation.x, tilt, blend)
	_model_root.position.y = lerpf(_model_root.position.y, lift, blend)
