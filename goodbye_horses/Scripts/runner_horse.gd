extends CharacterBody2D

signal captured

@export_group("Runner Stats")
@export var difficulty: int

var speed
var move_spots: Array[Vector2] = [
	Vector2(1028 - 200, 720 - 100),
	Vector2(1028 - 200, 720 - 200),
	Vector2(1028 - 200, 720 - 300),
	Vector2(1028 - 200, 720 - 400)
]
var run_spot: int
var target_locked = false
var is_captured: bool = false


func _ready():
	speed = 50 * difficulty


func _process(delta: float):
	if is_captured:
		return

	run_around(delta)


func run_around(delta):
	if !target_locked:
		target_locked = true
		run_spot = randi_range(0, 3)

	position.x = move_toward(position.x, move_spots[run_spot].x, speed * delta)
	position.y = move_toward(position.y, move_spots[run_spot].y, speed * delta)

	if position == move_spots[run_spot]:
		target_locked = false


func capture(catcher_global_position: Vector2) -> void:
	if is_captured:
		return

	is_captured = true
	target_locked = true
	velocity = Vector2.ZERO
	remove_from_group(&"lasso_catchable")

	# It is already caught, so it should no longer collide with another lasso
	# or interfere with the player while the capture visual finishes.
	var collision := get_node_or_null("runner_collision") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)

	captured.emit()

	# Give the win an unmistakable gameplay result: pull the runner toward the
	# player's horse while fading it out, then remove it from the run.
	var destination := catcher_global_position + Vector2(100.0, -12.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", destination, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
