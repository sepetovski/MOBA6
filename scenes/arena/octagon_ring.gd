extends Node3D

## Free-fly review of the octagon. WASD moves, mouse look after a click, Shift is faster.
## ARENA_SHOT=high|pitch|low frames the screenshot cameras. Default is the 55° pitch.

const WALK_SPEED := 12.0
const FAST_SPEED := 36.0

var _camera: Camera3D
var _yaw := 0.0
var _pitch := -35.0
var _captured := false
var _label: Label

func _ready() -> void:
	var layout := load("res://data/arena_layouts/octagon_ring_v1.tres") as ArenaLayout
	var arena := ArenaBuilder.build(layout)
	add_child(arena)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	add_child(_camera)
	_apply_shot(OS.get_environment("ARENA_SHOT"))
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)
	_label.text = "seed %d" % layout.layout_seed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_captured = not _captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _captured else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * 0.15
		_pitch = clampf(_pitch - event.relative.y * 0.15, -89.0, 89.0)
		_camera.rotation_degrees = Vector3(_pitch, _yaw, 0.0)
	elif event.is_action_pressed("ui_cancel"):
		_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		wish.z += 1.0
	if Input.is_key_pressed(KEY_A):
		wish.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		wish.x += 1.0
	if Input.is_key_pressed(KEY_E):
		wish.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		wish.y -= 1.0
	var speed := FAST_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	if wish != Vector3.ZERO:
		_camera.position += _camera.global_transform.basis * wish.normalized() * speed * delta
	if _label != null:
		_label.text = "%s\n%.0f FPS" % [_label.text.split("\n")[0], Engine.get_frames_per_second()]

func _apply_shot(mode: String) -> void:
	match mode:
		"high":
			_camera.position = Vector3(0, 78, 0.2)
			_camera.rotation_degrees = Vector3(-89, 0, 0)
			_pitch = -89.0
			_yaw = 0.0
		"low":
			_camera.position = Vector3(-18, 3.2, 28)
			_camera.rotation_degrees = Vector3(-8, -28, 0)
			_pitch = -8.0
			_yaw = -28.0
		_:
			var pitch := deg_to_rad(55.0)
			var distance := 52.0
			_camera.position = Vector3(0.0, distance * sin(pitch), distance * cos(pitch))
			_camera.rotation_degrees = Vector3(-55, 0, 0)
			_pitch = -55.0
			_yaw = 0.0
