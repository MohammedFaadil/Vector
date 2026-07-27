class_name Player
extends CharacterBody2D
## The shadow runner. Auto-runs right; the player triggers parkour actions.
## Full state machine: RUN, JUMP, DOUBLE_JUMP, FALL, SLIDE, ROLL, VAULT,
## WALL_RUN, LEDGE_GRAB, CLIMB, DEAD — with Vector-2-grade feel:
## coyote time, jump buffering, variable jump height, fast-fall,
## momentum preservation, landing rolls, and auto-parkour detection
## that rewards well-timed manual input with a speed boost.

signal landed(impact_speed: float)
signal did_move(move_name: String, perfect: bool)
signal died

enum S { RUN, JUMP, DOUBLE_JUMP, FALL, SLIDE, ROLL, VAULT, WALL_RUN, LEDGE_GRAB, CLIMB, DEAD }

# ---- Tuning (the "feel" numbers — all in pixels / seconds) ----
const GRAVITY := 2600.0
const FALL_GRAVITY_MULT := 1.25        # heavier on the way down = weighty arc
const FAST_FALL_MULT := 2.1            # holding slide in air slams you down
const MAX_FALL_SPEED := 1700.0
const JUMP_VELOCITY := -1000.0
const DOUBLE_JUMP_VELOCITY := -860.0
const JUMP_CUT_MULT := 0.42            # releasing jump early cuts the arc
const WALL_JUMP_VELOCITY := Vector2(140.0, -1020.0)
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.15
const BASE_RUN_SPEED := 430.0
const MAX_RUN_SPEED := 800.0           # reached at full difficulty
const AIR_ACCEL := 900.0
const GROUND_ACCEL := 2400.0
const SLIDE_FRICTION := 140.0
const ROLL_DURATION := 0.38
const ROLL_SPEED_BONUS := 90.0
const VAULT_DURATION := 0.26
const HARD_LANDING_SPEED := 1050.0     # faster than this → must roll or stumble
const STUMBLE_SPEED_LOSS := 0.45
const WALL_RUN_START_SPEED := -780.0   # upward velocity when latching a wall
const WALL_RUN_DECAY := 1900.0
const CLIMB_DURATION := 0.32
const PERFECT_WINDOW := 0.18           # tap within this of an auto-move = perfect
const PERFECT_BOOST := 70.0
const KILL_Y := 1400.0

var state: int = S.RUN
var run_speed := BASE_RUN_SPEED
var _speed_bonus := 0.0                # decaying reward from perfect moves
var _coyote := 0.0
var _jump_buffer := 0.0
var _can_double_jump := true
var _state_timer := 0.0                # time left in timed states (roll/vault/climb)
var _fall_peak_speed := 0.0
var _perfect_timer := 0.0              # counts down after an auto-move fires
var _auto_move_pending := ""
var _ledge_point := Vector2.ZERO
var _climb_from := Vector2.ZERO
var _wall_run_time := 0.0
var _wall_catch_used := false   # one mid-air wall latch per airtime
var _vault_duration := VAULT_DURATION
var _footstep_accum := 0.0

@onready var visual: PlayerVisual = $Visual
@onready var stand_shape: CollisionShape2D = $StandShape
@onready var low_shape: CollisionShape2D = $LowShape
@onready var vault_ray: RayCast2D = $VaultRay
@onready var wall_ray: RayCast2D = $WallRay
@onready var high_ray: RayCast2D = $HighRay
@onready var ledge_ray: RayCast2D = $LedgeRay

static func build() -> Player:
	## Constructs the whole player scene tree in code — no .tscn needed.
	var p := Player.new()
	p.name = "Player"
	p.collision_layer = 2
	p.collision_mask = 1 | 16          # world + walls
	p.floor_snap_length = 12.0

	var stand := CollisionShape2D.new()
	stand.name = "StandShape"
	var cap := CapsuleShape2D.new()
	cap.radius = 14.0
	cap.height = 68.0
	stand.shape = cap
	stand.position = Vector2(0, -34)   # capsule bottom exactly at the feet (y=0)
	p.add_child(stand)

	var low := CollisionShape2D.new()
	low.name = "LowShape"
	var lowcap := CapsuleShape2D.new()
	lowcap.radius = 13.0
	lowcap.height = 30.0
	low.shape = lowcap
	low.rotation = PI / 2.0
	low.position = Vector2(0, -13)   # rotated capsule bottom at the feet
	low.disabled = true
	p.add_child(low)

	var vis := PlayerVisual.new()
	vis.name = "Visual"
	p.add_child(vis)

	for cfg in [
		["VaultRay", Vector2(6, -22), Vector2(72, 0), 32],   # knee height, vaultable layer
		["WallRay", Vector2(6, -44), Vector2(46, 0), 1 | 16],
		["HighRay", Vector2(6, -86), Vector2(46, 0), 1 | 16],
		["LedgeRay", Vector2(48, -110), Vector2(0, 76), 1 | 16],
	]:
		var r := RayCast2D.new()
		r.name = cfg[0]
		r.position = cfg[1]
		r.target_position = cfg[2]
		r.collision_mask = cfg[3]
		r.enabled = true
		p.add_child(r)
	return p

