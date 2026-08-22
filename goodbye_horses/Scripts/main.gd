extends Node2D


@export_category("Level Flow")
## Set this true to skip the opening horse entrance while
## testing
@export var start_immediately: bool = false

@export_category("Level Intro")
## The wild horse begins just beyond the left edge of the screen.
@export var runner_intro_start_x: float = -150.0

## How quickly the wild horse crosses the screen to its normal start position.
@export var runner_intro_speed: float = 650.0

## The player waits off-screen while the wild horse makes its entrance.
@export var player_intro_start_x: float = -150.0

## After the wild horse reaches the right side, the player rides only a little
## way into the left side of the screen and stops here.
@export var player_intro_target_position: Vector2 = Vector2(180.0, 500.0)

## Player entrance speed.
@export var player_intro_speed: float = 550.0

## How long START! stays fully visible after gameplay is enabled.
@export var start_text_hold_time: float = 0.55

## How long START! takes to fade away.
@export var start_text_fade_time: float = 0.35

@export_category("Sugar Cube Lure")
@export var sugar_cube_lure_scene: PackedScene

## Where the cube visually leaves the player's horse from.
@export var lure_throw_origin_offset: Vector2 = Vector2(52.0, -34.0)


@export_category("Debug")
@export var enable_enter_catch_debug: bool = false


var catch_start: bool = false
var catch_game: Node2D
var bar_ui
var catch_game_active: bool = false
var caught_runner: Node2D = null
var catch_failures: int = 0
var _ending_level: bool = false
var _active_sugar_cube_lure: SugarCubeLure = null
var _runner_gameplay_start_position: Vector2
var level_definition: LevelDefinition


@onready var runner_horse = $runner_horse
@onready var player_horse: Horse = $player_horse
@onready var lasso_system: LassoController = $player_horse/LassoSystem
@onready var player_health: PlayerHealth = $player_horse/PlayerHealth
@onready var obstacle_spawner: ObstacleSpawner = $ObstacleSpawner
@onready var pickup_spawner: PickupSpawner = $PickupSpawner
@onready var stamina_bar: ProgressBar = $HealthHUD/StaminaBar
@onready var catch_failures_label: Label = $HealthHUD/CatchFailuresLabel
@onready var sugar_cube_label: Label = $HealthHUD/SugarCubeLabel
@onready var level_end_ui: LevelEndUI = $LevelEndUI
@onready var start_label: Label = $IntroHUD/StartLabel


func _ready() -> void:
	catch_game = $catch_game
	bar_ui = $catch_game/bar_ui

	level_definition = GameManager.get_current_level()

	if level_definition == null:
		push_error("Main: Could not load the current LevelDefinition.")
		return

	_apply_level_definition()

	## Difficulty controls both the catch game and sugar-cube rarity.
	if bar_ui.has_method("set_difficulty"):
		bar_ui.set_difficulty(runner_horse.difficulty)
	else:
		bar_ui.bar_speed = runner_horse.difficulty * 50

	pickup_spawner.set_difficulty(runner_horse.difficulty)

	_connect_gameplay_signals()
	_connect_level_end_ui()

	## Keep the minigame scene around, but remove it from the active tree until
	## the runner is actually lassoed.
	remove_child(catch_game)

	_update_catch_failures_hud()
	_update_stamina_hud(
		player_horse.current_stamina,
		player_horse.maximum_stamina
	)
	_update_sugar_cube_hud(
		player_horse.sugar_cubes,
		player_horse.maximum_sugar_cubes
	)

	_runner_gameplay_start_position = runner_horse.global_position
	_prepare_start_label()

	if start_immediately:
		start_level()
	else:
		_run_level_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_lure"):
		_try_throw_sugar_cube_lure()


func _process(_delta: float) -> void:
	if enable_enter_catch_debug and Input.is_key_pressed(KEY_ENTER):
		catch_start = true

	if catch_start:
		_start_catch_game()

	if not catch_game_active:
		return

	if bar_ui.catch:
		_finish_catch_game(true)
	elif bar_ui.fail:
		_finish_catch_game(false)


