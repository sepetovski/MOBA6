extends Node

## Twelve bots, no camera and no HUD. The gut soak test waits on Simulation.tick.


func _ready() -> void:
	var layout := load("res://data/arena_layouts/octagon_ring_v1.tres") as ArenaLayout
	var arena := ArenaBuilder.build(layout)
	add_child(arena)
	await arena.navigation_ready
	var config := MatchConfig.new()
	config.countdown_seconds = 1.0
	config.human_team = -1
	config.human_slot = -1
	config.bot_difficulty = BotController.Difficulty.CHASE
	config.match_seed = 1
	var bots := BotConfig.new()
	var simulation := Simulation.new()
	simulation.name = "Simulation"
	simulation.record_tick_cost = true
	add_child(simulation)
	simulation.start_match(config, arena)
	for unit in simulation.get_units():
		var bot := BotController.new()
		add_child(bot)
		bot.bind(unit.unit_id, simulation, bots, config.bot_difficulty)
	var gates := GateController.new()
	add_child(gates)
	gates.bind(arena, config.gate_open_seconds)
	for door in arena.get_node("GateDoors").get_children():
		if door is CollisionObject3D:
			(door as CollisionObject3D).collision_layer = 0
