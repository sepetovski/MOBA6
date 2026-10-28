class_name MovementMotor extends RefCounted

## Drives a CharacterBody3D from a MovementIntent. No Input, no wall clock, no global RNG.
##
## Cancel rules for vault and mantle:
## - can_move = false cancels immediately and returns the unit to GROUNDED or AIRBORNE.
## - start_forced_motion cancels the traversal and replaces it with FORCED.
## - A stun is can_move = false. Statuses (Phase 2) have no separate stun flag.
## Forced motion uses move_and_collide instead of move_and_slide so a wall stops the displacement.
## Every other state calls move_and_slide exactly once.

enum State { GROUNDED, CROUCHED, SLIDING, AIRBORNE, VAULTING, MANTLING, FORCED }

signal landed(fall_speed: float)
signal stuck()
signal state_changed(old_state: State, new_state: State)
signal forced_motion_ended(hit_wall: bool)
signal arrived()

var state: State = State.GROUNDED
var can_move := true
var can_jump := true
var can_crouch := true
var profile: MovementProfile

var _body: CharacterBody3D
var _map: RID
var _shape: CapsuleShape3D
var _follower := PathFollower.new()

var _has_goal := false
var _goal := Vector3.ZERO
var _steering := false
var _repathed := false
var _blocked_time := 0.0
var _stuck_emitted := false

var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _slide_cd_left := 0.0
var _slide_speed := 0.0
var _slide_dir := Vector3(0, 0, -1)
var _air_reference_speed := 0.0
var _jump_start_y := 0.0
var _jumped_this_step := false
var _air_jumps_left := 0
var _takeoff_height := 1.3
var _wall_push := Vector3.ZERO
var _was_on_floor := false
var _step_keep := Vector3.ZERO
var _did_step := false

var _path_points := PackedVector3Array()
var _path_time := 0.0
var _path_duration := 0.0
var _entry_speed := 0.0
var _entry_dir := Vector3(0, 0, -1)
var _path_done := false

var _forced_start := Vector3.ZERO
var _forced_displacement := Vector3.ZERO
var _forced_elapsed := 0.0
var _forced_duration := 0.0
var _forced_curve: Curve
var _forced_ignore_gravity := true
var _forced_vy := 0.0
var _forced_hit := false


func _init(body: CharacterBody3D, movement_profile: MovementProfile, nav_map: RID) -> void:
	_body = body
	profile = movement_profile
	_map = nav_map
	_follower.arrive_distance = profile.arrive_distance
	_configure_body()


func set_nav_map(nav_map: RID) -> void:
	_map = nav_map


func step(intent: MovementIntent, dt: float) -> void:
	_jumped_this_step = false
	_tick_timers(dt)
	if state == State.FORCED:
		_step_forced(dt)
		_update_facing(dt)
		return
	if not can_move and (state == State.VAULTING or state == State.MANTLING):
		_cancel_path()
	_apply_intent(intent)
	if state == State.VAULTING or state == State.MANTLING:
		_advance_path(dt)
		_body.move_and_slide()
		_finish_path_if_done()
	else:
		var takeoff := _resolve_transitions(intent)
		if state == State.VAULTING or state == State.MANTLING:
			_advance_path(dt)
			_body.move_and_slide()
			_finish_path_if_done()
		else:
			_apply_locomotion(intent, dt, takeoff)
			_cap_horizontal()
			_try_step_up(dt)
			var fall_vy := _body.velocity.y
			var was_air := state == State.AIRBORNE
			_body.move_and_slide()
			if not _body.is_on_floor():
				_body.velocity.y += _gravity_accel() * dt * 0.5
			_cap_horizontal()
			_post_contact(intent, was_air, fall_vy)
	_post_goal(intent, dt)
	_update_facing(dt)


func apply_impulse(impulse: Vector3) -> void:
	_body.velocity += impulse
	_cap_horizontal()


func start_forced_motion(displacement: Vector3, duration: float, ease_curve: Curve = null, ignore_gravity: bool = true) -> void:
	_cancel_path()
	_set_state(State.FORCED)
	_forced_start = _body.global_position
	_forced_displacement = displacement
	_forced_elapsed = 0.0
	_forced_duration = maxf(duration, 0.0001)
	_forced_curve = ease_curve
	_forced_ignore_gravity = ignore_gravity
	_forced_vy = _body.velocity.y
	_forced_hit = false


