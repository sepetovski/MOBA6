extends GutTest

const LAYOUT_PATH := "res://data/arena_layouts/octagon_ring_v1.tres"

func test_floor_faces_up() -> void:
	var arena := _arena()
	var mesh := arena.get_node("Navigation/Floor/Mesh").mesh as Mesh
	var faces := mesh.get_faces()
	var normal := (faces[1] - faces[0]).cross(faces[2] - faces[0])
	assert_gt(normal.y, 0.0, "floor winding must face up")

func test_props_inside_arena() -> void:
	var layout := _layout()
	for placement in layout.props:
		var bounds := PropKit.world_aabb(placement)
		for corner in _xz_corners(bounds):
			assert_true(ArenaMath.contains(corner, layout.apothem - 0.05) or _is_structure(placement.prop_type), "%s at %s leaves the octagon" % [placement.prop_type, placement.position])
		if _is_structure(placement.prop_type):
			continue
		assert_false(_hits_lane(bounds), "%s sits in the lane at %s" % [placement.prop_type, placement.position])
		assert_false(_hits_circle(bounds, Vector2(40, 0), 8.0) or _hits_circle(bounds, Vector2(-40, 0), 8.0), "%s is inside a gate exclusion" % placement.prop_type)
		assert_false(_intersects(bounds, -7.0, 7.0, -7.0, 7.0), "%s overlaps the platform exclusion" % placement.prop_type)

func test_lane_is_clear_beyond_the_ramps() -> void:
	var layout := _layout()
	for placement in layout.props:
		if str(placement.prop_type).begins_with("ramp"):
			continue
		var bounds := PropKit.world_aabb(placement)
		var min_x := bounds.position.x
		var max_x := min_x + bounds.size.x
		var min_z := bounds.position.z
		var max_z := min_z + bounds.size.z
		var in_lane_z := min_z < 3.0 and max_z > -3.0
		var in_outer_lane := (min_x < -11.0 or max_x > 11.0) and min_x < 40.0 and max_x > -40.0
		assert_false(in_lane_z and in_outer_lane, "%s blocks the lane" % placement.position)

func test_no_overlaps() -> void:
	var layout := _layout()
	for i in layout.props.size():
		var a := PropKit.world_aabb(layout.props[i])
		for j in range(i + 1, layout.props.size()):
			var b := PropKit.world_aabb(layout.props[j])
			if a.position.y > 0.05 or b.position.y > 0.05:
				continue
			var hit := a.intersection(b)
			assert_false(hit.size.x > 0.02 and hit.size.y > 0.02 and hit.size.z > 0.02, "%s overlaps %s" % [layout.props[i].position, layout.props[j].position])

func test_mirror_symmetry() -> void:
	var layout := _layout()
	for placement in layout.props:
		if placement.prop_type == &"platform_center":
			assert_lt(placement.position.length(), 0.01)
			continue
		assert_true(_has_mirror(layout, placement, true, false), "missing X mirror for %s at %s" % [placement.prop_type, placement.position])
		assert_true(_has_mirror(layout, placement, false, true), "missing Z mirror for %s at %s" % [placement.prop_type, placement.position])
		assert_true(_has_mirror(layout, placement, true, true), "missing XZ mirror for %s at %s" % [placement.prop_type, placement.position])

