class_name ArenaInfo extends Node

var _layout: ArenaLayout

func setup(layout: ArenaLayout) -> void:
	_layout = layout

func get_spawn_slot(team: int, slot: int) -> Transform3D:
	var row := int(slot / 3)
	var col := slot % 3
	var z := float(col - 1) * 2.0
	var x: float
	var yaw: float
	if team == Team.Id.A:
		x = -44.0 - 2.0 * float(row)
		yaw = -90.0
	else:
		x = 44.0 + 2.0 * float(row)
		yaw = 90.0
	var basis := ArenaMath.yaw_to_basis(yaw)
	return Transform3D(basis, Vector3(x, 0.0, z))

func get_bounds() -> AABB:
	var verts := get_octagon_polygon()
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for vert in verts:
		min_x = minf(min_x, vert.x)
		max_x = maxf(max_x, vert.x)
		min_z = minf(min_z, vert.y)
		max_z = maxf(max_z, vert.y)
	return AABB(Vector3(min_x, 0.0, min_z), Vector3(max_x - min_x, 0.0, max_z - min_z))

func get_octagon_polygon() -> PackedVector2Array:
	return ArenaMath.vertices(_layout.apothem)

func contains_xz(point: Vector2) -> bool:
	return ArenaMath.contains(point, _layout.apothem)
