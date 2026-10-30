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
var _towers: Array[TeamTower] = []
var _groves: Array[HealingGrove] = []
var _recent_hits: Dictionary = {}
var _played := 0
const ASSIST_SECONDS := 25.0
const BOUNTY_BASE := 100
const BOUNTY_PER_KILL := 50
const ASSIST_SHARE := 0.25


func _init() -> void:
	process_physics_priority = 0


func start_match(config: MatchConfig, arena: Node3D) -> void:
	_config = config
	_arena = arena
	_info = arena.get_node("ArenaInfo") as ArenaInfo
	rng.seed = config.match_seed
	_set_match_state(Match.State.SETUP)
	_spawn_roster()
	_spawn_towers()
	_spawn_groves()
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
	if _match.state != Match.State.RUNNING and cmd.kind != Command.Kind.STOP and cmd.kind != Command.Kind.AIM:
		return
	_queue.append(cmd)
	if cmd.kind != Command.Kind.AIM:
		DebugService.log_command(cmd)


func spawn_unit(hero: HeroDefinition, team: int, slot: int, controller: int) -> int:
	var id := _next_id
	_next_id += 1
	var unit := SimUnit.new()
	unit.name = "Unit%d" % id
	unit.set_meta("character_model", _random_character())
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


func get_clock_seconds() -> float:
	if _match.state == Match.State.COUNTDOWN:
		return _match.seconds_left()
	if _match.state == Match.State.FINISHED:
		return 0.0
	var played := float(_played) / float(GameConfig.TICK_RATE)
	return maxf(_config.match_seconds - played, 0.0)


func team_gold(team: int) -> int:
	var total := 0
	for unit in get_units():
		if unit.team == team:
			total += unit.state.gold
	return total


func winning_team() -> int:
	var west := team_gold(Team.Id.A)
	var east := team_gold(Team.Id.B)
	if west == east:
		return -1
	return Team.Id.A if west > east else Team.Id.B


func mvp_score(unit: SimUnit) -> int:
	if unit == null:
		return 0
	var state := unit.state
	return state.kills * 100 + state.assists * 40 + int(round(state.damage_dealt * 0.15)) - state.deaths * 60


func mvp_unit() -> SimUnit:
	var best: SimUnit = null
	var best_score := -999999
	for unit in get_units():
		var score := mvp_score(unit)
		if best == null or score > best_score:
			best = unit
			best_score = score
		elif score == best_score and unit.state.gold > best.state.gold:
			best = unit
	return best


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
	var live := _match.state != Match.State.FINISHED
	if live:
		_step_projectiles(step)
		_step_towers(step)
		_step_groves(step)
		_revive_ready()
	_keep_inside()
	if live:
		_separate(step)
	if _match.state == Match.State.RUNNING:
		_played += 1
		var limit := int(round(_config.match_seconds * float(GameConfig.TICK_RATE)))
		if limit < 1:
			limit = 1
		if _played >= limit:
			_finish_match()
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


func _random_character() -> String:
	var folder := "res://art/exports/runtime/characters"
	if DirAccess.open(folder) == null:
		folder = "res://art/exports/characters"
	var directory := DirAccess.open(folder)
	if directory == null:
		return ""
	var paths: PackedStringArray = []
	for file_name in directory.get_files():
		if file_name.ends_with(".glb"):
			paths.append("%s/%s" % [folder, file_name])
	if paths.is_empty():
		return ""
	paths.sort()
	return paths[rng.randi() % paths.size()]


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
	_credit_damage(source_id, target_id, amount)
	GameEvents.damage_dealt.emit(source_id, target_id, amount, 0)
	if unit.state.health > 0.0:
		return
	unit.state.alive = false
	unit.motor.can_move = false
	unit.combat.clear_attack()
	_score_kill(source_id, target_id)
	GameEvents.unit_died.emit(target_id, source_id)
	_respawn_at[target_id] = tick + 6 * GameConfig.TICK_RATE


func damage_from(source_id: int, target_id: int) -> float:
	var source := get_unit(source_id)
	if source == null:
		return 0.0
	return float(source.state.damage_to.get(target_id, 0.0))


func _credit_damage(source_id: int, target_id: int, amount: float) -> void:
	if source_id < 0 or source_id == target_id:
		return
	var source := get_unit(source_id)
	if source == null:
		return
	source.state.damage_dealt += amount
	source.state.damage_to[target_id] = float(source.state.damage_to.get(target_id, 0.0)) + amount
	if not _recent_hits.has(target_id):
		_recent_hits[target_id] = {}
	var hits: Dictionary = _recent_hits[target_id]
	hits[source_id] = tick


