class_name RunnerHorse
extends CharacterBody2D


signal captured
signal intro_arrived
signal lure_started
signal lure_reached
signal lure_finished


@export var anim2d: AnimatedSprite2D

@export_group("Runner Stats")
@export_range(1, 20, 1)
var difficulty: int = 5

@export var base_speed: float = 50.0


@export_group("Intro")
## Distance at which the intro movement snaps to the gameplay start point.
@export var intro_arrival_distance: float = 2.0


@export_group("Lure Behavior")
## While moving toward a sugar cube, the runner deliberately slows down and
## becomes predictable, creating a better lasso opportunity.
@export_range(0.1, 1.0, 0.05)
var lure_speed_multiplier: float = 0.45

## How close the runner must get before it stops to eat.
@export var lure_reached_distance: float = 34.0

## How long the runner stands still eating after it reaches the cube.
@export var lure_eat_duration: float = 2.5

## The lure lands this far in front of the runner, toward the player's horse.
@export var lure_landing_distance: float = 105.0

## Keeps lure landing locations inside the right-hand gameplay region.
@export var lure_landing_area: Rect2 = Rect2(
	610.0,
	300.0,
	330.0,
	360.0
)


@export_group("Roaming")
## The normal area the wild horse is allowed to evade within.
## This keeps it primarily on the right side while still allowing meaningful
## horizontal AND vertical movement.
@export var runner_area: Rect2 = Rect2(
	610.0,
	300.0,
	330.0,
	360.0
)

## How close the horse gets before considering a roaming target reached.
@export var target_reached_distance: float = 14.0

## Rejects tiny moves so the horse does not jitter around one small spot.
@export var minimum_target_distance: float = 105.0

## Most targets should require a noticeable horizontal change. This is what
## prevents the old "only moves up and down" behavior.
@export var minimum_horizontal_change: float = 65.0

## Adds useful vertical variation as well.
@export var minimum_vertical_change: float = 45.0

## The horse can change its mind before reaching a target. This creates jukes.
@export var minimum_retarget_time: float = 0.85
@export var maximum_retarget_time: float = 1.75

## Base chance to perform a mid-run juke when the retarget timer expires.
## Difficulty adds a small bonus to this chance.
@export_range(0.0, 1.0, 0.05)
var base_juke_chance: float = 0.28


var speed: float = 0.0

var move_target: Vector2 = Vector2.ZERO
var target_locked: bool = false
var is_captured: bool = false

var _retarget_timer: float = 0.0

var _active_lure: SugarCubeLure = null
var _is_eating_lure: bool = false
var _lure_eat_timer: float = 0.0

var _intro_active: bool = false
var _intro_target_global_position: Vector2 = Vector2.ZERO
var _intro_speed: float = 0.0


func _ready() -> void:
	speed = base_speed * difficulty
	anim2d.play("moving")


func _process(delta: float) -> void:
	if is_captured:
		return

	if _intro_active:
		_update_intro(delta)
		return

	# Stay parked at the intro destination until Main displays START! and
	# transitions the level to PLAYING.
	if GameManager.level_state == GameManager.LevelState.HERD_INTRO:
		velocity = Vector2.ZERO
		return

	if is_instance_valid(_active_lure):
		_update_lure_behavior(delta)
		return

	if _active_lure != null:
		_clear_lure_state()

	run_around(delta)


# ============================================================
# LEVEL INTRO
# ============================================================


func start_intro(
	start_global_position: Vector2,
	target_global_position: Vector2,
	intro_speed: float
) -> void:
	if is_captured:
		return

	global_position = start_global_position
	_intro_target_global_position = target_global_position
	_intro_speed = maxf(intro_speed, 1.0)
	_intro_active = true
	target_locked = true
	velocity = Vector2.ZERO

	if anim2d != null:
		anim2d.play("moving")


func _update_intro(delta: float) -> void:
	global_position = global_position.move_toward(
		_intro_target_global_position,
		_intro_speed * delta
	)

	if global_position.distance_to(
		_intro_target_global_position
	) > intro_arrival_distance:
		return

	global_position = _intro_target_global_position
	_intro_active = false
	target_locked = false
	velocity = Vector2.ZERO
	intro_arrived.emit()


func run_around(delta: float) -> void:
	if not target_locked:
		_choose_new_move_target()

	_retarget_timer = maxf(
		_retarget_timer - delta,
		0.0
	)

	# Occasionally change direction before reaching the destination.
	# Difficulty increases the chance slightly, so harder horses feel more
	# evasive without simply moving faster in a straight line.
	if _retarget_timer <= 0.0:
		var difficulty_bonus := clampf(
			float(difficulty - 1) * 0.025,
			0.0,
			0.22
		)

		var juke_chance := clampf(
			base_juke_chance + difficulty_bonus,
			0.0,
			0.65
		)

		if randf() <= juke_chance:
			_choose_new_move_target()
		else:
			_reset_retarget_timer()

	var distance_to_target := global_position.distance_to(
		move_target
	)

	if distance_to_target <= target_reached_distance:
		_choose_new_move_target()
		return

	var direction := global_position.direction_to(
		move_target
	)

	velocity = direction * speed
	move_and_slide()

	## Keep physics/collision response from pushing the runner outside its
	## intended evasive area.
	global_position.x = clampf(
		global_position.x,
		runner_area.position.x,
		runner_area.end.x
	)

	global_position.y = clampf(
		global_position.y,
		runner_area.position.y,
		runner_area.end.y
	)


