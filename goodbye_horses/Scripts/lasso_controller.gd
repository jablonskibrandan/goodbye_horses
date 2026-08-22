class_name LassoController
extends Node2D

signal meter_started
signal lasso_cast(power: float, cast_distance: float)
signal lasso_returned
signal catchable_touched(target: Node)


enum State {
	IDLE,
	AIMING_POWER,
	CASTING,
	EXTENDED,
	LATCHED,
	RETRACTING,
}


@export_category("Input")
@export var lasso_action: StringName = &"lasso"


@export_category("Cast Distance")
## The exact meter position determines how far the loop travels.
## Red, yellow, and green are progressively farther distance bands.
@export var minimum_cast_distance: float = 90.0
@export var red_max_cast_distance: float = 260.0
@export var yellow_max_cast_distance: float = 430.0
@export var maximum_cast_distance: float = 600.0


@export_category("Cast Motion")
@export var minimum_cast_duration: float = 0.34
@export var maximum_cast_duration: float = 0.62
## Height of the loop's ballistic arc above the line from hand to landing point.
@export var minimum_cast_arc_height: float = 42.0
@export var maximum_cast_arc_height: float = 105.0
## The loop lands below the hand, closer to the ground plane.
@export var landing_drop: float = 48.0
@export var fully_extended_time: float = 0.28
@export var retract_speed: float = 850.0


@export_category("Rope Physics")
## More segments = smoother rope, but more constraint work.
@export_range(8, 40, 1) var rope_segments: int = 22
## Gravity applied to the free rope points. This is what makes the line hang.
@export var rope_gravity: float = 1150.0
## Retains a little motion so the rope has a subtle whip instead of snapping rigidly.
@export_range(0.80, 0.999, 0.001) var rope_damping: float = 0.965
## How many times the rope length constraints are solved each physics frame.
@export_range(2, 16, 1) var constraint_iterations: int = 8
## Extra rope paid out beyond the straight-line hand-to-loop distance.
## Small values look like a taut cast; larger values hang lower.
@export_range(1.0, 1.30, 0.005) var rope_slack_multiplier: float = 1.055
## A small amount of extra slack at full extension, in pixels.
@export var extra_full_extension_slack: float = 18.0


@export_category("References")
@export var hand_anchor: Marker2D
@export var rope: Line2D
@export var lasso_head: LassoHead
@export var power_meter: LassoPowerMeter


var state: State = State.IDLE
var locked_power: float = 0.0

var _cast_distance: float = 0.0
var _cast_duration: float = 0.0
var _cast_arc_height: float = 0.0
var _cast_elapsed: float = 0.0
var _extended_elapsed: float = 0.0
var _cast_progress: float = 0.0

var _rope_points: Array[Vector2] = []
var _rope_previous_points: Array[Vector2] = []
var _current_rope_length: float = 0.0
var _catch_emitted_this_cast: bool = false

## While latched, the loop follows the exact point on the horse that it touched. 
var _latched_target: Node2D = null
var _latched_target_local_point: Vector2 = Vector2.ZERO
var _input_enabled: bool = true


func _ready() -> void:
	if rope != null:
		rope.visible = false
		rope.clear_points()

	if lasso_head != null:
		lasso_head.visible = false
		lasso_head.position = _get_rope_origin()
		lasso_head.monitoring = true
		lasso_head.body_entered.connect(_on_lasso_head_body_entered)
		lasso_head.area_entered.connect(_on_lasso_head_area_entered)

	if power_meter != null:
		power_meter.cancel_meter()


func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return

	if not event.is_action_pressed(lasso_action):
		return

	match state:
		State.IDLE:
			_begin_power_meter()
		State.AIMING_POWER:
			_lock_power_and_cast()
		_:
			pass

	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	match state:
		State.CASTING:
			_update_cast(delta)
		State.EXTENDED:
			_update_extended(delta)
		State.LATCHED:
			_update_latched()
		State.RETRACTING:
			_update_retraction(delta)

	if (
		state == State.CASTING
		or state == State.EXTENDED
		or state == State.LATCHED
		or state == State.RETRACTING
	):
		_update_rope_physics(delta)

	if state == State.CASTING or state == State.EXTENDED:
		_check_for_catchable_overlap()


func _begin_power_meter() -> void:
	if power_meter == null:
		return

	state = State.AIMING_POWER
	power_meter.start_meter()
	meter_started.emit()


