class_name PlayerController extends Node

## Turns pointer and keys into Commands. Never moves a unit.
## Reads clicks in _unhandled_input so a control that already consumed the event cannot start a hold.
## Physics priority -10 so commands exist before Simulation (M4) ticks.

signal command_issued(cmd: Command)

const DEFAULT_SETTINGS := "res://data/input_settings_default.tres"

@export var settings: InputSettings
@export var enabled := true

var _unit_id := -1
var _camera: MobaCamera
var _sink := Callable()
var _picker: CursorPicker
var _seq := 0
var _right_down := false
var _held_time := 0.0
var _steering := false
var _last_steer := Vector3.ZERO
var _cursor := Vector2.ZERO
var _cursor_valid := false
var _crouched := false
var _firing := false
var _wasd_moving := false
var face_cursor := false


func _init() -> void:
	process_physics_priority = -10


func _ready() -> void:
	_ensure_settings()


func bind(bound_unit_id: int, cam: MobaCamera, sink: Callable) -> void:
	_unit_id = bound_unit_id
	_camera = cam
	_sink = sink
	_picker = null


func _unhandled_input(event: InputEvent) -> void:
	_note_cursor(event)
	if not enabled:
		_clear_hold()
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event.is_action_pressed(&"move_click"):
		_begin_click()
		_mark_handled()
	elif event.is_action_released(&"move_click"):
		_end_click()
		_mark_handled()
	elif event.is_action_pressed(&"stop"):
		_emit(Command.Kind.STOP, _ground_or_zero(), true)
		_mark_handled()
	elif event.is_action_pressed(&"jump"):
		_emit(Command.Kind.JUMP, _ground_or_zero(), true)
		_mark_handled()
	elif event.is_action_released(&"jump"):
		_emit(Command.Kind.JUMP, _ground_or_zero(), false)
		_mark_handled()
	elif event.is_action_pressed(&"crouch_slide"):
		_on_crouch_press()
		_mark_handled()
	elif event.is_action_released(&"crouch_slide"):
		_on_crouch_release()
		_mark_handled()
	elif event.is_action_pressed(&"dash"):
		_emit(Command.Kind.DASH, _ground_or_zero(), true)
		_mark_handled()
	elif event.is_action_pressed(&"fire"):
		_firing = true
		_emit(Command.Kind.FIRE, _ground_or_zero(), true)
		_mark_handled()
	elif event.is_action_released(&"fire"):
		_firing = false
		_emit(Command.Kind.FIRE, _ground_or_zero(), false)
		_mark_handled()
	elif event.is_action_pressed(&"ability_1"):
		_emit(Command.Kind.CAST, _ground_or_zero(), true, -1, 0)
		_mark_handled()
	elif event.is_action_pressed(&"ability_2"):
		_emit(Command.Kind.CAST, _ground_or_zero(), true, -1, 1)
		_mark_handled()
	elif _item_slot(event) >= 0:
		_emit_item(_item_slot(event))
		_mark_handled()


func _physics_process(delta: float) -> void:
	_confine_mouse()
	if enabled and face_cursor:
		var aim: Variant = _ground_point()
		if aim is Vector3:
			_emit(Command.Kind.AIM, aim, true)
	if enabled:
		_drive_wasd()
	if not enabled:
		_clear_hold()
		return
	if not _right_down:
		return
	_held_time += delta
	var tuned := _ensure_settings()
	if _held_time < tuned.hold_threshold:
		return
	var ground: Variant = _ground_point()
	if ground == null or not ground is Vector3:
		return
	var point := ground as Vector3
	if not _steering:
		_steering = true
		_last_steer = point
		_emit(Command.Kind.STEER, point, true)
		return
	if point.distance_to(_last_steer) > tuned.steer_resend_distance:
		_last_steer = point
		_emit(Command.Kind.STEER, point, true)


func _begin_click() -> void:
	_right_down = true
	_held_time = 0.0
	_steering = false
	var unit_hit := _pick_unit()
	if unit_hit != null and unit_hit.hit and unit_hit.unit_id != _unit_id:
		_emit(Command.Kind.ATTACK_TARGET, unit_hit.position, true, unit_hit.unit_id)
		return
	var result := _pick_world()
	if result == null or not result.hit:
		return
	_emit(Command.Kind.MOVE_TO, result.position, true)


func _end_click() -> void:
	var was_steering := _steering
	var point := _last_steer
	_right_down = false
	_held_time = 0.0
	_steering = false
	if was_steering:
		_emit(Command.Kind.STEER, point, false)


