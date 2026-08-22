extends Node

signal world_speed_changed(new_speed: float)
signal temporary_speed_boost_started(multiplier: float, duration: float)
signal temporary_speed_boost_ended
signal level_state_changed(new_state: int)


enum LevelState {
	HERD_INTRO,
	PLAYING,
	CATCH_MINIGAME,
	LEVEL_COMPLETE,
	GAME_OVER,
}


## Shared forward-running speed for the current run.
## Obstacles, pickups, scenery, etc. should use this value so they stay in sync.
var base_world_speed: float = 350.0

## Persistent multiplier. This is the one to use later for horse speed stats,
## difficulty scaling, permanent run modifiers, etc.
var world_speed_multiplier: float = 1.0

## Temporary multiplier is kept separate so temporary run modifiers never
## overwrite the normal level/world speed.
var temporary_world_speed_multiplier: float = 1.0
var _temporary_speed_boost_time_remaining: float = 0.0

## Global level phase. Main decides WHEN this changes; other systems can react.
var level_state: int = LevelState.HERD_INTRO

## Levels all reuse main.tscn. This number decides which LevelDefinition resource
## main.gd loads when the scene starts.
var current_level_number: int = 1

const LEVEL_PATHS: Array[String] = [
	"res://Levels/level_01.tres",
	"res://Levels/level_02.tres",
	"res://Levels/level_03.tres"
]


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


func set_level_state(new_state: int) -> void:
	if level_state == new_state:
		return

	level_state = new_state
	level_state_changed.emit(level_state)


func is_level_state(state_to_check: int) -> bool:
	return level_state == state_to_check


func get_current_level() -> LevelDefinition:
	var index := current_level_number - 1

	if index < 0 or index >= LEVEL_PATHS.size():
		push_error(
			"GameManager: Invalid level number: %d"
			% current_level_number
		)
		return null

	return load(LEVEL_PATHS[index]) as LevelDefinition


func get_level_count() -> int:
	return LEVEL_PATHS.size()


func has_next_level() -> bool:
	return current_level_number < LEVEL_PATHS.size()


func advance_level() -> bool:
	if not has_next_level():
		return false

	current_level_number += 1
	return true


func go_to_level(level_number: int) -> void:
	current_level_number = clampi(
		level_number,
		1,
		LEVEL_PATHS.size()
	)
	reset_run_speed()
	reset_level_state()


func reset_to_first_level() -> void:
	current_level_number = 1
	reset_run_speed()
	reset_level_state()


func reset_level_state() -> void:
	set_level_state(LevelState.HERD_INTRO)


func reset_run_speed() -> void:
	base_world_speed = 350.0
	world_speed_multiplier = 1.0
	temporary_world_speed_multiplier = 1.0
	_temporary_speed_boost_time_remaining = 0.0
	world_speed_changed.emit(get_world_speed())


## Resets the current attempt while keeping the current level number.
func reset_run() -> void:
	reset_run_speed()
	reset_level_state()
