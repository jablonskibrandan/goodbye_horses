class_name LassoHead
extends Area2D


@export_category("Loop Visual")
@export var loop_width: float = 58.0
@export var loop_height: float = 34.0
@export var line_width: float = 3.5
@export var loop_tilt_degrees: float = -10.0
@export_range(16, 64, 1) var loop_segments: int = 36
@export var rope_color: Color = Color("c8a36a")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array()
	var rotation_radians := deg_to_rad(loop_tilt_degrees)

	for index in range(loop_segments + 1):
		var angle := TAU * float(index) / float(loop_segments)
		var point := Vector2(
			cos(angle) * loop_width * 0.5,
			sin(angle) * loop_height * 0.5
		)
		point = point.rotated(rotation_radians)
		points.append(point)

	draw_polyline(
		points,
		rope_color,
		line_width,
		true
	)
