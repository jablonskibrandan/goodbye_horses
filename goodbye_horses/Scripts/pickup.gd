class_name Pickup
extends Area2D

signal collected(pickup: Pickup, horse: Horse)


enum PickupType {
	APPLE,
	CARROT,
	SUGAR_CUBE,
}


@export_category("Pickup")
@export var pickup_type: PickupType = PickupType.APPLE
@export var item_id: StringName = &"apple"
@export var quantity: int = 1


@export_category("Movement")
## Most pickups should move with the world. Increase this for special pickups
## that should approach the player faster than normal scenery.
@export var speed_multiplier: float = 1.0
@export var despawn_x: float = -150.0


@export_category("Immediate Effects")
@export var auto_use_on_collect: bool = true
@export var heart_restore_amount: int = 0
@export var stamina_restore_amount: float = 0.0
@export var speed_boost_multiplier: float = 1.0
@export var speed_boost_duration: float = 0.0


var _has_been_collected: bool = false


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
	if _has_been_collected:
		return

	if not body is Horse:
		return

	var horse := body as Horse

	if pickup_type == PickupType.SUGAR_CUBE:
		if not horse.add_sugar_cubes(quantity):
			# Inventory is full. Leave the pickup in the world instead of
			# wasting it.
			return
	else:
		if auto_use_on_collect:
			_apply_immediate_effect(horse)

	_has_been_collected = true

	horse.register_pickup(item_id, quantity)
	collected.emit(self, horse)
	queue_free()


func _apply_immediate_effect(horse: Horse) -> void:
	if heart_restore_amount > 0:
		horse.heal(heart_restore_amount)

	if stamina_restore_amount > 0.0:
		horse.restore_stamina(stamina_restore_amount)

	if speed_boost_multiplier > 1.0 and speed_boost_duration > 0.0:
		GameManager.activate_temporary_speed_boost(
			speed_boost_multiplier,
			speed_boost_duration
		)