func _choose_new_move_target() -> void:
	var best_candidate := global_position
	var best_score := -INF

	## Try several random points and keep the one that produces the strongest
	## useful change from the horse's current position.
	for _attempt in range(14):
		var candidate := Vector2(
			randf_range(
				runner_area.position.x,
				runner_area.end.x
			),
			randf_range(
				runner_area.position.y,
				runner_area.end.y
			)
		)

		var offset := candidate - global_position
		var distance := offset.length()

		if distance < minimum_target_distance:
			continue

		## Strongly prefer a real horizontal move, while still rewarding vertical
		## variation. This avoids selecting points directly above/below repeatedly.
		var horizontal_score := absf(offset.x)
		var vertical_score := absf(offset.y)

		var score := (
			distance
			+ horizontal_score * 0.8
			+ vertical_score * 0.25
		)

		if absf(offset.x) < minimum_horizontal_change:
			score -= 250.0

		if absf(offset.y) < minimum_vertical_change:
			score -= 45.0

		if score > best_score:
			best_score = score
			best_candidate = candidate

	move_target = best_candidate
	target_locked = true
	_reset_retarget_timer()


func _reset_retarget_timer() -> void:
	var difficulty_ratio := clampf(
		float(difficulty - 1) / 19.0,
		0.0,
		1.0
	)

	## Higher difficulty shortens the decision window a little.
	var min_time := lerpf(
		minimum_retarget_time,
		minimum_retarget_time * 0.72,
		difficulty_ratio
	)

	var max_time := lerpf(
		maximum_retarget_time,
		maximum_retarget_time * 0.72,
		difficulty_ratio
	)

	_retarget_timer = randf_range(
		min_time,
		max_time
	)


# ============================================================
# SUGAR CUBE LURE
# ============================================================


func get_lure_landing_position(
	player_global_position: Vector2
) -> Vector2:
	var toward_player := global_position.direction_to(
		player_global_position
	)

	if toward_player == Vector2.ZERO:
		toward_player = Vector2.LEFT

	var landing_position := (
		global_position
		+ toward_player * lure_landing_distance
	)

	landing_position.x = clampf(
		landing_position.x,
		lure_landing_area.position.x,
		lure_landing_area.end.x
	)

	landing_position.y = clampf(
		landing_position.y,
		lure_landing_area.position.y,
		lure_landing_area.end.y
	)

	return landing_position


func set_lure(lure: SugarCubeLure) -> void:
	if is_captured:
		return

	if lure == null or not is_instance_valid(lure):
		return

	_active_lure = lure
	_is_eating_lure = false
	_lure_eat_timer = 0.0
	target_locked = true

	lure_started.emit()


func clear_lure(lure: SugarCubeLure = null) -> void:
	if lure != null and lure != _active_lure:
		return

	_clear_lure_state()


func _update_lure_behavior(delta: float) -> void:
	if not is_instance_valid(_active_lure):
		_clear_lure_state()
		return

	if _is_eating_lure:
		velocity = Vector2.ZERO

		_lure_eat_timer = maxf(
			_lure_eat_timer - delta,
			0.0
		)

		if _lure_eat_timer <= 0.0:
			if is_instance_valid(_active_lure):
				_active_lure.consume()

			_clear_lure_state()

		return

	var distance_to_lure := global_position.distance_to(
		_active_lure.global_position
	)

	if distance_to_lure <= lure_reached_distance:
		_begin_eating_lure()
		return

	var lure_speed := speed * lure_speed_multiplier
	var direction := global_position.direction_to(
		_active_lure.global_position
	)

	# move_and_slide gives the lure approach smooth diagonal motion instead of
	# moving X/Y independently like the normal roaming behavior.
	velocity = direction * lure_speed
	move_and_slide()


func _begin_eating_lure() -> void:
	_is_eating_lure = true
	_lure_eat_timer = lure_eat_duration
	velocity = Vector2.ZERO

	lure_reached.emit()


func _clear_lure_state() -> void:
	var had_lure := _active_lure != null

	_active_lure = null
	_is_eating_lure = false
	_lure_eat_timer = 0.0
	target_locked = false
	_retarget_timer = 0.0
	velocity = Vector2.ZERO

	if had_lure:
		lure_finished.emit()


# ============================================================
# CAPTURE
# ============================================================


func capture(catcher_global_position: Vector2) -> void:
	if is_captured:
		return

	is_captured = true
	target_locked = true
	velocity = Vector2.ZERO

	if is_instance_valid(_active_lure):
		_active_lure.consume()

	_clear_lure_state()
	remove_from_group(&"lasso_catchable")

	# It is already caught, so it should no longer collide with another lasso
	# or interfere with the player while the capture visual finishes.
	var collision := get_node_or_null(
		"runner_collision"
	) as CollisionShape2D

	if collision != null:
		collision.set_deferred(
			"disabled",
			true
		)

	captured.emit()

	# Pull the captured runner toward the player while fading it away.
	#var destination := (
		#catcher_global_position
		#+ Vector2(100.0, -12.0)
	#)
#
	#var tween := create_tween()
	#tween.set_parallel(true)
#
	#tween.tween_property(
		#self,
		#"global_position",
		#destination,
		#0.45
	#).set_trans(
		#Tween.TRANS_QUAD
	#).set_ease(
		#Tween.EASE_IN
	#)
#
	#tween.tween_property(
		#self,
		#"modulate:a",
		#0.0,
		#0.45
	#)
#
	#tween.set_parallel(false)
	#tween.tween_callback(queue_free)
