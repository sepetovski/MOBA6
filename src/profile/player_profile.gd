class_name PlayerProfile extends RefCounted

## Local career. Stats only, no replay. Steam can later fill account_id and the same file.

const NAME_LIMIT := 16
const HISTORY_LIMIT := 20

var player_name := "Gladiator"
var hero_id := "gladiator"
var role := "melee"
var account_id := ""
var matches := 0
var wins := 0
var losses := 0
var draws := 0
var kills := 0
var deaths := 0
var assists := 0
var damage := 0
var gold := 0
var mvps := 0
var history: Array[Dictionary] = []


func sanitize_name(raw: String) -> String:
	var trimmed := raw.strip_edges()
	if trimmed.length() > NAME_LIMIT:
		trimmed = trimmed.substr(0, NAME_LIMIT).strip_edges()
	if trimmed.is_empty():
		return "Gladiator"
	return trimmed


func set_name(raw: String) -> void:
	player_name = sanitize_name(raw)


func set_role(next: String) -> void:
	role = "ranged" if next == "ranged" else "melee"
	var allowed := HeroCatalog.ids_for_role(role)
	if allowed.is_empty():
		return
	if not allowed.has(hero_id):
		hero_id = allowed[0]


func set_hero(id: String) -> void:
	var hero := HeroCatalog.by_id(StringName(id))
	if hero == null:
		return
	hero_id = String(hero.id)
	role = HeroCatalog.role_name(hero)


func add_match(entry: Dictionary) -> void:
	matches += 1
	var result := str(entry.get("result", "draw"))
	if result == "win":
		wins += 1
	elif result == "loss":
		losses += 1
	else:
		draws += 1
	kills += int(entry.get("kills", 0))
	deaths += int(entry.get("deaths", 0))
	assists += int(entry.get("assists", 0))
	damage += int(entry.get("damage", 0))
	gold += int(entry.get("gold", 0))
	if bool(entry.get("mvp", false)):
		mvps += 1
	history.push_front(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_back()


func career_line() -> String:
	if matches <= 0:
		return "No matches yet"
	return "%d matches    %d-%d-%d    K/D/A %d/%d/%d    %d MVP" % [
		matches, wins, losses, draws, kills, deaths, assists, mvps,
	]


func to_dict() -> Dictionary:
	var listed: Array = []
	for entry in history:
		listed.append(entry)
	return {
		"version": 1,
		"player_name": player_name,
		"hero_id": hero_id,
		"role": role,
		"account_id": account_id,
		"matches": matches,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"kills": kills,
		"deaths": deaths,
		"assists": assists,
		"damage": damage,
		"gold": gold,
		"mvps": mvps,
		"history": listed,
	}


func from_dict(data: Dictionary) -> void:
	player_name = sanitize_name(str(data.get("player_name", player_name)))
	account_id = str(data.get("account_id", ""))
	hero_id = str(data.get("hero_id", hero_id))
	role = str(data.get("role", role))
	matches = int(data.get("matches", 0))
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	draws = int(data.get("draws", 0))
	kills = int(data.get("kills", 0))
	deaths = int(data.get("deaths", 0))
	assists = int(data.get("assists", 0))
	damage = int(data.get("damage", 0))
	gold = int(data.get("gold", 0))
	mvps = int(data.get("mvps", 0))
	history.clear()
	var listed: Variant = data.get("history", [])
	if listed is Array:
		for item in listed:
			if item is Dictionary:
				history.append(item)
	set_role(role)
