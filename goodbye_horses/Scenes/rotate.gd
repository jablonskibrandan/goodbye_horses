extends Sprite2D


@export_category("Rolling")

## Approximate radius of the log in pixels.
## Smaller number = faster rotation.
@export var rolling_radius: float = 10.0


@export_category("Bouncing")

## How quickly the log gets pulled back down.
@export var gravity: float = 900.0

## Smallest bounce.
@export var minimum_bounce_force: float = 55.0

## Largest bounce.
@export var maximum_bounce_force: float = 105.0

## Minimum time between bounces.
@export var minimum_bounce_delay: float = 0.35

## Maximum time between bounces.
@export var maximum_bounce_delay: float = 0.85


var _ground_y: float

var _vertical_velocity: float = 0.0

var _bounce_timer: float = 0.0

var _is_bouncing: bool = false


func _ready() -> void:
	_ground_y = position.y

	_reset_bounce_timer()


func _process(delta: float) -> void:
	_update_rolling(delta)
	_update_bouncing(delta)


func _update_rolling(delta: float) -> void:
	var obstacle := get_parent() as Obstacle

	if obstacle == null:
		return

	var movement_speed := (
		GameManager.get_world_speed()
		* obstacle.speed_multiplier
	)

	var angular_speed := (
		movement_speed
		/ rolling_radius
	)

	rotation -= (
		angular_speed
		* delta
	)


func _update_bouncing(delta: float) -> void:
	if _is_bouncing:
		_vertical_velocity += (
			gravity
			* delta
		)

		position.y += (
			_vertical_velocity
			* delta
		)

		if position.y >= _ground_y:
			position.y = _ground_y

			_vertical_velocity = 0.0

			_is_bouncing = false

			_reset_bounce_timer()

		return

	_bounce_timer -= delta

	if _bounce_timer <= 0.0:
		_start_bounce()


func _start_bounce() -> void:
	_is_bouncing = true

	_vertical_velocity = -randf_range(
		minimum_bounce_force,
		maximum_bounce_force
	)


func _reset_bounce_timer() -> void:
	_bounce_timer = randf_range(
		minimum_bounce_delay,
		maximum_bounce_delay
	)
