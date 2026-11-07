class_name HeroCatalog extends RefCounted

## The three greybox heroes. Same movement profile, different attacks.

const SHIPPED: PackedStringArray = ["gladiator", "skirmisher", "slinger"]


static func for_slot(slot: int) -> HeroDefinition:
	var roster: Array[HeroDefinition] = [gladiator(), slinger(), skirmisher()]
	var index := posmod(slot, roster.size())
	return roster[index]


static func all_ids() -> PackedStringArray:
	var ids := SHIPPED.duplicate()
	for extra in BalanceStore.hero_ids():
		if not ids.has(extra):
			ids.append(extra)
	return ids


static func by_id(id: StringName) -> HeroDefinition:
	var hero := _shipped(id)
	if hero == null:
		hero = _custom(id)
	if hero == null:
		return null
	BalanceStore.apply_hero(hero)
	return hero


static func resolve(slot: int, human: bool, hero_id: String) -> HeroDefinition:
	if human and not hero_id.is_empty():
		var picked := by_id(StringName(hero_id))
		if picked != null:
			return picked
	return for_slot(slot)


static func role_name(hero: HeroDefinition) -> String:
	if hero != null and hero.stats != null and hero.stats.attack == UnitStats.Attack.RANGED:
		return "ranged"
	return "melee"


