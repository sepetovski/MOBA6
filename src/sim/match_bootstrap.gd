extends Node

## Builds the playable match. The scene file stays a single node.

const LAYOUT := "res://data/arena_layouts/octagon_ring_v1.tres"
const MATCH := "res://data/match_configs/default.tres"
const BOTS := "res://data/bot_configs/default.tres"
const CAMERA := "res://data/camera_profiles/default.tres"


func _ready() -> void:
	var layout := load(LAYOUT) as ArenaLayout
	var arena := ArenaBuilder.build(layout)
	add_child(arena)
	ArtDressing.attach(arena)
	await arena.navigation_ready
	var config := load(MATCH) as MatchConfig
	var bots := load(BOTS) as BotConfig
	var simulation := Simulation.new()
	simulation.name = "Simulation"
	add_child(simulation)
	simulation.start_match(config, arena)
	var camera := MobaCamera.new()
	camera.name = "MobaCamera"
	camera.profile = load(CAMERA) as CameraProfile
	add_child(camera)
	var info := arena.get_node("ArenaInfo") as ArenaInfo
	# The octagon AABB stops at the ring. Grow it so a free camera can cross the tunnels and stands.
	camera.set_bounds(info.get_bounds().grow(28.0))
	var human := simulation.get_human()
	if human != null:
		camera.follow(human)
	var player := PlayerController.new()
	player.name = "PlayerController"
	add_child(player)
	if human != null:
		player.bind(human.unit_id, camera, simulation.submit_command)
		player.face_cursor = true
		player.enabled = false
		if player.settings != null:
			player.settings.confine_mouse = false
	var fader := OcclusionFader.new()
	fader.name = "OcclusionFader"
	add_child(fader)
	if human != null and camera.camera != null:
		fader.bind(camera.camera, human, camera.profile)
	for unit in simulation.get_units():
		if unit.state.controller != UnitState.Controller.BOT:
			continue
		var bot := BotController.new()
		bot.name = "Bot%d" % unit.unit_id
		add_child(bot)
		bot.bind(unit.unit_id, simulation, bots, config.bot_difficulty)
	var hud := DebugHud.new()
	hud.name = "DebugHud"
	add_child(hud)
	hud.bind(simulation, camera)
	var gates := GateController.new()
	gates.name = "GateController"
	add_child(gates)
	gates.bind(arena, config.gate_open_seconds)
	GameEvents.match_state_changed.connect(func(state: int) -> void:
		if state == Match.State.RUNNING and human != null:
			player.enabled = true
	)
