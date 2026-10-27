extends Node

## Autoload DebugService. Presentation may read the recent command log. It never changes gameplay.

var show_overlay := false
var recent_commands: Array[Command] = []

func log_command(cmd: Command) -> void:
	recent_commands.append(cmd)
	if recent_commands.size() > 32:
		recent_commands.pop_front()
