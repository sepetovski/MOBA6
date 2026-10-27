extends GutTest

const EXPECTED_ACTIONS: Array[String] = [
	"move_click",
	"select",
	"jump",
	"crouch_slide",
	"stop",
	"ability_1",
	"ability_2",
	"ability_3",
	"ability_4",
	"camera_lock",
	"zoom_in",
	"zoom_out",
	"camera_pan_left",
	"camera_pan_right",
	"camera_pan_up",
	"camera_pan_down",
	"debug_help",
	"debug_collision",
	"debug_nav",
	"debug_freecam",
]

func test_physics_tick_rate_is_60() -> void:
	assert_eq(Engine.physics_ticks_per_second, 60)

func test_physics_engine_is_jolt() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")

func test_input_actions_exist() -> void:
	for action: String in EXPECTED_ACTIONS:
		assert_true(InputMap.has_action(action), "missing action %s" % action)

func test_autoloads_exist() -> void:
	assert_not_null(get_node_or_null("/root/GameEvents"))
	assert_not_null(get_node_or_null("/root/GameConfig"))
	assert_not_null(get_node_or_null("/root/DebugService"))
