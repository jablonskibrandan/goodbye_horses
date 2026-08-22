extends Node

@export var obstacle_spawner: ObstacleSpawner
@export var pickup_spawner: PickupSpawner
@export var lasso_system: LassoController
@export var player_horse: Horse
@export var game_over_ui: GameOverUI

func _game_over(
	reason: String
) -> void:
	if (
		GameManager.level_state
		== GameManager.LevelState.GAME_OVER
	):
		return

	GameManager.set_level_state(
		GameManager.LevelState.GAME_OVER
	)

	obstacle_spawner.stop_spawning()
	pickup_spawner.stop_spawning()

	player_horse.set_controls_enabled(
		false
	)

	lasso_system.cancel_and_retract()

	game_over_ui.show_game_over(
		reason
	)
