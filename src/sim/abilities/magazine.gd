class_name Magazine extends RefCounted

## Rounds in the current magazine. Empty starts a reload. The simulation ticks this. No wall clock.

var rounds := 0
var capacity := 8
var reload_left := 0.0
var reload_seconds := 1.6
var shot_wait := 0.0
var shot_interval := 0.45


func fill(next_capacity: int, next_reload: float, next_interval: float) -> void:
	capacity = maxi(next_capacity, 1)
	reload_seconds = maxf(next_reload, 0.05)
	shot_interval = maxf(next_interval, 0.05)
	rounds = capacity
	reload_left = 0.0
	shot_wait = 0.0


func tick(dt: float) -> void:
	shot_wait = maxf(shot_wait - dt, 0.0)
	if reload_left <= 0.0:
		return
	reload_left = maxf(reload_left - dt, 0.0)
	if reload_left <= 0.0:
		rounds = capacity


func reloading() -> bool:
	return reload_left > 0.0


func try_spend() -> bool:
	if reload_left > 0.0 or shot_wait > 0.0:
		return false
	if rounds <= 0:
		reload_left = reload_seconds
		return false
	rounds -= 1
	shot_wait = shot_interval
	if rounds <= 0:
		reload_left = reload_seconds
	return true
