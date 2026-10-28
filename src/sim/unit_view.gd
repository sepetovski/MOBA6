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


func _process(_delta: float) -> void:
	if _unit != null:
		visible = _unit.state.alive
