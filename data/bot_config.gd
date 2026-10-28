class_name BotConfig extends Resource

@export var think_interval := 0.25 # s between decisions
@export var reaction_jitter := 0.15 # s, random extra delay per bot
@export var wander_radius := 15.0 # m
@export var wander_pause_min := 0.5 # s
@export var wander_pause_max := 2.0 # s
@export var chase_range := 20.0 # m
@export var chase_stop_distance := 3.0 # m
@export var jump_rate := 0.10 # jumps per second while moving
@export var slide_rate := 0.05 # slides per second while moving
@export var slide_hold_min := 0.5 # s
@export var slide_hold_max := 1.0 # s
