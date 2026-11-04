extends Node

## Eye-level look along the dirt road, for checking the forest against the reference.


func _ready() -> void:
	var layout := MatchMap.prepare(load("res://data/arena_layouts/octagon_ring_v1.tres") as ArenaLayout)
	var arena := ArenaBuilder.build(layout, false)
	add_child(arena)
	ArtDressing.attach(arena)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 55.0
	add_child(camera)
	camera.position = Vector3(-18.0, 22.0, 36.0)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
