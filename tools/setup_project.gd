extends SceneTree

## Writes InputMap actions, physics layer names, autoloads and the GUT plugin into project.godot.
## Safe to run twice: every setting is assigned, never appended.

const ACTIONS := {
	"move_click": "mouse_right",
	"select": "mouse_left",
	"jump": KEY_SPACE,
	"crouch_slide": KEY_CTRL,
	"stop": KEY_S,
	"ability_1": KEY_Q,
	"ability_2": KEY_W,
	"ability_3": KEY_E,
	"ability_4": KEY_R,
	"camera_lock": KEY_Y,
	"zoom_in": "wheel_up",
	"zoom_out": "wheel_down",
	"camera_pan_left": KEY_LEFT,
	"camera_pan_right": KEY_RIGHT,
	"camera_pan_up": KEY_UP,
	"camera_pan_down": KEY_DOWN,
	"debug_help": KEY_F1,
	"debug_collision": KEY_F2,
	"debug_nav": KEY_F3,
	"debug_freecam": KEY_F4,
}

const LAYER_NAMES := ["World", "Props", "Units", "Projectiles", "Triggers", "Pick", "NavBlock", "Occluders"]

func _init() -> void:
	_apply_display_and_physics()
	for action: String in ACTIONS:
		_set_action(action, ACTIONS[action])
	for index in LAYER_NAMES.size():
		ProjectSettings.set_setting("layer_names/3d_physics/layer_%d" % (index + 1), LAYER_NAMES[index])
	ProjectSettings.set_setting("autoload/GameEvents", "*res://src/core/game_events.gd")
	ProjectSettings.set_setting("autoload/GameConfig", "*res://src/core/game_config.gd")
	ProjectSettings.set_setting("autoload/DebugService", "*res://src/core/debug_service.gd")
	ProjectSettings.set_setting("editor_plugins/enabled", PackedStringArray(["res://addons/gut/plugin.cfg"]))
	var err := ProjectSettings.save()
	if err != OK:
		push_error("ProjectSettings.save failed: %s" % error_string(err))
		quit(1)
		return
	print("setup_project: saved")
	quit(0)

func _apply_display_and_physics() -> void:
	ProjectSettings.set_setting("display/window/size/viewport_width", 1920)
	ProjectSettings.set_setting("display/window/size/viewport_height", 1080)
	ProjectSettings.set_setting("display/window/size/resizable", true)
	ProjectSettings.set_setting("physics/3d/physics_engine", "Jolt Physics")
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", 60)
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus")

func _set_action(action: String, binding: Variant) -> void:
	var event: InputEvent
	if binding is int:
		var key := InputEventKey.new()
		key.physical_keycode = binding as Key
		event = key
	elif binding == "mouse_left":
		event = _mouse(MOUSE_BUTTON_LEFT)
	elif binding == "mouse_right":
		event = _mouse(MOUSE_BUTTON_RIGHT)
	elif binding == "wheel_up":
		event = _mouse(MOUSE_BUTTON_WHEEL_UP)
	elif binding == "wheel_down":
		event = _mouse(MOUSE_BUTTON_WHEEL_DOWN)
	else:
		push_error("unknown binding %s" % str(binding))
		return
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.5, "events": [event]})

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
