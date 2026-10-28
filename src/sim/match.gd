class_name Match extends RefCounted

## SETUP spawns the twelve units. COUNTDOWN freezes them. RUNNING opens play.
## Time is ticks, not the wall clock.

enum State { SETUP, COUNTDOWN, RUNNING }

var state := State.SETUP
var ticks_left := 0


func begin_countdown(seconds: float) -> void:
	state = State.COUNTDOWN
	ticks_left = maxi(int(round(seconds * float(GameConfig.TICK_RATE))), 0)


func advance() -> bool:
	if state != State.COUNTDOWN:
		return false
	if ticks_left > 0:
		ticks_left -= 1
	if ticks_left > 0:
		return false
	state = State.RUNNING
	return true


func seconds_left() -> float:
	return float(ticks_left) / float(GameConfig.TICK_RATE)
