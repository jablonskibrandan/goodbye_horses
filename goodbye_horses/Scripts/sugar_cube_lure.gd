class_name SugarCubeLure
extends Node2D


signal landed(lure: SugarCubeLure)
signal expired(lure: SugarCubeLure)
signal consumed(lure: SugarCubeLure)


@export_category("Throw")
## Minimum flight time for a short throw.
@export var minimum_throw_duration: float = 0.45

## Maximum flight time for a long throw.
@export var maximum_throw_duration: float = 0.85

## How high the middle control point is lifted above the straight line.
## Larger values make a taller arc.
@export var minimum_arc_height: float = 90.0

## Extra arc height based on throw distance.
@export var arc_height_per_pixel: float = 0.28

## How many complete rotations the cube makes while flying.
@export var spin_turns: float = 1.25


@export_category("On Ground")
## How long the lure waits on the ground if the wild horse never reaches it.
@export var ground_lifetime: float = 6.0


var _start_position: Vector2
var _control_position: Vector2
var _end_position: Vector2

var _flight_elapsed: float = 0.0
var _throw_duration: float = 0.65
var _ground_time_remaining: float = 0.0

var _is_flying: bool = false
var _has_landed: bool = false
var _finished: bool = false


func start_throw(
	start_global_position: Vector2,
	landing_global_position: Vector2
) -> void:
	_start_position = start_global_position
	_end_position = landing_global_position

	var distance := _start_position.distance_to(
		_end_position
	)

	_throw_duration = clampf(
		distance / 520.0,
		minimum_throw_duration,
		maximum_throw_duration
	)

	var arc_height := maxf(
		minimum_arc_height,
		distance * arc_height_per_pixel
	)

	# Quadratic Bézier control point. Raising the midpoint creates the
	# parabolic-looking throw arc.
	_control_position = (
		(_start_position + _end_position) * 0.5
		+ Vector2.UP * arc_height
	)

	global_position = _start_position
	rotation = 0.0

	_flight_elapsed = 0.0
	_is_flying = true
	_has_landed = false
	_finished = false


func _process(delta: float) -> void:
	if _finished:
		return

	if _is_flying:
		_update_flight(delta)
		return

	if _has_landed:
		_update_ground_lifetime(delta)


func _update_flight(delta: float) -> void:
	_flight_elapsed += delta

	var t := clampf(
		_flight_elapsed / _throw_duration,
		0.0,
		1.0
	)

	global_position = _quadratic_bezier(
		_start_position,
		_control_position,
		_end_position,
		t
	)

	rotation = TAU * spin_turns * t

	if t < 1.0:
		return

	_is_flying = false
	_has_landed = true
	_ground_time_remaining = ground_lifetime
	global_position = _end_position

	landed.emit(self)


func _update_ground_lifetime(delta: float) -> void:
	_ground_time_remaining = maxf(
		_ground_time_remaining - delta,
		0.0
	)

	if _ground_time_remaining > 0.0:
		return

	_finished = true
	expired.emit(self)
	queue_free()


func consume() -> void:
	if _finished:
		return

	_finished = true
	consumed.emit(self)
	queue_free()


func is_landed() -> bool:
	return _has_landed and not _finished


func _quadratic_bezier(
	point_a: Vector2,
	control_point: Vector2,
	point_b: Vector2,
	t: float
) -> Vector2:
	var inverse_t := 1.0 - t

	return (
		inverse_t * inverse_t * point_a
		+ 2.0 * inverse_t * t * control_point
		+ t * t * point_b
	)