func test_traversal_classes() -> void:
	var expected := {
		&"crate_s": TraversalClass.Kind.VAULT,
		&"crate_m": TraversalClass.Kind.MANTLE,
		&"crate_l": TraversalClass.Kind.MANTLE,
		&"crate_flat": TraversalClass.Kind.VAULT,
		&"barrel": TraversalClass.Kind.VAULT,
		&"barrel_cluster": TraversalClass.Kind.VAULT,
		&"wall_low": TraversalClass.Kind.VAULT,
		&"wall_mid": TraversalClass.Kind.MANTLE,
		&"wall_high": TraversalClass.Kind.WALL,
		&"pillar": TraversalClass.Kind.WALL,
		&"platform": TraversalClass.Kind.VAULT,
		&"platform_center": TraversalClass.Kind.VAULT,
		&"tunnel_slide": TraversalClass.Kind.SLIDE_GAP,
		&"tunnel_crouch": TraversalClass.Kind.CROUCH_GAP,
		&"stack_stair": TraversalClass.Kind.VAULT,
	}
	for prop_type: StringName in expected:
		assert_eq(PropKit.traversal_for(prop_type), expected[prop_type], String(prop_type))
		if prop_type != &"tunnel_slide" and prop_type != &"tunnel_crouch" and prop_type != &"stack_stair":
			assert_eq(TraversalClass.from_height(PropKit.height_of(prop_type)), expected[prop_type], String(prop_type))
	assert_eq(PropKit.traversal_for(&"ramp_15"), -1)
	assert_eq(TraversalClass.from_height(0.4), TraversalClass.Kind.STEP)
	assert_eq(TraversalClass.from_height(2.2), TraversalClass.Kind.WALL)

func test_clearances() -> void:
	var layout := _layout()
	var cover: Array[AABB] = []
	for placement in layout.props:
		if _is_structure(placement.prop_type):
			continue
		cover.append(PropKit.world_aabb(placement))
	for i in cover.size():
		for j in range(i + 1, cover.size()):
			var dx := _axis_gap(cover[i].position.x, cover[i].size.x, cover[j].position.x, cover[j].size.x)
			var dz := _axis_gap(cover[i].position.z, cover[i].size.z, cover[j].position.z, cover[j].size.z)
			var overlap_x := _axis_overlap(cover[i].position.x, cover[i].size.x, cover[j].position.x, cover[j].size.x)
			var overlap_z := _axis_overlap(cover[i].position.z, cover[i].size.z, cover[j].position.z, cover[j].size.z)
			# A corridor is a gap you can walk along, so the props must overlap on the other axis.
			if dx > 0.0 and overlap_z > 0.4:
				assert_gte(dx, 1.45, "corridor %.2f between props" % dx)
			if dz > 0.0 and overlap_x > 0.4:
				assert_gte(dz, 1.45, "corridor %.2f between props" % dz)
		assert_true(_inside_margin(cover[i], 38.4), "prop closer than 1.5 m to the wall")

func test_spawn_slots_and_paths() -> void:
	var arena := _arena()
	await arena.navigation_ready
	# GUT must pump physics frames or the navigation server never publishes the bake.
	await wait_physics_frames(5)
	var region := arena.get_node("Navigation") as NavigationRegion3D
	var map := region.get_navigation_map()
	var info := arena.get_node("ArenaInfo") as ArenaInfo
	var spawns: Array[Vector3] = []
	for team in [0, 1]:
		for slot in 6:
			var marker_name := "Spawn_%s_%d" % ["A" if team == 0 else "B", slot]
			var marker := arena.get_node("Spawns").get_node(marker_name) as Marker3D
			var expected := info.get_spawn_slot(team, slot)
			assert_lt(marker.global_position.distance_to(expected.origin), 0.01)
			var forward := -marker.global_basis.z
			var want := Vector3.RIGHT if team == 0 else Vector3.LEFT
			assert_gt(forward.dot(want), 0.99, marker_name)
			var closest := NavigationServer3D.map_get_closest_point(map, marker.global_position)
			var flat := Vector2(closest.x, closest.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z))
			assert_lt(flat, 0.2, "%s off the navmesh by %s" % [marker_name, closest])
			spawns.append(marker.global_position)
			assert_true(_in_tunnel(marker.global_position), marker_name)
	for a in 6:
		for b in 6:
			var path := NavigationServer3D.map_get_path(map, spawns[a], spawns[6 + b], true)
			assert_gt(path.size(), 1, "no path from A%d to B%d" % [a, b])
			assert_lt(path[path.size() - 1].distance_to(spawns[6 + b]), 1.0, "path A%d B%d stops early" % [a, b])
	var door := arena.get_node("GateDoors/Gate_A_Door")
	assert_false(region.is_ancestor_of(door))
	var door_b := arena.get_node("GateDoors/Gate_B_Door")
	assert_false(region.is_ancestor_of(door_b))

