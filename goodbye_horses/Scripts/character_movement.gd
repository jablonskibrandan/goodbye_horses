class_name Horse
extends CharacterBody2D


signal stamina_changed(
	current_stamina: float,
	maximum_stamina: float
)

signal horse_exhausted

signal pickup_collected(
	item_id: StringName,
	quantity: int
)


@export var horse_player_animated_sprite: AnimatedSprite2D


@export_category("Horse Stats")

@export var speed: float = 300.0

@export var maximum_stamina: float = 100.0

@export var stamina_drain_per_second: float = 2.0


@export_category("Movement Bounds")

## Rectangle the horse is allowed to move inside.
@export var movement_bounds = Rect2(
	100.0,
	350.0,
	800.0,
	300.0
)

@export var boundary_padding: Vector2 = Vector2(
	24.0,
	24.0
)


@export_category("Jump")

@export var jump_height: float = 70.0

@export var jump_duration: float = 0.65

@export var visuals: Node2D


@export_category("Hit Reaction")

## How long movement is slowed after taking damage.
@export_range(0.1, 5.0, 0.1)
var hit_slow_duration: float = 2.0

## Percentage of normal movement speed while hurt.
## 0.45 means 45% of normal speed.
@export_range(0.1, 1.0, 0.05)
var hit_speed_multiplier: float = 0.45

## How long the horse flashes after being hit.
@export_range(0.1, 3.0, 0.05)
var hit_flash_duration: float = 0.8

## How quickly the sprite flashes.
@export_range(0.02, 0.5, 0.01)
var hit_flash_interval: float = 0.08

## How transparent the sprite becomes during a flash.
@export_range(0.0, 1.0, 0.05)
var hit_flash_alpha: float = 0.25


@onready var player_health: PlayerHealth = (
	$PlayerHealth
)


var current_stamina: float

var is_jumping: bool = false


var _jump_timer: float = 0.0

var _visuals_start_position: Vector2

var _exhaustion_emitted: bool = false


# Hit reaction.
var _hit_slow_timer: float = 0.0

var _hit_flash_timer: float = 0.0

var _hit_flash_step_timer: float = 0.0

var _flash_dimmed: bool = false

var _normal_sprite_modulate: Color = Color.WHITE


func _ready() -> void:
	horse_player_animated_sprite.play(
		"moving"
	)

	current_stamina = maximum_stamina

	if visuals != null:
		_visuals_start_position = (
			visuals.position
		)

	if horse_player_animated_sprite != null:
		_normal_sprite_modulate = (
			horse_player_animated_sprite.modulate
		)

	if player_health != null:
		player_health.damaged.connect(
			_on_player_damaged
		)

	stamina_changed.emit(
		current_stamina,
		maximum_stamina
	)


func _physics_process(
	delta: float
) -> void:
	_handle_hit_reaction(delta)

	_handle_movement()

	_handle_jump(delta)

	_handle_stamina(delta)

	move_and_slide()

	_keep_inside_movement_bounds()


# ============================================================
# MOVEMENT
# ============================================================


func _handle_movement() -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	var current_speed := speed

	# Slow the horse while recovering
	# from a hit.
	if _hit_slow_timer > 0.0:
		current_speed *= (
			hit_speed_multiplier
		)

	velocity = (
		direction
		* current_speed
	)


# ============================================================
# HIT REACTION
# ============================================================


func _on_player_damaged(
	_amount: int
) -> void:
	# Reset the slowdown timer every time
	# successful damage occurs.
	_hit_slow_timer = (
		hit_slow_duration
	)

	# Start/restart flashing.
	_hit_flash_timer = (
		hit_flash_duration
	)

	_hit_flash_step_timer = 0.0

	_flash_dimmed = false

	# Make the first flash happen immediately.
	_set_sprite_flash(
		true
	)


