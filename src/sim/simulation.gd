class_name Simulation extends Node

## Fixed-tick owner of gameplay state. Commands in, presentation out. No camera, no HUD.

signal ticked(tick: int)

var tick := 0
var rng := RandomNumberGenerator.new()

var _config: MatchConfig
var _arena: Node3D
var _info: ArenaInfo
var _match := Match.new()
var _started := false
var _units: Dictionary = {}
var _order: Array[int] = []
var _queue: Array[Command] = []
var _bot_seeds: Dictionary = {}
var _next_id := 1
var _shots: Array[CombatProjectile] = []
var _respawn_at: Dictionary = {}


func _init() -> void:
	process_physics_priority = 0


func start_match(config: MatchConfig, arena: Node3D) -> void:
	_config = config
	_arena = arena
	_info = arena.get_node("ArenaInfo") as ArenaInfo
	rng.seed = config.match_seed
	_set_match_state(Match.State.SETUP)
	_spawn_roster()
	_match.begin_countdown(config.countdown_seconds)
	_set_frozen(true)
	_set_match_state(Match.State.COUNTDOWN)
	if _match.ticks_left <= 0:
		_enter_running()
	_started = true


func submit_command(cmd: Command) -> void:
	cmd.tick = tick + 1
	var unit := get_unit(cmd.unit_id)
	if unit == null or not unit.state.alive:
		return
	if _match.state != Match.State.RUNNING and cmd.kind != Command.Kind.STOP:
		return
	_queue.append(cmd)
	DebugService.log_command(cmd)


func spawn_unit(hero: HeroDefinition, team: int, slot: int, controller: int) -> int:
	var id := _next_id
	_next_id += 1
	var unit := SimUnit.new()
	unit.name = "Unit%d" % id
	add_child(unit)
	var nav_map := _arena.get_world_3d().navigation_map
	unit.setup(id, hero, team, slot, nav_map)
	unit.state.controller = controller as UnitState.Controller
	unit.place_at(_info.get_spawn_slot(team, slot))
	_units[id] = unit
	_order.append(id)
	_order.sort()
	if controller == UnitState.Controller.BOT:
		_bot_seeds[id] = rng.randi()
	GameEvents.unit_spawned.emit(id)
	return id


func get_unit(unit_id: int) -> SimUnit:
	return _units.get(unit_id) as SimUnit


func get_units() -> Array[SimUnit]:
	var listed: Array[SimUnit] = []
	for id in _order:
		var unit := _units[id] as SimUnit
		if unit != null:
			listed.append(unit)
	return listed


func get_match_state() -> int:
	return _match.state


func get_countdown_seconds() -> float:
	return _match.seconds_left()


func get_human() -> SimUnit:
	for unit in get_units():
		if unit.state.controller == UnitState.Controller.HUMAN:
			return unit
	return null


func bot_seed(unit_id: int) -> int:
	return int(_bot_seeds.get(unit_id, 1))


func debug_teleport(unit_id: int, point: Vector3) -> void:
	if not OS.is_debug_build():
		return
	var unit := get_unit(unit_id)
	if unit == null:
		return
	unit.global_position = point
	unit.velocity = Vector3.ZERO
	unit.reset_physics_interpolation()


func debug_respawn_all() -> void:
	if not OS.is_debug_build():
		return
	for unit in get_units():
		unit.place_at(unit.spawn_transform)
		unit.motor.reset_motion()
		unit.state.alive = true
		unit.state.health = unit.state.max_health


func debug_damage(unit_id: int, amount: float) -> void:
	if not OS.is_debug_build():
		return
	var unit := get_unit(unit_id)
	if unit == null or not unit.state.alive:
		return
	unit.state.health = maxf(unit.state.health - amount, 0.0)
	GameEvents.damage_dealt.emit(0, unit_id, amount, 0)
	if unit.state.health <= 0.0:
		unit.state.alive = false
		GameEvents.unit_died.emit(unit_id, 0)


var record_tick_cost := false


func _physics_process(_delta: float) -> void:
	if not _started:
		return
	var started := 0
	if record_tick_cost:
		started = Time.get_ticks_usec()
	tick += 1
	_apply_due_commands()
	if _match.advance():
		_enter_running()
	var step := 1.0 / float(GameConfig.TICK_RATE)
	for id in _order:
		var unit := _units[id] as SimUnit
		if unit != null and unit.state.alive:
			unit.sim_step(step, self)
	_step_projectiles(step)
	_revive_ready()
	_keep_inside()
	_separate(step)
	if record_tick_cost:
		_tick_times.append(Time.get_ticks_usec() - started)
	ticked.emit(tick)


var _tick_times: Array[int] = []


func take_tick_times() -> Array[int]:
	var copy := _tick_times.duplicate()
	_tick_times.clear()
	return copy


func _apply_due_commands() -> void:
	var due: Array[Command] = []
	var later: Array[Command] = []
	for cmd in _queue:
		if cmd.tick <= tick:
			due.append(cmd)
		else:
			later.append(cmd)
	_queue = later
	due.sort_custom(func(a: Command, b: Command) -> bool:
		if a.unit_id == b.unit_id:
			return a.seq < b.seq
		return a.unit_id < b.unit_id
	)
	for cmd in due:
		var unit := get_unit(cmd.unit_id)
		if unit != null and unit.state.alive:
			unit.apply_command(cmd)


