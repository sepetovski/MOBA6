extends SceneTree

## tools/screenshot.sh <scene> <out.png> [frames]
## User args after -- : scene path, output png, optional frame count.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: screenshot_runner.gd -- <scene> <out.png> [frames]")
		quit(2)
		return
	var scene_path := str(args[0])
	var out_path := str(args[1])
	var frames := 60
	if args.size() > 2:
		frames = int(args[2])
	if not ResourceLoader.exists(scene_path):
		push_error("scene not found: %s" % scene_path)
		quit(1)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("not a packed scene: %s" % scene_path)
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	for _i in frames:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("viewport image is empty")
		quit(1)
		return
	if not out_path.is_absolute_path():
		out_path = ProjectSettings.globalize_path("res://").path_join(out_path)
	var directory := out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var err := image.save_png(out_path)
	if err != OK:
		push_error("save_png failed: %s" % error_string(err))
		quit(1)
		return
	print("screenshot: %s (%dx%d)" % [out_path, image.get_width(), image.get_height()])
	quit(0)
