extends Node

## Builds the playable match. F5 opens the menu over the forest. Play flies the camera
## across the ring, shows both teams, then counts in.

const LAYOUT := "res://data/arena_layouts/octagon_ring_v1.tres"
const MATCH := "res://data/match_configs/default.tres"
const BOTS := "res://data/bot_configs/default.tres"
const CAMERA := "res://data/camera_profiles/default.tres"

var _arena: Node3D
var _camera: MobaCamera
var _flow: MatchFlow
var _simulation: Simulation
var _player: PlayerController
var _hud: DebugHud
var _booting := false
var _wired := false
var _profile_saved := false


func _ready() -> void:
	var layout := load(LAYOUT) as ArenaLayout
	# Grey crates stay in the layout for tests. The match itself is the forest and the rocks.
	_arena = ArenaBuilder.build(layout, false)
	add_child(_arena)
	ArtDressing.attach(_arena)
	_camera = MobaCamera.new()
	_camera.name = "MobaCamera"
	_camera.profile = load(CAMERA) as CameraProfile
	add_child(_camera)
	var info := _arena.get_node("ArenaInfo") as ArenaInfo
	_camera.set_bounds(info.get_bounds().grow(28.0))
	_camera.present(Vector3(0.0, 0.0, 6.0), 40.0, true)
	_flow = MatchFlow.new()
	_flow.name = "MatchFlow"
	add_child(_flow)
	_flow.open_menu(_camera)
	_flow.play_requested.connect(_on_play)
	_flow.again_requested.connect(_on_again)
	_flow.menu_requested.connect(_on_menu)
	if get_tree().has_meta(&"auto_play") and bool(get_tree().get_meta(&"auto_play")):
		get_tree().set_meta(&"auto_play", false)
		_on_play()


func _on_play() -> void:
	if _booting or _simulation != null:
		return
	_booting = true
	_flow.hold("Opening the gates")
	while is_instance_valid(_arena) and not _arena.has_meta("navigation_ready"):
		await get_tree().process_frame
	if not is_instance_valid(self) or _simulation != null:
		return
	var config := (load(MATCH) as MatchConfig).duplicate(true) as MatchConfig
	config.countdown_seconds = 3.0
	var profile := ProfileStore.current()
	config.human_hero_id = profile.hero_id
	config.human_name = profile.player_name
	var bots := load(BOTS) as BotConfig
	_simulation = Simulation.new()
	_simulation.name = "Simulation"
	add_child(_simulation)
	_simulation.prepare_match(config, _arena)
	var human := _simulation.get_human()
	_player = PlayerController.new()
	_player.name = "PlayerController"
	add_child(_player)
	if human != null:
		_player.bind(human.unit_id, _camera, _simulation.submit_command)
		_player.face_cursor = true
		_player.enabled = false
		if _player.settings != null:
			_player.settings.confine_mouse = false
	var feedback := InputFeedback.new()
	feedback.name = "InputFeedback"
	add_child(feedback)
	if human != null:
		feedback.bind(_player, _camera, human, _camera.profile)
	var fader := OcclusionFader.new()
	fader.name = "OcclusionFader"
	add_child(fader)
	if human != null and _camera.camera != null:
		fader.bind(_camera.camera, human, _camera.profile)
	for unit in _simulation.get_units():
		if unit.state.controller != UnitState.Controller.BOT:
			continue
		var bot := BotController.new()
		bot.name = "Bot%d" % unit.unit_id
		add_child(bot)
		bot.bind(unit.unit_id, _simulation, bots, config.bot_difficulty)
	_hud = DebugHud.new()
	_hud.name = "DebugHud"
	_hud.show_chrome = false
	_hud.show_result = false
	add_child(_hud)
	_hud.bind(_simulation, _camera)
	var gates := GateController.new()
	gates.name = "GateController"
	add_child(gates)
	gates.bind(_arena, config.gate_open_seconds)
	if not _wired:
		GameEvents.match_state_changed.connect(_on_match_state)
		_wired = true
	_flow.start_intro(_simulation, _camera)


func _on_match_state(state: int) -> void:
	if _simulation == null:
		return
	if state == Match.State.RUNNING:
		if _player != null:
			_player.enabled = true
		if _hud != null:
			_hud.show_chrome = true
		var human := _simulation.get_human()
		if human != null:
			_camera.set_presenting(false)
			_camera.set_locked(true)
			_camera.follow(human)
		_flow.on_running()
	elif state == Match.State.FINISHED:
		if _player != null:
			_player.enabled = false
		if _hud != null:
			_hud.show_chrome = false
		if not _profile_saved:
			_profile_saved = true
			ProfileStore.record_match(_simulation)
		_flow.show_results(_simulation)


func _on_again() -> void:
	get_tree().set_meta(&"auto_play", true)
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().set_meta(&"auto_play", false)
	get_tree().reload_current_scene()