func _apply_level_definition() -> void:
	if level_definition == null:
		return

	GameManager.set_base_world_speed(
		level_definition.world_speed
	)

	runner_horse.difficulty = level_definition.runner_difficulty
	runner_horse.speed = (
		runner_horse.base_speed
		* runner_horse.difficulty
	)

	player_horse.stamina_drain_per_second = (
		level_definition.stamina_drain_per_second
	)

	## Obstacle pacing.
	obstacle_spawner.minimum_spawn_time = (
		level_definition.obstacle_minimum_spawn_time
	)
	obstacle_spawner.maximum_spawn_time = (
		level_definition.obstacle_maximum_spawn_time
	)
	obstacle_spawner.initial_spawn_delay = (
		level_definition.obstacle_initial_delay
	)

	# Pickup pacing and sugar-cube rarity.
	pickup_spawner.minimum_spawn_time = (
		level_definition.pickup_minimum_spawn_time
	)
	pickup_spawner.maximum_spawn_time = (
		level_definition.pickup_maximum_spawn_time
	)
	pickup_spawner.initial_spawn_delay = (
		level_definition.pickup_initial_delay
	)
	pickup_spawner.sugar_cube_base_weight = (
		level_definition.sugar_cube_base_weight
	)
	pickup_spawner.sugar_cube_difficulty_decay = (
		level_definition.sugar_cube_difficulty_decay
	)
	pickup_spawner.minimum_sugar_cube_weight = (
		level_definition.minimum_sugar_cube_weight
	)


func _connect_gameplay_signals() -> void:
	if not lasso_system.catchable_touched.is_connected(
		_on_lasso_catchable_touched
	):
		lasso_system.catchable_touched.connect(
			_on_lasso_catchable_touched
		)

	if not player_health.damaged.is_connected(_on_player_damaged):
		player_health.damaged.connect(_on_player_damaged)

	if not player_health.died.is_connected(_on_player_died):
		player_health.died.connect(_on_player_died)

	if not player_horse.horse_exhausted.is_connected(_on_horse_exhausted):
		player_horse.horse_exhausted.connect(_on_horse_exhausted)

	if not player_horse.stamina_changed.is_connected(_update_stamina_hud):
		player_horse.stamina_changed.connect(_update_stamina_hud)

	if not player_horse.sugar_cubes_changed.is_connected(
		_update_sugar_cube_hud
	):
		player_horse.sugar_cubes_changed.connect(
			_update_sugar_cube_hud
		)

	if not runner_horse.captured.is_connected(_on_runner_captured):
		runner_horse.captured.connect(_on_runner_captured)


func _connect_level_end_ui() -> void:
	if not level_end_ui.replay_requested.is_connected(_on_replay_requested):
		level_end_ui.replay_requested.connect(_on_replay_requested)

	if not level_end_ui.next_level_requested.is_connected(
		_on_next_level_requested
	):
		level_end_ui.next_level_requested.connect(
			_on_next_level_requested
		)


# ============================================================
# LEVEL STATES
# ============================================================


func _enter_herd_intro_state() -> void:
	GameManager.set_level_state(
		GameManager.LevelState.HERD_INTRO
	)

	obstacle_spawner.stop_spawning()
	pickup_spawner.stop_spawning()
	player_horse.set_controls_enabled(false)
	player_horse.set_stamina_drain_enabled(false)
	lasso_system.set_enabled(false)


