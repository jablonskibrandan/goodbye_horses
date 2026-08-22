class_name ObstacleSpawner
extends Node2D


@export_category("Obstacles")
@export var obstacle_scenes: Array[PackedScene] = []


@export_category("References")
@export var horse: Horse


@export_category("Spawning")
@export var minimum_spawn_time: float = 1.0
@export var maximum_spawn_time: float = 2.25
@export var initial_spawn_delay: float = 1.0
@export var auto_start: bool = false

## Extra distance beyond the right edge of the viewport.
@export var spawn_x_offset: float = 75.0

## Keeps spawned objects slightly away from the exact top/bottom of the
## horse movement lane. Set to 0 if we want the full lane used.
@export var vertical_spawn_padding: float = 0.0


@onready var spawn_timer: Timer = $SpawnTimer


var _spawning: bool = false


func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner has no obstacle scenes assigned.")
		return

	if horse == null:
		push_error("ObstacleSpawner needs the player Horse assigned.")
		return

	if auto_start:
		start_spawning()


func start_spawning() -> void:
	if obstacle_scenes.is_empty() or horse == null:
		return

	_spawning = true
	spawn_timer.stop()
	spawn_timer.wait_time = maxf(initial_spawn_delay, 0.01)
	spawn_timer.start()


func stop_spawning() -> void:
	_spawning = false
	spawn_timer.stop()


func is_spawning() -> bool:
	return _spawning


func _on_spawn_timer_timeout() -> void:
	if not _spawning:
		return

	_spawn_obstacle()
	_schedule_next_spawn()


func _spawn_obstacle() -> void:
	if obstacle_scenes.is_empty() or horse == null:
		return

	var selected_scene: PackedScene = obstacle_scenes.pick_random()
	if selected_scene == null:
		return

	var obstacle := selected_scene.instantiate()
	get_tree().current_scene.add_child(obstacle)

	var bounds: Rect2 = horse.movement_bounds
	var lane_padding := horse.boundary_padding.y + vertical_spawn_padding

	var minimum_y := bounds.position.y + lane_padding
	var maximum_y := bounds.end.y - lane_padding

	if maximum_y < minimum_y:
		var center_y := bounds.get_center().y
		minimum_y = center_y
		maximum_y = center_y

	var viewport_right := get_viewport_rect().size.x
	var spawn_x := viewport_right + spawn_x_offset

	obstacle.global_position = Vector2(
		spawn_x,
		randf_range(minimum_y, maximum_y)
	)


func _schedule_next_spawn() -> void:
	if not _spawning:
		return

	spawn_timer.wait_time = randf_range(
		minimum_spawn_time,
		maxf(maximum_spawn_time, minimum_spawn_time)
	)
	spawn_timer.start()
