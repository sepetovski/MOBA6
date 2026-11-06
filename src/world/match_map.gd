class_name MatchMap extends RefCounted

## The playable ring is wider than the greybox test layout so three lanes fit.
## Tests keep loading octagon_ring_v1.tres unchanged.

const APOTHEM := 58.0
const STAND_ROWS := 4


static func prepare(source: ArenaLayout) -> ArenaLayout:
	var layout := source.duplicate(true) as ArenaLayout
	layout.apothem = APOTHEM
	layout.stand_rows = STAND_ROWS
	return layout
