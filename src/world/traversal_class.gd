class_name TraversalClass extends RefCounted

## How a prop can be crossed. STEP / VAULT / MANTLE / WALL come from height.
## SLIDE_GAP and CROUCH_GAP are tagged explicitly by the prop kit.

enum Kind { STEP, VAULT, MANTLE, WALL, SLIDE_GAP, CROUCH_GAP }

const STEP_MAX := 0.4
const VAULT_MAX := 1.2
const MANTLE_MAX := 2.0

static func from_height(height: float) -> Kind:
	if height <= STEP_MAX:
		return Kind.STEP
	if height <= VAULT_MAX:
		return Kind.VAULT
	if height <= MANTLE_MAX:
		return Kind.MANTLE
	return Kind.WALL
