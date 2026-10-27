# Decisions

Agents append one line when they take a default. Do not change a locked decision without the human lead.

| ID | Date | Decision | Why |
|---|---|---|---|
| ADR-001 | 2026-10-27 | Godot 4.7.2-stable, standard build, pinned | Every agent and the headless test run must share one engine. Upgrade only between milestones |
| ADR-002 | 2026-10-27 | Jolt Physics set explicitly in Project Settings | The engine default can change between Godot builds. Never switch mid-project |
| ADR-003 | 2026-10-27 | GUT 9.7.1 for tests | Headless, exits non-zero on failure, and matches the Godot 4.7 line |
| ADR-004 | 2026-10-27 | Wall-line gaps are 1.5 m, not the 1.2 m example in the M1 brief. Nav agent radius is 0.4 m | §4 forbids corridors under 1.5 m. Godot ceils a 0.45 m agent radius to whole 0.2 m cells and reports an error, so the radius is 0.4 m (2 cells). Ramps slope along local +Z so the mirror rule does not reverse them |
| ADR-005 | 2026-10-27 | Occlusion fade uses `GeometryInstance3D.transparency`, not a dither shader. Stencil silhouettes are skipped | PLAN §7 M2-T5 says "dithered fade". The M2 brief is the task contract and names `transparency` plus `find_occluders`. Stencil materials are the optional path the brief says to skip when the fade is enough |
| ADR-006 | 2026-10-27 | `STEER` is sent once when the hold crosses `hold_threshold`, then again only after the y = 0 cursor point moves more than `steer_resend_distance` | PLAN §7 says "every tick". The M2 brief's resend distance is the contract, so a still cursor does not flood the simulation |
| ADR-007 | 2026-10-27 | Occlusion sample heights are offsets from the focus node's origin, and that origin is the feet | The brief's samples are "feet + 0.2 m, 0.9 m, 1.7 m". The sandbox unit's origin sits on the ground. M4 should pass a feet node into `OcclusionFader.bind` |
| ADR-008 | 2026-10-27 | The reticle sits on the physics pick (crate tops included). `STEER` uses the y = 0 plane from `screen_to_ground` | `MOVE_TO` sends the picked surface point. The brief's "cursor ground point" for steer resend is the plane, so holding on a crate still steers across the floor |
