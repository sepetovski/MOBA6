# Interfaces

Binding type names. Do not rename one without an entry in `docs/DECISIONS.md`. Owners fill in the signature when their milestone lands.

| Type | Owner | Status |
|---|---|---|
| `Command` | A0 | defined in M0 (`src/core/command.gd`) |
| `Team` | A0 | defined in M0 (`src/core/team.gd`) |
| `GameEvents` | A0 | defined in M0 |
| `GameConfig` | A0 | defined in M0 |
| `DebugService` | A0 | defined in M0 |
| `MovementProfile` | A3 | planned (M3) |
| `MovementMotor` | A3 | planned (M3) |
| `MovementIntent` | A3 | planned (M3) |
| `HeroDefinition` | A5 (stub by A4) | planned (M5) |
| `Simulation` | A4 | planned (M4) |
| `SimUnit` | A4 | planned (M4) |
| `UnitState` | A4 | planned (M4) |
| `UnitView` | A4 | planned (M4) |
| `ArenaLayout` | A1 | defined in M1 (`data/arena_layout.gd`) |
| `PropPlacement` | A1 | defined in M1 (`data/prop_placement.gd`) |
| `ArenaBuilder` | A1 | defined in M1. `static func build(layout) -> Node3D`. Floor, walls, gates and props are children of `Navigation`. Gate doors are siblings of it |
| `ArenaInfo` | A1 | defined in M1. `get_spawn_slot(team, slot) -> Transform3D`, `get_bounds() -> AABB`, `get_octagon_polygon() -> PackedVector2Array`, `contains_xz(point) -> bool` |
| `TraversalClass` | A1 | defined in M1. `from_height(height) -> Kind`. Constants mirror the movement defaults until M3 |
| `CrowdRenderer` | A1 | defined in M1. `set_density(0..1)`, `set_excitement(0..1)` |
| `CursorPicker` | A2 | planned (M2) |
| `MobaCamera` | A2 | planned (M2) |
