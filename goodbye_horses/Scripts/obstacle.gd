class_name Obstacle
extends Area2D


@export_category("Obstacle")
@export var damage: int = 1
@export var can_be_jumped_over: bool = true


@export_category("Movement")
## Allows special obstacles to move faster/slower than the shared world speed.
## Normal stationary scenery obstacles should stay at 1.0.
@export var speed_multiplier: float = 1.0


@export_category("Cleanup")
@export var despawn_x: float = -150.0


var _has_hit_player: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position.x -= (
		GameManager.get_world_speed()
		* speed_multiplier
		* delta
	)

	if global_position.x <= despawn_x:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit_player:
		return

	if not body is Horse:
		return

	var horse := body as Horse

	if can_be_jumped_over and horse.is_jumping:
		return

	_has_hit_player = true
	horse.take_damage(damage)