func get_horizontal_speed() -> float:
	return Vector2(_body.velocity.x, _body.velocity.z).length()


func has_goal() -> bool:
	return _has_goal


func reset_motion() -> void:
	_cancel_path()
	_clear_goal(false)
	_steering = false
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_slide_cd_left = 0.0
	_slide_speed = 0.0
	_blocked_time = 0.0
	_repathed = false
	_stuck_emitted = false
	_air_reference_speed = 0.0
	_air_jumps_left = profile.air_jumps
	_wall_push = Vector3.ZERO
	_body.velocity = Vector3.ZERO
	_set_capsule(profile.height_stand)
	_set_state(State.GROUNDED)


func readout() -> String:
	var grounded := "yes" if _body.is_on_floor() else "no"
	return "state %s   speed %.2f   grounded %s   height %.2f" % [
		State.keys()[state],
		get_horizontal_speed(),
		grounded,
		_body.global_position.y,
	]


func _configure_body() -> void:
	_body.floor_max_angle = deg_to_rad(profile.floor_max_angle_deg)
	_body.floor_snap_length = profile.floor_snap_length
	_body.floor_stop_on_slope = true
	_body.floor_constant_speed = true
	_body.up_direction = Vector3.UP
	_body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_body.collision_layer = GameConfig.LAYER_UNITS
	_body.collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS
	var existing := _body.get_node_or_null("Capsule") as CollisionShape3D
	if existing == null:
		existing = CollisionShape3D.new()
		existing.name = "Capsule"
		_body.add_child(existing)
	if existing.shape == null or not (existing.shape is CapsuleShape3D):
		existing.shape = CapsuleShape3D.new()
	_shape = existing.shape as CapsuleShape3D
	_set_capsule(profile.height_stand)


func _set_capsule(height: float) -> void:
	var full := maxf(height, profile.radius * 2.0)
	_shape.radius = profile.radius
	_shape.height = full
	var node := _body.get_node("Capsule") as CollisionShape3D
	node.position = Vector3(0.0, full * 0.5, 0.0)


func _tick_timers(dt: float) -> void:
	_coyote_left = maxf(_coyote_left - dt, 0.0)
	_jump_buffer_left = maxf(_jump_buffer_left - dt, 0.0)
	_slide_cd_left = maxf(_slide_cd_left - dt, 0.0)


func _apply_intent(intent: MovementIntent) -> void:
	if intent.stop or not can_move:
		_clear_goal(false)
		_steering = false
		intent.has_move_target = false
		intent.steering = false
	if intent.steering and can_move:
		if _has_goal:
			_clear_goal(false)
		_steering = true
		intent.has_move_target = false
	elif not intent.steering:
		_steering = false
	if intent.has_move_target and can_move:
		var changed := not _has_goal or intent.move_target.distance_squared_to(_goal) > 0.0001
		if changed:
			_goal = intent.move_target
			_has_goal = true
			_repathed = false
			_stuck_emitted = false
			_blocked_time = 0.0
		# An empty path on the first query is usually the navmap still syncing, so keep trying.
		if changed or (_has_goal and _follower.is_unreachable()):
			_follower.arrive_distance = profile.arrive_distance
			_follower.set_goal(_map, _body.global_position, _goal)


func _resolve_transitions(intent: MovementIntent) -> bool:
	if state == State.SLIDING:
		_slide_jump_or_exit(intent)
		return _jumped_this_step
	if _try_traversal(intent):
		return false
	match state:
		State.GROUNDED:
			if _try_jump(intent):
				return true
			if _try_slide(intent):
				return false
			if can_crouch and intent.crouch_slide_held and get_horizontal_speed() < profile.slide_enter_speed:
				_set_state(State.CROUCHED)
				_set_capsule(profile.height_crouch)
		State.CROUCHED:
			if _try_jump(intent):
				return true
			if not intent.crouch_slide_held and _headroom_clear():
				_set_state(State.GROUNDED)
				_set_capsule(profile.height_stand)
		State.AIRBORNE:
			if _try_jump(intent):
				return true
	return false


