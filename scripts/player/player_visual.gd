class_name PlayerVisual
extends Node2D
## The shadow man himself. Two rendering modes:
##  1. PROCEDURAL (default, zero assets): a parametric 11-joint skeleton posed
##     per state and drawn as a smooth black silhouette with a warm rim-light
##     pass and motion-trail ghosts. Looks like an animated shadow out of the box.
##  2. SPRITESHEET: drop Mixamo-rendered silhouette sheets into res://art/player/
##     named  <anim>_<frames>.png  (e.g. run_12.png, jump_8.png, slide_6.png,
##     roll_10.png, wallrun_8.png, hang_4.png, climb_8.png, fall_6.png,
##     death_10.png) and they are auto-detected and used instead.

# Mirrors Player.S — kept local to avoid a cyclic preload between the scripts.
enum S { RUN, JUMP, DOUBLE_JUMP, FALL, SLIDE, ROLL, VAULT, WALL_RUN, LEDGE_GRAB, CLIMB, DEAD }

const BODY_COLOR := Color(0.02, 0.02, 0.035)
const LIMB_W := 9.0
const TORSO_W := 13.0
const TRAIL_LEN := 7

var rim_color := Color(1.0, 0.62, 0.3, 0.35)   # set by theme
var _phase := 0.0
var _pose: Dictionary = {}
var _trail: Array = []          # ring buffer of [pose, global_pos]
var _trail_tick := 0
var _dying := false
var _death_t := 0.0
var _sprite: AnimatedSprite2D = null
var _sheet_map := {}            # state int -> anim name

func _ready() -> void:
	_try_load_spritesheets()
	set_process(false)   # normally driven by Player via update_visual()

func _process(delta: float) -> void:
	# Only runs during the death dissolve, which must animate after the
	# Player script has stopped updating us.
	if _dying:
		_death_t += delta
		queue_redraw()

func reset() -> void:
	_dying = false
	_death_t = 0.0
	_trail.clear()
	modulate = Color.WHITE
	set_process(false)
	# Show a neutral running pose immediately (e.g. behind the main menu).
	_pose = _compute_pose(S.RUN, Vector2.ZERO)
	queue_redraw()
	if _sprite:
		_sprite.visible = true

func update_visual(state: int, vel: Vector2, delta: float) -> void:
	if _dying:
		_death_t += delta
		queue_redraw()
		return
	_phase += absf(vel.x) * delta * 0.028
	_pose = _compute_pose(state, vel)
	# Motion trail ghosts only at speed, only on HIGH+ quality.
	if SettingsManager.trails_enabled() and absf(vel.x) > 520.0:
		_trail_tick += 1
		if _trail_tick % 3 == 0:
			_trail.push_front([_pose.duplicate(), global_position])
			if _trail.size() > TRAIL_LEN:
				_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	if _sprite:
		_sprite.play(_sheet_map.get(state, "run"))
	queue_redraw()

func play_death() -> void:
	_dying = true
	_death_t = 0.0
	set_process(true)   # self-animate the dissolve; Player stops driving us now
	if _sprite and _sheet_map.has(S.DEAD):
		_sprite.play(_sheet_map[S.DEAD])
	var burst := CPUParticles2D.new()
	burst.amount = int(40 * SettingsManager.particles_scale())
	burst.one_shot = true
	burst.emitting = true
	burst.lifetime = 0.9
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 420.0
	burst.gravity = Vector2(0, 500)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = Color(0.05, 0.05, 0.09)
	burst.position = Vector2(0, -40)
	add_child(burst)
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)

# ------------------------------------------------------------------- drawing

func _draw() -> void:
	if _sprite:
		return   # spritesheet mode: AnimatedSprite2D child renders instead
	if _pose.is_empty():
		return
	# Trail ghosts (oldest faintest), drawn in our local space.
	for i in range(_trail.size() - 1, -1, -1):
		var alpha := 0.05 + 0.05 * float(TRAIL_LEN - i) / TRAIL_LEN
		var offset: Vector2 = _trail[i][1] - global_position
		_draw_figure(_trail[i][0], offset, Color(0.1, 0.15, 0.3, alpha))
	# Death dissolve: figure breaks upward and fades.
	var col := BODY_COLOR
	if _dying:
		var t := clampf(_death_t / 0.8, 0.0, 1.0)
		col.a = 1.0 - t
		_draw_figure(_pose, Vector2(0, -t * 30.0), col)
		return
	# Rim-light pass: same figure nudged toward the light, drawn underneath.
	var rim_pose := {}
	for k in _pose:
		rim_pose[k] = _pose[k] + Vector2(2.5, -2.5)
	_draw_figure(rim_pose, Vector2.ZERO, rim_color)
	_draw_figure(_pose, Vector2.ZERO, col)

