class_name PickupSpawner
extends Node2D


@export_category("Pickups")
## Normal pickups such as apples and carrots. These all have equal base weight.
@export var pickup_scenes: Array[PackedScene] = []

## Sugar cube is handled separately so its chance can decrease with difficulty.
@export var sugar_cube_scene: PackedScene


@export_category("Sugar Cube Rarity")
## Weight at difficulty 1. With two normal pickups at weight 1 each, a value
## of 1.0 means roughly a 33% sugar-cube chance on the easiest difficulty.
@export_range(0.0, 5.0, 0.05)
var sugar_cube_base_weight: float = 1.0

## Sugar-cube weight is multiplied by this once for every difficulty level
## above 1. 0.72 gives about 12% at difficulty 5 and about 3% at difficulty 10.
@export_range(0.1, 1.0, 0.01)
var sugar_cube_difficulty_decay: float = 0.72

## Prevents the item from becoming mathematically impossible at very high
## difficulty unless you deliberately set this to 0.
@export_range(0.0, 1.0, 0.01)
var minimum_sugar_cube_weight: float = 0.05


@export_category("References")
@export var horse: Horse


@export_category("Timing")
@export var minimum_spawn_time: float = 2.5
@export var maximum_spawn_time: float = 5.0
@export var initial_spawn_delay: float = 2.0
@export var auto_start: bool = false


@export_category("Spawn Area")
## Extra distance beyond the right edge of the viewport.
@export var spawn_x_offset: float = 75.0

## Keeps spawned objects slightly away from the exact top/bottom of the
## horse movement lane. Set to 0 if we want the full lane used.
@export var vertical_spawn_padding: float = 0.0


@onready var spawn_timer: Timer = $SpawnTimer


var _spawning: bool = false
var _difficulty_level: int = 1


func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if pickup_scenes.is_empty() and sugar_cube_scene == null:
		push_warning("PickupSpawner has no pickup scenes assigned.")
		return

	if horse == null:
		push_error("PickupSpawner needs the player Horse assigned.")
		return

	if auto_start:
		start_spawning()


func set_difficulty(difficulty: int) -> void:
	_difficulty_level = maxi(difficulty, 1)


func get_sugar_cube_spawn_chance() -> float:
	var regular_weight := float(pickup_scenes.size())
	var sugar_weight := _get_sugar_cube_weight()
	var total_weight := regular_weight + sugar_weight

	if total_weight <= 0.0:
		return 0.0

	return sugar_weight / total_weight


func start_spawning() -> void:
	if (
		pickup_scenes.is_empty()
		and sugar_cube_scene == null
	):
		return

	if horse == null:
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

	_spawn_pickup()
	_schedule_next_spawn()


func _spawn_pickup() -> void:
	if horse == null:
		return

	var selected_scene := _choose_pickup_scene()

	if selected_scene == null:
		return

	var pickup := selected_scene.instantiate()
	get_tree().current_scene.add_child(pickup)

	var bounds: Rect2 = horse.movement_bounds
	var lane_padding := (
		horse.boundary_padding.y
		+ vertical_spawn_padding
	)

	var minimum_y := bounds.position.y + lane_padding
	var maximum_y := bounds.end.y - lane_padding

	if maximum_y < minimum_y:
		var center_y := bounds.get_center().y
		minimum_y = center_y
		maximum_y = center_y

	var viewport_right := get_viewport_rect().size.x
	var spawn_x := viewport_right + spawn_x_offset

	pickup.global_position = Vector2(
		spawn_x,
		randf_range(minimum_y, maximum_y)
	)


func _choose_pickup_scene() -> PackedScene:
	var regular_count := pickup_scenes.size()
	var sugar_weight := _get_sugar_cube_weight()

	if sugar_cube_scene == null:
		if regular_count == 0:
			return null

		return pickup_scenes.pick_random()

	var total_weight := float(regular_count) + sugar_weight

	if total_weight <= 0.0:
		return null

	var roll := randf() * total_weight

	## Sugar cube gets the first weighted slice.
	if roll < sugar_weight:
		return sugar_cube_scene

	## Every regular pickup gets weight 1.0.
	roll -= sugar_weight

	if regular_count <= 0:
		return sugar_cube_scene

	var regular_index := clampi(
		int(floor(roll)),
		0,
		regular_count - 1
	)

	return pickup_scenes[regular_index]


func _get_sugar_cube_weight() -> float:
	if sugar_cube_scene == null:
		return 0.0

	var difficulty_steps := maxi(
		_difficulty_level - 1,
		0
	)

	var difficulty_weight := (
		sugar_cube_base_weight
		* pow(
			sugar_cube_difficulty_decay,
			difficulty_steps
		)
	)

	return maxf(
		difficulty_weight,
		minimum_sugar_cube_weight
	)


func _schedule_next_spawn() -> void:
	if not _spawning:
		return

	spawn_timer.wait_time = randf_range(
		minimum_spawn_time,
		maxf(maximum_spawn_time, minimum_spawn_time)
	)
	spawn_timer.start()
