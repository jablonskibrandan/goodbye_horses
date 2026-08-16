extends Node2D

var long_bar
var moving_bar
var aim_bar
var starting_bar_position = Vector2(640 - 60, 360 - 200)
var long_bar_height
var moving_bar_direction = 1
var bar_speed = 200
var error = 15
var hold = false
var hit_count = 0

func _ready():
	long_bar = $long_bar
	long_bar_height = long_bar.scale.y * 120
	moving_bar = $moving_bar
	aim_bar = $aim_bar
	long_bar.position = starting_bar_position
	moving_bar.position = starting_bar_position
	aim_bar.position = starting_bar_position + Vector2(0,randf_range(0, long_bar_height))

func _process(delta):
	moving_bar.position.y += (bar_speed * delta * moving_bar_direction)
	if moving_bar.position.y >= long_bar_height + starting_bar_position.y or moving_bar.position.y <= starting_bar_position.y:
		moving_bar_direction *= -1
	
	if Input.is_key_pressed(KEY_SPACE) == true and hold == false:
		hold = true
		if moving_bar.position.y <= aim_bar.position.y + error and moving_bar.position.y >= aim_bar.position.y - error:
			reset()
			print("HIT")
			hit_count += 1
			if hit_count == 3:
				print("WIN")
				hit_count = 0
		else:
			print("MISS")
			hit_count = 0
			print(moving_bar.position.y)
			print(aim_bar.position.y)
			reset()
			
	if Input.is_key_pressed(KEY_SPACE) == false:
		hold = false
			
func reset():
	moving_bar.position = starting_bar_position
	aim_bar.position = starting_bar_position + Vector2(0,randf_range(0, long_bar_height))
	moving_bar_direction = 1