func _enter_running() -> void:
	_match.state = Match.State.RUNNING
	_set_frozen(false)
	_set_match_state(Match.State.RUNNING)


func _set_frozen(frozen: bool) -> void:
	for unit in get_units():
		unit.set_frozen(frozen)


func _set_match_state(next: int) -> void:
	_match.state = next as Match.State
	GameEvents.match_state_changed.emit(next)


func _spawn_roster() -> void:
	for slot in 6:
		var controller := UnitState.Controller.BOT
		if _config.human_team == Team.Id.A and _config.human_slot == slot:
			controller = UnitState.Controller.HUMAN
		spawn_unit(HeroCatalog.for_slot(slot), Team.Id.A, slot, controller)
	for slot in 6:
		var controller := UnitState.Controller.BOT
		if _config.human_team == Team.Id.B and _config.human_slot == slot:
			controller = UnitState.Controller.HUMAN
		spawn_unit(HeroCatalog.for_slot(slot), Team.Id.B, slot, controller)


func deal_damage(source_id: int, target_id: int, amount: float) -> void:
	var unit := get_unit(target_id)
	if unit == null or not unit.state.alive or amount <= 0.0:
		return
	unit.state.health = maxf(unit.state.health - amount, 0.0)
	GameEvents.damage_dealt.emit(source_id, target_id, amount, 0)
	if unit.state.health > 0.0:
		return
	unit.state.alive = false
	unit.motor.can_move = false
	unit.combat.clear_attack()
	GameEvents.unit_died.emit(target_id, source_id)
	_respawn_at[target_id] = tick + 6 * GameConfig.TICK_RATE


func launch_projectile(owner: SimUnit, aim_at: Vector3, direction: Vector3, speed: float, damage: float) -> void:
	var shot := CombatProjectile.new()
	shot.position = owner.global_position + Vector3(0.0, 1.1, 0.0)
	shot.origin = shot.position
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.01:
		flat = Vector3(aim_at.x - shot.position.x, 0.0, aim_at.z - shot.position.z)
	shot.velocity = flat.normalized() * speed
	shot.damage = damage
	shot.team = owner.team
	shot.owner_id = owner.unit_id
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.9, 0.9)
	visual.material_override = material
	visual.position = shot.position
	add_child(visual)
	shot.mesh = visual
	_shots.append(shot)


func _step_projectiles(dt: float) -> void:
	var keep: Array[CombatProjectile] = []
	for shot in _shots:
		shot.position += shot.velocity * dt
		if shot.mesh != null:
			shot.mesh.global_position = shot.position
		var spent := shot.position.distance_to(shot.origin) > 28.0
		if not spent:
			for unit in get_units():
				if not unit.state.alive or unit.team == shot.team:
					continue
				var reach := shot.radius + unit.motor.profile.radius
				if unit.global_position.distance_to(shot.position) <= reach + 0.6:
					deal_damage(shot.owner_id, unit.unit_id, shot.damage)
					spent = true
					break
		if spent:
			if shot.mesh != null:
				shot.mesh.queue_free()
		else:
			keep.append(shot)
	_shots = keep


func _revive_ready() -> void:
	var due: Array[int] = []
	for key in _respawn_at.keys():
		if tick >= int(_respawn_at[key]):
			due.append(int(key))
	for id in due:
		_respawn_at.erase(id)
		var unit := get_unit(id)
		if unit == null:
			continue
		unit.state.alive = true
		unit.state.health = unit.state.max_health
		unit.place_at(unit.spawn_transform)
		unit.motor.reset_motion()
		unit.set_frozen(_match.state != Match.State.RUNNING)
		unit.combat.clear_attack()


func _keep_inside() -> void:
	for unit in get_units():
		if not unit.state.alive:
			continue
		var point := unit.global_position
		var in_tunnel := absf(point.z) <= 4.2 and absf(point.x) >= 38.0 and absf(point.x) <= 49.2
		var inside := in_tunnel or _info.contains_xz(Vector2(point.x, point.z))
		if inside and point.y > -1.0 and point.y < 8.0:
			continue
		unit.place_at(unit.spawn_transform)
		unit.motor.reset_motion()
		unit.set_frozen(_match.state != Match.State.RUNNING)


func _separate(dt: float) -> void:
	var listed := get_units()
	for i in listed.size():
		for j in range(i + 1, listed.size()):
			var a := listed[i]
			var b := listed[j]
			if not a.state.alive or not b.state.alive:
				continue
			if a.scripted_motion() or b.scripted_motion():
				continue
			var delta := b.global_position - a.global_position
			delta.y = 0.0
			var distance := delta.length()
			var limit := (a.motor.profile.radius + b.motor.profile.radius) * _config.separation_radius_scale
			if distance >= limit:
				continue
			var direction := Vector3.RIGHT if a.unit_id < b.unit_id else Vector3.LEFT
			if distance > 0.001:
				direction = delta / distance
			var push := minf((limit - distance) * 0.5, _config.separation_speed * dt)
			a.move_and_collide(-direction * push)
			b.move_and_collide(direction * push)