func _run_level_intro() -> void:
	_enter_herd_intro_state()

	## Keep the player's horse completely off-screen while the wild horse makes
	## the first entrance. It will not be clamped into the gameplay bounds while
	## waiting for its cue.
	if is_instance_valid(player_horse):
		player_horse.prepare_intro(
			Vector2(
				player_intro_start_x,
				player_intro_target_position.y
			)
		)

	if not is_instance_valid(runner_horse):
		_show_start_and_begin()
		return

	var intro_start := Vector2(
		runner_intro_start_x,
		_runner_gameplay_start_position.y
	)

	runner_horse.start_intro(
		intro_start,
		_runner_gameplay_start_position,
		runner_intro_speed
	)

	await runner_horse.intro_arrived

	if _ending_level:
		return

	## The wild horse is now parked on the right. Bring the player's horse in
	## separately from off-screen left, stopping near the left side.
	if is_instance_valid(player_horse):
		var player_intro_start := Vector2(
			player_intro_start_x,
			player_intro_target_position.y
		)

		player_horse.start_intro(
			player_intro_start,
			player_intro_target_position,
			player_intro_speed
		)

		await player_horse.intro_arrived

	if _ending_level:
		return

	_show_start_and_begin()


func _prepare_start_label() -> void:
	if start_label == null:
		return

	start_label.visible = false
	start_label.modulate.a = 0.0
	start_label.scale = Vector2.ONE


