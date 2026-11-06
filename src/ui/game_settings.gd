class_name GameSettings extends RefCounted

## Graphics and the saved control layout. Presentation only. user://settings.cfg.

const PATH := "user://settings.cfg"
const FPS_CHOICES: Array[int] = [30, 60, 120, 144, 0]

static var fps := 60
static var vsync := true
static var shadows := true
static var fullscreen := false
static var scheme := "mouse"
## 0 solid, 1 invisible. Negative until boot, so tests keep the camera profile value.
static var cover_see_through := -1.0


static func boot() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		fps = int(file.get_value("graphics", "fps", 60))
		vsync = bool(file.get_value("graphics", "vsync", true))
		shadows = bool(file.get_value("graphics", "shadows", true))
		fullscreen = bool(file.get_value("graphics", "fullscreen", false))
		cover_see_through = float(file.get_value("graphics", "cover_see_through", 0.75))
		scheme = str(file.get_value("controls", "scheme", "mouse"))
		ControlBindings.apply_preset(scheme if scheme == "wasd" else "mouse")
		for action in ControlBindings.GAMEPLAY:
			var encoded := str(file.get_value("bindings", action, ""))
			if encoded.is_empty():
				continue
			var event := ControlBindings.decode(encoded)
			if event != null:
				ControlBindings.set_event(action, event)
	else:
		scheme = "mouse"
		cover_see_through = 0.75
		ControlBindings.apply_preset("mouse")
	apply_graphics()


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("graphics", "fps", fps)
	file.set_value("graphics", "vsync", vsync)
	file.set_value("graphics", "shadows", shadows)
	file.set_value("graphics", "fullscreen", fullscreen)
	file.set_value("graphics", "cover_see_through", cover_see_through if cover_see_through >= 0.0 else 0.75)
	file.set_value("controls", "scheme", scheme)
	for action in ControlBindings.GAMEPLAY:
		file.set_value("bindings", action, ControlBindings.encode(action))
	file.save(PATH)


static func use_scheme(next: String) -> void:
	scheme = "wasd" if next == "wasd" else "mouse"
	ControlBindings.apply_preset(scheme)
	save()


static func set_fps(value: int) -> void:
	fps = value
	apply_graphics()
	save()


static func set_vsync(on: bool) -> void:
	vsync = on
	apply_graphics()
	save()


static func set_shadows(on: bool) -> void:
	shadows = on
	apply_graphics()
	save()


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_graphics()
	save()


static func set_cover_see_through(value: float) -> void:
	cover_see_through = clampf(value, 0.2, 0.95)
	save()


static func apply_graphics() -> void:
	Engine.max_fps = fps
	var sync := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(sync)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sun := tree.root.find_child("Sun", true, false) as DirectionalLight3D
	if sun == null:
		return
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 64.0 if shadows else 0.0


static func fps_label(value: int) -> String:
	return "Max" if value <= 0 else str(value)
