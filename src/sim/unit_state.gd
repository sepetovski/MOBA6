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
