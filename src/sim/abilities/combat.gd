class_name Combat extends RefCounted

## Basic attacks and the two abilities on a hero. The simulation calls step.

var attack_target := -1
var cooldowns: Array[float] = []

var _unit: SimUnit
var _stats: UnitStats
var _abilities: Array[AbilityDefinition] = []
var _attack_wait := 0.0
var _dash_slash := false
var _dash_radius := 0.0
var _dash_damage := 0.0
var _bombs: Array[Dictionary] = []


func setup(unit: SimUnit, hero: HeroDefinition) -> void:
	_unit = unit
	_stats = hero.stats if hero.stats != null else UnitStats.new()
	_abilities = hero.abilities
	cooldowns.clear()
	for _ability in _abilities:
		cooldowns.append(0.0)


func attack_range() -> float:
	return _stats.attack_range


func opens_with_dash() -> bool:
	if _abilities.is_empty():
		return false
	return _abilities[0].kind == AbilityDefinition.Kind.DASH


func ability_line() -> String:
	var parts: PackedStringArray = []
	var keys := ["Q", "W"]
	for index in mini(_abilities.size(), keys.size()):
		var ready := "ready" if cooldowns[index] <= 0.0 else "%.1f" % cooldowns[index]
		parts.append("%s %s (%s)" % [keys[index], _abilities[index].display_name, ready])
	var style := "melee" if _stats.attack == UnitStats.Attack.MELEE else "ranged"
	return "%s  %s" % [style, "   ".join(parts)]


func clear_attack() -> void:
	attack_target = -1


func cast(slot: int, point: Vector3) -> void:
	if slot < 0 or slot >= _abilities.size():
		return
	if cooldowns[slot] > 0.0 or not _unit.motor.can_move:
		return
	var ability := _abilities[slot]
	cooldowns[slot] = ability.cooldown
	GameEvents.ability_cast.emit(_unit.unit_id, slot)
	match ability.kind:
		AbilityDefinition.Kind.DASH:
			_start_dash(ability)
		AbilityDefinition.Kind.SLASH:
			_slash(ability.radius, ability.damage)
		AbilityDefinition.Kind.WHIRL:
			_whirl(ability.radius, ability.damage)
		AbilityDefinition.Kind.BOMB:
			_arm_bomb(ability, point)


func begin(dt: float, sim: Simulation) -> void:
	_attack_wait = maxf(_attack_wait - dt, 0.0)
	for index in cooldowns.size():
		cooldowns[index] = maxf(cooldowns[index] - dt, 0.0)
	_tick_bombs(dt, sim)
	if not _unit.state.alive or not _unit.motor.can_move:
		return
	if attack_target < 0:
		return
	var target := sim.get_unit(attack_target)
	if target == null or not target.state.alive or target.team == _unit.team:
		attack_target = -1
		return
	var offset := target.global_position - _unit.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > _stats.attack_range:
		_unit.intent.has_move_target = true
		_unit.intent.move_target = target.global_position
		_unit.intent.steering = false
		return
	_unit.intent.stop = true
	if offset.length_squared() > 0.01:
		_unit.look_at(_unit.global_position + offset, Vector3.UP)
	if _attack_wait > 0.0:
		return
	_attack_wait = _stats.attack_interval
	if _stats.attack == UnitStats.Attack.RANGED:
		var aim := offset.normalized() if distance > 0.05 else -_unit.global_basis.z
		sim.launch_projectile(_unit, target.global_position + Vector3(0, 1.0, 0), aim, _stats.projectile_speed, _stats.attack_damage)
		return
	if distance <= _stats.attack_range + 0.3:
		sim.deal_damage(_unit.unit_id, target.unit_id, _stats.attack_damage)
		_flash(1.6, 0.12)


func finish() -> void:
	if _dash_slash and _unit.motor.state != MovementMotor.State.FORCED:
		_dash_slash = false
		_slash(_dash_radius, _dash_damage)


func _start_dash(ability: AbilityDefinition) -> void:
	var forward := -_unit.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var distance := ability.dash_distance
	if distance < 0.0:
		forward = -forward
		distance = -distance
	_unit.motor.start_forced_motion(forward * distance, ability.dash_seconds)
	if ability.damage > 0.0:
		_dash_slash = true
		_dash_radius = ability.radius
		_dash_damage = ability.damage


func _arm_bomb(ability: AbilityDefinition, point: Vector3) -> void:
	var aim := point - _unit.global_position
	aim.y = 0.0
	if aim.length() > ability.range:
		aim = aim.normalized() * ability.range
	var spot := _unit.global_position + aim
	spot.y = 0.05
	_bombs.append({
		"point": spot,
		"fuse": ability.delay,
		"radius": ability.radius,
		"damage": ability.damage,
	})
	_ring(spot, 0.4, ability.delay + 0.15)


func _tick_bombs(dt: float, sim: Simulation) -> void:
	var keep: Array[Dictionary] = []
	for bomb in _bombs:
		bomb["fuse"] = float(bomb["fuse"]) - dt
		if float(bomb["fuse"]) > 0.0:
			keep.append(bomb)
			continue
		var spot: Vector3 = bomb["point"]
		_hurt_near(sim, spot, float(bomb["radius"]), float(bomb["damage"]), false)
		_ring(spot, float(bomb["radius"]), 0.25)
	_bombs = keep


func _slash(radius: float, damage: float) -> void:
	if damage <= 0.0:
		return
	var forward := -_unit.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return
	forward = forward.normalized()
	var sim := _simulation()
	if sim == null:
		return
	for other in sim.get_units():
		if not _can_hit(other):
			continue
		var offset := other.global_position - _unit.global_position
		offset.y = 0.0
		if offset.length() > radius or offset.normalized().dot(forward) < 0.2:
			continue
		sim.deal_damage(_unit.unit_id, other.unit_id, damage)
	_flash(radius, 0.16)


func _whirl(radius: float, damage: float) -> void:
	var sim := _simulation()
	if sim == null:
		return
	_hurt_near(sim, _unit.global_position, radius, damage, true)
	_ring(_unit.global_position, radius, 0.2)


func _hurt_near(sim: Simulation, spot: Vector3, radius: float, damage: float, ignore_self: bool) -> void:
	for other in sim.get_units():
		if not _can_hit(other):
			continue
		if ignore_self and other.unit_id == _unit.unit_id:
			continue
		var offset := other.global_position - spot
		offset.y = 0.0
		if offset.length() <= radius:
			sim.deal_damage(_unit.unit_id, other.unit_id, damage)


func _can_hit(other: SimUnit) -> bool:
	return other != null and other.state.alive and other.team != _unit.team


func _simulation() -> Simulation:
	var node := _unit.get_parent()
	return node as Simulation


func _flash(length: float, life: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.15, length)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.92, 0.92, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = material
	visual.position = Vector3(0, 1.0, -length * 0.5)
	_unit.add_child(visual)
	_fade(visual, life)


func _ring(spot: Vector3, radius: float, life: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.85, 0.85, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = material
	visual.position = spot
	var host := _unit.get_parent()
	if host == null:
		return
	host.add_child(visual)
	_fade(visual, life)


func _fade(visual: MeshInstance3D, life: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = life
	timer.timeout.connect(visual.queue_free)
	visual.add_child(timer)
	timer.start()
