class_name BotController extends Node

## Decisions become Commands. The bot never moves its unit directly.

enum Difficulty { OFF, IDLE, WANDER, CHASE }

var _unit_id := -1
var _sim: Simulation
var _config: BotConfig
var _difficulty := Difficulty.CHASE
var _rng := RandomNumberGenerator.new()
var _next_think := 0
var _pause_until := 0
var _slide_release := -1
var _last_stuck_tick := -10000
var _had_goal := false
var _slow_ticks := 0
var _left_gate := false
var _seq := 0


func _init() -> void:
	process_physics_priority = -10


func difficulty() -> int:
	return _difficulty


func set_difficulty(next: int) -> void:
	_difficulty = next as Difficulty


func bind(bound_unit_id: int, sim: Simulation, config: BotConfig, difficulty: int) -> void:
	_unit_id = bound_unit_id
	_sim = sim
	_config = config
	_difficulty = difficulty as Difficulty
	_rng.seed = sim.bot_seed(bound_unit_id)
	var jitter := int(round(_rng.randf_range(0.0, config.reaction_jitter) * float(GameConfig.TICK_RATE)))
	_next_think = jitter
	GameEvents.unit_stuck.connect(_on_stuck)
	add_to_group(&"bot_controller")


func _physics_process(_delta: float) -> void:
	if _sim == null or _difficulty == Difficulty.OFF:
		return
	if _sim.get_match_state() != Match.State.RUNNING:
		return
	var unit := _sim.get_unit(_unit_id)
	if unit == null or not unit.state.alive:
		return
	if _slide_release >= 0 and _sim.tick >= _slide_release:
		_command(Command.Kind.CROUCH_SLIDE, unit.global_position, false)
		_slide_release = -1
	if unit.motor.has_goal() and unit.motor.get_horizontal_speed() < 0.4:
		_slow_ticks += 1
	else:
		_slow_ticks = 0
	if _slow_ticks >= 50:
		_slow_ticks = 0
		_pause_until = 0
		_command(Command.Kind.STOP, unit.global_position, true)
		_command(Command.Kind.JUMP, unit.global_position, true)
		var side := 5.0 if unit.unit_id % 2 == 0 else -5.0
		_command(Command.Kind.STEER, unit.global_position + Vector3(0.0, 0.0, side), true)
	if _sim.tick < _next_think:
		return
	var interval := maxi(int(round(_config.think_interval * float(GameConfig.TICK_RATE))), 1)
	_next_think = _sim.tick + interval
	if _difficulty == Difficulty.IDLE:
		return
	if absf(unit.global_position.x) > 36.0:
		_command(Command.Kind.STEER, Vector3(0.0, 0.0, unit.global_position.z * 0.2), true)
		return
	if _left_gate == false:
		_left_gate = true
		_command(Command.Kind.STEER, Vector3.ZERO, false)
	var has_goal := unit.motor.has_goal()
	if _had_goal and not has_goal:
		var pause := _rng.randf_range(_config.wander_pause_min, _config.wander_pause_max)
		_pause_until = _sim.tick + int(round(pause * float(GameConfig.TICK_RATE)))
	_had_goal = has_goal
	if _sim.tick < _pause_until and not has_goal:
		return
	_think(unit)


func _think(unit: SimUnit) -> void:
	var moving := unit.motor.has_goal() or unit.motor.get_horizontal_speed() > 0.4
	if _difficulty == Difficulty.CHASE:
		var enemy := _nearest_enemy(unit)
		if enemy != null:
			var flat := Vector2(enemy.global_position.x - unit.global_position.x, enemy.global_position.z - unit.global_position.z)
			if flat.length() <= _config.chase_stop_distance:
				_command(Command.Kind.STOP, unit.global_position, true)
			else:
				_command(Command.Kind.MOVE_TO, enemy.global_position, true)
			_maybe_mobility(unit, true)
			return
	if unit.motor.has_goal():
		_maybe_mobility(unit, moving)
		return
	if _sim.tick < _pause_until:
		return
	_wander(unit)


func _wander(unit: SimUnit) -> void:
	var angle := _rng.randf() * TAU
	var radius := _rng.randf_range(2.0, _config.wander_radius)
	var raw := unit.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	var map := unit.get_world_3d().navigation_map
	var point := NavigationServer3D.map_get_closest_point(map, raw)
	_command(Command.Kind.MOVE_TO, point, true)


func _maybe_mobility(unit: SimUnit, moving: bool) -> void:
	if not moving:
		return
	if _rng.randf() < _config.jump_rate * _config.think_interval:
		_command(Command.Kind.JUMP, unit.global_position, true)
		_command(Command.Kind.JUMP, unit.global_position, false)
	if _slide_release < 0 and _rng.randf() < _config.slide_rate * _config.think_interval:
		_command(Command.Kind.CROUCH_SLIDE, unit.global_position, true)
		var hold := _rng.randf_range(_config.slide_hold_min, _config.slide_hold_max)
		_slide_release = _sim.tick + maxi(int(round(hold * float(GameConfig.TICK_RATE))), 1)


func _nearest_enemy(unit: SimUnit) -> SimUnit:
	var best: SimUnit = null
	var best_d := _config.chase_range
	for other in _sim.get_units():
		if other.team == unit.team or not other.state.alive:
			continue
		var flat := Vector2(other.global_position.x - unit.global_position.x, other.global_position.z - unit.global_position.z)
		var distance := flat.length()
		if distance < best_d:
			best_d = distance
			best = other
	return best


func _on_stuck(stuck_id: int) -> void:
	if stuck_id != _unit_id or _sim == null:
		return
	var unit := _sim.get_unit(_unit_id)
	if unit == null:
		return
	_pause_until = 0
	_wander(unit)
	var window := int(2.0 * float(GameConfig.TICK_RATE))
	if _sim.tick - _last_stuck_tick <= window:
		_command(Command.Kind.JUMP, unit.global_position, true)
	_last_stuck_tick = _sim.tick


func _command(kind: Command.Kind, point: Vector3, pressed: bool) -> void:
	var cmd := Command.new()
	cmd.unit_id = _unit_id
	cmd.kind = kind
	cmd.point = point
	cmd.pressed = pressed
	cmd.seq = _seq
	_seq += 1
	_sim.submit_command(cmd)
