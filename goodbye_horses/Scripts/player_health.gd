class_name PlayerHealth
extends Node


signal health_changed(
	current_hearts: int,
	max_hearts: int
)

signal damaged(amount: int)
signal healed(amount: int)
signal died


@export_category("Health")
@export var max_hearts: int = 4


@export_category("Damage Protection")
@export var invulnerability_duration: float = 0.75


var current_hearts: int
var is_dead: bool = false
var _invulnerability_timer: float = 0.0


func _ready() -> void:
	current_hearts = max_hearts

	health_changed.emit(
		current_hearts,
		max_hearts
	)


func _process(delta: float) -> void:
	if _invulnerability_timer <= 0.0:
		return

	_invulnerability_timer = maxf(
		_invulnerability_timer - delta,
		0.0
	)


func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	if _invulnerability_timer > 0.0:
		return

	current_hearts = clampi(
		current_hearts - amount,
		0,
		max_hearts
	)

	_invulnerability_timer = invulnerability_duration

	damaged.emit(amount)
	health_changed.emit(
		current_hearts,
		max_hearts
	)

	print(
		"Player hearts: ",
		current_hearts,
		"/",
		max_hearts
	)

	if current_hearts <= 0:
		_die()


func lose_heart(amount: int = 1) -> void:
	## Used for rule-based penalties such as failing the catch minigame.
	## Unlike take_damage(), this intentionally ignores the temporary
	## invulnerability window from obstacle hits.
	if is_dead:
		return

	if amount <= 0:
		return

	current_hearts = clampi(
		current_hearts - amount,
		0,
		max_hearts
	)

	damaged.emit(amount)
	health_changed.emit(
		current_hearts,
		max_hearts
	)

	if current_hearts <= 0:
		_die()


func heal(amount: int = 1) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	if current_hearts >= max_hearts:
		return

	var previous_hearts := current_hearts

	current_hearts = clampi(
		current_hearts + amount,
		0,
		max_hearts
	)

	var amount_actually_healed := (
		current_hearts - previous_hearts
	)

	healed.emit(amount_actually_healed)
	health_changed.emit(
		current_hearts,
		max_hearts
	)

	print(
		"Player hearts: ",
		current_hearts,
		"/",
		max_hearts
	)


func is_at_full_health() -> bool:
	return current_hearts >= max_hearts


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit()