func _slide_jump_or_exit(intent: MovementIntent) -> bool:
	if _try_jump(intent):
		return true
	var slow := _slide_speed < profile.slide_min_speed
	var released := not intent.crouch_slide_held
	if not slow and not released:
		return false
	var crouch := intent.crouch_slide_held or not _headroom_clear()
	if slow or crouch or released:
		_finish_slide(crouch)
		return true
	return false


func _try_jump(intent: MovementIntent) -> bool:
	if not can_jump:
		return false
	var buffered := intent.jump_pressed or _jump_buffer_left > 0.0
	if not buffered:
		return false
	if state == State.CROUCHED and not _headroom_clear():
		return false
	if state == State.AIRBORNE and not _body.is_on_floor() and _coyote_left <= 0.0:
		if not intent.jump_pressed:
			return false
		var wall := _wall_normal()
		if wall != Vector3.ZERO:
			return _begin_wall_jump(wall)
		if _air_jumps_left <= 0:
			_jump_buffer_left = profile.jump_buffer
			return false
		_air_jumps_left -= 1
		return _begin_air_jump(profile.air_jump_height)
	var grounded_enough := _body.is_on_floor() or _coyote_left > 0.0 or state == State.GROUNDED or state == State.CROUCHED or state == State.SLIDING
	if not grounded_enough:
		if intent.jump_pressed:
			_jump_buffer_left = profile.jump_buffer
		return false
	if state == State.CROUCHED:
		_set_capsule(profile.height_stand)
		_set_state(State.GROUNDED)
	return _begin_air_jump(profile.jump_height)


func _begin_air_jump(height: float) -> bool:
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_wall_push = Vector3.ZERO
	_takeoff_height = height
	_air_reference_speed = get_horizontal_speed()
	_jumped_this_step = true
	if state == State.SLIDING:
		_slide_cd_left = profile.slide_cooldown
		_air_jumps_left = profile.air_jumps
	elif state != State.AIRBORNE:
		_air_jumps_left = profile.air_jumps
	_set_state(State.AIRBORNE)
	return true


func _begin_wall_jump(wall: Vector3) -> bool:
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_takeoff_height = profile.wall_jump_height
	_wall_push = wall * profile.wall_jump_push
	var along := _flat_velocity() - wall * _flat_velocity().dot(wall)
	_set_horizontal(along * 0.35 + _wall_push)
	_air_reference_speed = maxf(get_horizontal_speed(), profile.wall_jump_push)
	_air_jumps_left = profile.air_jumps
	_jumped_this_step = true
	_set_state(State.AIRBORNE)
	return true


func _wall_normal() -> Vector3:
	if not _body.is_on_wall():
		return Vector3.ZERO
	var best := Vector3.ZERO
	var best_horiz := 0.0
	for index in _body.get_slide_collision_count():
		var normal: Vector3 = _body.get_slide_collision(index).get_normal()
		var horizontal := Vector2(normal.x, normal.z).length()
		if normal.y < profile.wall_jump_normal_y and horizontal > best_horiz:
			best = normal
			best_horiz = horizontal
	if best_horiz < 0.5:
		return Vector3.ZERO
	return Vector3(best.x, 0.0, best.z).normalized()


func _try_slide(intent: MovementIntent) -> bool:
	if not can_crouch or _slide_cd_left > 0.0:
		return false
	if not _body.is_on_floor():
		return false
	# A press slides immediately when fast. Holding Ctrl also slides once a run is up to speed.
	if not intent.crouch_slide_pressed and not intent.crouch_slide_held:
		return false
	if get_horizontal_speed() < profile.slide_enter_speed:
		return false
	_begin_slide(intent.crouch_slide_pressed)
	return true


func _begin_slide(boost: bool) -> void:
	var flat := _flat_velocity()
	if flat.length_squared() > 0.01:
		_slide_dir = flat.normalized()
	else:
		_slide_dir = _facing()
	var speed := flat.length()
	if boost:
		speed += profile.slide_boost
	_slide_speed = minf(speed, profile.max_speed_cap)
	_set_capsule(profile.height_slide)
	_set_state(State.SLIDING)


func _finish_slide(to_crouch: bool) -> void:
	_slide_cd_left = profile.slide_cooldown
	if to_crouch:
		_set_capsule(profile.height_crouch)
		_set_state(State.CROUCHED)
	else:
		_set_capsule(profile.height_stand)
		_set_state(State.GROUNDED)


