class_name HeroCatalog extends RefCounted

## The three greybox heroes. Same movement profile, different attacks.

static func for_slot(slot: int) -> HeroDefinition:
	var roster: Array[HeroDefinition] = [gladiator(), slinger(), skirmisher()]
	var index := posmod(slot, roster.size())
	return roster[index]


static func by_id(id: StringName) -> HeroDefinition:
	for hero in [gladiator(), slinger(), skirmisher()]:
		if hero.id == id:
			return hero
	return null


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


static func ids_for_role(role: String) -> Array[String]:
	var ids: Array[String] = []
	for hero in [gladiator(), skirmisher(), slinger()]:
		if role_name(hero) == role:
			ids.append(String(hero.id))
	return ids


static func blurb(id: String) -> String:
	match id:
		"gladiator":
			return "Melee. Dash Strike and Cleave."
		"skirmisher":
			return "Melee. Lunge and Whirl."
		"slinger":
			return "Ranged. Bomb and Backstep."
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
			return ""
	var path := "res://art/exports/runtime/characters/%s" % file_name
	if ResourceLoader.exists(path):
		return path
	return ""


static func gladiator() -> HeroDefinition:
	var hero := _base(&"gladiator", "Gladiator")
	hero.stats.attack = UnitStats.Attack.MELEE
	hero.stats.attack_damage = 18.0
	hero.stats.attack_range = 4.2
	hero.stats.attack_interval = 0.8
	hero.abilities = [
		_slash(&"dash_strike", "Dash Strike", 24.0, 2.4, 6.5, 0.2, 6.0),
		_kind(&"cleave", "Cleave", AbilityDefinition.Kind.SLASH, 16.0, 2.6, 4.0),
	]
	return hero


static func slinger() -> HeroDefinition:
	var hero := _base(&"slinger", "Slinger")
	hero.stats.attack = UnitStats.Attack.RANGED
	hero.stats.attack_damage = 12.0
	hero.stats.attack_range = 13.0
	hero.stats.attack_interval = 0.95
	hero.stats.projectile_speed = 20.0
	hero.abilities = [
		_bomb(),
		_dash_only(&"backstep", "Backstep", 5.0, 0.16, 5.0, true),
	]
	return hero


static func skirmisher() -> HeroDefinition:
	var hero := _base(&"skirmisher", "Skirmisher")
	hero.stats.attack = UnitStats.Attack.MELEE
	hero.stats.attack_damage = 11.0
	hero.stats.attack_range = 3.8
	hero.stats.attack_interval = 0.55
	hero.abilities = [
		_slash(&"lunge", "Lunge", 14.0, 1.6, 7.0, 0.18, 5.0),
		_kind(&"whirl", "Whirl", AbilityDefinition.Kind.WHIRL, 14.0, 2.6, 6.0),
	]
	return hero


static func _base(id: StringName, display_name: String) -> HeroDefinition:
	var hero := HeroDefinition.new()
	hero.id = id
	hero.display_name = display_name
	hero.stats = UnitStats.new()
	hero.stats.max_health = 140.0
	hero.movement = load("res://data/movement_profiles/gladiator.tres") as MovementProfile
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
