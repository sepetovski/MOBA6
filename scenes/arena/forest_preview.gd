extends Node

## Eye-level look along the dirt road, for checking the forest against the reference.


func _ready() -> void:
	var layout := load("res://data/arena_layouts/octagon_ring_v1.tres") as ArenaLayout
	var arena := ArenaBuilder.build(layout, false)
	add_child(arena)
	ArtDressing.attach(arena)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 52.0
	add_child(camera)
	camera.position = Vector3(-8.0, 1.6, 2.4)
	camera.look_at(Vector3(10.0, 1.4, -1.2), Vector3.UP)