func _try_traversal(intent: MovementIntent) -> bool:
	if not intent.jump_pressed or not can_jump or not can_move:
		return false
	if state != State.GROUNDED and state != State.AIRBORNE and state != State.CROUCHED:
		return false
	if state == State.CROUCHED and not _headroom_clear():
		return false
	var probe := _probe()
	if probe.is_empty():
		return false
	var kind: String = probe["kind"]
	if kind == "vault":
		_start_vault(probe)
		return true
	if kind == "mantle":
		_start_mantle(probe)
		return true
	return false


func _apply_locomotion(intent: MovementIntent, dt: float, takeoff: bool) -> void:
	if takeoff:
		_jump_start_y = _body.global_position.y
		_body.velocity.y = _takeoff_speed()
		if _wall_push != Vector3.ZERO:
			var along := _flat_velocity() - _wall_push.normalized() * _flat_velocity().dot(_wall_push.normalized())
			_set_horizontal(along * 0.35 + _wall_push)
			_wall_push = Vector3.ZERO
	if _should_cut(intent):
		_cut_rise()
	if state == State.AIRBORNE or takeoff:
		_body.velocity.y += _gravity_accel() * dt * 0.5
	elif _body.is_on_floor() or state == State.GROUNDED or state == State.CROUCHED or state == State.SLIDING:
		if _body.velocity.y > 0.0:
			_body.velocity.y = 0.0
		_body.velocity.y = minf(_body.velocity.y, -profile.floor_stick)
	if state == State.SLIDING:
		_apply_slide(intent, dt)
	elif state == State.AIRBORNE:
		_apply_air(intent, dt)
	else:
		_apply_ground(intent, dt)


func _should_cut(intent: MovementIntent) -> bool:
	return state == State.AIRBORNE and _body.velocity.y > 0.0 and not intent.jump_held


func _cut_rise() -> void:
	var risen := _body.global_position.y - _jump_start_y
	var remaining := maxf(profile.min_jump_height - risen, 0.0)
	var cap := sqrt(2.0 * profile.gravity * remaining) if remaining > 0.0 else 0.0
	_body.velocity.y = minf(_body.velocity.y, cap)


func _takeoff_speed() -> float:
	return sqrt(2.0 * profile.gravity * _takeoff_height)


func _gravity_accel() -> float:
	if _body.velocity.y > 0.0:
		return -profile.gravity
	return -profile.gravity * profile.fall_gravity_mult


func _apply_ground(intent: MovementIntent, dt: float) -> void:
	var wish := _wish_direction(intent) if can_move else Vector3.ZERO
	var speed := profile.run_speed
	if state == State.CROUCHED:
		speed *= profile.crouch_speed_mult
	var desired := _along_floor(wish * speed)
	var current := _flat_velocity()
	var rate := profile.acceleration if desired.length_squared() >= current.length_squared() else profile.deceleration
	if desired.length_squared() < 0.0001:
		rate = profile.deceleration
	current = current.move_toward(Vector3(desired.x, 0.0, desired.z), rate * dt)
	_set_horizontal(current)


func _apply_air(intent: MovementIntent, dt: float) -> void:
	var current := _flat_velocity()
	var wish := _wish_direction(intent) if can_move else Vector3.ZERO
	var limit := maxf(profile.run_speed, _air_reference_speed)
	if wish.length_squared() > 0.0001:
		var desired := wish * limit
		current = current.move_toward(desired, profile.acceleration * profile.air_control * dt)
		if current.length() > limit:
			current = current.normalized() * limit
	_set_horizontal(current)


func _apply_slide(intent: MovementIntent, dt: float) -> void:
	_slide_speed -= profile.slide_friction * dt
	if _body.is_on_floor():
		var normal := _body.get_floor_normal()
		var slope := acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0))
		var downhill := Vector3(-normal.x, 0.0, -normal.z)
		if downhill.length_squared() > 0.0001:
			downhill = downhill.normalized()
			var along := downhill.dot(_slide_dir)
			_slide_speed += profile.gravity * sin(slope) * profile.slide_slope_factor * along * dt
	var wish := _wish_direction(intent) if can_move else Vector3.ZERO
	if wish.length_squared() > 0.0001:
		var max_step := deg_to_rad(profile.turn_rate_deg * profile.slide_turn_factor) * dt
		var signed := _slide_dir.signed_angle_to(wish, Vector3.UP)
		_slide_dir = _slide_dir.rotated(Vector3.UP, clampf(signed, -max_step, max_step)).normalized()
	_slide_speed = clampf(_slide_speed, 0.0, profile.max_speed_cap)
	var velocity := _along_floor(_slide_dir * _slide_speed)
	_set_horizontal(velocity)


