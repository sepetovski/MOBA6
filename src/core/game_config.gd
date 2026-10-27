extends Node

## Autoload GameConfig. Collision bit masks and the simulation tick rate. No gameplay numbers.

const TICK_RATE := 60

const LAYER_WORLD := 1
const LAYER_PROPS := 2
const LAYER_UNITS := 4
const LAYER_PROJECTILES := 8
const LAYER_TRIGGERS := 16
const LAYER_PICK := 32
const LAYER_NAVBLOCK := 64
const LAYER_OCCLUDERS := 128
