class_name UnitView extends Node3D

## Read-only. Wraps the gray capsule. M8 swaps the mesh without touching the simulation.

var _placeholder: PlaceholderUnitView
var _unit: SimUnit


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
	return true


func play_swing() -> void:
	var model := get_node_or_null("ModelRoot") as Node3D
	if model == null:
		return
	var rest := model.rotation.y
	var tween := create_tween()
	tween.tween_property(model, "rotation:y", rest + 1.15, 0.07)
	tween.tween_property(model, "rotation:y", rest - 0.35, 0.06)
	tween.tween_property(model, "rotation:y", rest, 0.1)


func _process(_delta: float) -> void:
	if _unit != null:
		visible = _unit.state.alive
