class_name LayoutGenerator extends RefCounted

## One seeded quadrant, mirrored across X = 0 and Z = 0.
## Yaw: X mirror negates, Z mirror is 180° − yaw, both is yaw + 180°.
## No negative scale. Wall-line gaps are 1.5 m because PLAN §4 beats the brief's 1.2 m example.

const CLUSTER_GAP := 2.5
const WALL_GAP := 1.5
const PLACEMENT_TRIES := 160

static func generate(layout_seed_value: int) -> ArenaLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed_value
	var layout := ArenaLayout.new()
	layout.layout_seed = layout_seed_value
	var quadrant: Array[PropPlacement] = []
	var clusters: Array[AABB] = []
	var required: Array[String] = ["wall_line", "wall_line", "wall_mid", "wall_mid", "tunnel_slide", "tunnel_crouch"]
	for kind in required:
		if not _place(quadrant, clusters, rng, kind):
			push_error("layout generator could not place required %s" % kind)
	var fillers: Array[String] = ["l_crates", "line_crates", "barrel_ring", "stack_stair", "pillars", "wall_high", "crate_l", "crate_flat_line"]
	var filler_index := 0
	var guard := 0
	while clusters.size() < 16 and guard < 40:
		guard += 1
		var kind: String = fillers[filler_index % fillers.size()]
		filler_index += 1
		if _place(quadrant, clusters, rng, kind):
			pass
	layout.props = _mirror_all(quadrant)
	_add_center(layout)
	print("layout seed %d: quadrant clusters %d, props %d, cover %.1f%%" % [
		layout_seed_value, clusters.size(), layout.props.size(), _cover_percent(layout)
	])
	return layout

static func _place(quadrant: Array[PropPlacement], clusters: Array[AABB], rng: RandomNumberGenerator, kind: String) -> bool:
	var local := _local_cluster(kind)
	for _attempt in PLACEMENT_TRIES:
		var origin := Vector3(rng.randf_range(6.0, 32.0), 0.0, -rng.randf_range(8.0, 32.0))
		var yaw := float(rng.randi_range(0, 3)) * 90.0
		var world := _transform_cluster(local, origin, yaw)
		var bounds := _union(world)
		if _excluded(bounds):
			continue
		if not _separated(bounds, clusters):
			continue
		for item in world:
			quadrant.append(item)
		clusters.append(bounds)
		return true
	return false

static func _excluded(bounds: AABB) -> bool:
	if bounds.position.x < 1.2:
		return true
	if bounds.position.z + bounds.size.z > -3.1:
		return true
	if not _inside_margin(bounds, 38.5):
		return true
	if _hits_circle(bounds, Vector2(40.0, 0.0), 8.0):
		return true
	if _intersects_xz(bounds, -8.0, 8.0, -8.0, 8.0):
		return true
	if _intersects_xz(bounds, -3.6, 3.6, -9.6, -6.8):
		return true
	return false

static func _inside_margin(bounds: AABB, apothem: float) -> bool:
	var min_x := bounds.position.x
	var max_x := min_x + bounds.size.x
	var min_z := bounds.position.z
	var max_z := min_z + bounds.size.z
	var corners: Array[Vector2] = [
		Vector2(min_x, min_z), Vector2(max_x, min_z), Vector2(max_x, max_z), Vector2(min_x, max_z),
	]
	for corner in corners:
		if not ArenaMath.contains(corner, apothem):
			return false
	return true

static func _hits_circle(bounds: AABB, center: Vector2, radius: float) -> bool:
	var min_x := bounds.position.x
	var max_x := min_x + bounds.size.x
	var min_z := bounds.position.z
	var max_z := min_z + bounds.size.z
	var x := clampf(center.x, min_x, max_x)
	var z := clampf(center.y, min_z, max_z)
	return Vector2(x, z).distance_to(center) < radius

static func _intersects_xz(bounds: AABB, min_x: float, max_x: float, min_z: float, max_z: float) -> bool:
	var bmin_x := bounds.position.x
	var bmax_x := bmin_x + bounds.size.x
	var bmin_z := bounds.position.z
	var bmax_z := bmin_z + bounds.size.z
	return bmin_x < max_x and bmax_x > min_x and bmin_z < max_z and bmax_z > min_z

static func _separated(bounds: AABB, clusters: Array[AABB]) -> bool:
	for other in clusters:
		if _axial_gap(bounds, other) < CLUSTER_GAP:
			return false
	return true

static func _axial_gap(a: AABB, b: AABB) -> float:
	var dx := maxf(b.position.x - (a.position.x + a.size.x), a.position.x - (b.position.x + b.size.x))
	var dz := maxf(b.position.z - (a.position.z + a.size.z), a.position.z - (b.position.z + b.size.z))
	if dx < 0.0 and dz < 0.0:
		return -1.0
	if dx < 0.0:
		return dz
	if dz < 0.0:
		return dx
	return maxf(dx, dz)

static func _union(members: Array[PropPlacement]) -> AABB:
	var bounds := PropKit.world_aabb(members[0])
	for index in range(1, members.size()):
		bounds = bounds.merge(PropKit.world_aabb(members[index]))
	return bounds

static func _transform_cluster(members: Array[PropPlacement], origin: Vector3, yaw: float) -> Array[PropPlacement]:
	var world: Array[PropPlacement] = []
	for member in members:
		var copy := member.duplicate() as PropPlacement
		copy.position = origin + ArenaMath.rotate_xz(member.position, yaw)
		copy.yaw_deg = member.yaw_deg + yaw
		world.append(copy)
	return world

