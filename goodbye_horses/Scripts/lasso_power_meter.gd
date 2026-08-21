class_name LassoPowerMeter
extends Control


@export_category("Meter")
@export_range(0.1, 5.0, 0.05) var sweep_speed: float = 1.25
@export_range(0.0, 1.0, 0.01) var red_end: float = 0.40
@export_range(0.0, 1.0, 0.01) var yellow_end: float = 0.72
@export var bar_height: float = 26.0
@export var marker_width: float = 5.0


var power: float = 0.0
var is_running: bool = false
var _direction: float = 1.0


func _ready() -> void:
	visible = false
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_running:
		return

	power += _direction * sweep_speed * delta

	if power >= 1.0:
		power = 1.0
		_direction = -1.0
	elif power <= 0.0:
		power = 0.0
		_direction = 1.0

	queue_redraw()


func start_meter() -> void:
	power = 0.0
	_direction = 1.0
	is_running = true
	visible = true
	set_process(true)
	queue_redraw()


func lock_power() -> float:
	var locked_power := power
	is_running = false
	visible = false
	set_process(false)
	queue_redraw()
	return locked_power


func cancel_meter() -> void:
	is_running = false
	visible = false
	set_process(false)
	queue_redraw()


func get_zone_name(value: float = power) -> StringName:
	if value < red_end:
		return &"red"
	if value < yellow_end:
		return &"yellow"
	return &"green"


func _draw() -> void:
	var height := minf(bar_height, size.y - 12.0)
	var bar_rect := Rect2(
		0.0,
		(size.y - height) * 0.5,
		size.x,
		height
	)

	var red_width := bar_rect.size.x * red_end
	var yellow_width := bar_rect.size.x * (yellow_end - red_end)
	var green_width := bar_rect.size.x * (1.0 - yellow_end)

	draw_rect(
		Rect2(bar_rect.position, Vector2(red_width, height)),
		Color("c84545")
	)
	draw_rect(
		Rect2(
			bar_rect.position + Vector2(red_width, 0.0),
			Vector2(yellow_width, height)
		),
		Color("d6a632")
	)
	draw_rect(
		Rect2(
			bar_rect.position + Vector2(red_width + yellow_width, 0.0),
			Vector2(green_width, height)
		),
		Color("4eaa60")
	)

	draw_rect(bar_rect, Color("241f1a"), false, 3.0)

	var marker_x := bar_rect.position.x + bar_rect.size.x * power
	var marker_top := bar_rect.position.y - 7.0
	var marker_bottom := bar_rect.end.y + 7.0

	draw_line(
		Vector2(marker_x, marker_top),
		Vector2(marker_x, marker_bottom),
		Color.WHITE,
		marker_width,
		true
	)
	draw_line(
		Vector2(marker_x + marker_width, marker_top),
		Vector2(marker_x + marker_width, marker_bottom),
		Color("241f1a"),
		1.5,
		true
	)
