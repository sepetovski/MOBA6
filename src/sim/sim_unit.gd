class_name SimUnit extends CharacterBody3D

## A body the simulation steps. It has no _physics_process of its own.

var unit_id := 0
var team := 0
var state: UnitState
var motor: MovementMotor
var intent := MovementIntent.new()
var spawn_transform := Transform3D.IDENTITY
var combat: Combat
var hero_name := ""


func setup(id: int, hero: HeroDefinition, team_id: int, slot: int, nav_map: RID) -> void:
	unit_id = id
	team = team_id
	var profile := hero.movement if hero.movement != null else MovementProfile.new()
	state = UnitState.new()
	state.unit_id = id
	state.team = team_id
	state.hero_id = hero.id
	var letter := "A" if team_id == Team.Id.A else "B"
	state.display_name = "%s%d" % [letter, slot + 1]
	hero_name = hero.display_name
	state.max_health = hero.stats.max_health if hero.stats != null else 100.0
	state.health = state.max_health
	combat = Combat.new()
	combat.setup(self, hero)
	motor = MovementMotor.new(self, profile, nav_map)
	motor.landed.connect(func(fall_speed: float) -> void: GameEvents.unit_landed.emit(unit_id, fall_speed))
	motor.stuck.connect(func() -> void: GameEvents.unit_stuck.emit(unit_id))
	var view := UnitView.new()
	view.name = "UnitView"
	add_child(view)
	view.bind(self)
	set_meta("unit_id", unit_id)
	set_meta("radius", profile.radius)


func place_at(spawn: Transform3D) -> void:
	spawn_transform = spawn
	global_transform = spawn
	velocity = Vector3.ZERO
	reset_physics_interpolation()


func apply_command(cmd: Command) -> void:
	match cmd.kind:
		Command.Kind.MOVE_TO:
			intent.has_move_target = true
			intent.move_target = cmd.point
			intent.steering = false
			combat.clear_attack()
		Command.Kind.STEER:
			intent.steering = cmd.pressed
			if cmd.pressed:
				intent.steer_point = cmd.point
				intent.has_move_target = false
				combat.clear_attack()
		Command.Kind.STOP:
			intent.stop = true
			combat.clear_attack()
		Command.Kind.ATTACK_TARGET:
			combat.attack_target = cmd.target_id
		Command.Kind.CAST:
			if cmd.pressed:
				combat.cast(cmd.slot, cmd.point)
		Command.Kind.JUMP:
			if cmd.pressed:
				intent.jump_pressed = true
				intent.jump_held = true
			else:
				intent.jump_held = false
		Command.Kind.CROUCH_SLIDE:
			if cmd.pressed:
				intent.crouch_slide_pressed = true
				intent.crouch_slide_held = true
			else:
				intent.crouch_slide_held = false


func sim_step(dt: float, sim: Simulation) -> void:
	if combat != null:
		combat.begin(dt, sim)
	motor.step(intent, dt)
	if combat != null:
		combat.finish()
	intent.clear_edges()
	state.move_state = motor.state
	state.velocity = velocity
	state.facing_yaw = rotation.y


func set_frozen(frozen: bool) -> void:
	motor.can_move = not frozen
	motor.can_jump = not frozen
	motor.can_crouch = not frozen


func scripted_motion() -> bool:
	return motor.state == MovementMotor.State.VAULTING or motor.state == MovementMotor.State.MANTLING or motor.state == MovementMotor.State.FORCED