func _show_start_and_begin() -> void:
	if start_label == null:
		start_level()
		return

	start_label.text = "START!"
	start_label.visible = true
	start_label.modulate.a = 1.0
	start_label.scale = Vector2(0.72, 0.72)
	start_label.pivot_offset = start_label.size * 0.5

	start_level()

	var pop_tween := create_tween()
	pop_tween.tween_property(
		start_label,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	await pop_tween.finished
	await get_tree().create_timer(start_text_hold_time).timeout

	if not is_instance_valid(start_label):
		return

	var fade_tween := create_tween()
	fade_tween.tween_property(
		start_label,
		"modulate:a",
		0.0,
		start_text_fade_time
	)

	await fade_tween.finished

	if is_instance_valid(start_label):
		start_label.visible = false

func start_level() -> void:
	if _ending_level:
		return

	GameManager.set_level_state(
		GameManager.LevelState.PLAYING
	)

	player_horse.set_controls_enabled(true)
	player_horse.set_stamina_drain_enabled(true)
	lasso_system.set_enabled(true)
	obstacle_spawner.start_spawning()
	pickup_spawner.start_spawning()


func _enter_catch_minigame_state() -> void:
	GameManager.set_level_state(
		GameManager.LevelState.CATCH_MINIGAME
	)

	


func _resume_playing_after_catch() -> void:
	if _ending_level:
		return

	GameManager.set_level_state(
		GameManager.LevelState.PLAYING
	)



# ============================================================
# SUGAR CUBE LURE
# ============================================================


func _try_throw_sugar_cube_lure() -> void:
	if _ending_level:
		return

	if GameManager.level_state != GameManager.LevelState.PLAYING:
		return

	if sugar_cube_lure_scene == null:
		push_warning("Main: Sugar Cube Lure Scene is not assigned.")
		return

	if not is_instance_valid(runner_horse):
		return

	## Only one lure can be active at a time. This prevents accidentally burning
	## several cubes during one catch opportunity.
	if is_instance_valid(_active_sugar_cube_lure):
		return

	if not player_horse.use_sugar_cube():
		return

	var lure := (
		sugar_cube_lure_scene.instantiate()
		as SugarCubeLure
	)

	if lure == null:
		push_error("Main: Sugar Cube Lure Scene must use SugarCubeLure.")
		return

	add_child(lure)
	_active_sugar_cube_lure = lure

	lure.landed.connect(_on_sugar_cube_landed)
	lure.expired.connect(_on_sugar_cube_lure_expired)
	lure.consumed.connect(_on_sugar_cube_lure_consumed)

	var throw_start := (
		player_horse.global_position
		+ lure_throw_origin_offset
	)

	var landing_position = runner_horse.get_lure_landing_position(
		player_horse.global_position
	)

	lure.start_throw(
		throw_start,
		landing_position
	)


func _on_sugar_cube_landed(lure: SugarCubeLure) -> void:
	if lure != _active_sugar_cube_lure:
		return

	if not is_instance_valid(runner_horse):
		return

	if _ending_level:
		return

	## The wild horse only reacts after the cube physically lands. During the
	## Bezier flight it continues its normal evasive movement.
	runner_horse.set_lure(lure)


func _on_sugar_cube_lure_expired(lure: SugarCubeLure) -> void:
	if is_instance_valid(runner_horse):
		runner_horse.clear_lure(lure)

	if lure == _active_sugar_cube_lure:
		_active_sugar_cube_lure = null


func _on_sugar_cube_lure_consumed(lure: SugarCubeLure) -> void:
	if is_instance_valid(runner_horse):
		runner_horse.clear_lure(lure)

	if lure == _active_sugar_cube_lure:
		_active_sugar_cube_lure = null


func _clear_active_lure() -> void:
	if not is_instance_valid(_active_sugar_cube_lure):
		_active_sugar_cube_lure = null
		return

	var lure := _active_sugar_cube_lure
	_active_sugar_cube_lure = null

	if is_instance_valid(runner_horse):
		runner_horse.clear_lure(lure)

	lure.queue_free()


# ============================================================
# LASSO / CATCH GAME
# ============================================================


func _on_lasso_catchable_touched(target: Node) -> void:
	if _ending_level:
		return

	if GameManager.level_state != GameManager.LevelState.PLAYING:
		return

	if target == null:
		return

	if target == runner_horse or target.is_in_group(&"lasso_catchable"):
		if target is Node2D:
			caught_runner = target as Node2D
			catch_start = true


func _start_catch_game() -> void:
	catch_start = false

	if _ending_level or catch_game_active:
		return

	if caught_runner == null or not is_instance_valid(caught_runner):
		return

	bar_ui.reset_game()

	if catch_game.get_parent() == null:
		add_child(catch_game)

	catch_game_active = true
	_enter_catch_minigame_state()


func _finish_catch_game(won: bool) -> void:
	if not catch_game_active:
		return

	catch_game_active = false

	if catch_game.get_parent() == self:
		remove_child(catch_game)

	## The rope stays attached for the whole timing game. Once the result is
	## decided it can retract.
	if lasso_system != null:
		lasso_system.release_latch()

	bar_ui.reset_game()
	catch_start = false

	if won:
		_capture_runner()
	else:
		caught_runner = null
		_register_catch_failure()


func _on_player_damaged(_amount: int) -> void:
	if _ending_level:
		return

	## Any hit breaks an active/airborne lasso immediately.
	if lasso_system != null:
		lasso_system.cancel_and_retract()

	if not catch_game_active:
		catch_start = false
		caught_runner = null
		return

	## A fatal hit will be handled by PlayerHealth.died. Do not also turn it into
	## a third-catch-failure game over with the wrong reason.
	var fatal_hit := player_health.current_hearts <= 0

	catch_game_active = false

	if catch_game.get_parent() == self:
		remove_child(catch_game)

	bar_ui.reset_game()
	catch_start = false
	caught_runner = null

	if not fatal_hit:
		_register_catch_failure()


func _register_catch_failure() -> void:
	if _ending_level:
		return

	catch_failures += 1
	_update_catch_failures_hud()

	## A failed capture always costs one heart. This bypasses normal obstacle
	## invulnerability so a failed minigame can never avoid its penalty.
	player_health.lose_heart(1)

	## lose_heart() may have emitted died and already entered GAME_OVER.
	if _ending_level:
		return

	## Catch failures no longer directly end the level. They are tracked for
	## the final star rating, while the lost heart is the immediate penalty.
	_resume_playing_after_catch()


func _capture_runner() -> void:
	var target := caught_runner

	if not is_instance_valid(target):
		target = runner_horse

	if not is_instance_valid(target):
		caught_runner = null
		return

	if target.has_method("capture"):
		target.capture(player_horse.global_position)
	else:
		target.queue_free()
		_on_runner_captured()

	caught_runner = null


# ============================================================
# FAIL CONDITIONS
# ============================================================


func _on_player_died() -> void:
	_game_over("You lost all four hearts.")


func _on_horse_exhausted() -> void:
	_game_over("Your horse ran out of stamina.")


func _game_over(reason: String) -> void:
	if _ending_level:
		return

	_ending_level = true

	GameManager.set_level_state(
		GameManager.LevelState.GAME_OVER
	)

	_stop_gameplay_for_ending()
	level_end_ui.show_game_over(
		reason,
		catch_failures
	)


# ============================================================
# LEVEL COMPLETE / STARS
# ============================================================


func _on_runner_captured() -> void:
	_complete_level()


func _complete_level() -> void:
	if _ending_level:
		return

	_ending_level = true

	GameManager.set_level_state(
		GameManager.LevelState.LEVEL_COMPLETE
	)

	_stop_gameplay_for_ending()

	await get_tree().create_timer(0.55).timeout

	var stars := _calculate_stars()
	var stamina_percent := 0

	if player_horse.maximum_stamina > 0.0:
		stamina_percent = roundi(
			(player_horse.current_stamina / player_horse.maximum_stamina)
			* 100.0
		)

	level_end_ui.show_level_complete(
		GameManager.current_level_number,
		stars,
		player_health.current_hearts,
		player_health.max_hearts,
		catch_failures,
		stamina_percent,
		GameManager.has_next_level()
	)


func _calculate_stars() -> int:
	var health_stars := 0
	var catch_stars := 0

	## Health determines the best rating the player can earn.
	match player_health.current_hearts:
		4:
			health_stars = 3
		3, 2:
			health_stars = 2
		1:
			health_stars = 1
		_:
			health_stars = 0

	## Catch failures independently cap the final rating.
	if catch_failures == 0:
		catch_stars = 3
	elif catch_failures == 1:
		catch_stars = 2
	elif catch_failures <= 3:
		catch_stars = 1
	else:
		## More than three failures means the level can still be completed,
		## but the player earns no stars.
		catch_stars = 0

	return mini(health_stars, catch_stars)

func _stop_gameplay_for_ending() -> void:
	_clear_active_lure()
	obstacle_spawner.stop_spawning()
	pickup_spawner.stop_spawning()
	player_horse.set_controls_enabled(false)
	player_horse.set_stamina_drain_enabled(false)
	lasso_system.set_enabled(false)

	if catch_game_active:
		catch_game_active = false

		if catch_game.get_parent() == self:
			remove_child(catch_game)

		bar_ui.reset_game()

	catch_start = false
	caught_runner = null

	## Freeze scrolling hazards/pickups that already exist on screen.
	GameManager.set_world_speed_multiplier(0.0)

	if (
		GameManager.level_state == GameManager.LevelState.GAME_OVER
		and is_instance_valid(runner_horse)
	):
		runner_horse.set_process(false)
		runner_horse.set_physics_process(false)


# ============================================================
# HUD
# ============================================================


func _update_stamina_hud(
	current_stamina: float,
	maximum_stamina: float
) -> void:
	if stamina_bar == null:
		return

	stamina_bar.max_value = maximum_stamina
	stamina_bar.value = current_stamina


func _update_catch_failures_hud() -> void:
	if catch_failures_label == null:
		return

	catch_failures_label.text = "CATCH FAILS: %d" % catch_failures


func _update_sugar_cube_hud(
	current_amount: int,
	_maximum_amount: int
) -> void:
	if sugar_cube_label == null:
		return

	sugar_cube_label.text = "SUGAR CUBE x%d" % current_amount


# ============================================================
# RESULTS BUTTONS
# ============================================================


func _on_replay_requested() -> void:
	GameManager.reset_run()
	get_tree().reload_current_scene()


func _on_next_level_requested() -> void:
	if not GameManager.advance_level():
		return

	GameManager.reset_run_speed()
	GameManager.reset_level_state()

	## Every level reuses this same gameplay scene. On reload, _ready() reads the
	## new current_level_number and applies the matching .tres definition.
	get_tree().reload_current_scene()
