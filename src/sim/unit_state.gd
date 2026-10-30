class_name UnitState extends RefCounted

## Plain data. No node references, so a later server can copy it.

enum Controller { NONE, HUMAN, BOT }

var unit_id := 0
var team := 0
var hero_id: StringName
var display_name := ""
var controller := Controller.NONE
var alive := true
var health := 100.0
var max_health := 100.0
var move_state := 0
var velocity := Vector3.ZERO
var facing_yaw := 0.0
var kills := 0
var deaths := 0
var assists := 0
var damage_dealt := 0.0
var damage_to: Dictionary = {}
var gold := 0
