extends Node3D

## Bakes the navigation mesh once the colliders are in the tree.
## bake_navigation_mesh() is asynchronous: wait for bake_finished, then two physics frames.

signal navigation_ready

func _ready() -> void:
	var region := get_node_or_null("Navigation") as NavigationRegion3D
	if region == null:
		navigation_ready.emit()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var map := region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, 0.2)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	# A bool captured by a lambda is not updated. A dictionary is.
	# Threaded bakes emit bake_finished; the synchronous call fills the resource but never syncs the map.
	var state := {"done": false}
	region.bake_finished.connect(func() -> void: state["done"] = true)
	region.bake_navigation_mesh(true)
	var started := Time.get_ticks_msec()
	while not state["done"] and Time.get_ticks_msec() - started < 20000:
		await get_tree().process_frame
	if not state["done"]:
		push_error("navigation bake timed out")
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation_ready.emit()
