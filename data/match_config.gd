class_name MatchConfig extends Resource

@export var countdown_seconds := 5.0 # s
@export var gate_open_seconds := 1.0 # s
@export var match_seed := 1
@export var human_team := 0 # Team.Id
@export var human_slot := 0 # 0 to 5
@export var bot_difficulty := 3 # BotController.Difficulty, 3 = CHASE
@export var separation_speed := 2.0 # m/s, maximum push between overlapping units
@export var separation_radius_scale := 1.0 # multiplier on the sum of the two radii
