class_name AbilityDefinition extends Resource

## One hero ability. The kind picks the behavior; the numbers are the tuning.

enum Kind { SLASH, DASH, BOMB, WHIRL }

@export var id: StringName
@export var display_name: String
@export var kind := Kind.SLASH
@export var damage := 18.0 # hp
@export var range := 2.4 # m, how far a slash or bomb can be aimed
@export var radius := 2.2 # m, area of a slash, whirl, or bomb
@export var cooldown := 5.0 # s
@export var dash_distance := 6.0 # m
@export var dash_seconds := 0.22 # s
@export var delay := 0.55 # s, bomb fuse
