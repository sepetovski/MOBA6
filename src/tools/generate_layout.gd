extends SceneTree

## Usage: godot --headless --path . -s src/tools/generate_layout.gd -- <seed>

func _init() -> void:
	var layout_seed_value := 1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		layout_seed_value = int(str(args[0]))
	var layout := LayoutGenerator.generate(layout_seed_value)
	var err := ResourceSaver.save(layout, "res://data/arena_layouts/octagon_ring_v1.tres")
	if err != OK:
		push_error("save failed: %s" % error_string(err))
		quit(1)
		return
	print("wrote data/arena_layouts/octagon_ring_v1.tres")
	quit(0)
