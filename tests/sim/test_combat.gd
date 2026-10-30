extends GutTest

func test_melee_dash_and_bomb() -> void:
	var layout := load("res://data/arena_layouts/octagon_ring_v1.tres") as ArenaLayout
	var arena := ArenaBuilder.build(layout)
	add_child_autofree(arena)
	await arena.navigation_ready
	var config := MatchConfig.new()
	config.countdown_seconds = 0.0
	config.human_team = Team.Id.A
	config.human_slot = 0
	config.bot_difficulty = BotController.Difficulty.OFF
	var simulation := Simulation.new()
	add_child_autofree(simulation)
	simulation.start_match(config, arena)
	var hero := simulation.get_human()
	var enemy := _enemy(simulation, hero.team)
	var ally := _ally(simulation, hero)
	enemy.place_at(Transform3D(Basis.IDENTITY, hero.global_position + Vector3(1.6, 0, 0)))
	var before_enemy := enemy.state.health
	var before_ally := ally.state.health
	hero.combat.attack_target = enemy.unit_id
	for _i in 8:
		await get_tree().physics_frame
	assert_lt(enemy.state.health, before_enemy, "a melee swing should hurt the enemy")
	ally.place_at(Transform3D(Basis.IDENTITY, hero.global_position + Vector3(-1.5, 0, 0)))
	before_ally = ally.state.health
	hero.combat.attack_target = ally.unit_id
	for _i in 8:
		await get_tree().physics_frame
	assert_eq(ally.state.health, before_ally, "an ally is not a target")
	hero.combat.clear_attack()
	hero.basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
	var start_x := hero.global_position.x
	hero.combat.cast(0, hero.global_position)
	for _i in 20:
		await get_tree().physics_frame
	assert_gt(hero.global_position.x - start_x, 2.0, "dash strike should carry the gladiator forward")
	var slinger := _named(simulation, "Slinger", hero.team)
	var bomb_target := _enemy(simulation, slinger.team)
	bomb_target.place_at(Transform3D(Basis.IDENTITY, slinger.global_position + Vector3(4, 0, 0)))
	var bomb_health := bomb_target.state.health
	slinger.combat.cast(0, bomb_target.global_position)
	for _i in 50:
		await get_tree().physics_frame
	assert_lt(bomb_target.state.health, bomb_health, "the bomb should land on the enemy")
	var victim := enemy
	victim.state.alive = true
	victim.state.health = 400.0
	victim.state.deaths = 0
	victim.motor.can_move = true
	hero.state.kills = 0
	var helper := ally
	helper.state.assists = 0
	victim.state.kills = 4
	var hero_gold := hero.state.gold
	var ally_gold := helper.state.gold
	simulation.deal_damage(helper.unit_id, victim.unit_id, 20.0)
	simulation.deal_damage(hero.unit_id, victim.unit_id, 400.0)
	assert_eq(hero.state.kills, 1, "the last hit is the kill")
	assert_eq(victim.state.deaths, 1, "the victim records a death")
	assert_eq(helper.state.assists, 1, "damage inside the assist window counts")
	assert_almost_eq(simulation.damage_from(hero.unit_id, victim.unit_id), hero.state.damage_to[victim.unit_id], 0.01)
	assert_gte(hero.state.damage_dealt, 400.0)
	assert_eq(hero.state.gold - hero_gold, 300, "bounty is 100 plus 50 for each kill the victim had")
	assert_eq(helper.state.gold - ally_gold, 75, "one assist takes the whole 25 percent")
	for unit in simulation.get_units():
		unit.state.kills = 0
		unit.state.assists = 0
		unit.state.deaths = 0
		unit.state.damage_dealt = 0.0
	hero.state.kills = 5
	hero.state.damage_dealt = 800.0
	hero.state.deaths = 1
	helper.state.kills = 1
	helper.state.damage_dealt = 2000.0
	helper.state.deaths = 6
	assert_eq(simulation.mvp_unit().unit_id, hero.unit_id, "kills outweigh raw damage when deaths are high")
	hero.combat.clear_attack()
	hero.place_at(Transform3D(Basis.IDENTITY, Vector3.ZERO))
	hero.state.alive = true
	hero.state.health = 40.0
	var hurt := hero.state.health
	for _i in 30:
		await get_tree().physics_frame
	assert_gt(hero.state.health, hurt, "the centre grove should heal whoever stands in it")


func _enemy(simulation: Simulation, team: int) -> SimUnit:
	for unit in simulation.get_units():
		if unit.team != team and unit.state.alive:
			return unit
	return null


func _ally(simulation: Simulation, hero: SimUnit) -> SimUnit:
	for unit in simulation.get_units():
		if unit.team == hero.team and unit.unit_id != hero.unit_id:
			return unit
	return null


func _named(simulation: Simulation, hero_name: String, team: int) -> SimUnit:
	for unit in simulation.get_units():
		if unit.team == team and unit.hero_name == hero_name:
			return unit
	return null