func _along_floor(vector: Vector3) -> Vector3:
	if not _body.is_on_floor():
		return Vector3(vector.x, 0.0, vector.z)
	var normal := _body.get_floor_normal()
	var projected := vector - normal * vector.dot(normal)
	var flat_len := Vector2(vector.x, vector.z).length()
	if projected.length_squared() < 0.000001:
		return Vector3.ZERO
	return projected.normalized() * flat_len


func _wish_direction(intent: MovementIntent) -> Vector3:
	if _steering:
		var to := intent.steer_point - _body.global_position
		to.y = 0.0
		if to.length() <= profile.arrive_distance:
			return Vector3.ZERO
		return to.normalized()
	if _has_goal:
		return _follower.next_direction(_body.global_position)
	return Vector3.ZERO


func _try_step_up(dt: float) -> void:
	if state != State.GROUNDED and state != State.CROUCHED:
		return
	if not _body.is_on_floor():
		return
	var motion := Vector3(_body.velocity.x, 0.0, _body.velocity.z) * dt
	if motion.length() < 0.001:
		return
	var collision := KinematicCollision3D.new()
	var from := _body.global_transform
	if not _body.test_move(from, motion, collision):
		return
	var normal := collision.get_normal()
	if normal.y > profile.step_face_normal_y:
		return
	var up := Vector3.UP * profile.step_height
	if _body.test_move(from, up):
		return
	var raised := from.translated(up)
	if _body.test_move(raised, motion):
		return
	_body.global_position += up + motion
	var drop := _ray(_body.global_position + Vector3.UP * 0.05, _body.global_position + Vector3.DOWN * (profile.step_height + 0.2))
	if not drop.is_empty():
		_body.global_position.y = drop.position.y
	_step_keep = Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	_did_step = true
	_body.velocity.x = 0.0
	_body.velocity.z = 0.0


func _cap_horizontal() -> void:
	var flat := _flat_velocity()
	if flat.length() > profile.max_speed_cap:
		flat = flat.normalized() * profile.max_speed_cap
		_body.velocity.x = flat.x
		_body.velocity.z = flat.z


func _set_horizontal(flat: Vector3) -> void:
	var velocity := Vector3(flat.x, 0.0, flat.z)
	if velocity.length() > profile.max_speed_cap:
		velocity = velocity.normalized() * profile.max_speed_cap
	_body.velocity.x = velocity.x
	_body.velocity.z = velocity.z


func _post_contact(intent: MovementIntent, was_air: bool, fall_vy: float) -> void:
	if _did_step:
		_body.velocity.x = _step_keep.x
		_body.velocity.z = _step_keep.z
		_did_step = false
		_cap_horizontal()
	if was_air and _body.is_on_floor():
		var fall_speed := maxf(-fall_vy, 0.0)
		landed.emit(fall_speed)
		_air_jumps_left = profile.air_jumps
		if _jump_buffer_left > 0.0:
			_jump_buffer_left = maxf(_jump_buffer_left, 0.05)
		if can_crouch and intent.crouch_slide_held and get_horizontal_speed() >= profile.slide_enter_speed and _slide_cd_left <= 0.0:
			_begin_slide(false)
		elif intent.crouch_slide_held or not _headroom_clear():
			_set_capsule(profile.height_crouch)
			_set_state(State.CROUCHED)
		else:
			_set_capsule(profile.height_stand)
			_set_state(State.GROUNDED)
	elif _was_on_floor and not _body.is_on_floor() and not _jumped_this_step and state != State.VAULTING and state != State.MANTLING:
		_coyote_left = profile.coyote_time
		_air_reference_speed = get_horizontal_speed()
		if state == State.SLIDING:
			_slide_cd_left = profile.slide_cooldown
		if _headroom_clear():
			_set_capsule(profile.height_stand)
		_set_state(State.AIRBORNE)
	_was_on_floor = _body.is_on_floor()


