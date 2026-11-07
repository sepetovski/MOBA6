class_name ItemDefinition extends RefCounted

## One shop row. Mods are numbers. Actives are only effects the simulation already knows.

var id := ""
var display_name := ""
var price := 0
var category := "damage"
var mods: Array[Dictionary] = []
var active := "none"
var cooldown := 8.0
var reach := 8.0
var duration := 0.6


static func from_dict(raw: Dictionary) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = str(raw.get("id", ""))
	item.display_name = str(raw.get("name", item.id))
	item.price = int(raw.get("price", 0))
	item.category = str(raw.get("category", "damage"))
	item.active = str(raw.get("active", "none"))
	item.cooldown = float(raw.get("cooldown", 8.0))
	item.reach = float(raw.get("range", 8.0))
	item.duration = float(raw.get("duration", 0.6))
	var listed: Array = raw.get("mods", [])
	for entry in listed:
		if entry is Dictionary:
			item.mods.append(entry as Dictionary)
	return item


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"price": price,
		"category": category,
		"mods": mods,
		"active": active,
		"cooldown": cooldown,
		"range": reach,
		"duration": duration,
	}


func mod_text() -> String:
	var parts: PackedStringArray = []
	for entry in mods:
		var stat := str(entry.get("stat", ""))
		var mode := str(entry.get("mode", "flat"))
		var amount := float(entry.get("amount", 0.0))
		if mode == "percent":
			parts.append("%s %+.0f%%" % [stat, amount])
		else:
			parts.append("%s %+.0f" % [stat, amount])
	if active != "none":
		parts.append(active)
	return ", ".join(parts)
