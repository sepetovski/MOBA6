class_name CursorPicker extends RefCounted

## Camera ray against physics bodies. mask 0 means World | Props | Pick.
## A miss falls back to the y = 0 plane. Outside the viewport is always a miss.
## pick() never queries the Units layer. Clicks on units are ground clicks in M2.

const DEFAULT_SETTINGS := "res://data/input_settings_default.tres"

var _camera: Camera3D
var _range := 200.0
var _ground_slope_deg := 40.0


class PickResult:
	var hit := false
	var position := Vector3.ZERO
	var normal := Vector3.UP
	var collider: Object = null
	var is_ground := false
	var unit_id := -1


func _init(cam: Camera3D) -> void:
	_camera = cam
	var settings := load(DEFAULT_SETTINGS) as InputSettings
	if settings != null:
		_range = settings.pick_range
		_ground_slope_deg = settings.ground_slope_deg


func pick(screen_pos: Vector2, mask := 0) -> PickResult:
	var use_mask := mask
	if use_mask == 0:
		use_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS | GameConfig.LAYER_PICK
	return _cast(screen_pos, use_mask, true)


func pick_unit(screen_pos: Vector2) -> PickResult:
	var result := _cast(screen_pos, GameConfig.LAYER_UNITS, false)
	result.unit_id = _read_unit_id(result.collider)
	if result.unit_id < 0:
		result.hit = false
	return result


func _cast(screen_pos: Vector2, mask: int, allow_plane: bool) -> PickResult:
	var result := PickResult.new()
	if _camera == null or not is_instance_valid(_camera):
		return result
	var viewport := _camera.get_viewport()
	if viewport == null:
		return result
	var size := viewport.get_visible_rect().size
	if screen_pos.x < 0.0 or screen_pos.y < 0.0 or screen_pos.x > size.x or screen_pos.y > size.y:
		return result
	var origin := _camera.project_ray_origin(screen_pos)
	var direction := _camera.project_ray_normal(screen_pos)
	var world := _camera.get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * _range, mask)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			result.hit = true
			result.position = hit.position
			result.normal = hit.normal
			result.collider = hit.collider
			result.is_ground = _is_ground(result.normal)
			return result
	if not allow_plane:
		return result
	var plane: Variant = _plane_y0(origin, direction)
	if plane is Vector3:
		result.hit = true
		result.position = plane
		result.normal = Vector3.UP
		result.collider = null
		result.is_ground = true
	return result


func _is_ground(normal: Vector3) -> bool:
	if normal.length_squared() < 0.0001:
		return false
	return normal.normalized().angle_to(Vector3.UP) <= deg_to_rad(_ground_slope_deg)


static func _plane_y0(origin: Vector3, direction: Vector3) -> Variant:
	if absf(direction.y) < 0.000001:
		return null
	var along := -origin.y / direction.y
	if along < 0.0:
		return null
	return origin + direction * along


func _read_unit_id(collider: Object) -> int:
	if collider == null or not collider.has_meta(&"unit_id"):
		return -1
	return int(collider.get_meta(&"unit_id"))
