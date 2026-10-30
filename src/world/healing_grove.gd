class_name HealingGrove extends Node3D

## A heal volume with no disc. The forest floor is the visual. Standing inside still heals.

var team := -1
var radius := 6.0
var heal_per_second := 16.0


func configure(at: Vector3, zone_radius: float, team_id: int, rate: float) -> void:
	position = at
	radius = zone_radius
	team = team_id
	heal_per_second = rate
	name = "Grove%s" % ("All" if team_id < 0 else ("A" if team_id == Team.Id.A else "B"))


func covers(point: Vector3) -> bool:
	var flat := point - global_position
	flat.y = 0.0
	return flat.length() <= radius
