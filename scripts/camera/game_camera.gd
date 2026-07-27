class_name GameCamera
extends Camera2D
## Chase camera: leads ahead of the runner proportionally to speed, follows
## height softly, and layers trauma-based screen shake (decays as trauma²,
## so big hits feel violent and settle smoothly).

var target: Node2D = null
var _trauma := 0.0
var _shake_seed := 0.0
var _look_ahead := 0.0
var _y := 0.0

func _ready() -> void:
	make_current()
	position_smoothing_enabled = false   # we smooth by hand for full control

func snap_to(pos: Vector2) -> void:
	_look_ahead = 260.0
	_y = pos.y - 120.0
	global_position = Vector2(pos.x + _look_ahead, _y)
	reset_smoothing()

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var vel: Vector2 = target.velocity if target is CharacterBody2D else Vector2.ZERO
	# Look-ahead grows with speed: at full sprint you see much more runway.
	var want_ahead := clampf(vel.x * 0.55, 200.0, 460.0)
	_look_ahead = lerpf(_look_ahead, want_ahead, 1.0 - exp(-3.0 * delta))
	# Vertical: soft follow, biased upward so ground stays low in frame.
	var want_y := target.global_position.y - 120.0
	var y_speed := 4.0 if vel.y > 400.0 else 2.2   # track falls faster
	_y = lerpf(_y, want_y, 1.0 - exp(-y_speed * delta))
	var base := Vector2(target.global_position.x + _look_ahead, _y)
	# Shake: smooth noise offsets + a touch of roll, scaled by trauma².
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
		_shake_seed += delta * 30.0
		var s := _trauma * _trauma
		base += Vector2(
			sin(_shake_seed * 1.1) * 18.0 * s,
			cos(_shake_seed * 1.7) * 14.0 * s)
		rotation = sin(_shake_seed * 0.9) * 0.02 * s
	else:
		rotation = 0.0
	global_position = base