func _lock_power_and_cast() -> void:
	if power_meter == null:
		return

	locked_power = clampf(power_meter.lock_power(), 0.0, 1.0)

	## The exact position where the player stops the meter determines the distance.
	## The color zones simply divide that continuous range into readable bands.
	_cast_distance = _get_distance_from_meter(locked_power)
	_cast_duration = lerpf(
		minimum_cast_duration,
		maximum_cast_duration,
		locked_power
	)
	_cast_arc_height = lerpf(
		minimum_cast_arc_height,
		maximum_cast_arc_height,
		locked_power
	)

	_cast_elapsed = 0.0
	_extended_elapsed = 0.0
	_cast_progress = 0.0
	_catch_emitted_this_cast = false
	_latched_target = null
	_latched_target_local_point = Vector2.ZERO
	state = State.CASTING

	if lasso_head != null:
		lasso_head.position = _get_rope_origin()
		lasso_head.visible = true

	if rope != null:
		rope.visible = true

	_initialize_rope()
	lasso_cast.emit(locked_power, _cast_distance)


func _get_distance_from_meter(power: float) -> float:
	if power_meter == null:
		return lerpf(minimum_cast_distance, maximum_cast_distance, power)

	var red_end := clampf(power_meter.red_end, 0.01, 0.98)
	var yellow_end := clampf(power_meter.yellow_end, red_end + 0.01, 0.99)

	if power < red_end:
		var red_t := power / red_end
		return lerpf(
			minimum_cast_distance,
			red_max_cast_distance,
			red_t
		)

	if power < yellow_end:
		var yellow_t := (power - red_end) / (yellow_end - red_end)
		return lerpf(
			red_max_cast_distance,
			yellow_max_cast_distance,
			yellow_t
		)

	var green_t := (power - yellow_end) / (1.0 - yellow_end)
	return lerpf(
		yellow_max_cast_distance,
		maximum_cast_distance,
		green_t
	)


func _update_cast(delta: float) -> void:
	if lasso_head == null:
		_finish_lasso()
		return

	_cast_elapsed += delta
	_cast_progress = clampf(_cast_elapsed / _cast_duration, 0.0, 1.0)

	var origin := _get_rope_origin()
	var landing := origin + Vector2(_cast_distance, landing_drop)

	## A simple projectile-style parabola. 
	var t := _cast_progress
	var position_on_line := origin.lerp(landing, t)
	var arc_offset := -4.0 * _cast_arc_height * t * (1.0 - t)
	position_on_line.y += arc_offset
	lasso_head.position = position_on_line

	if _cast_progress >= 1.0:
		state = State.EXTENDED
		_extended_elapsed = 0.0


func _update_extended(delta: float) -> void:
	_extended_elapsed += delta

	if _extended_elapsed >= fully_extended_time:
		state = State.RETRACTING




func _update_latched() -> void:
	if not is_instance_valid(_latched_target):
		release_latch()
		return

	## Follow the point on the horse where the loop originally touched it.
	## Using global coordinates here lets this work even though LassoSystem is
	## parented under the moving player horse.
	lasso_head.global_position = _latched_target.to_global(
		_latched_target_local_point
	)


func _latch_to_target(target: Node2D) -> void:
	if target == null or lasso_head == null:
		return

	_latched_target = target
	_latched_target_local_point = target.to_local(lasso_head.global_position)
	state = State.LATCHED

	## The catch game can last for several seconds. Keep the loop and rope
	## visible for that entire time instead of allowing normal auto-retraction.
	lasso_head.visible = true
	if rope != null:
		rope.visible = true


func release_latch() -> void:
	if state != State.LATCHED:
		return

	_latched_target = null
	_latched_target_local_point = Vector2.ZERO

	## Once the catch game ends, let the rope visibly retract back to the player.
	state = State.RETRACTING


func cancel_and_retract() -> void:
	if power_meter != null:
		power_meter.cancel_meter()

	match state:
		State.IDLE:
			return
		State.AIMING_POWER:
			_finish_lasso()
		State.CASTING, State.EXTENDED, State.LATCHED:
			_latched_target = null
			_latched_target_local_point = Vector2.ZERO
			state = State.RETRACTING
		State.RETRACTING:
			pass


func set_enabled(enabled: bool) -> void:
	_input_enabled = enabled

	if not enabled:
		cancel_and_retract()


func is_latched() -> bool:
	return state == State.LATCHED and is_instance_valid(_latched_target)


func _update_retraction(delta: float) -> void:
	if lasso_head == null:
		_finish_lasso()
		return

	var origin := _get_rope_origin()
	lasso_head.position = lasso_head.position.move_toward(
		origin,
		retract_speed * delta
	)

	if lasso_head.position.distance_to(origin) <= 2.0:
		_finish_lasso()


