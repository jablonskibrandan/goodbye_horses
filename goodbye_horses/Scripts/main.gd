extends Node2D


func _ready() -> void:
	GameManager.reset_run_speed()

	if has_node("runner_horse") and has_node("catch_game/bar_ui"):
		$"catch_game/bar_ui".bar_speed = $runner_horse.difficulty * 50
