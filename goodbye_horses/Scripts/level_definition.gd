class_name LevelDefinition
extends Resource


@export_category("Level")
@export var level_name: String = "Level 1"


@export_category("World")
@export var world_speed: float = 350.0


@export_category("Wild Horse")
@export_range(1, 20, 1)
var runner_difficulty: int = 5


@export_category("Player")
@export var stamina_drain_per_second: float = 2.0


@export_category("Obstacles")
@export var obstacle_minimum_spawn_time: float = 1.0
@export var obstacle_maximum_spawn_time: float = 2.0
@export var obstacle_initial_delay: float = 1.0


@export_category("Pickups")
@export var pickup_minimum_spawn_time: float = 3.0
@export var pickup_maximum_spawn_time: float = 5.5
@export var pickup_initial_delay: float = 2.0


@export_category("Sugar Cubes")
@export var sugar_cube_base_weight: float = 1.0
@export_range(0.1, 1.0, 0.01)
var sugar_cube_difficulty_decay: float = 0.72
@export_range(0.0, 1.0, 0.01)
var minimum_sugar_cube_weight: float = 0.05
