extends Node2D


var catch_start: bool = false
var catch_game: Node2D
var bar_ui
var catch_game_active: bool = false
var caught_runner: Node2D = null


@onready var runner_horse = $runner_horse
@onready var player_horse = $player_horse
@onready var lasso_system: LassoController = $player_horse/LassoSystem


func _ready() -> void:
	catch_game = $catch_game
	bar_ui = $catch_game/bar_ui

	# Runner difficulty controls the speed of the catch minigame bar.
	bar_ui.bar_speed = runner_horse.difficulty * 50

	if not lasso_system.catchable_touched.is_connected(
		_on_lasso_catchable_touched
	):
		lasso_system.catchable_touched.connect(
			_on_lasso_catchable_touched
		)

	# Keep the minigame scene around, but remove it from the active tree until
	# the runner is actually lassoed.
	remove_child(catch_game)


func _process(_delta: float) -> void:
	# Keep Enter as a debug shortcut for testing the catch minigame.
	if Input.is_key_pressed(KEY_ENTER):
		catch_start = true

	if catch_start:
		_start_catch_game()

	if not catch_game_active:
		return

	# IMPORTANT: win and fail are intentionally different outcomes.
	if bar_ui.catch:
		_finish_catch_game(true)
	elif bar_ui.fail:
		_finish_catch_game(false)


func _on_lasso_catchable_touched(target: Node) -> void:
	if target == null:
		return

	if target == runner_horse or target.is_in_group(&"lasso_catchable"):
		if target is Node2D:
			caught_runner = target as Node2D
		catch_start = true


func _start_catch_game() -> void:
	catch_start = false

	if catch_game_active:
		return

	# A fresh lasso attempt should always start the timing game cleanly.
	bar_ui.reset_game()

	if catch_game.get_parent() == null:
		add_child(catch_game)

	catch_game_active = true


func _finish_catch_game(won: bool) -> void:
	if not catch_game_active:
		return

	catch_game_active = false

	if catch_game.get_parent() == self:
		remove_child(catch_game)

	# The lasso stays on the runner through the entire timing game. It only
	# starts retracting once the result has been decided.
	if lasso_system != null:
		lasso_system.release_latch()

	if won:
		_capture_runner()
	else:
		# Failure means the horse escaped the attempt and remains catchable.
		caught_runner = null

	bar_ui.reset_game()
	catch_start = false


func _capture_runner() -> void:
	var target := caught_runner
	if not is_instance_valid(target):
		target = runner_horse

	if not is_instance_valid(target):
		caught_runner = null
		return

	# runner_horse.gd owns the visual capture/removal behavior.
	if target.has_method("capture"):
		target.capture(player_horse.global_position)
	else:
		target.queue_free()

	caught_runner = null