func _draw_figure(p: Dictionary, offset: Vector2, col: Color) -> void:
	var seg := func(a: String, b: String, w: float) -> void:
		draw_line(p[a] + offset, p[b] + offset, col, w, true)
		draw_circle(p[a] + offset, w * 0.5, col)
		draw_circle(p[b] + offset, w * 0.5, col)
	seg.call("hip", "neck", TORSO_W)
	seg.call("hip", "knee_b", LIMB_W)
	seg.call("knee_b", "foot_b", LIMB_W * 0.85)
	seg.call("hip", "knee_f", LIMB_W)
	seg.call("knee_f", "foot_f", LIMB_W * 0.85)
	seg.call("neck", "elbow_b", LIMB_W * 0.85)
	seg.call("elbow_b", "hand_b", LIMB_W * 0.7)
	seg.call("neck", "elbow_f", LIMB_W * 0.85)
	seg.call("elbow_f", "hand_f", LIMB_W * 0.7)
	draw_circle(p["head"] + offset, 11.0, col)

# ------------------------------------------------------------ pose synthesis
## Everything below turns (state, velocity, run phase) into 11 joint positions.
## Origin = feet on the ground. -Y is up. The figure runs to the right.

func _compute_pose(state: int, vel: Vector2) -> Dictionary:
	match state:
		S.RUN: return _pose_run()
		S.JUMP, S.DOUBLE_JUMP: return _pose_jump(vel)
		S.FALL: return _pose_fall(vel)
		S.SLIDE: return _pose_slide()
		S.ROLL: return _pose_roll()
		S.VAULT: return _pose_vault()
		S.WALL_RUN: return _pose_wallrun()
		S.LEDGE_GRAB: return _pose_hang()
		S.CLIMB: return _pose_vault()
		_: return _pose_run()

func _limb(origin: Vector2, upper_ang: float, upper_len: float,
		lower_ang: float, lower_len: float) -> Array:
	var mid := origin + Vector2(cos(upper_ang), sin(upper_ang)) * upper_len
	var end := mid + Vector2(cos(lower_ang), sin(lower_ang)) * lower_len
	return [mid, end]

func _base(hip: Vector2, lean: float) -> Dictionary:
	var neck := hip + Vector2(sin(lean) * 34.0, -34.0)
	return {"hip": hip, "neck": neck, "head": neck + Vector2(sin(lean) * 12.0 + 4.0, -13.0)}

