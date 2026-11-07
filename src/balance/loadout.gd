class_name Loadout extends RefCounted

## Turns owned items into a fresh stats copy and movement copy. Flats apply first, then percents of the base.


const RUN_CAP := 6.2
const INTERVAL_FLOOR := 0.30
const GUARD_FLOOR := 0.45


static func apply(base_stats: UnitStats, base_move: MovementProfile, base_guard: float, owned: PackedStringArray) -> Dictionary:
	var stats := base_stats.duplicate(true) as UnitStats
	var move := base_move.duplicate(true) as MovementProfile
	var guard := base_guard
	var health_flat := 0.0
	var health_percent := 0.0
	var damage_flat := 0.0
	var damage_percent := 0.0
	var interval_faster := 0.0
	var reload_shorter := 0.0
	var run_percent := 0.0
	var dash_shorter := 0.0
	var guard_less := 0.0
	for id in owned:
		var item := BalanceStore.item(id)
		if item == null:
			continue
		for entry in item.mods:
			var stat := str(entry.get("stat", ""))
			var mode := str(entry.get("mode", "flat"))
			var amount := float(entry.get("amount", 0.0))
			if stat == "health" and mode == "flat":
				health_flat += amount
			elif stat == "health":
				health_percent += amount
			elif stat == "attack_damage" and mode == "flat":
				damage_flat += amount
			elif stat == "attack_damage":
				damage_percent += amount
			elif stat == "attack_interval":
				interval_faster += amount
			elif stat == "magazine":
				stats.magazine += int(round(amount))
			elif stat == "reload":
				reload_shorter += amount
			elif stat == "run_speed":
				run_percent += amount
			elif stat == "dash_charges":
				move.dash_charges += int(round(amount))
			elif stat == "dash_recharge":
				dash_shorter += amount
			elif stat == "damage_taken":
				guard_less += amount
	stats.max_health = maxf(base_stats.max_health + health_flat + base_stats.max_health * health_percent / 100.0, 1.0)
	stats.attack_damage = maxf(base_stats.attack_damage + damage_flat + base_stats.attack_damage * damage_percent / 100.0, 1.0)
	var interval := base_stats.attack_interval * maxf(1.0 - interval_faster / 100.0, 0.2)
	stats.attack_interval = maxf(interval, INTERVAL_FLOOR)
	stats.magazine = maxi(stats.magazine, 1)
	stats.reload_seconds = maxf(base_stats.reload_seconds * maxf(1.0 - reload_shorter / 100.0, 0.2), 0.2)
	move.run_speed = minf(base_move.run_speed * (1.0 + run_percent / 100.0), RUN_CAP)
	move.dash_charges = clampi(move.dash_charges, 1, 4)
	move.dash_recharge = maxf(base_move.dash_recharge * maxf(1.0 - dash_shorter / 100.0, 0.25), 0.4)
	guard = base_guard * maxf(1.0 - guard_less / 100.0, GUARD_FLOOR)
	return {"stats": stats, "move": move, "guard": guard}
