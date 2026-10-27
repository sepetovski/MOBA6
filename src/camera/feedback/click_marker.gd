class_name ClickMarker extends Node3D

## One pooled MOVE_TO ring. Scales from the start radius to the end radius while fading.
## The mesh is built at 1 m and scaled on XZ so the centre stays put.

var active := false

var _ring: GroundRing
var _age := 0.0
var _duration := 0.4
var _radius_start := 0.3
var _radius_end := 1.0


func _ready() -> void:
	if _ring == null:
		_ring = GroundRing.new()
		_ring.name = "Ring"
		add_child(_ring)
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	if not active:
		set_process(false)
		visible = false


func age() -> float:
	return _age


func play(point: Vector3, normal: Vector3, duration: float, radius_start: float, radius_end: float, color: Color, lift: float) -> void:
	if _ring == null:
		_ring = GroundRing.new()
		_ring.name = "Ring"
		add_child(_ring)
	active = true
	visible = true
	_age = 0.0
	_duration = maxf(duration, 0.001)
	_radius_start = radius_start
	_radius_end = radius_end
	_ring.set_surface_lift(0.0)
	_ring.configure(1.0, 0.12, color, 1.0)
	_ring.place_at(point + normal.normalized() * lift, normal)
	_apply(0.0)
	set_process(true)


func _process(delta: float) -> void:
	if not active:
		return
	_age += delta
	var t := clampf(_age / _duration, 0.0, 1.0)
	_apply(t)
	if _age >= _duration:
		active = false
		visible = false
		set_process(false)


func _apply(t: float) -> void:
	var radius := lerpf(_radius_start, _radius_end, t)
	_ring.scale = Vector3(radius, 1.0, radius)
	_ring.set_alpha(1.0 - t)