func _post_goal(intent: MovementIntent, dt: float) -> void:
	if _has_goal and _follower.is_unreachable():
		_blocked_time += dt
		if _blocked_time >= profile.stuck_time:
			_clear_goal(false)
			intent.has_move_target = false
		return
	if _has_goal and _follower.is_arrived(_body.global_position, profile.arrive_distance):
		_clear_goal(true)
		intent.has_move_target = false
		return
	if not _has_goal:
		_blocked_time = 0.0
		return
	var slow := get_horizontal_speed() < profile.run_speed * profile.blocked_speed_fraction
	if slow and (state == State.GROUNDED or state == State.CROUCHED):
		_blocked_time += dt
	else:
		_blocked_time = 0.0
	if not _repathed and _blocked_time >= profile.repath_blocked_time:
		_follower.set_goal(_map, _body.global_position, _goal)
		_repathed = true
		_blocked_time = 0.0
		if _follower.is_unreachable():
			_clear_goal(false)
			intent.has_move_target = false
	elif _repathed and _blocked_time >= profile.stuck_time and not _stuck_emitted:
		_stuck_emitted = true
		stuck.emit()


func _clear_goal(emit_arrived: bool) -> void:
	_has_goal = false
	_follower.clear()
	_blocked_time = 0.0
	_repathed = false
	if emit_arrived:
		arrived.emit()


var _aim := Vector3.ZERO


func set_aim(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	_aim = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO


func _update_facing(dt: float) -> void:
	var direction := _aim if _aim != Vector3.ZERO else _flat_velocity()
	if _aim == Vector3.ZERO and state == State.SLIDING:
		direction = _slide_dir
	if direction.length_squared() < 0.04:
		return
	# Godot yaw θ points the nose (−Z) along (−sin θ, −cos θ). The X term is negated
	# so the mouse on the left faces left, not the mirror of it.
	var target := atan2(-direction.x, -direction.z)
	var max_step := deg_to_rad(profile.turn_rate_deg) * dt
	var delta := wrapf(target - _body.rotation.y, -PI, PI)
	_body.rotation.y += clampf(delta, -max_step, max_step)


func _flat_velocity() -> Vector3:
	return Vector3(_body.velocity.x, 0.0, _body.velocity.z)


func _facing() -> Vector3:
	var forward := -_body.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return forward.normalized()


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)


func _mask() -> int:
	return GameConfig.LAYER_WORLD | GameConfig.LAYER_PROPS


func _headroom_clear() -> bool:
	return _capsule_fits(_body.global_position, profile.height_stand)


func _capsule_fits(feet: Vector3, height: float) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = maxf(profile.radius - 0.05, 0.05)
	shape.height = maxf(height - 0.08, shape.radius * 2.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5))
	params.collision_mask = _mask()
	params.exclude = [_body.get_rid()]
	params.margin = 0.0
	var hits := _body.get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, _mask())
	query.exclude = [_body.get_rid()]
	query.hit_from_inside = false
	return _body.get_world_3d().direct_space_state.intersect_ray(query)


