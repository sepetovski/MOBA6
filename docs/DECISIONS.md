# Decisions

Agents append one line when they take a default. Do not change a locked decision without the human lead.

| ID | Date | Decision | Why |
|---|---|---|---|
| ADR-001 | 2026-10-27 | Godot 4.7.2-stable, standard build, pinned | Every agent and the headless test run must share one engine. Upgrade only between milestones |
| ADR-002 | 2026-10-27 | Jolt Physics set explicitly in Project Settings | The engine default can change between Godot builds. Never switch mid-project |
| ADR-003 | 2026-10-27 | GUT 9.7.1 for tests | Headless, exits non-zero on failure, and matches the Godot 4.7 line |
| ADR-004 | 2026-10-27 | Wall-line gaps are 1.5 m, not the 1.2 m example in the M1 brief. Nav agent radius is 0.4 m | §4 forbids corridors under 1.5 m. Godot ceils a 0.45 m agent radius to whole 0.2 m cells and reports an error, so the radius is 0.4 m (2 cells). Ramps slope along local +Z so the mirror rule does not reverse them |
| ADR-005 | 2026-10-27 | The movement gym bakes navigation at agent radius 0.4 m, not the 0.45 m in the M3 brief | Same Godot cell error as ADR-004. Climb 0.4 m, slope 40°, height 1.8 m stay as specified |
| ADR-006 | 2026-10-27 | A vault whose landing is more than `vault_landing_reach` (2 m) from the near face becomes a mantle when the top can hold the capsule | A 4×4×1 m block has a legal far-side landing and would be vaulted. The gym asks for a mount. Thin walls still vault |
| ADR-007 | 2026-10-27 | Air control does not bleed horizontal speed when there is no steer or path wish | The cap is `max(run_speed, takeoff speed)`. Slide-jumps need to keep their speed. Input still steers at `acceleration * air_control` |
| ADR-008 | 2026-10-27 | The top probe samples 0.05 m, half inset and `vault_top_inset` (0.3 m) past the face | A 0.3 m wall has no top exactly 0.3 m past the near face, so a single sample misses it |
| ADR-009 | 2026-10-27 | One extra jump in the air, and Space on a wall kicks away from it. Ctrl slides whenever grounded speed is at least 4 m/s, including while the key is held. The gym click is a move order, not hold-to-steer | Playtest ask: League click, one double jump, wall jump, slide when fast. Touching a screen edge unlocks the gym camera; Y locks it back on the capsule |
| ADR-010 | 2026-10-27 | Occlusion fade uses `GeometryInstance3D.transparency`, not a dither shader. Stencil silhouettes are skipped | The M2 brief names `transparency` and `find_occluders`. Stencil materials are the optional path the brief says to skip |
| ADR-011 | 2026-10-27 | `STEER` is sent once when the hold crosses `hold_threshold`, then again only after the y = 0 cursor point moves more than `steer_resend_distance` | A still cursor does not flood the simulation. The gym itself does not steer on hold (ADR-009); `PlayerController` still can, for M4 |
| ADR-012 | 2026-10-27 | Occlusion sample heights are offsets from the focus node's origin, and that origin is the feet | The brief's samples are feet + 0.2 m, 0.9 m and 1.7 m. M4 should pass a feet node into `OcclusionFader.bind` |
| ADR-013 | 2026-10-27 | The reticle sits on the physics pick (crate tops included). `STEER` uses the y = 0 plane from `screen_to_ground` | `MOVE_TO` sends the picked surface point. Holding on a crate still steers across the floor |
| ADR-014 | 2026-10-28 | Three greybox heroes, each with a basic attack and two abilities. Right-click on another unit is `ATTACK_TARGET`. Q and W cast. Bots do not dash | A full ability framework waits. This set is enough to feel melee, ranged, a dash, a slash, and a bomb. Multiplayer is still later |
