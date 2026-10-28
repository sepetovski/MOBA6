class_name GateController extends Node

## Opens the gates when the match starts running. Presentation only.

var _doors: Array[StaticBody3D] = []
var _crowd: CrowdRenderer
var _seconds := 1.0


func bind(arena: Node3D, open_seconds: float) -> void:
	_seconds = open_seconds
	var parent := arena.get_node_or_null("GateDoors")
	if parent != null:
		for child in parent.get_children():
			if child is StaticBody3D:
				_doors.append(child)
	_crowd = arena.get_node_or_null("Crowd") as CrowdRenderer
	GameEvents.match_state_changed.connect(_on_state)


func _on_state(state: int) -> void:
	if state != Match.State.RUNNING:
		return
	for door in _doors:
		door.collision_layer = 0
		door.collision_mask = 0
		var tween := create_tween()
		tween.tween_property(door, "position:y", -4.0, _seconds)
	if _crowd != null:
		_crowd.set_excitement(1.0)
		var fade := create_tween()
		fade.tween_method(_crowd.set_excitement, 1.0, 0.3, 5.0)
