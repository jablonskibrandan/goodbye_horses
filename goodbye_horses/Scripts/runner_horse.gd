extends CharacterBody2D

@export_group("Runner Stats")
@export var difficulty: int
var speed
var move_spots: Array[Vector2] = [
	Vector2(1028 - 200, 720 - 200),
	Vector2(1028 - 200, 200),
	Vector2(1028 - 600, 720 - 200),
	Vector2(1028 - 600, 200),
	Vector2(1080 - 400, 350)
	]
var run_spot: int
var target_locked = false

func _ready():
	speed = 50 * difficulty

func _process(delta: float):
	run_around(delta)

func run_around(delta):
	if !target_locked:
		target_locked = true
		run_spot = randi_range(0, 4)
	
	position.x = move_toward(position.x, move_spots[run_spot].x, speed * delta)
	position.y = move_toward(position.y, move_spots[run_spot].y, speed * delta)
	
	if position == move_spots[run_spot]:
		target_locked = false
	