func _finish_lasso() -> void:
	state = State.IDLE
	_cast_progress = 0.0
	_latched_target = null
	_latched_target_local_point = Vector2.ZERO
	_rope_points.clear()
	_rope_previous_points.clear()
	_current_rope_length = 0.0

	if lasso_head != null:
		lasso_head.position = _get_rope_origin()
		lasso_head.visible = false

	if rope != null:
		rope.clear_points()
		rope.visible = false

	lasso_returned.emit()


func _initialize_rope() -> void:
	_rope_points.clear()
	_rope_previous_points.clear()

	var origin := _get_rope_origin()
	var finish := lasso_head.position if lasso_head != null else origin

	for index in range(rope_segments + 1):
		var t := float(index) / float(rope_segments)
		var point := origin.lerp(finish, t)
		_rope_points.append(point)
		_rope_previous_points.append(point)

	_current_rope_length = maxf(origin.distance_to(finish), 1.0)
	_draw_rope()


func _update_rope_physics(delta: float) -> void:
	if rope == null or lasso_head == null:
		return

	if _rope_points.size() != rope_segments + 1:
		_initialize_rope()

	var start := _get_rope_origin()
	var finish := lasso_head.position
	var straight_distance := start.distance_to(finish)


	var desired_slack := extra_full_extension_slack * _get_extension_ratio()
	var desired_length := (
		straight_distance * rope_slack_multiplier
		+ desired_slack
	)
	_current_rope_length = maxf(desired_length, straight_distance + 0.5)

	# Verlet integration for all free rope points.
	var gravity_step := Vector2.DOWN * rope_gravity * delta * delta

	for index in range(1, _rope_points.size() - 1):
		var current := _rope_points[index]
		var previous := _rope_previous_points[index]
		var velocity_step := (current - previous) * rope_damping

		_rope_previous_points[index] = current
		_rope_points[index] = current + velocity_step + gravity_step

	# Keep both ends attached.
	_rope_points[0] = start
	_rope_points[_rope_points.size() - 1] = finish

	var segment_length := _current_rope_length / float(rope_segments)

	for _iteration in range(constraint_iterations):
		_rope_points[0] = start
		_rope_points[_rope_points.size() - 1] = finish

		for index in range(rope_segments):
			var first := _rope_points[index]
			var second := _rope_points[index + 1]
			var difference := second - first
			var distance := difference.length()

			if distance <= 0.0001:
				continue

			var correction := difference * ((distance - segment_length) / distance)

			if index == 0:
				# Hand end is fixed.
				_rope_points[index + 1] -= correction
			elif index + 1 == rope_segments:
				# Lasso-loop end is fixed.
				_rope_points[index] += correction
			else:
				_rope_points[index] += correction * 0.5
				_rope_points[index + 1] -= correction * 0.5

		_rope_points[0] = start
		_rope_points[_rope_points.size() - 1] = finish

	_draw_rope()


func _get_extension_ratio() -> float:
	if maximum_cast_distance <= 0.0 or lasso_head == null:
		return 0.0

	return clampf(
		_get_rope_origin().distance_to(lasso_head.position) / maximum_cast_distance,
		0.0,
		1.0
	)


func _draw_rope() -> void:
	if rope == null:
		return

	var points := PackedVector2Array()
	for point in _rope_points:
		points.append(point)
	rope.points = points


func _get_rope_origin() -> Vector2:
	if hand_anchor == null:
		return Vector2.ZERO

	return hand_anchor.position


func _check_for_catchable_overlap() -> void:
	if lasso_head == null or _catch_emitted_this_cast:
		return

	for body in lasso_head.get_overlapping_bodies():
		_try_emit_catchable(body)
		if _catch_emitted_this_cast:
			return

	for area in lasso_head.get_overlapping_areas():
		_try_emit_catchable(area)
		if _catch_emitted_this_cast:
			return


func _try_emit_catchable(target: Node) -> void:
	if _catch_emitted_this_cast:
		return

	if state != State.CASTING and state != State.EXTENDED:
		return

	if target != null and target.is_in_group(&"lasso_catchable"):
		_catch_emitted_this_cast = true

		if target is Node2D:
			_latch_to_target(target as Node2D)

		catchable_touched.emit(target)


func _on_lasso_head_body_entered(body: Node2D) -> void:
	_try_emit_catchable(body)


func _on_lasso_head_area_entered(area: Area2D) -> void:
	_try_emit_catchable(area)