func _score_kill(killer_id: int, target_id: int) -> void:
	var victim := get_unit(target_id)
	if victim != null:
		victim.state.deaths += 1
	var killer: SimUnit = null
	if killer_id >= 0 and killer_id != target_id:
		killer = get_unit(killer_id)
		if killer != null:
			killer.state.kills += 1
	var assisters: Array[SimUnit] = []
	var window := int(ASSIST_SECONDS * float(GameConfig.TICK_RATE))
	var hits: Dictionary = _recent_hits.get(target_id, {})
	for source_id in hits.keys():
		var id := int(source_id)
		if id == killer_id or id == target_id:
			continue
		if tick - int(hits[source_id]) > window:
			continue
		var helper := get_unit(id)
		if helper != null:
			helper.state.assists += 1
			assisters.append(helper)
	_recent_hits.erase(target_id)
	if victim != null:
		_pay_bounty(killer, assisters, victim)


func _pay_bounty(killer: SimUnit, assisters: Array[SimUnit], victim: SimUnit) -> void:
	var bounty := BOUNTY_BASE + victim.state.kills * BOUNTY_PER_KILL
	if killer != null:
		_give_gold(killer, bounty)
	if assisters.is_empty():
		return
	var pool := int(round(float(bounty) * ASSIST_SHARE))
	var share := int(pool / assisters.size())
	var extra := pool % assisters.size()
	for index in assisters.size():
		var amount := share
		if index < extra:
			amount += 1
		_give_gold(assisters[index], amount)


func _give_gold(unit: SimUnit, amount: int) -> void:
	if unit == null or amount <= 0:
		return
	unit.state.gold += amount
	GameEvents.gold_awarded.emit(unit.unit_id, amount)


func _finish_match() -> void:
	if _match.state == Match.State.FINISHED:
		return
	_set_frozen(true)
	_set_match_state(Match.State.FINISHED)


func _spawn_groves() -> void:
	_groves.append(_grove(Vector3(-45.0, 0.0, 0.0), 7.0, Team.Id.A, 22.0))
	_groves.append(_grove(Vector3(45.0, 0.0, 0.0), 7.0, Team.Id.B, 22.0))
	_groves.append(_grove(Vector3.ZERO, 8.0, -1, 12.0))


func _grove(at: Vector3, zone_radius: float, team_id: int, rate: float) -> HealingGrove:
	var grove := HealingGrove.new()
	grove.configure(at, zone_radius, team_id, rate)
	_arena.add_child(grove)
	return grove


func _step_groves(dt: float) -> void:
	if _match.state != Match.State.RUNNING:
		return
	for grove in _groves:
		for unit in get_units():
			if not unit.state.alive or not grove.covers(unit.global_position):
				continue
			if grove.team >= 0 and unit.team != grove.team:
				continue
			unit.state.health = minf(unit.state.health + grove.heal_per_second * dt, unit.state.max_health)


func launch_projectile(owner: SimUnit, aim_at: Vector3, direction: Vector3, speed: float, damage: float, color := Color(0.95, 0.45, 0.2)) -> void:
	launch_projectile_from(owner.global_position + Vector3(0.0, 1.1, 0.0), owner.team, owner.unit_id, direction, speed, damage, color)


func launch_projectile_from(origin: Vector3, team: int, owner_id: int, direction: Vector3, speed: float, damage: float, color := Color(0.95, 0.55, 0.15)) -> void:
	var shot := CombatProjectile.new()
	shot.position = origin
	shot.origin = shot.position
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.01:
		flat = Vector3(0, 0, -1)
	shot.velocity = flat.normalized() * speed
	shot.damage = damage
	shot.team = team
	shot.owner_id = owner_id
	shot.color = color
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
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
		if not spent and damage_props(shot.position, shot.radius + 0.4, shot.damage):
			spent = true
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


func damage_props(point: Vector3, radius: float, amount: float, hit_towers := true) -> bool:
	var hit := false
	hit = _hurt_destructibles(_arena, point, radius + 1.2, amount) or hit
	if hit_towers:
		for tower in _towers:
			if tower.health <= 0.0:
				continue
			var flat := tower.global_position - point
			flat.y = 0.0
			if flat.length() > radius + 1.4:
				continue
			hit = true
			tower.hurt(amount)
	return hit


func _hurt_destructibles(node: Node, point: Vector3, reach: float, amount: float) -> bool:
	var hit := false
	if node != _arena and node.has_meta("destructible") and node is Node3D:
		var flat := (node as Node3D).global_position - point
		flat.y = 0.0
		if flat.length() <= reach:
			hit = true
			var left := float(node.get_meta("health")) - amount
			if left <= 0.0:
				node.queue_free()
			else:
				node.set_meta("health", left)
	for child in node.get_children():
		if is_instance_valid(child):
			hit = _hurt_destructibles(child, point, reach, amount) or hit
	return hit


func _spawn_towers() -> void:
	var west := TeamTower.new()
	west.build(Team.Id.A, Vector3(-30.0, 0.0, 0.0))
	var east := TeamTower.new()
	east.build(Team.Id.B, Vector3(30.0, 0.0, 0.0))
	_arena.add_child(west)
	_arena.add_child(east)
	_towers.append(west)
	_towers.append(east)


func _step_towers(dt: float) -> void:
	if _match.state != Match.State.RUNNING:
		return
	for tower in _towers:
		tower.step(dt, self)


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
