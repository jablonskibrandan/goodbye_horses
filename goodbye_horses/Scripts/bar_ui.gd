extends Node2D

var long_bar
var moving_bar
var aim_bar
var starting_bar_position = Vector2(1028 - 60, 720 - 200)
var long_bar_height
var moving_bar_direction = 1
var bar_speed = 200
var error = 15
var hold = false
var hit_count = 0
var catch = false
var fail = false


func _ready():
	long_bar = $long_bar
	long_bar_height = long_bar.scale.y * 120
	moving_bar = $moving_bar
	aim_bar = $aim_bar
	long_bar.position = starting_bar_position
	moving_bar.position = starting_bar_position
	aim_bar.position = starting_bar_position + Vector2(0, randf_range(0, long_bar_height))


func _process(delta):
	# Once the result is decided, stop taking input until main.gd removes/resets
	# the minigame. This prevents the win frame from also changing the result.
	if catch or fail:
		return

	moving_bar.position.y += (bar_speed * delta * moving_bar_direction)
	if moving_bar.position.y >= long_bar_height + starting_bar_position.y or moving_bar.position.y <= starting_bar_position.y:
		moving_bar_direction *= -1

	if Input.is_key_pressed(KEY_SPACE) == true and hold == false:
		hold = true
		if moving_bar.position.y <= aim_bar.position.y + error and moving_bar.position.y >= aim_bar.position.y - error:
			reset_round()
			print("HIT")
			hit_count += 1
			if hit_count >= 3:
				print("WIN")
				hit_count = 0
				catch = true
		else:
			print("MISS")
			hit_count = 0
			fail = true
			reset_round()

	if Input.is_key_pressed(KEY_SPACE) == false:
		hold = false


func reset_round() -> void:
	moving_bar.position = starting_bar_position
	aim_bar.position = starting_bar_position + Vector2(0, randf_range(0, long_bar_height))
	moving_bar_direction = 1


func reset_game() -> void:
	# Full reset used whenever a catch attempt begins or ends.
	hit_count = 0
	catch = false
	fail = false
	hold = Input.is_key_pressed(KEY_SPACE)
	reset_round()