func _handle_hit_reaction(
	delta: float
) -> void:
	# -------------------------
	# Slowdown
	# -------------------------

	if _hit_slow_timer > 0.0:
		_hit_slow_timer = maxf(
			_hit_slow_timer - delta,
			0.0
		)

	# -------------------------
	# Flashing
	# -------------------------

	if _hit_flash_timer <= 0.0:
		return

	_hit_flash_timer = maxf(
		_hit_flash_timer - delta,
		0.0
	)

	_hit_flash_step_timer -= delta

	if _hit_flash_step_timer <= 0.0:
		_hit_flash_step_timer = (
			hit_flash_interval
		)

		_flash_dimmed = (
			not _flash_dimmed
		)

		_set_sprite_flash(
			_flash_dimmed
		)

	# Flash finished.
	if _hit_flash_timer <= 0.0:
		_flash_dimmed = false

		if horse_player_animated_sprite != null:
			horse_player_animated_sprite.modulate = (
				_normal_sprite_modulate
			)


func _set_sprite_flash(
	dimmed: bool
) -> void:
	if horse_player_animated_sprite == null:
		return

	var flash_color := (
		_normal_sprite_modulate
	)

	if dimmed:
		flash_color.a *= (
			hit_flash_alpha
		)

	horse_player_animated_sprite.modulate = (
		flash_color
	)


# ============================================================
# JUMP
# ============================================================


func _handle_jump(
	delta: float
) -> void:
	if (
		Input.is_action_just_pressed(
			"jump"
		)
		and not is_jumping
	):
		_start_jump()

	if not is_jumping:
		return

	_jump_timer += delta

	var jump_progress := (
		_jump_timer
		/ jump_duration
	)

	if jump_progress >= 1.0:
		_finish_jump()
		return

	var height := (
		sin(
			jump_progress
			* PI
		)
		* jump_height
	)

	if visuals != null:
		visuals.position = (
			_visuals_start_position
			+ Vector2.UP
			* height
		)


func _start_jump() -> void:
	is_jumping = true

	_jump_timer = 0.0


func _finish_jump() -> void:
	is_jumping = false

	_jump_timer = 0.0

	if visuals != null:
		visuals.position = (
			_visuals_start_position
		)


# ============================================================
# STAMINA
# ============================================================


func _handle_stamina(
	delta: float
) -> void:
	if current_stamina <= 0.0:
		if not _exhaustion_emitted:
			_exhaustion_emitted = true

			horse_exhausted.emit()

		return

	current_stamina = maxf(
		current_stamina
		- stamina_drain_per_second
		* delta,
		0.0
	)

	stamina_changed.emit(
		current_stamina,
		maximum_stamina
	)


func restore_stamina(
	amount: float
) -> void:
	if amount <= 0.0:
		return

	current_stamina = minf(
		current_stamina + amount,
		maximum_stamina
	)

	_exhaustion_emitted = false

	stamina_changed.emit(
		current_stamina,
		maximum_stamina
	)


# ============================================================
# HEALTH
# ============================================================


func take_damage(
	amount: int
) -> void:
	if player_health == null:
		push_error(
			"Horse is missing its PlayerHealth child node."
		)

		return

	player_health.take_damage(
		amount
	)


func heal(
	amount: int = 1
) -> void:
	if player_health == null:
		push_error(
			"Horse is missing its PlayerHealth child node."
		)

		return

	player_health.heal(
		amount
	)


func is_at_full_health() -> bool:
	if player_health == null:
		return true

	return (
		player_health.is_at_full_health()
	)


# ============================================================
# PICKUPS
# ============================================================


func register_pickup(
	item_id: StringName,
	quantity: int = 1
) -> void:
	if quantity <= 0:
		return

	pickup_collected.emit(
		item_id,
		quantity
	)


# ============================================================
# MOVEMENT BOUNDS
# ============================================================


func _keep_inside_movement_bounds() -> void:
	var minimum_position = (
		movement_bounds.position
		+ boundary_padding
	)

	var maximum_position = (
		movement_bounds.end
		- boundary_padding
	)

	global_position.x = clampf(
		global_position.x,
		minimum_position.x,
		maximum_position.x
	)

	global_position.y = clampf(
		global_position.y,
		minimum_position.y,
		maximum_position.y
	)
