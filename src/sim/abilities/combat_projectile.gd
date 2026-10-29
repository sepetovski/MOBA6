class_name CombatProjectile extends RefCounted

var position := Vector3.ZERO
var velocity := Vector3.ZERO
var damage := 0.0
var team := 0
var owner_id := 0
var radius := 0.35
var origin := Vector3.ZERO
var color := Color(0.95, 0.45, 0.2)
var mesh: MeshInstance3D
