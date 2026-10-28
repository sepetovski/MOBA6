class_name UnitStats extends Resource

## Basic attack numbers. Movement speed stays on MovementProfile.

enum Attack { MELEE, RANGED }

@export var max_health := 140.0 # hp
@export var attack := Attack.MELEE
@export var attack_damage := 16.0 # hp per swing
@export var attack_range := 2.4 # m
@export var attack_interval := 0.85 # s between swings
@export var projectile_speed := 18.0 # m/s, ranged only
