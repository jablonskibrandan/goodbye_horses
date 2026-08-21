extends Node

signal world_speed_changed(new_speed: float)
signal temporary_speed_boost_started(multiplier: float, duration: float)
signal temporary_speed_boost_ended

## Shared forward-running speed for the current run.
## Obstacles, pickups, scenery, etc. should use this value so they stay in sync.
var base_world_speed: float = 350.0

## Persistent multiplier. This is the one to use later for horse speed stats,
## difficulty scaling, permanent run modifiers, etc.
var world_speed_multiplier: float = 1.0

## Temporary multiplier is kept separate so a sugar cube never overwrites the
## horse's normal speed modifier.
var temporary_world_speed_multiplier: float = 1.0
var _temporary_speed_boost_time_remaining: float = 0.0


func _process(delta: float) -> void:
	if _temporary_speed_boost_time_remaining <= 0.0:
		return

	_temporary_speed_boost_time_remaining = maxf(
		_temporary_speed_boost_time_remaining - delta,
		0.0
	)

	if _temporary_speed_boost_time_remaining <= 0.0:
		temporary_world_speed_multiplier = 1.0
		world_speed_changed.emit(get_world_speed())
		temporary_speed_boost_ended.emit()


func get_world_speed() -> float:
	return (
		base_world_speed
		* world_speed_multiplier
		* temporary_world_speed_multiplier
	)


func set_base_world_speed(new_speed: float) -> void:
	base_world_speed = maxf(new_speed, 0.0)
	world_speed_changed.emit(get_world_speed())


func set_world_speed_multiplier(new_multiplier: float) -> void:
	world_speed_multiplier = maxf(new_multiplier, 0.0)
	world_speed_changed.emit(get_world_speed())


func activate_temporary_speed_boost(
	multiplier: float,
	duration: float
) -> void:
	if multiplier <= 1.0 or duration <= 0.0:
		return

	# Re-collecting a boost refreshes its duration. A stronger boost can replace
	# a weaker active one, but collecting a weaker one will not slow the player.
	temporary_world_speed_multiplier = maxf(
		temporary_world_speed_multiplier,
		multiplier
	)
	_temporary_speed_boost_time_remaining = duration

	world_speed_changed.emit(get_world_speed())
	temporary_speed_boost_started.emit(
		temporary_world_speed_multiplier,
		duration
	)


func reset_run_speed() -> void:
	base_world_speed = 350.0
	world_speed_multiplier = 1.0
	temporary_world_speed_multiplier = 1.0
	_temporary_speed_boost_time_remaining = 0.0
	world_speed_changed.emit(get_world_speed())