static func ids_for_role(role: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for id in all_ids():
		var hero := by_id(StringName(id))
		if role_name(hero) == role:
			ids.append(id)
	return ids


static func blurb(id: String) -> String:
	match id:
		"gladiator":
			return "Melee. Dash Strike and Cleave."
		"skirmisher":
			return "Melee. Lunge and Whirl."
		"slinger":
			return "Ranged. Bomb and a faster shot."
		_:
			var overlay := BalanceStore.hero_overlay(id)
			var kind := "Ranged" if str(overlay.get("attack", "melee")) == "ranged" else "Melee"
			return "%s. Uses the %s kit." % [kind, str(overlay.get("template", "gladiator"))]
	return ""


static func model_for(id: StringName) -> String:
	var file_name := ""
	match String(id):
		"gladiator":
			file_name = "knight_C.glb"
		"skirmisher":
			file_name = "elf_C.glb"
		"slinger":
			file_name = "mage_C.glb"
		_:
			var template := str(BalanceStore.hero_overlay(String(id)).get("template", ""))
			if not template.is_empty() and template != String(id):
				return model_for(StringName(template))
			return ""
	var path := "res://art/exports/runtime/characters/%s" % file_name
	if ResourceLoader.exists(path):
		return path
	return ""


static func template_sheet(attack: String) -> Dictionary:
	var ranged := attack == "ranged"
	var hero := _shipped(StringName("slinger" if ranged else "gladiator"))
	return {
		"display_name": "New hero",
		"attack": "ranged" if ranged else "melee",
		"template": "slinger" if ranged else "gladiator",
		"max_health": hero.stats.max_health,
		"run_speed": hero.movement.run_speed,
		"attack_damage": hero.stats.attack_damage,
		"attack_interval": hero.stats.attack_interval,
		"magazine": hero.stats.magazine,
		"reload_seconds": hero.stats.reload_seconds,
		"attack_range": hero.stats.attack_range,
		"projectile_speed": hero.stats.projectile_speed,
		"dash_charges": hero.movement.dash_charges,
		"dash_recharge": hero.movement.dash_recharge,
		"dash_speed": hero.movement.dash_speed,
		"damage_taken": 1.0,
	}


static func gladiator() -> HeroDefinition:
	return by_id(&"gladiator")


static func _gladiator() -> HeroDefinition:
	var hero := _base(&"gladiator", "Gladiator")
	hero.movement = _move(4.3, 2, 5.0, 12.5)
	hero.stats.attack = UnitStats.Attack.MELEE
	hero.stats.max_health = 170.0
	hero.stats.attack_damage = 18.0
	hero.stats.attack_range = 3.2
	hero.stats.attack_interval = 0.55
	hero.stats.magazine = 7
	hero.stats.reload_seconds = 1.8
	hero.abilities = [
		_slash(&"dash_strike", "Dash Strike", 24.0, 2.4, 6.5, 0.2, 6.0),
		_kind(&"cleave", "Cleave", AbilityDefinition.Kind.SLASH, 16.0, 2.6, 4.0),
	]
	return hero


static func slinger() -> HeroDefinition:
	return by_id(&"slinger")


static func _slinger() -> HeroDefinition:
	var hero := _base(&"slinger", "Slinger")
	hero.movement = _move(4.4, 2, 4.8, 12.5)
	hero.stats.attack = UnitStats.Attack.RANGED
	hero.stats.max_health = 110.0
	hero.stats.attack_damage = 12.0
	hero.stats.attack_range = 14.0
	hero.stats.attack_interval = 0.42
	hero.stats.projectile_speed = 22.0
	hero.stats.magazine = 10
	hero.stats.reload_seconds = 1.6
	hero.abilities = [
		_bomb(),
		_dash_only(&"backstep", "Backstep", 5.0, 0.16, 5.0, true),
	]
	return hero


static func skirmisher() -> HeroDefinition:
	return by_id(&"skirmisher")


static func _skirmisher() -> HeroDefinition:
	var hero := _base(&"skirmisher", "Skirmisher")
	hero.movement = _move(5.0, 3, 3.8, 12.5)
	hero.stats.attack = UnitStats.Attack.MELEE
	hero.stats.max_health = 125.0
	hero.stats.attack_damage = 13.0
	hero.stats.attack_range = 3.0
	hero.stats.attack_interval = 0.45
	hero.stats.magazine = 8
	hero.stats.reload_seconds = 1.4
	hero.abilities = [
		_slash(&"lunge", "Lunge", 14.0, 1.6, 7.0, 0.18, 5.0),
		_kind(&"whirl", "Whirl", AbilityDefinition.Kind.WHIRL, 14.0, 2.6, 6.0),
	]
	return hero


static func _shipped(id: StringName) -> HeroDefinition:
	match String(id):
		"gladiator":
			return _gladiator()
		"slinger":
			return _slinger()
		"skirmisher":
			return _skirmisher()
	return null


static func _custom(id: StringName) -> HeroDefinition:
	var overlay := BalanceStore.hero_overlay(String(id))
	var template := str(overlay.get("template", ""))
	if template.is_empty():
		return null
	var hero := _shipped(StringName(template))
	if hero == null:
		return null
	hero.id = id
	hero.display_name = str(overlay.get("display_name", id))
	if str(overlay.get("attack", "melee")) == "ranged":
		hero.stats.attack = UnitStats.Attack.RANGED
	else:
		hero.stats.attack = UnitStats.Attack.MELEE
	return hero


static func _move(run: float, charges: int, recharge: float, dash: float) -> MovementProfile:
	var profile := (load("res://data/movement_profiles/gladiator.tres") as MovementProfile).duplicate(true) as MovementProfile
	profile.run_speed = run
	profile.dash_charges = charges
	profile.dash_recharge = recharge
	profile.dash_speed = dash
	return profile


static func _base(id: StringName, display_name: String) -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.id = id
	hero.display_name = display_name
	hero.stats = UnitStats.new()
	hero.stats.max_health = 140.0
	return hero


static func _kind(id: StringName, display_name: String, kind: AbilityDefinition.Kind, damage: float, radius: float, cooldown: float) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.id = id
	ability.display_name = display_name
	ability.kind = kind
	ability.damage = damage
	ability.radius = radius
	ability.cooldown = cooldown
	return ability


static func _slash(id: StringName, display_name: String, damage: float, radius: float, distance: float, seconds: float, cooldown: float) -> AbilityDefinition:
	var ability := _kind(id, display_name, AbilityDefinition.Kind.DASH, damage, radius, cooldown)
	ability.dash_distance = distance
	ability.dash_seconds = seconds
	return ability


static func _dash_only(id: StringName, display_name: String, distance: float, seconds: float, cooldown: float, backward: bool) -> AbilityDefinition:
	var ability := _kind(id, display_name, AbilityDefinition.Kind.DASH, 0.0, 0.0, cooldown)
	ability.dash_distance = -distance if backward else distance
	ability.dash_seconds = seconds
	return ability


static func _bomb() -> AbilityDefinition:
	var ability := _kind(&"bomb", "Bomb", AbilityDefinition.Kind.BOMB, 26.0, 3.2, 7.0)
	ability.range = 12.0
	ability.delay = 0.6
	return ability
