extends GutTest


func before_each() -> void:
	BalanceStore.reset()


func test_kill_and_assist_gold() -> void:
	assert_eq(BalanceStore.kill_bounty(0), 180)
	assert_eq(BalanceStore.kill_bounty(2), 260)
	assert_eq(BalanceStore.kill_bounty(8), 340)
	assert_eq(int(BalanceStore.rules()["assist_gold"]), 60)
	assert_almost_eq(float(BalanceStore.rules()["gold_per_second"]), 3.0, 0.001)


func test_slinger_is_slower_and_heavier() -> void:
	var ranged := HeroCatalog.slinger()
	var melee := HeroCatalog.gladiator()
	assert_eq(ranged.stats.magazine, 10)
	assert_almost_eq(ranged.stats.attack_interval, 0.42, 0.001)
	assert_almost_eq(ranged.stats.attack_damage, 12.0, 0.001)
	assert_eq(melee.stats.magazine, 7)
	assert_almost_eq(melee.stats.max_health, 170.0, 0.001)
	assert_eq(HeroCatalog.skirmisher().movement.dash_charges, 3)


func test_flat_health_and_percent_damage_stack_from_the_base() -> void:
	var stats := UnitStats.new()
	stats.max_health = 100.0
	stats.attack_damage = 10.0
	stats.attack_interval = 0.4
	stats.attack = UnitStats.Attack.RANGED
	var move := MovementProfile.new()
	move.run_speed = 4.0
	move.dash_charges = 2
	move.dash_recharge = 4.0
	var heart := ItemDefinition.new()
	heart.id = "heart"
	heart.mods.append({"stat": "health", "mode": "flat", "amount": 40.0})
	var blade := ItemDefinition.new()
	blade.id = "blade"
	blade.mods.append({"stat": "attack_damage", "mode": "percent", "amount": 12.0})
	var quick := ItemDefinition.new()
	quick.id = "quick"
	quick.mods.append({"stat": "attack_interval", "mode": "percent", "amount": 50.0})
	BalanceStore.save(BalanceStore.rules(), {}, [heart, blade, quick])
	var built := Loadout.apply(stats, move, 1.0, PackedStringArray(["heart", "blade", "quick"]))
	var next := built["stats"] as UnitStats
	assert_almost_eq(next.max_health, 140.0, 0.001)
	assert_almost_eq(next.attack_damage, 11.2, 0.001)
	assert_almost_eq(next.attack_interval, 0.30, 0.001)


func test_stat_items_are_not_actives() -> void:
	var actives := 0
	for item in BalanceStore.items():
		if item.active != "none":
			actives += 1
		else:
			assert_ne(item.category, "active")
	assert_eq(actives, 3)
	assert_eq(int(BalanceStore.rules()["inventory_slots"]), 10)
	assert_eq(int(BalanceStore.rules()["active_slots"]), 4)


func test_added_hero_uses_the_template_kit() -> void:
	var id := BalanceStore.add_hero("Night Blade", "melee")
	var hero := HeroCatalog.by_id(StringName(id))
	assert_eq(hero.display_name, "Night Blade")
	assert_eq(hero.stats.attack, UnitStats.Attack.MELEE)
	assert_eq(hero.abilities.size(), 2)
	assert_true(HeroCatalog.ids_for_role("melee").has(id))
	assert_false(HeroCatalog.model_for(hero.id).is_empty())
	BalanceStore.reset()


func test_rules_round_trip() -> void:
	var rules := BalanceStore.rules()
	rules["match_seconds"] = 90.0
	rules["gold_per_second"] = 5.0
	BalanceStore.save(rules, {}, BalanceStore.items())
	BalanceStore.reload()
	assert_almost_eq(float(BalanceStore.rules()["match_seconds"]), 90.0, 0.001)
	assert_almost_eq(float(BalanceStore.rules()["gold_per_second"]), 5.0, 0.001)
	BalanceStore.reset()
