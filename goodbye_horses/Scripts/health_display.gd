class_name HealthDisplay
extends TextureRect


@export_category("Heart Textures")

@export var four_hearts_texture: Texture2D
@export var three_hearts_texture: Texture2D
@export var two_hearts_texture: Texture2D
@export var one_heart_texture: Texture2D


@export_category("References")

@export var player_health: PlayerHealth


func _ready() -> void:
	if player_health == null:
		push_error(
			"HealthDisplay: PlayerHealth is not assigned."
		)
		return

	player_health.health_changed.connect(
		_on_health_changed
	)

	# Set the correct image immediately.
	_on_health_changed(
		player_health.current_hearts,
		player_health.max_hearts
	)


func _on_health_changed(
	current_hearts: int,
	_max_hearts: int
) -> void:
	match current_hearts:
		4:
			texture = four_hearts_texture

		3:
			texture = three_hearts_texture

		2:
			texture = two_hearts_texture

		1:
			texture = one_heart_texture

		0:
			# Game over should be happening here,
			# so just leave the final texture visible.
			texture = one_heart_texture
