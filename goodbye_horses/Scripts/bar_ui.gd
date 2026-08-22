extends Node2D


@export_category("Bar")
@export var bar_position: Vector2 = Vector2(955.0, 500.0)
@export var bar_size: Vector2 = Vector2(55.0, 190.0)


@export_category("Difficulty")
@export_range(1, 20, 1)
var difficulty: int = 1

## Green success-zone height at the easiest difficulty.
@export var easiest_target_height: float = 90.0

## Green success-zone height at difficulty 10 and above.
@export var hardest_target_height: float = 28.0

@export var base_bar_speed: float = 50.0


@export_category("Marker")
@export var marker_height: float = 8.0


@export_category("Colors")
@export var background_color: Color = Color(0.12, 0.12, 0.12, 0.95)
@export var target_color: Color = Color(0.18, 0.72, 0.24, 1.0)
@export var marker_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 1.0)


var bar_speed: float = 200.0
var target_height: float = 60.0
var target_y: float = 0.0
var marker_y: float = 0.0
var marker_direction: float = 1.0
var hold: bool = false
var hit_count: int = 0
var catch: bool = false
var fail: bool = false


func _ready() -> void:
	set_difficulty(difficulty)
	reset_game()


func _process(delta: float) -> void:
	if catch or fail:
		queue_redraw()
		return

	_update_marker(delta)
	_handle_input()
	queue_redraw()


func _draw() -> void:
	var bar_rect := Rect2(bar_position, bar_size)

	draw_rect(
		bar_rect,
		background_color,
		true
	)

	var target_rect := Rect2(
		Vector2(bar_position.x, target_y),
		Vector2(bar_size.x, target_height)
	)

	draw_rect(
		target_rect,
		target_color,
		true
	)

	var marker_rect := Rect2(
		Vector2(
			bar_position.x,
			marker_y - marker_height * 0.5
		),
		Vector2(bar_size.x, marker_height)
	)

	draw_rect(
		marker_rect,
		marker_color,
		true
	)

	draw_rect(
		bar_rect,
		border_color,
		false,
		3.0
	)


func set_difficulty(new_difficulty: int) -> void:
	difficulty = clampi(new_difficulty, 1, 20)

	# Difficulty 1 -> 0.0, difficulty 10+ -> 1.0.
	var difficulty_ratio := clampf(
		inverse_lerp(1.0, 10.0, float(difficulty)),
		0.0,
		1.0
	)

	target_height = lerpf(
		easiest_target_height,
		hardest_target_height,
		difficulty_ratio
	)

	bar_speed = float(difficulty) * base_bar_speed
	_randomize_target()
	queue_redraw()


func _update_marker(delta: float) -> void:
	marker_y += bar_speed * delta * marker_direction

	var top := bar_position.y + marker_height * 0.5
	var bottom := (
		bar_position.y
		+ bar_size.y
		- marker_height * 0.5
	)

	if marker_y >= bottom:
		marker_y = bottom
		marker_direction = -1.0
	elif marker_y <= top:
		marker_y = top
		marker_direction = 1.0


func _handle_input() -> void:
	var space_pressed := Input.is_key_pressed(KEY_SPACE)

	if space_pressed and not hold:
		hold = true

		if _marker_is_inside_target():
			hit_count += 1
			print("HIT")

			if hit_count >= 3:
				print("WIN")
				hit_count = 0
				catch = true
				return

			reset_round()
		else:
			print("MISS")
			hit_count = 0
			fail = true

	if not space_pressed:
		hold = false


func _marker_is_inside_target() -> bool:
	return (
		marker_y >= target_y
		and marker_y <= target_y + target_height
	)


func _randomize_target() -> void:
	var minimum_y := bar_position.y
	var maximum_y := (
		bar_position.y
		+ bar_size.y
		- target_height
	)

	if maximum_y <= minimum_y:
		target_y = minimum_y
		return

	target_y = randf_range(minimum_y, maximum_y)


func reset_round() -> void:
	marker_y = bar_position.y + marker_height * 0.5
	marker_direction = 1.0
	_randomize_target()
	queue_redraw()


func reset_game() -> void:
	hit_count = 0
	catch = false
	fail = false
	hold = Input.is_key_pressed(KEY_SPACE)
	reset_round()
