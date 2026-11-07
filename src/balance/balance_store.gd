class_name BalanceStore extends RefCounted

## Local overrides in user://balance.json. Shipped numbers are used when a field is missing.
## Gold rules are read every payout. Hero numbers apply the next time a unit spawns.

const PATH := "user://balance.json"

const HERO_FIELDS: PackedStringArray = [
	"max_health", "run_speed", "attack_damage", "attack_interval", "magazine",
	"reload_seconds", "attack_range", "projectile_speed", "dash_charges",
	"dash_recharge", "dash_speed", "damage_taken",
]

const STATS: PackedStringArray = [
	"health", "attack_damage", "attack_interval", "magazine", "reload",
	"run_speed", "dash_charges", "dash_recharge", "damage_taken",
]

const ACTIVES: PackedStringArray = ["none", "blink", "leap", "stun"]

static var revision := 0
static var _rules: Dictionary = {}
static var _heroes: Dictionary = {}
static var _items: Array[ItemDefinition] = []
static var _custom_items := false
static var _loaded := false


static func boot() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_rules = {}
		_heroes = {}
		_items = _shipped_items()
		_custom_items = false
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_items = _shipped_items()
		return
	var root: Dictionary = parsed
	_rules = root.get("rules", {})
	_heroes = root.get("heroes", {})
	if root.has("items"):
		_custom_items = true
		_items = []
		for entry in root.get("items", []):
			if entry is Dictionary:
				var item := ItemDefinition.from_dict(entry)
				if not item.id.is_empty():
					_items.append(item)
	else:
		_items = _shipped_items()


static func reload() -> void:
	_loaded = false
	boot()
	revision += 1


static func save(rules: Dictionary, heroes: Dictionary, items: Array[ItemDefinition]) -> void:
	_rules = rules.duplicate(true)
	_heroes = heroes.duplicate(true)
	_items = items
	_custom_items = true
	_loaded = true
	revision += 1
	var listed: Array = []
	for item in items:
		listed.append(item.to_dict())
	var root := {"rules": _rules, "heroes": _heroes, "items": listed}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(root, "\t"))


static func reset() -> void:
	_rules = {}
	_heroes = {}
	_items = _shipped_items()
	_custom_items = false
	_loaded = true
	revision += 1
	DirAccess.remove_absolute(PATH)


static func rules() -> Dictionary:
	boot()
	return {
		"match_seconds": float(_rules.get("match_seconds", 300.0)),
		"gold_per_second": float(_rules.get("gold_per_second", 3.0)),
		"kill_gold": int(_rules.get("kill_gold", 180)),
		"kill_streak_gold": int(_rules.get("kill_streak_gold", 40)),
		"kill_streak_cap": int(_rules.get("kill_streak_cap", 160)),
		"assist_gold": int(_rules.get("assist_gold", 60)),
		"assist_seconds": float(_rules.get("assist_seconds", 10.0)),
		"start_gold": int(_rules.get("start_gold", 0)),
	}


static func kill_bounty(victim_kills: int) -> int:
	var row := rules()
	var streak := maxi(victim_kills, 0) * int(row["kill_streak_gold"])
	streak = mini(streak, int(row["kill_streak_cap"]))
	return int(row["kill_gold"]) + streak


static func items() -> Array[ItemDefinition]:
	boot()
	return _items


static func item(id: String) -> ItemDefinition:
	for entry in items():
		if entry.id == id:
			return entry
	return null


static func hero_overlay(id: String) -> Dictionary:
	boot()
	var raw: Variant = _heroes.get(id, {})
	return raw if raw is Dictionary else {}


static func apply_hero(hero: HeroDefinition) -> void:
	if hero == null or hero.stats == null:
		return
	var overlay := hero_overlay(String(hero.id))
	if overlay.is_empty():
		return
	if overlay.has("max_health"):
		hero.stats.max_health = float(overlay["max_health"])
	if overlay.has("attack_damage"):
		hero.stats.attack_damage = float(overlay["attack_damage"])
	if overlay.has("attack_interval"):
		hero.stats.attack_interval = float(overlay["attack_interval"])
	if overlay.has("magazine"):
		hero.stats.magazine = int(overlay["magazine"])
	if overlay.has("reload_seconds"):
		hero.stats.reload_seconds = float(overlay["reload_seconds"])
	if overlay.has("attack_range"):
		hero.stats.attack_range = float(overlay["attack_range"])
	if overlay.has("projectile_speed"):
		hero.stats.projectile_speed = float(overlay["projectile_speed"])
	if hero.movement == null:
		return
	if overlay.has("run_speed"):
		hero.movement.run_speed = float(overlay["run_speed"])
	if overlay.has("dash_charges"):
		hero.movement.dash_charges = int(overlay["dash_charges"])
	if overlay.has("dash_recharge"):
		hero.movement.dash_recharge = float(overlay["dash_recharge"])
	if overlay.has("dash_speed"):
		hero.movement.dash_speed = float(overlay["dash_speed"])