func test_budget() -> void:
	var arena := _arena()
	var crowd := arena.get_node("Crowd") as CrowdRenderer
	assert_lte(crowd.instance_count(), 3000)
	var crowd_draws := 0
	for child in crowd.get_children():
		if child is GeometryInstance3D:
			crowd_draws += 1
	assert_lte(crowd_draws, 3)
	var draws := 0
	var triangles := 0
	for node in arena.find_children("*", "GeometryInstance3D", true, false):
		draws += 1
		if node is MultiMeshInstance3D and node.multimesh != null:
			triangles += _mesh_tris(node.multimesh.mesh) * node.multimesh.instance_count
		elif node is MeshInstance3D and node.mesh != null:
			triangles += _mesh_tris(node.mesh)
	assert_lte(draws, 800, "draw calls %d" % draws)
	assert_lte(triangles, 1500000, "triangles %d" % triangles)
	gut.p("draws %d triangles %d crowd %d" % [draws, triangles, crowd.instance_count()])

func _layout() -> ArenaLayout:
	return load(LAYOUT_PATH) as ArenaLayout

func _arena() -> Node3D:
	var arena := ArenaBuilder.build(_layout())
	add_child_autofree(arena)
	return arena

func _is_structure(prop_type: StringName) -> bool:
	return prop_type == &"platform_center" or str(prop_type).begins_with("ramp")

func _xz_corners(bounds: AABB) -> Array[Vector2]:
	return [
		Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.position.x + bounds.size.x, bounds.position.z),
		Vector2(bounds.position.x, bounds.position.z + bounds.size.z),
		Vector2(bounds.position.x + bounds.size.x, bounds.position.z + bounds.size.z),
	]

func _hits_lane(bounds: AABB) -> bool:
	return _intersects(bounds, -40.0, 40.0, -3.0, 3.0)

func _hits_circle(bounds: AABB, center: Vector2, radius: float) -> bool:
	var x := clampf(center.x, bounds.position.x, bounds.position.x + bounds.size.x)
	var z := clampf(center.y, bounds.position.z, bounds.position.z + bounds.size.z)
	return Vector2(x, z).distance_to(center) < radius - 0.05

func _intersects(bounds: AABB, min_x: float, max_x: float, min_z: float, max_z: float) -> bool:
	return bounds.position.x < max_x and bounds.position.x + bounds.size.x > min_x and bounds.position.z < max_z and bounds.position.z + bounds.size.z > min_z

func _has_mirror(layout: ArenaLayout, placement: PropPlacement, flip_x: bool, flip_z: bool) -> bool:
	var want := placement.position
	if flip_x:
		want.x = -want.x
	if flip_z:
		want.z = -want.z
	var yaw := placement.yaw_deg
	if flip_x and flip_z:
		yaw = ArenaMath.mirror_yaw_both(yaw)
	elif flip_x:
		yaw = ArenaMath.mirror_yaw_x(yaw)
	else:
		yaw = ArenaMath.mirror_yaw_z(yaw)
	for other in layout.props:
		if other.prop_type != placement.prop_type:
			continue
		if other.position.distance_to(want) > 0.01:
			continue
		if ArenaMath.yaw_delta(other.yaw_deg, yaw) <= 0.5:
			return true
	return false

func _axis_gap(origin_a: float, size_a: float, origin_b: float, size_b: float) -> float:
	return maxf(origin_b - (origin_a + size_a), origin_a - (origin_b + size_b))

func _axis_overlap(origin_a: float, size_a: float, origin_b: float, size_b: float) -> float:
	return minf(origin_a + size_a, origin_b + size_b) - maxf(origin_a, origin_b)

func _inside_margin(bounds: AABB, apothem: float) -> bool:
	for corner in _xz_corners(bounds):
		if not ArenaMath.contains(corner, apothem):
			return false
	return true

func _in_tunnel(point: Vector3) -> bool:
	return absf(point.z) <= 4.0 and absf(point.x) >= 40.0 and absf(point.x) <= 49.0

func _mesh_tris(mesh: Mesh) -> int:
	return int(mesh.get_faces().size() / 3)
