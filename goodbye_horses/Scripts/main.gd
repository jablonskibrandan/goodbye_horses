extends Node2D

func _ready():
	$"catch_game/bar_ui".bar_speed = $runner_horse.difficulty * 50