func _on_crouch_press() -> void:
	if _ensure_settings().crouch_toggle:
		_crouched = not _crouched
		_emit(Command.Kind.CROUCH_SLIDE, _ground_or_zero(), _crouched)
		return
	_emit(Command.Kind.CROUCH_SLIDE, _ground_or_zero(), true)


func _on_crouch_release() -> void:
	if _ensure_settings().crouch_toggle:
		return
	_emit(Command.Kind.CROUCH_SLIDE, _ground_or_zero(), false)


func _drive_wasd() -> void:
	if _camera == null or not InputMap.has_action(&"move_forward"):
		return
	var wish := Vector3.ZERO
	var forward := _camera.planar_forward()
	var right := _camera.planar_right()
	if Input.is_action_pressed(&"move_forward"):
		wish += forward
	if Input.is_action_pressed(&"move_back"):
		wish -= forward
	if Input.is_action_pressed(&"move_right"):
		wish += right
	if Input.is_action_pressed(&"move_left"):
		wish -= right
	if wish.length_squared() < 0.01:
		if _wasd_moving:
			_wasd_moving = false
			_emit(Command.Kind.STEER, _ground_or_zero(), false)
		return
	_wasd_moving = true
	var point := _camera.follow_origin() + wish.normalized() * 10.0
	_emit(Command.Kind.STEER, point, true)


func _clear_hold() -> void:
	_right_down = false
	_held_time = 0.0
	_steering = false
	if _firing:
		_firing = false
		_emit(Command.Kind.FIRE, _ground_or_zero(), false)


func _item_slot(event: InputEvent) -> int:
	for slot in 4:
		var action := "item_%d" % (slot + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return slot
	return -1


func _emit_item(slot: int) -> void:
	var cmd := Command.new()
	cmd.tick = 0
	cmd.seq = _seq
	_seq += 1
	cmd.unit_id = _unit_id
	cmd.kind = Command.Kind.ACTIVATE
	cmd.point = _ground_or_zero()
	cmd.slot = slot
	cmd.item_id = ""
	command_issued.emit(cmd)
	if _sink.is_valid():
		_sink.call(cmd)


func _emit(kind: Command.Kind, point: Vector3, pressed: bool, target_id := -1, slot := -1) -> void:
	var cmd := Command.new()
	cmd.tick = 0
	cmd.seq = _seq
	_seq += 1
	cmd.unit_id = _unit_id
	cmd.kind = kind
	cmd.point = point
	cmd.pressed = pressed
	cmd.target_id = target_id
	cmd.slot = slot
	command_issued.emit(cmd)
	if _sink.is_valid():
		_sink.call(cmd)


func _pick_unit() -> CursorPicker.PickResult:
	var picker := _ensure_picker()
	if picker == null:
		return null
	return picker.pick_unit(_cursor_position())


func _pick_world() -> CursorPicker.PickResult:
	var picker := _ensure_picker()
	if picker == null:
		return null
	return picker.pick(_cursor_position())


func _ground_point() -> Variant:
	if _camera == null or not is_instance_valid(_camera):
		return null
	return _camera.screen_to_ground(_cursor_position())


func _ground_or_zero() -> Vector3:
	var ground: Variant = _ground_point()
	if ground is Vector3:
		return ground
	return Vector3.ZERO


func _ensure_picker() -> CursorPicker:
	if _camera == null or not is_instance_valid(_camera) or _camera.camera == null:
		return null
	if _picker == null:
		_picker = CursorPicker.new(_camera.camera)
	return _picker


func _ensure_settings() -> InputSettings:
	if settings == null:
		settings = load(DEFAULT_SETTINGS) as InputSettings
	return settings


func _note_cursor(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor = (event as InputEventMouseMotion).position
		_cursor_valid = true
	elif event is InputEventMouseButton:
		_cursor = (event as InputEventMouseButton).position
		_cursor_valid = true


func _cursor_position() -> Vector2:
	if _cursor_valid:
		return _cursor
	if is_inside_tree():
		return get_viewport().get_mouse_position()
	return Vector2.ZERO


func _confine_mouse() -> void:
	var tuned := _ensure_settings()
	if tuned == null or not tuned.confine_mouse:
		return
	if DisplayServer.get_name() == "headless":
		return
	var mode := Input.MOUSE_MODE_CONFINED if DisplayServer.window_is_focused() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = mode


func _mark_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()