func reset(spawn: Vector2) -> void:
	global_position = spawn
	velocity = Vector2.ZERO
	collision_mask = 1 | 16   # in case the last run ended mid-ledge-grab
	state = S.RUN
	run_speed = BASE_RUN_SPEED
	_speed_bonus = 0.0
	_can_double_jump = true
	_fall_peak_speed = 0.0    # stale impact speed would fake a hard landing
	_jump_buffer = 0.0
	_coyote = 0.0
	_wall_catch_used = false
	_set_low_profile(false)
	visual.reset()

func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	if GameManager.state != GameManager.State.PLAYING:
		return

	_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_perfect_timer = maxf(_perfect_timer - delta, 0.0)
	_speed_bonus = maxf(_speed_bonus - delta * 30.0, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
		_check_perfect_input()

	# Target speed ramps with difficulty plus perfect-move bonuses.
	var target_speed := lerpf(BASE_RUN_SPEED, MAX_RUN_SPEED, GameManager.difficulty()) + _speed_bonus

	match state:
		S.RUN: _state_run(delta, target_speed)
		S.JUMP, S.DOUBLE_JUMP, S.FALL: _state_air(delta, target_speed)
		S.SLIDE: _state_slide(delta, target_speed)
		S.ROLL: _state_roll(delta, target_speed)
		S.VAULT: _state_vault(delta, target_speed)
		S.WALL_RUN: _state_wall_run(delta)
		S.LEDGE_GRAB: _state_ledge_grab(delta)
		S.CLIMB: _state_climb(delta)

	move_and_slide()
	GameManager.update_distance(global_position.x / 100.0)
	visual.update_visual(state, velocity, delta)

	if global_position.y > KILL_Y:
		kill()

# ------------------------------------------------------------------ states

func _state_run(delta: float, target_speed: float) -> void:
	velocity.x = move_toward(velocity.x, target_speed, GROUND_ACCEL * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_coyote = COYOTE_TIME
	_can_double_jump = true
	_wall_catch_used = false   # grounded → mid-air wall latch is available again
	_footsteps(delta)

	# Auto-parkour lookahead: what is directly ahead of us?
	if vault_ray.is_colliding() and not wall_ray.is_colliding():
		_begin_vault()
		return
	if wall_ray.is_colliding():
		if not high_ray.is_colliding():
			_begin_climb_over()   # low wall — mantle it
			return
		_begin_wall_run()          # tall wall — run up it
		return

	if _jump_buffer > 0.0:
		_do_jump()
	elif Input.is_action_pressed("slide"):
		_enter_slide()
	elif not is_on_floor():
		_change_state(S.FALL)

func _state_air(delta: float, target_speed: float) -> void:
	var g := GRAVITY * (FALL_GRAVITY_MULT if velocity.y > 0.0 else 1.0)
	if Input.is_action_pressed("slide") and velocity.y > -100.0:
		g = GRAVITY * FAST_FALL_MULT   # fast-fall slam
	velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)
	velocity.x = move_toward(velocity.x, target_speed, AIR_ACCEL * delta)
	_fall_peak_speed = maxf(_fall_peak_speed, velocity.y)

	# Variable jump height: releasing jump early cuts upward momentum.
	if state == S.JUMP and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= JUMP_CUT_MULT
		_change_state(S.FALL)

	if velocity.y > 0.0 and state != S.FALL:
		_change_state(S.FALL)

	# Mid-air wall catch → wall-run. Once per airtime, or peeling off a wall
	# would re-latch every few frames and "elevator" the player out of any pit.
	if not _wall_catch_used and wall_ray.is_colliding() and high_ray.is_colliding() \
			and velocity.y > -200.0:
		_begin_wall_run()
		return
	# Ledge catch: wall at chest, clear above, floor found by the ledge probe.
	if wall_ray.is_colliding() and not high_ray.is_colliding() and ledge_ray.is_colliding() and velocity.y > 0.0:
		_begin_ledge_grab()
		return

	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_do_jump()
		elif _can_double_jump:
			_do_double_jump()

	if is_on_floor():
		_land()

func _state_slide(delta: float, target_speed: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	# Slides bleed a little speed but keep most momentum (heavy, greasy feel).
	velocity.x = move_toward(velocity.x, target_speed * 0.92, SLIDE_FRICTION * delta)
	if not is_on_floor():
		_set_low_profile(false)
		_change_state(S.FALL)
		return
	# A crate directly ahead while sliding would pin us against it — pop up
	# into a vault instead (unless something overhead forces us to stay low).
	if vault_ray.is_colliding() and not _ceiling_blocked():
		_set_low_profile(false)
		_begin_vault()
		return
	if _jump_buffer > 0.0:
		_set_low_profile(false)
		_do_jump()
		return
	if not Input.is_action_pressed("slide") and not _ceiling_blocked():
		_set_low_profile(false)
		_change_state(S.RUN)

func _state_roll(delta: float, target_speed: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	velocity.x = move_toward(velocity.x, target_speed + ROLL_SPEED_BONUS, GROUND_ACCEL * delta)
	_state_timer -= delta
	if _jump_buffer > 0.0 and _state_timer < ROLL_DURATION * 0.5:
		_set_low_profile(false)
		_do_jump()
		return
	if _state_timer <= 0.0:
		_set_low_profile(false)
		if Input.is_action_pressed("slide"):
			_enter_slide()
		else:
			_change_state(S.RUN)

func _state_vault(delta: float, target_speed: float) -> void:
	# A shaped hop that floats over the obstacle while keeping full momentum.
	# Peak rise ≈ 77 px — comfortably above the 52 px vault crates.
	velocity.x = move_toward(velocity.x, target_speed * 1.05, GROUND_ACCEL * delta)
	_state_timer -= delta
	var t := clampf(1.0 - (_state_timer / _vault_duration), 0.0, 1.0)
	velocity.y = lerpf(-760.0, 420.0, t)
	if _state_timer <= 0.0:
		_change_state(S.FALL if not is_on_floor() else S.RUN)

func _state_wall_run(delta: float) -> void:
	_wall_run_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 3200.0 * delta)
	velocity.y += WALL_RUN_DECAY * delta
	# Reached a grabbable top edge? Take it.
	if not high_ray.is_colliding() and ledge_ray.is_colliding():
		_begin_ledge_grab()
		return
	# Player tap → wall-jump kick with a big vertical boost. Re-arms the
	# air latch so skilled players can chain kicks up very tall walls.
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = WALL_JUMP_VELOCITY
		_can_double_jump = true
		_wall_catch_used = false
		_change_state(S.JUMP)
		AudioManager.play("jump", 0.0, 0.9)
		did_move.emit("wall_jump", _perfect_timer > 0.0)
		return
	# Out of upward momentum → peel off and fall.
	if velocity.y > 60.0 or not wall_ray.is_colliding():
		_change_state(S.FALL)

func _state_ledge_grab(delta: float) -> void:
	velocity = Vector2.ZERO
	global_position = global_position.lerp(_ledge_point + Vector2(-26, 46), 18.0 * delta)
	_state_timer -= delta
	# Auto-climb after a beat, instantly on jump tap (the reward for attention).
	if _jump_buffer > 0.0 or _state_timer <= 0.0:
		var perfect := _jump_buffer > 0.0
		_jump_buffer = 0.0
		if perfect:
			_award_perfect("climb")
		_climb_from = global_position
		_change_state(S.CLIMB)
		_state_timer = CLIMB_DURATION
		AudioManager.play("vault", -4.0)

func _state_climb(delta: float) -> void:
	_state_timer -= delta
	var t := clampf(1.0 - (_state_timer / CLIMB_DURATION), 0.0, 1.0)
	# Deterministic sweep from grab point up over the lip, with a small arc.
	var goal := _ledge_point + Vector2(30, -4)
	var eased := t * t * (3.0 - 2.0 * t)   # smoothstep
	global_position = _climb_from.lerp(goal, eased) + Vector2(0, -sin(t * PI) * 26.0)
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		global_position = goal
		collision_mask = 1 | 16   # re-enable world collision (off during grab)
		velocity.x = run_speed * 0.7
		_can_double_jump = true
		_fall_peak_speed = 0.0    # the climb rescued the fall — forget its speed
		_change_state(S.RUN)

# --------------------------------------------------------------- transitions

func _do_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	velocity.y = JUMP_VELOCITY
	_change_state(S.JUMP)
	AudioManager.play_varied("jump")
	did_move.emit("jump", false)

func _do_double_jump() -> void:
	_jump_buffer = 0.0
	_can_double_jump = false
	velocity.y = DOUBLE_JUMP_VELOCITY
	_change_state(S.DOUBLE_JUMP)
	AudioManager.play_varied("double_jump")
	did_move.emit("double_jump", false)

func _enter_slide() -> void:
	_set_low_profile(true)
	_change_state(S.SLIDE)
	AudioManager.play("slide", -6.0)
	did_move.emit("slide", false)

func _land() -> void:
	var impact := _fall_peak_speed
	_fall_peak_speed = 0.0
	landed.emit(impact)
	if impact > HARD_LANDING_SPEED:
		# Hard landing: rolling (slide held or tapped) keeps speed, otherwise stumble.
		if Input.is_action_pressed("slide") or _jump_buffer > 0.0:
			_begin_roll(true)
		else:
			velocity.x *= (1.0 - STUMBLE_SPEED_LOSS)
			AudioManager.play("land_hard")
			_begin_roll(false)
	else:
		AudioManager.play("land_soft", -6.0)
		if Input.is_action_pressed("slide"):
			_enter_slide()
		else:
			_change_state(S.RUN)

func _begin_roll(perfect: bool) -> void:
	_set_low_profile(true)
	_state_timer = ROLL_DURATION
	_change_state(S.ROLL)
	AudioManager.play("roll")
	if perfect:
		_award_perfect("roll")
	did_move.emit("roll", perfect)

func _begin_vault() -> void:
	_vault_duration = VAULT_DURATION
	_state_timer = _vault_duration
	_auto_move_pending = "vault"
	_perfect_timer = PERFECT_WINDOW
	_change_state(S.VAULT)
	AudioManager.play("vault")
	did_move.emit("vault", false)

func _begin_climb_over() -> void:
	# Mantling a low wall reuses the vault arc, stretched taller and longer.
	_vault_duration = VAULT_DURATION * 1.35
	_state_timer = _vault_duration
	_auto_move_pending = "mantle"
	_perfect_timer = PERFECT_WINDOW
	_change_state(S.VAULT)
	AudioManager.play("vault", -2.0, 0.85)
	did_move.emit("mantle", false)

func _begin_wall_run() -> void:
	velocity.y = WALL_RUN_START_SPEED
	velocity.x = 30.0
	_wall_run_time = 0.0
	_wall_catch_used = true
	_auto_move_pending = "wall_run"
	_perfect_timer = PERFECT_WINDOW
	_change_state(S.WALL_RUN)
	AudioManager.play("wall_run", -4.0)
	did_move.emit("wall_run", false)

func _begin_ledge_grab() -> void:
	_ledge_point = ledge_ray.get_collision_point()
	_state_timer = 0.28
	# Hang/climb is fully animated — drop world collision so the capsule can't
	# depenetrate against the wall face and jitter. Restored when CLIMB ends.
	collision_mask = 0
	_change_state(S.LEDGE_GRAB)
	AudioManager.play("ledge_grab")
	did_move.emit("ledge_grab", false)

func _check_perfect_input() -> void:
	# Tapping jump right as an auto-move fires = "perfect" — Vector 2's timing reward.
	if _perfect_timer > 0.0 and _auto_move_pending != "":
		_award_perfect(_auto_move_pending)
		_auto_move_pending = ""

func _award_perfect(move_name: String) -> void:
	_speed_bonus = minf(_speed_bonus + PERFECT_BOOST, PERFECT_BOOST * 2.5)
	AudioManager.play("whoosh", -4.0, 1.2)
	did_move.emit(move_name, true)

func stumble() -> void:
	## Called by obstacles you clip without the right move — costs speed, not life.
	if state == S.DEAD:
		return
	velocity.x *= (1.0 - STUMBLE_SPEED_LOSS)
	AudioManager.play("land_hard", -3.0, 0.8)

func kill() -> void:
	if state == S.DEAD:
		return
	state = S.DEAD
	velocity = Vector2.ZERO
	_set_low_profile(false)
	visual.play_death()
	died.emit()
	GameManager.on_player_death()

# ------------------------------------------------------------------ helpers

func _change_state(s: int) -> void:
	state = s

func _set_low_profile(low: bool) -> void:
	stand_shape.set_deferred("disabled", low)
	low_shape.set_deferred("disabled", not low)

func _ceiling_blocked() -> bool:
	# Can't stand up mid-slide if something is overhead.
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -20), global_position + Vector2(0, -84), 1)
	return space.intersect_ray(q).size() > 0

func _footsteps(delta: float) -> void:
	_footstep_accum += absf(velocity.x) * delta
	if _footstep_accum > 130.0:
		_footstep_accum = 0.0
		AudioManager.play_varied("footstep", -14.0)