static func _local_cluster(kind: String) -> Array[PropPlacement]:
	match kind:
		"wall_line":
			return _centered([
				_member(&"wall_low", Vector3(0, 0, 0)),
				_member(&"wall_low", Vector3(4.0 + WALL_GAP, 0, 0)),
			])
		"wall_mid":
			return [_member(&"wall_mid", Vector3.ZERO)]
		"wall_high":
			return [_member(&"wall_high", Vector3.ZERO)]
		"tunnel_slide":
			return [_member(&"tunnel_slide", Vector3.ZERO)]
		"tunnel_crouch":
			return [_member(&"tunnel_crouch", Vector3.ZERO)]
		"stack_stair":
			return [_member(&"stack_stair", Vector3.ZERO)]
		"l_crates":
			# A solid 2×2 block. An open L leaves a 1 m notch, under the 1.5 m corridor minimum.
			return _centered([
				_member(&"crate_s", Vector3(0, 0, 0)),
				_member(&"crate_s", Vector3(1, 0, 0)),
				_member(&"crate_s", Vector3(0, 0, 1)),
				_member(&"crate_s", Vector3(1, 0, 1)),
			])
		"line_crates":
			return _centered([
				_member(&"crate_m", Vector3(0, 0, 0)),
				_member(&"crate_m", Vector3(1.5, 0, 0)),
				_member(&"crate_m", Vector3(3.0, 0, 0)),
				_member(&"crate_m", Vector3(4.5, 0, 0)),
			])
		"barrel_ring":
			return _centered([
				_member(&"crate_m", Vector3.ZERO),
				_member(&"barrel", Vector3(1.2, 0, 0)),
				_member(&"barrel", Vector3(-1.2, 0, 0)),
				_member(&"barrel", Vector3(0, 0, 1.2)),
				_member(&"barrel", Vector3(0, 0, -1.2)),
			])
		"pillars":
			return _centered([
				_member(&"pillar", Vector3(0, 0, 0)),
				_member(&"pillar", Vector3(1.2, 0, 0)),
			])
		"crate_l":
			return [_member(&"crate_l", Vector3.ZERO)]
		"crate_flat_line":
			return _centered([
				_member(&"crate_flat", Vector3(0, 0, 0)),
				_member(&"crate_flat", Vector3(2.0, 0, 0)),
				_member(&"barrel", Vector3(3.45, 0, 0)),
			])
		_:
			return [_member(&"crate_s", Vector3.ZERO)]

static func _centered(members: Array[PropPlacement]) -> Array[PropPlacement]:
	var bounds := _union(members)
	var shift := bounds.get_center()
	shift.y = 0.0
	for member in members:
		member.position -= shift
	return members

static func _member(prop_type: StringName, local_position: Vector3) -> PropPlacement:
	var placement := PropPlacement.new()
	placement.prop_type = prop_type
	placement.position = local_position
	return placement

static func _mirror_all(quadrant: Array[PropPlacement]) -> Array[PropPlacement]:
	var all: Array[PropPlacement] = []
	for item in quadrant:
		all.append(item)
		all.append(_mirrored(item, true, false))
		all.append(_mirrored(item, false, true))
		all.append(_mirrored(item, true, true))
	return all

static func _mirrored(item: PropPlacement, flip_x: bool, flip_z: bool) -> PropPlacement:
	var copy := item.duplicate() as PropPlacement
	if flip_x:
		copy.position.x = -item.position.x
	if flip_z:
		copy.position.z = -item.position.z
	if flip_x and flip_z:
		copy.yaw_deg = ArenaMath.mirror_yaw_both(item.yaw_deg)
	elif flip_x:
		copy.yaw_deg = ArenaMath.mirror_yaw_x(item.yaw_deg)
	else:
		copy.yaw_deg = ArenaMath.mirror_yaw_z(item.yaw_deg)
	return copy

static func _add_center(layout: ArenaLayout) -> void:
	layout.props.append(_member(&"platform_center", Vector3.ZERO))
	var run_lane := PropKit.ramp_run(15.0)
	var run_side := PropKit.ramp_run(25.0)
	# Local +Z is uphill. These yaws point uphill at the platform and match the mirror rule.
	layout.props.append(_ramp(&"ramp_15", Vector3(7.05 + run_lane * 0.5, 0, 0), -90.0))
	layout.props.append(_ramp(&"ramp_15", Vector3(-(7.05 + run_lane * 0.5), 0, 0), 90.0))
	layout.props.append(_ramp(&"ramp_25", Vector3(0, 0, -(7.05 + run_side * 0.5)), 0.0))
	layout.props.append(_ramp(&"ramp_25", Vector3(0, 0, 7.05 + run_side * 0.5), 180.0))

static func _ramp(prop_type: StringName, pos: Vector3, yaw: float) -> PropPlacement:
	var placement := _member(prop_type, pos)
	placement.yaw_deg = yaw
	return placement

static func _cover_percent(layout: ArenaLayout) -> float:
	var area := 0.0
	for placement in layout.props:
		var size := PropKit.footprint(placement.prop_type)
		area += size.x * size.y
	var floor_area := 8.0 * layout.apothem * layout.apothem * tan(PI / 8.0)
	return 100.0 * area / floor_area
