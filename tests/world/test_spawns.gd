extends GutTest

## The back spawn row has to stand on the tunnel floor, not inside the back wall.


func test_back_row_clears_the_back_wall() -> void:
	for spec in [{"apothem": 40.0, "rows": 8}, {"apothem": 58.0, "rows": 4}]:
		var layout := ArenaLayout.new()
		layout.apothem = float(spec["apothem"])
		layout.stand_rows = int(spec["rows"])
		var info := ArenaInfo.new()
		info.setup(layout)
		var outer := layout.apothem + layout.wall_thickness + float(layout.stand_rows) * layout.stand_row_depth
		for team in [0, 1]:
			for slot in 6:
				var point := info.get_spawn_slot(team, slot).origin
				assert_true(info.allows(point), "slot %d at %s is outside" % [slot, point])
				assert_gt(absf(point.x), layout.apothem + layout.wall_thickness, "slot %d is inside the ring wall" % slot)
				assert_lt(absf(point.x), outer - 0.5, "slot %d at %s is in the back wall" % [slot, point])
