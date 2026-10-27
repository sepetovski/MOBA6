# Tuning

Every gameplay number lives in a `Resource` `@export` field. List it here when you add it.

| Value | Unit | Default | File | Why |
|---|---|---|---|---|
| Nav agent radius | m | 0.4 | `src/world/arena_builder.gd` | Brief asked for 0.45. Godot ceils that to a whole 0.2 m cell and errors. 0.4 is 2 cells. See ADR-004 |
| Wall-line gap | m | 1.5 | `src/world/layout_generator.gd` | Brief example was 1.2. PLAN §4 minimum corridor is 1.5 |
