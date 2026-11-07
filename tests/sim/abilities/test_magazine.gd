extends GutTest

## Left-click spending is a magazine. Empty starts a reload. No scene required.


func test_melee_magazine_is_smaller_and_slower_than_ranged() -> void:
	BalanceStore.reset()
	var melee := HeroCatalog.gladiator().stats
	var skirmisher := HeroCatalog.skirmisher().stats
	var ranged := HeroCatalog.slinger().stats
	assert_between(melee.magazine, 7, 10)
	assert_between(skirmisher.magazine, 7, 10)
	assert_between(ranged.magazine, 8, 12)
	assert_lt(ranged.attack_interval, melee.attack_interval)
	assert_gte(ranged.attack_interval, 0.35)
	assert_lt(ranged.attack_damage, melee.attack_damage)
	assert_between(melee.reload_seconds, 1.0, 2.0)
	assert_between(ranged.reload_seconds, 1.0, 2.0)


func test_empty_magazine_reloads_then_fires() -> void:
	var magazine := Magazine.new()
	magazine.fill(8, 1.0, 0.5)
	var spent := 0
	for _shot in 8:
		assert_true(magazine.try_spend())
		spent += 1
		magazine.tick(0.5)
	assert_eq(spent, 8)
	assert_false(magazine.try_spend())
	assert_true(magazine.reloading())
	magazine.tick(1.0)
	assert_false(magazine.reloading())
	assert_eq(magazine.rounds, 8)
	assert_true(magazine.try_spend())
	assert_eq(magazine.rounds, 7)


func test_fire_rate_blocks_a_second_shot() -> void:
	var magazine := Magazine.new()
	magazine.fill(18, 1.2, 0.22)
	assert_true(magazine.try_spend())
	assert_false(magazine.try_spend())
	magazine.tick(0.22)
	assert_true(magazine.try_spend())
