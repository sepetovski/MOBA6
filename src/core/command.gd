class_name Command extends RefCounted

## A request that gameplay state change. Humans, bots and later network clients all send these.
## Simulation.submit_command stamps tick. pressed applies to STEER, CROUCH_SLIDE and JUMP
## (a JUMP with pressed = false is the key release, which variable jump height needs).

enum Kind { MOVE_TO, STEER, STOP, JUMP, CROUCH_SLIDE, CAST, ATTACK_TARGET }

var tick: int
var seq: int
var unit_id: int
var kind: Kind
var point: Vector3
var target_id: int = -1
var slot: int = -1
var pressed: bool = true
