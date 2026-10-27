# Decisions

Agents append one line when they take a default. Do not change a locked decision without the human lead.

| ID | Date | Decision | Why |
|---|---|---|---|
| ADR-001 | 2026-10-27 | Godot 4.7.2-stable, standard build, pinned | Every agent and the headless test run must share one engine. Upgrade only between milestones |
| ADR-002 | 2026-10-27 | Jolt Physics set explicitly in Project Settings | The engine default can change between Godot builds. Never switch mid-project |
| ADR-003 | 2026-10-27 | GUT 9.7.1 for tests | Headless, exits non-zero on failure, and matches the Godot 4.7 line |
