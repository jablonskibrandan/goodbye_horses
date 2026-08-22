class_name LevelEndUI
extends CanvasLayer


signal replay_requested
signal next_level_requested


@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/VBox/Title
@onready var stars_label: Label = $Root/Center/Panel/Margin/VBox/Stars
@onready var summary_label: Label = $Root/Center/Panel/Margin/VBox/Summary
@onready var replay_button: Button = $Root/Center/Panel/Margin/VBox/Buttons/ReplayButton
@onready var next_level_button: Button = $Root/Center/Panel/Margin/VBox/Buttons/NextLevelButton


func _ready() -> void:
	root.visible = false

	replay_button.pressed.connect(
		func() -> void:
			replay_requested.emit()
	)

	next_level_button.pressed.connect(
		func() -> void:
			next_level_requested.emit()
	)


func show_level_complete(
	level_number: int,
	stars: int,
	current_hearts: int,
	max_hearts: int,
	catch_failures: int,
	stamina_percent: int,
	has_next_level: bool
) -> void:
	root.visible = true
	title_label.text = "HORSE CAPTURED!\nLEVEL %d COMPLETE" % level_number
	stars_label.visible = true
	stars_label.text = _get_star_text(stars)

	summary_label.text = (
		"HEARTS: %d / %d\n"
		+ "FAILED CATCHES: %d\n"
		+ "STAMINA REMAINING: %d%%"
	) % [
		current_hearts,
		max_hearts,
		catch_failures,
		stamina_percent,
	]

	next_level_button.visible = has_next_level
	replay_button.grab_focus()


func show_game_over(
	reason: String,
	catch_failures: int
) -> void:
	root.visible = true
	title_label.text = "GAME OVER"
	stars_label.visible = false
	summary_label.text = "%s\n\nFAILED CATCHES: %d" % [
		reason,
		catch_failures,
	]

	next_level_button.visible = false
	replay_button.grab_focus()


func hide_screen() -> void:
	root.visible = false


func _get_star_text(stars: int) -> String:
	var result := ""

	for index in range(3):
		if index < stars:
			result += "★"
		else:
			result += "☆"

	return result
