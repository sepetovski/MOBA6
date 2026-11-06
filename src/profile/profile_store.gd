class_name ProfileStore extends RefCounted

## user://profile.json. A Steam login can later set account_id and the persona name.
## The saved shape stays the same, so Steam Cloud can sync this file without a second format.

static var file_path := "user://profile.json"
static var _profile: PlayerProfile


static func current() -> PlayerProfile:
	if _profile == null:
		_profile = _read()
	return _profile


static func save() -> void:
	var profile := current()
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("profile save failed: %s" % file_path)
		return
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))


static func record_match(sim: Simulation) -> void:
	var human := sim.get_human()
	if human == null:
		return
	var profile := current()
	var winner := sim.winning_team()
	var result := "draw"
	if winner >= 0:
		result = "win" if winner == human.team else "loss"
	var mvp := sim.mvp_unit()
	var state := human.state
	var entry := {
		"at": int(Time.get_unix_time_from_system()),
		"hero_id": String(state.hero_id),
		"hero_name": human.hero_name,
		"role": HeroCatalog.role_name(HeroCatalog.by_id(state.hero_id)),
		"result": result,
		"kills": state.kills,
		"deaths": state.deaths,
		"assists": state.assists,
		"damage": int(round(state.damage_dealt)),
		"gold": state.gold,
		"mvp": mvp != null and mvp.unit_id == human.unit_id,
	}
	profile.add_match(entry)
	save()


static func use_file(path: String) -> void:
	file_path = path
	_profile = null


static func _read() -> PlayerProfile:
	var profile := PlayerProfile.new()
	if not FileAccess.file_exists(file_path):
		return profile
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return profile
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		profile.from_dict(parsed)
	return profile
