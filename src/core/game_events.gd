extends Node

## Autoload GameEvents. The simulation emits. Presentation and UI listen.

signal unit_spawned(unit_id: int)
signal unit_died(unit_id: int, killer_id: int)
signal damage_dealt(source_id: int, target_id: int, amount: float, damage_type: int)
signal ability_cast(unit_id: int, slot: int)
signal status_applied(unit_id: int, status_id: StringName)
signal match_state_changed(state: int)
signal unit_stuck(unit_id: int)
signal unit_landed(unit_id: int, fall_speed: float)
