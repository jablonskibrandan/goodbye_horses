extends Node2D

var catch_start = false
var catch_game
var bar_ui
var default_child_count = 3

func _ready():
	$"catch_game/bar_ui".bar_speed = $runner_horse.difficulty * 50
	catch_game = $catch_game
	bar_ui = $"catch_game/bar_ui"
	remove_child($catch_game)
	
func _process(delta):
	if Input.is_key_pressed(KEY_ENTER):
		catch_start = true
		
	activate_catching()

func activate_catching():
	if catch_start:
		catch_start = false
		if get_child_count() < default_child_count:
			add_child(catch_game)
	
	if bar_ui.catch or bar_ui.fail:
		remove_child(catch_game)
		bar_ui.catch = false
		bar_ui.fail = false
		catch_start = false