func _probe() -> Dictionary:
	var velocity := _flat_velocity()
	var direction := velocity.normalized() if velocity.length() > 0.2 else _facing()
	if velocity.length() > 0.2 and velocity.normalized().dot(direction) < 0.0:
		return {}
	var origin := _body.global_position
	var reach := profile.radius + profile.vault_reach
	var best: Dictionary = {}
	var best_distance := reach + 1.0
	var heights: Array[float] = [profile.probe_knee, profile.probe_chest, profile.probe_head]
	for height in heights:
		var from: Vector3 = origin + Vector3.UP * height
		var hit := _ray(from, from + direction * reach)
		if hit.is_empty():
			continue
		var hit_normal: Vector3 = hit.normal
		var hit_position: Vector3 = hit.position
		if absf(hit_normal.y) > 0.45:
			continue
		var distance: float = from.distance_to(hit_position)
		if distance < best_distance:
			best_distance = distance
			best = hit
	if best.is_empty():
		return {}
	var best_normal: Vector3 = best.normal
	var into := Vector3(-best_normal.x, 0.0, -best_normal.z)
	if into.length_squared() < 0.0001:
		return {}
	into = into.normalized()
	var align := deg_to_rad(profile.vault_align_deg)
	if direction.dot(into) < cos(align):
		return {}
	var face: Vector3 = best.position
	var top := _find_top(face, into)
	if top < 0.0:
		return {}
	var height := top - origin.y
	var far := _far_edge(face, into, top)
	var depth := far.distance_to(Vector3(face.x, far.y, face.z))
	var stand := face + into * minf(profile.radius * 0.5, maxf(depth * 0.4, 0.05))
	stand.y = top + 0.02
	var kind := "none"
	if height <= profile.step_height:
		kind = "step"
	elif height <= profile.vault_max_height:
		kind = "vault"
	elif height <= profile.mantle_max_height:
		kind = "mantle"
	else:
		kind = "wall"
	var landing := far + into * (profile.radius + 0.15)
	var floor_hit := _ray(landing + Vector3.UP * 2.0, landing + Vector3.DOWN * 6.0)
	if not floor_hit.is_empty():
		landing.y = floor_hit.position.y
	else:
		landing.y = origin.y
	var landing_gap := Vector2(landing.x - face.x, landing.z - face.z).length()
	var vault_ok := kind == "vault" and velocity.length() >= profile.vault_min_speed and landing_gap <= profile.vault_landing_reach and _capsule_fits(landing, profile.height_stand)
	var face_dir := _facing()
	if velocity.length() > 1.0:
		face_dir = velocity.normalized()
	var mantle_ok := (kind == "mantle" or (kind == "vault" and not vault_ok)) and height <= profile.mantle_max_height and height > profile.step_height and _capsule_fits(stand, profile.height_stand) and face_dir.dot(into) >= cos(align)
	if vault_ok:
		kind = "vault"
	elif mantle_ok:
		kind = "mantle"
	else:
		return {}
	return {
		"kind": kind,
		"top": top,
		"into": into,
		"face": face,
		"landing": landing,
		"stand": stand,
		"far": far,
	}


func _find_top(face: Vector3, into: Vector3) -> float:
	var best := -1.0
	var feet_y := _body.global_position.y
	var ceiling := feet_y + profile.mantle_max_height + 0.2
	# A 0.3 m wall has no top at exactly vault_top_inset past the near face, so sample inward too.
	var insets: Array[float] = [0.05, profile.vault_top_inset * 0.5, profile.vault_top_inset]
	for inset in insets:
		var sample: Vector3 = Vector3(face.x, ceiling, face.z) + into * inset
		var hit := _ray(sample, Vector3(sample.x, feet_y - 0.5, sample.z))
		if hit.is_empty():
			continue
		var hit_normal: Vector3 = hit.normal
		if hit_normal.y < 0.5:
			continue
		var top_y: float = hit.position.y
		if top_y > feet_y + 0.05 and top_y > best:
			best = top_y
	return best


func _far_edge(face: Vector3, into: Vector3, top: float) -> Vector3:
	var last := face
	last.y = top
	var cursor := face + into * 0.05
	for _i in 48:
		cursor += into * 0.1
		var from := Vector3(cursor.x, top + 0.4, cursor.z)
		var hit := _ray(from, from + Vector3.DOWN * 1.2)
		if hit.is_empty():
			break
		var hit_position: Vector3 = hit.position
		if hit_position.y < top - 0.25:
			break
		last = hit_position
	return last


func _start_vault(probe: Dictionary) -> void:
	var into: Vector3 = probe["into"]
	var face: Vector3 = probe["face"]
	var top: float = probe["top"]
	var landing: Vector3 = probe["landing"]
	var far: Vector3 = probe["far"]
	var start := _body.global_position
	var rise := face - into * (profile.radius + 0.05)
	rise.y = top + 0.1
	var over := far + into * (profile.radius + 0.05)
	over.y = top + 0.1
	_entry_speed = get_horizontal_speed()
	_entry_dir = into
	_begin_path(PackedVector3Array([start, rise, over, landing]), profile.vault_duration, State.VAULTING)


func _start_mantle(probe: Dictionary) -> void:
	var into: Vector3 = probe["into"]
	var face: Vector3 = probe["face"]
	var stand: Vector3 = probe["stand"]
	var top: float = probe["top"]
	var start := _body.global_position
	var rise := face - into * (profile.radius + 0.05)
	rise.y = top + 0.02
	_entry_speed = minf(get_horizontal_speed(), profile.run_speed)
	_entry_dir = into
	_begin_path(PackedVector3Array([start, rise, stand]), profile.mantle_duration, State.MANTLING)


