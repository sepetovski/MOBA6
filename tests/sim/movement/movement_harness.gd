class_name MovementHarness extends Node

## Runs a GymUnit from a scripted list of [frame, MovementIntent] inside _physics_process
## so the tick matches production. A9's movement tests drive this.

signal finished

var trace: Array[Dictionary] = []
var hook: Callable = Callable()
var prime := Vector3.ZERO
var use_prime := false

var _unit: GymUnit
var _script: Array = []
var _frame := 0
var _total := 0
var _running := false
var _warmup := 0
var _current := MovementIntent.new()


func build_boxes(parent: Node3D, specs: Array) -> void:
	for spec in specs:
		var center: Vector3 = spec["center"]
		var size: Vector3 = spec["size"]
		var body := StaticBody3D.new()
		body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_PICK
		body.collision_mask = 0
		body.position = center
		if spec.has("rotation_degrees"):
			body.rotation_degrees = spec["rotation_degrees"]
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_node.mesh = mesh
		body.add_child(mesh_node)
		parent.add_child(body)


func spawn_unit(parent: Node3D, at: Vector3, nav_map: RID = RID(), movement_profile: MovementProfile = null) -> GymUnit:
	var body := GymUnit.new()
	body.position = at
	parent.add_child(body)
	var profile := movement_profile if movement_profile != null else MovementProfile.new()
	body.setup(profile, nav_map)
	return body


func run(unit: GymUnit, script: Array, frame_count: int) -> void:
	_unit = unit
	_script = script
	_total = frame_count
	_frame = 0
	_warmup = 12
	_running = true
	_current = MovementIntent.new()
	trace = []
	set_physics_process(true)


func max_height() -> float:
	var highest := -INF
	for sample in trace:
		var position: Vector3 = sample["position"]
		highest = maxf(highest, position.y)
	return highest


func distance_travelled() -> float:
	if trace.size() < 2:
		return 0.0
	var first: Vector3 = trace[0]["position"]
	var last: Vector3 = trace[trace.size() - 1]["position"]
	return Vector2(last.x - first.x, last.z - first.z).length()


func final_state() -> int:
	if trace.is_empty():
		return -1
	return int(trace[trace.size() - 1]["state"])


func passed_through(box: AABB) -> bool:
	if trace.is_empty():
		return false
	var previous: Vector3 = trace[0]["position"]
	for sample in trace:
		var position: Vector3 = sample["position"]
		if box.has_point(position) or _segment_hits(previous, position, box):
			return true
		previous = position
	return false


func slide_distance() -> float:
	var started := false
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	for sample in trace:
		if int(sample["state"]) != MovementMotor.State.SLIDING:
			if started:
				break
			continue
		var position: Vector3 = sample["position"]
		if not started:
			from = position
			started = true
		to = position
	if not started:
		return 0.0
	return Vector2(to.x - from.x, to.z - from.z).length()


func saw_state(which: int) -> bool:
	for sample in trace:
		if int(sample["state"]) == which:
			return true
	return false


func _physics_process(dt: float) -> void:
	if not _running or _unit == null or _unit.motor == null:
		return
	if _warmup > 0:
		_unit.motor.step(MovementIntent.new(), dt)
		_warmup -= 1
		if _warmup == 0 and use_prime:
			_unit.velocity = prime
		return
	var intent := _intent_for(_frame)
	if hook.is_valid():
		hook.call(_frame, _unit, intent)
	_unit.motor.step(intent, dt)
	intent.clear_edges()
	trace.append({
		"frame": _frame,
		"position": _unit.global_position,
		"velocity": _unit.velocity,
		"state": int(_unit.motor.state),
		"grounded": _unit.is_on_floor(),
	})
	_frame += 1
	if _frame >= _total:
		_running = false


func wait_done() -> void:
	while _running:
		await get_tree().physics_frame


func _intent_for(frame: int) -> MovementIntent:
	for entry in _script:
		if int(entry[0]) == frame:
			_current = (entry[1] as MovementIntent).clone()
			return _current
	_current.clear_edges()
	return _current


func _segment_hits(a: Vector3, b: Vector3, box: AABB) -> bool:
	var direction := b - a
	var t_min := 0.0
	var t_max := 1.0
	var low := box.position
	var high := box.position + box.size
	for axis in 3:
		var start := a[axis]
		var delta := direction[axis]
		var box_min := low[axis]
		var box_max := high[axis]
		if absf(delta) < 0.000001:
			if start < box_min or start > box_max:
				return false
			continue
		var t1 := (box_min - start) / delta
		var t2 := (box_max - start) / delta
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return false
	return true
