class_name UnitView extends Node3D

## Read-only. Wraps the gray capsule. M8 swaps the mesh without touching the simulation.

var _placeholder: PlaceholderUnitView


func bind(unit: SimUnit) -> void:
	_placeholder = PlaceholderUnitView.new()
	_placeholder.name = "Placeholder"
	add_child(_placeholder)
	_placeholder.bind(unit)