func _begin_path(points: PackedVector3Array, duration: float, next: State) -> void:
	_path_points = points
	_path_duration = maxf(duration, 0.05)
	_path_time = 0.0
	_path_done = false
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	_set_capsule(profile.height_stand)
	_set_state(next)


func _advance_path(dt: float) -> void:
	var t0 := clampf(_path_time / _path_duration, 0.0, 1.0)
	_path_time += dt
	var t1 := clampf(_path_time / _path_duration, 0.0, 1.0)
	var target := _path_sample(t1)
	var delta := target - _body.global_position
	_body.velocity = delta / maxf(dt, 0.0001)
	if t0 >= 1.0 or _path_time >= _path_duration:
		_path_done = true


func _finish_path_if_done() -> void:
	if not _path_done:
		return
	var landing := _path_points[_path_points.size() - 1]
	_body.global_position = landing
	_body.velocity = Vector3(_entry_dir.x, 0.0, _entry_dir.z) * _entry_speed
	_body.velocity.y = -profile.floor_stick
	_path_points = PackedVector3Array()
	_path_done = false
	var floor_y := _ray_floor(landing)
	if absf(landing.y - floor_y) <= 0.2:
		_set_state(State.GROUNDED)
		_was_on_floor = true
	else:
		_air_reference_speed = _entry_speed
		_set_state(State.AIRBORNE)
		_was_on_floor = false
	_body.reset_physics_interpolation()


func _ray_floor(feet: Vector3) -> float:
	var hit := _ray(feet + Vector3.UP * 0.2, feet + Vector3.DOWN * 2.0)
	if hit.is_empty():
		return feet.y
	return hit.position.y


func _path_sample(t: float) -> Vector3:
	if _path_points.size() == 1:
		return _path_points[0]
	var lengths: Array[float] = []
	var total := 0.0
	for i in _path_points.size() - 1:
		var length := _path_points[i].distance_to(_path_points[i + 1])
		lengths.append(length)
		total += length
	if total < 0.0001:
		return _path_points[_path_points.size() - 1]
	var target := clampf(t, 0.0, 1.0) * total
	var walked := 0.0
	for i in lengths.size():
		var length: float = lengths[i]
		if walked + length >= target or i == lengths.size() - 1:
			var u := 0.0 if length < 0.0001 else (target - walked) / length
			return _path_points[i].lerp(_path_points[i + 1], clampf(u, 0.0, 1.0))
		walked += length
	return _path_points[_path_points.size() - 1]


func _cancel_path() -> void:
	_path_points = PackedVector3Array()
	_path_time = 0.0
	_path_done = false
	if state != State.VAULTING and state != State.MANTLING:
		return
	if _body.is_on_floor():
		_set_state(State.GROUNDED)
	else:
		_set_state(State.AIRBORNE)


func _step_forced(dt: float) -> void:
	var previous := clampf(_forced_elapsed / _forced_duration, 0.0, 1.0)
	_forced_elapsed += dt
	var next := clampf(_forced_elapsed / _forced_duration, 0.0, 1.0)
	if _forced_curve != null and _forced_curve.point_count > 0:
		previous = _forced_curve.sample(previous)
		next = _forced_curve.sample(next)
	var from := _forced_start + _forced_displacement * previous
	var to := _forced_start + _forced_displacement * next
	var motion := to - _body.global_position
	if not _forced_ignore_gravity:
		_forced_vy -= profile.gravity * dt
		motion.y += _forced_vy * dt
	var collision := _body.move_and_collide(motion)
	var hit := collision != null
	var ended := hit or _forced_elapsed >= _forced_duration - 0.0001
	if ended:
		var rate := _forced_displacement / _forced_duration
		_body.velocity = Vector3(rate.x, 0.0 if _forced_ignore_gravity else _forced_vy, rate.z)
		if hit:
			var normal := collision.get_normal()
			var into := _body.velocity.dot(normal)
			if into < 0.0:
				_body.velocity -= normal * into
		_cap_horizontal()
		var grounded := _body.is_on_floor()
		if not grounded:
			var floor_hit := _ray(_body.global_position, _body.global_position + Vector3.DOWN * 0.25)
			grounded = not floor_hit.is_empty()
		_set_state(State.GROUNDED if grounded else State.AIRBORNE)
		forced_motion_ended.emit(hit)
