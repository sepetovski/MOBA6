extends GutTest

## The local profile keeps a name, a hero, and match stats. No replay.


var _path := ""


func before_each() -> void:
	_path = "user://test_profile_%d.json" % Time.get_ticks_usec()
	ProfileStore.use_file(_path)


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	ProfileStore.use_file("user://profile.json")


func test_name_role_and_hero_round_trip() -> void:
	var profile := ProfileStore.current()
	profile.set_name("  Nia the Longname Person  ")
	assert_eq(profile.player_name, "Nia the Longname")
	profile.set_role("ranged")
	assert_eq(profile.hero_id, "slinger")
	assert_eq(profile.role, "ranged")
	profile.set_hero("skirmisher")
	assert_eq(profile.role, "melee")
	assert_eq(profile.hero_id, "skirmisher")
	ProfileStore.save()
	ProfileStore.use_file(_path)
	var loaded := ProfileStore.current()
	assert_eq(loaded.player_name, "Nia the Longname")
	assert_eq(loaded.hero_id, "skirmisher")
	assert_eq(loaded.role, "melee")


func test_history_keeps_the_latest_twenty() -> void:
	var profile := ProfileStore.current()
	for index in 25:
		profile.add_match({
			"result": "win" if index < 20 else "loss",
			"kills": 1,
			"deaths": 0,
			"assists": 2,
			"damage": 10,
			"gold": 4,
			"mvp": index == 24,
			"hero_name": "Slinger",
		})
	assert_eq(profile.matches, 25)
	assert_eq(profile.wins, 20)
	assert_eq(profile.losses, 5)
	assert_eq(profile.history.size(), PlayerProfile.HISTORY_LIMIT)
	assert_eq(str(profile.history[0]["result"]), "loss")
	assert_true(bool(profile.history[0]["mvp"]))
	assert_eq(profile.kills, 25)
	assert_eq(profile.mvps, 1)
	ProfileStore.save()
	ProfileStore.use_file(_path)
	var loaded := ProfileStore.current()
	assert_eq(loaded.matches, 25)
	assert_eq(loaded.history.size(), PlayerProfile.HISTORY_LIMIT)
	assert_eq(str(loaded.history[0]["hero_name"]), "Slinger")


func test_empty_name_becomes_gladiator() -> void:
	var profile := ProfileStore.current()
	profile.set_name("   ")
	assert_eq(profile.player_name, "Gladiator")
	assert_eq(profile.career_line(), "No matches yet")


func test_resolve_uses_the_chosen_hero_only_for_the_human() -> void:
	var human := HeroCatalog.resolve(0, true, "slinger")
	var ignored := HeroCatalog.resolve(0, false, "slinger")
	var missing := HeroCatalog.resolve(1, true, "nope")
	assert_eq(String(human.id), "slinger")
	assert_eq(human.stats.attack, UnitStats.Attack.RANGED)
	assert_eq(String(ignored.id), String(HeroCatalog.for_slot(0).id))
	assert_eq(String(missing.id), String(HeroCatalog.for_slot(1).id))
	assert_eq(HeroCatalog.ids_for_role("melee"), ["gladiator", "skirmisher"])
	assert_eq(HeroCatalog.ids_for_role("ranged"), ["slinger"])
	assert_false(HeroCatalog.model_for(&"slinger").is_empty())