static func sheet(hero: HeroDefinition) -> Dictionary:
	var row := {
		"max_health": hero.stats.max_health,
		"run_speed": hero.movement.run_speed if hero.movement != null else 4.5,
		"attack_damage": hero.stats.attack_damage,
		"attack_interval": hero.stats.attack_interval,
		"magazine": hero.stats.magazine,
		"reload_seconds": hero.stats.reload_seconds,
		"attack_range": hero.stats.attack_range,
		"projectile_speed": hero.stats.projectile_speed,
		"dash_charges": hero.movement.dash_charges if hero.movement != null else 2,
		"dash_recharge": hero.movement.dash_recharge if hero.movement != null else 4.6,
		"dash_speed": hero.movement.dash_speed if hero.movement != null else 12.5,
		"damage_taken": float(hero_overlay(String(hero.id)).get("damage_taken", 1.0)),
	}
	return row


static func _shipped_items() -> Array[ItemDefinition]:
	var listed: Array[ItemDefinition] = []
	listed.append(_item("keen_edge", "Keen Edge", 400, "damage", [{"stat": "attack_damage", "mode": "flat", "amount": 6.0}]))
	listed.append(_item("heavy_blade", "Heavy Blade", 800, "damage", [{"stat": "attack_damage", "mode": "percent", "amount": 12.0}]))
	listed.append(_item("quick_string", "Quick String", 750, "tempo", [{"stat": "attack_interval", "mode": "percent", "amount": 10.0}]))
	listed.append(_item("deep_quiver", "Deep Quiver", 500, "tempo", [{"stat": "magazine", "mode": "flat", "amount": 4.0}]))
	listed.append(_item("heartwood", "Heartwood", 350, "vitality", [{"stat": "health", "mode": "flat", "amount": 40.0}]))
	listed.append(_item("giants_blood", "Giant's Blood", 900, "vitality", [{"stat": "health", "mode": "percent", "amount": 15.0}]))
	listed.append(_item("light_boots", "Light Boots", 450, "mobility", [{"stat": "run_speed", "mode": "percent", "amount": 8.0}]))
	listed.append(_item("second_wind", "Second Wind", 1000, "mobility", [{"stat": "dash_charges", "mode": "flat", "amount": 1.0}]))
	listed.append(_item("short_fuse", "Short Fuse", 700, "mobility", [{"stat": "dash_recharge", "mode": "percent", "amount": 15.0}]))
	listed.append(_item("iron_skin", "Iron Skin", 800, "guard", [{"stat": "damage_taken", "mode": "percent", "amount": 10.0}]))
	var blink := _item("blink_charm", "Blink Charm", 1100, "active", [{"stat": "run_speed", "mode": "percent", "amount": 4.0}])
	blink.active = "blink"
	blink.cooldown = 12.0
	blink.reach = 8.0
	listed.append(blink)
	var leap := _item("leap_stone", "Leap Stone", 900, "active", [{"stat": "health", "mode": "flat", "amount": 20.0}])
	leap.active = "leap"
	leap.cooldown = 10.0
	leap.reach = 2.2
	leap.duration = 6.0
	listed.append(leap)
	var stun := _item("stun_net", "Stun Net", 1200, "active", [{"stat": "attack_damage", "mode": "flat", "amount": 4.0}])
	stun.active = "stun"
	stun.cooldown = 14.0
	stun.reach = 7.0
	stun.duration = 0.6
	listed.append(stun)
	return listed


static func _item(id: String, display_name: String, price: int, category: String, mods: Array) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = id
	item.display_name = display_name
	item.price = price
	item.category = category
	for entry in mods:
		item.mods.append(entry)
	return item