func _pose_run() -> Dictionary:
	var s := sin(_phase)
	var c := sin(_phase + PI)
	var hip := Vector2(0, -52.0 + absf(s) * 3.0)
	var p := _base(hip, 0.35)
	# Legs: thigh swings ±50°, shin trails with knee bend biased by cycle half.
	var fa := PI / 2.0 + s * 0.9
	var fl := _limb(hip, fa, 26.0, fa + 0.5 + maxf(-s, 0.0) * 1.3, 26.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var ba := PI / 2.0 + c * 0.9
	var bl := _limb(hip, ba, 26.0, ba + 0.5 + maxf(-c, 0.0) * 1.3, 26.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	# Arms pump opposite to legs, elbows bent.
	var af := PI / 2.0 + c * 0.8
	var afl := _limb(p["neck"], af, 20.0, af - 1.2, 18.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var ab := PI / 2.0 + s * 0.8
	var abl := _limb(p["neck"], ab, 20.0, ab - 1.2, 18.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_jump(vel: Vector2) -> Dictionary:
	var rise := clampf(-vel.y / 1000.0, 0.0, 1.0)
	var hip := Vector2(0, -54.0)
	var p := _base(hip, 0.25)
	var fl := _limb(hip, PI * 0.62 - rise * 0.5, 26.0, PI * 0.95, 24.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, PI * 0.42, 26.0, PI * 0.30, 24.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], -PI * 0.25, 20.0, -PI * 0.1, 18.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], PI * 0.85, 20.0, PI * 0.6, 18.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_fall(vel: Vector2) -> Dictionary:
	var drop := clampf(vel.y / 1400.0, 0.0, 1.0)
	var hip := Vector2(0, -52.0)
	var p := _base(hip, 0.15 - drop * 0.2)
	var fl := _limb(hip, PI * 0.55, 26.0, PI * 0.75 + drop * 0.3, 24.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, PI * 0.4, 26.0, PI * 0.5, 24.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], -PI * 0.45, 20.0, -PI * 0.7, 18.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], -PI * 0.75, 20.0, -PI * 0.95, 18.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_slide() -> Dictionary:
	var hip := Vector2(-6, -20.0)
	var neck := hip + Vector2(30.0, -12.0)
	var p := {"hip": hip, "neck": neck, "head": neck + Vector2(12.0, -8.0)}
	var fl := _limb(hip, -0.15, 30.0, 0.15, 26.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, 0.9, 24.0, -0.2, 24.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(neck, 0.5, 18.0, 1.2, 16.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(neck, 2.6, 18.0, 2.2, 16.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_roll() -> Dictionary:
	# Tucked ball, spun by the run phase for a tumbling read.
	var ang := _phase * 2.0
	var c := Vector2(0, -24.0)
	var p := {}
	p["hip"] = c + Vector2(cos(ang), sin(ang)) * 12.0
	p["neck"] = c + Vector2(cos(ang + PI), sin(ang + PI)) * 12.0
	p["head"] = p["neck"] + (p["neck"] - c).normalized() * 10.0
	var fl := _limb(p["hip"], ang + 2.2, 16.0, ang + 3.6, 14.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(p["hip"], ang + 2.6, 16.0, ang + 4.0, 14.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], ang - 0.6, 14.0, ang + 0.6, 12.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], ang - 1.0, 14.0, ang + 0.2, 12.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_vault() -> Dictionary:
	# Legs swept sideways over the obstacle, one arm planted down.
	var hip := Vector2(0, -46.0)
	var p := _base(hip, 0.55)
	var fl := _limb(hip, 0.2, 28.0, -0.3, 24.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, 0.7, 26.0, 0.3, 22.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], PI * 0.45, 22.0, PI * 0.5, 20.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], -PI * 0.3, 20.0, -PI * 0.15, 18.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_wallrun() -> Dictionary:
	# Body vertical against the wall, legs driving upward.
	var s := sin(_phase * 1.6)
	var hip := Vector2(6, -50.0)
	var neck := hip + Vector2(-16.0, -30.0)
	var p := {"hip": hip, "neck": neck, "head": neck + Vector2(-6.0, -13.0)}
	var fl := _limb(hip, 0.3 + s * 0.4, 26.0, 1.4 + s * 0.4, 24.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, 0.3 - s * 0.4, 26.0, 1.4 - s * 0.4, 24.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(neck, -0.4, 20.0, 0.4, 18.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(neck, 2.8, 18.0, 2.4, 16.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_hang() -> Dictionary:
	# Hanging from the ledge by both hands, legs dangling.
	var sway := sin(_phase * 0.7) * 0.1
	var neck := Vector2(8, -74.0)
	var hip := neck + Vector2(sin(sway) * 10.0 - 4.0, 36.0)
	var p := {"hip": hip, "neck": neck, "head": neck + Vector2(2.0, -12.0)}
	var fl := _limb(hip, PI * 0.55 + sway, 24.0, PI * 0.65, 22.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, PI * 0.45 - sway, 24.0, PI * 0.4, 22.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var up := Vector2(20, -108.0) - neck
	p["elbow_f"] = neck + up * 0.5 + Vector2(4, 0)
	p["hand_f"] = neck + up + Vector2(6, 0)
	p["elbow_b"] = neck + up * 0.5 - Vector2(6, 0)
	p["hand_b"] = neck + up - Vector2(4, 0)
	return p

# ------------------------------------------------------- spritesheet support

func _try_load_spritesheets() -> void:
	var dir := DirAccess.open("res://art/player")
	if dir == null:
		return
	var anim_for_state := {
		"run": S.RUN, "jump": S.JUMP, "doublejump": S.DOUBLE_JUMP,
		"fall": S.FALL, "slide": S.SLIDE, "roll": S.ROLL, "vault": S.VAULT,
		"wallrun": S.WALL_RUN, "hang": S.LEDGE_GRAB, "climb": S.CLIMB,
		"death": S.DEAD,
	}
	var frames := SpriteFrames.new()
	var found := false
	for f in dir.get_files():
		if not f.ends_with(".png"):
			continue
		var stem := f.get_basename()          # e.g. "run_12"
		var parts := stem.rsplit("_", true, 1)
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		var anim: String = parts[0]
		var count := int(parts[1])
		if not anim_for_state.has(anim) or count < 1:
			continue
		var tex: Texture2D = load("res://art/player/" + f)
		if tex == null:
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 24.0)
		frames.set_animation_loop(anim, anim in ["run", "wallrun", "hang", "slide"])
		var fw := tex.get_width() / count
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, tex.get_height())
			frames.add_frame(anim, at)
		found = true
	if not found:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(0, -52)
	add_child(_sprite)
	_sheet_map.clear()
	for anim in anim_for_state:
		if frames.has_animation(anim):
			_sheet_map[anim_for_state[anim]] = anim
