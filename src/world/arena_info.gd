class_name ArenaInfo extends Node

var _layout: ArenaLayout

func setup(layout: ArenaLayout) -> void:
	_layout = layout

func get_spawn_slot(team: int, slot: int) -> Transform3D:
	var row := int(slot / 3)
	var col := slot % 3
	var z := float(col - 1) * 2.0
	# The deep test tunnel fits the old 44 m / 46 m rows. A short match tunnel
	# clamps both rows so the back three are not inside the back wall.
	var preferred := _layout.apothem + 4.0 + 2.0 * float(row)
	var inner_limit := _layout.apothem + _layout.wall_thickness + 1.5
	var outer_face := _layout.apothem + _layout.wall_thickness + float(_layout.stand_rows) * _layout.stand_row_depth
	var outer_limit := outer_face - 1.2
	var along := preferred
	if preferred > outer_limit or preferred < inner_limit:
		var t := 0.28 if row == 0 else 0.78
		along = lerpf(inner_limit, maxf(outer_limit, inner_limit), t)
	var x: float
	var yaw: float
	if team == Team.Id.A:
		x = -along
		yaw = -90.0
	else:
		x = along
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

func get_apothem() -> float:
	return _layout.apothem

func contains_xz(point: Vector2) -> bool:
	return ArenaMath.contains(point, _layout.apothem)

func allows(point: Vector3) -> bool:
	if point.y <= -1.0 or point.y >= 8.0:
		return false
	if contains_xz(Vector2(point.x, point.z)):
		return true
	var gate := _layout.apothem
	var mouth := _layout.gate_width * 0.55
	var outer := gate + _layout.wall_thickness + _layout.gate_depth + 1.5
	return absf(point.z) <= mouth and absf(point.x) >= gate - 2.5 and absf(point.x) <= outer
