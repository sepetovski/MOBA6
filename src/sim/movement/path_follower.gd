class_name PathFollower extends RefCounted

## Waypoints from NavigationServer3D. The motor latches a goal and calls set_goal
## only when that goal changes, not every tick.

var arrive_distance := 0.3

var _points := PackedVector3Array()
var _index := 0


func set_goal(map: RID, from: Vector3, to: Vector3) -> void:
	_index = 0
	if not map.is_valid():
		_points = PackedVector3Array()
		return
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	_points = NavigationServer3D.map_get_path(map, from, goal, true)
	if _points.size() < 2:
		_points = PackedVector3Array()


func next_direction(position: Vector3) -> Vector3:
	if _points.size() < 2:
		return Vector3.ZERO
	while _index < _points.size() - 1 and _flat_distance(position, _points[_index]) <= arrive_distance:
		_index += 1
	var target := _points[_index]
	var delta := Vector3(target.x - position.x, 0.0, target.z - position.z)
	if _index == _points.size() - 1 and delta.length() <= arrive_distance:
		return Vector3.ZERO
	if delta.length_squared() < 0.000001:
		return Vector3.ZERO
	return delta.normalized()


func is_arrived(position: Vector3, distance: float) -> bool:
	if _points.is_empty():
		return false
	return _flat_distance(position, _points[_points.size() - 1]) <= distance


func is_unreachable() -> bool:
	return _points.is_empty()


func clear() -> void:
	_points = PackedVector3Array()
	_index = 0


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var flat := Vector2(a.x - b.x, a.z - b.z)
	return flat.length()
