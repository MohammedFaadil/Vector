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

const BODY_COLOR := Color(0.015, 0.015, 0.025)
const LIMB_W := 9.0
const TORSO_W := 13.0
const TRAIL_LEN := 12

var rim_color := Color(1.0, 0.62, 0.3, 0.35)   # set by theme
var _phase := 0.0
var _pose: Dictionary = {}
var _trail: Array = []          # ring buffer of [pose, global_pos, velocity]
var _trail_tick := 0
var _dying := false
var _death_t := 0.0
var _sprite: AnimatedSprite2D = null
var _sheet_map := {}            # state int -> anim name
var _last_state := S.RUN
var _state_transition_t := 0.0
var _prev_pose: Dictionary = {}
var _breathing_phase := 0.0
var _impact_flash := 0.0
var _perfect_flash := 0.0

func _ready() -> void:
	_try_load_spritesheets()
	set_process(false)   # normally driven by Player via update_visual()

func _process(delta: float) -> void:
	# Only runs during the death dissolve, which must animate after the
	# Player script has stopped updating us.
	if _dying:
		_death_t += delta
		queue_redraw()
	
	# Update breathing animation
	_breathing_phase += delta * 2.0
	
	# Decay flashes
	_impact_flash = max(_impact_flash - delta * 5.0, 0.0)
	_perfect_flash = max(_perfect_flash - delta * 8.0, 0.0)

func reset() -> void:
	_dying = false
	_death_t = 0.0
	_trail.clear()
	modulate = Color.WHITE
	set_process(false)
	# Show a neutral running pose immediately (e.g. behind the main menu).
	_pose = _compute_pose(S.RUN, Vector2.ZERO)
	_prev_pose = _pose.duplicate()
	queue_redraw()
	if _sprite:
		_sprite.visible = true

func update_visual(state: int, vel: Vector2, delta: float) -> void:
	if _dying:
		_death_t += delta
		queue_redraw()
		return
	
	# Smooth state transitions
	if state != _last_state:
		_state_transition_t = 0.15
		_prev_pose = _pose.duplicate()
		_last_state = state
	
	if _state_transition_t > 0.0:
		_state_transition_t = max(_state_transition_t - delta, 0.0)
	
	_phase += absf(vel.x) * delta * 0.028
	_pose = _compute_pose(state, vel)
	
	# Interpolate between poses during state transitions
	if _state_transition_t > 0.0 and not _prev_pose.is_empty():
		var t := 1.0 - _state_transition_t / 0.15
		t = t * t * (3.0 - 2.0 * t)  # smoothstep
		for k in _pose:
			if _prev_pose.has(k):
				_pose[k] = _prev_pose[k].lerp(_pose[k], t)
	
	# Motion trail ghosts only at speed, only on HIGH+ quality.
	if SettingsManager.trails_enabled() and absf(vel.x) > 480.0:
		_trail_tick += 1
		if _trail_tick % 2 == 0:  # More frequent trails
			_trail.push_front([_pose.duplicate(), global_position, vel])
			if _trail.size() > TRAIL_LEN:
				_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()
	
	if _sprite:
		_sprite.play(_sheet_map.get(state, "run"))
	queue_redraw()

func trigger_impact_flash() -> void:
	_impact_flash = 1.0

func trigger_perfect_flash() -> void:
	_perfect_flash = 1.0

func play_death() -> void:
	_dying = true
	_death_t = 0.0
	set_process(true)   # self-animate the dissolve; Player stops driving us now
	if _sprite and _sheet_map.has(S.DEAD):
		_sprite.play(_sheet_map[S.DEAD])
	var burst := CPUParticles2D.new()
	burst.amount = int(60 * SettingsManager.particles_scale())
	burst.one_shot = true
	burst.emitting = true
	burst.lifetime = 1.2
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 500.0
	burst.gravity = Vector2(0, 600)
	burst.scale_amount_min = 2.5
	burst.scale_amount_max = 6.0
	burst.color = Color(0.05, 0.05, 0.09)
	burst.position = Vector2(0, -40)
	add_child(burst)
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)

# ------------------------------------------------------------------- drawing

func _draw() -> void:
	if _sprite:
		return   # spritesheet mode: AnimatedSprite2D child renders instead
	if _pose.is_empty():
		return
	
	# Trail ghosts (oldest faintest), drawn in our local space.
	for i in range(_trail.size() - 1, -1, -1):
		var alpha := 0.03 + 0.08 * float(TRAIL_LEN - i) / TRAIL_LEN
		var offset: Vector2 = _trail[i][1] - global_position
		# Fade based on velocity difference
		var vel_diff := (_trail[i][2] - (get_parent() as Node2D).velocity).length() / 500.0
		alpha *= (1.0 - vel_diff * 0.5)
		_draw_figure(_trail[i][0], offset, Color(0.08, 0.12, 0.25, alpha))
	
	# Death dissolve: figure breaks upward and fades.
	var col := BODY_COLOR
	if _dying:
		var t := clampf(_death_t / 1.0, 0.0, 1.0)
		col.a = 1.0 - t
		# Disintegration effect - particles breaking off
		for j in range(8):
			var ang := j * TAU / 8.0 + _death_t * 3.0
			var dist := t * 80.0
			var pcol := Color(col, col.a * (1.0 - t * 0.5))
			_draw_figure(_pose, Vector2(cos(ang), sin(ang)) * dist + Vector2(0, -t * 40.0), pcol)
		_draw_figure(_pose, Vector2(0, -t * 30.0), col)
		return
	
	# Perfect flash overlay
	if _perfect_flash > 0.0:
		var pf_col := Color(1.0, 0.95, 0.4, _perfect_flash * 0.6)
		_draw_figure(_pose, Vector2.ZERO, pf_col)
	
	# Impact flash overlay
	if _impact_flash > 0.0:
		var if_col := Color(1.0, 0.5, 0.2, _impact_flash * 0.4)
		_draw_figure(_pose, Vector2.ZERO, if_col)
	
	# Rim-light pass: same figure nudged toward the light, drawn underneath.
	var rim_pose := {}
	for k in _pose:
		rim_pose[k] = _pose[k] + Vector2(3.0, -3.0)
	_draw_figure(rim_pose, Vector2.ZERO, rim_color)
	
	# Subtle secondary rim for depth
	var rim_pose2 := {}
	for k in _pose:
		rim_pose2[k] = _pose[k] + Vector2(1.5, -1.5)
	_draw_figure(rim_pose2, Vector2.ZERO, Color(rim_color.r * 0.8, rim_color.g * 0.8, rim_color.b * 0.8, rim_color.a * 0.5))
	
	# Main figure
	_draw_figure(_pose, Vector2.ZERO, col)
	
	# Breathing motion - subtle chest expansion
	if _last_state == S.RUN or _last_state == S.SLIDE:
		var breath := sin(_breathing_phase) * 0.5
		var chest_pos := _pose["neck"] + Vector2(0, -8.0 + breath)
		draw_circle(chest_pos, 8.0 + breath, Color(col, 0.1))

func _draw_figure(p: Dictionary, offset: Vector2, col: Color) -> void:
	var seg := func(a: String, b: String, w: float) -> void:
		var pa := p[a] + offset
		var pb := p[b] + offset
		draw_line(pa, pb, col, w, true)
		draw_circle(pa, w * 0.5, col)
		draw_circle(pb, w * 0.5, col)
	
	# Torso
	seg.call("hip", "neck", TORSO_W)
	
	# Legs
	seg.call("hip", "knee_b", LIMB_W)
	seg.call("knee_b", "foot_b", LIMB_W * 0.85)
	seg.call("hip", "knee_f", LIMB_W)
	seg.call("knee_f", "foot_f", LIMB_W * 0.85)
	
	# Arms
	seg.call("neck", "elbow_b", LIMB_W * 0.85)
	seg.call("elbow_b", "hand_b", LIMB_W * 0.7)
	seg.call("neck", "elbow_f", LIMB_W * 0.85)
	seg.call("elbow_f", "hand_f", LIMB_W * 0.7)
	
	# Head with subtle detail
	draw_circle(p["head"] + offset, 11.0, col)
	# Eye glint (subtle)
	if col.a > 0.5:
		draw_circle(p["head"] + offset + Vector2(4.0, -3.0), 1.5, Color(rim_color, 0.3))

# ------------------------------------------------------------ pose synthesis
## Everything below turns (state, velocity, run phase) into 11 joint positions.
## Origin = feet on the ground. -Y is up. The figure runs to the right.

func _compute_pose(state: int, vel: Vector2) -> Dictionary:
	match state:
		S.RUN: return _pose_run(vel)
		S.JUMP, S.DOUBLE_JUMP: return _pose_jump(vel)
		S.FALL: return _pose_fall(vel)
		S.SLIDE: return _pose_slide(vel)
		S.ROLL: return _pose_roll()
		S.VAULT: return _pose_vault()
		S.WALL_RUN: return _pose_wallrun()
		S.LEDGE_GRAB: return _pose_hang()
		S.CLIMB: return _pose_climb()
		_: return _pose_run(vel)

func _limb(origin: Vector2, upper_ang: float, upper_len: float,
		lower_ang: float, lower_len: float) -> Array:
	var mid := origin + Vector2(cos(upper_ang), sin(upper_ang)) * upper_len
	var end := mid + Vector2(cos(lower_ang), sin(lower_ang)) * lower_len
	return [mid, end]

func _base(hip: Vector2, lean: float) -> Dictionary:
	var neck := hip + Vector2(sin(lean) * 36.0, -36.0)
	return {"hip": hip, "neck": neck, "head": neck + Vector2(sin(lean) * 14.0 + 5.0, -15.0)}

func _pose_run(vel: Vector2) -> Dictionary:
	var s := sin(_phase)
	var c := sin(_phase + PI)
	var speed_factor := clampf(absf(vel.x) / 800.0, 0.5, 1.5)
	var hip := Vector2(0, -54.0 + absf(s) * 4.0 * speed_factor)
	var p := _base(hip, 0.35 + speed_factor * 0.1)
	
	# Legs: thigh swings ±55°, shin trails with knee bend biased by cycle half.
	var fa := PI / 2.0 + s * 1.0 * speed_factor
	var fl := _limb(hip, fa, 28.0, fa + 0.6 + maxf(-s, 0.0) * 1.4, 28.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var ba := PI / 2.0 + c * 1.0 * speed_factor
	var bl := _limb(hip, ba, 28.0, ba + 0.6 + maxf(-c, 0.0) * 1.4, 28.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	
	# Arms pump opposite to legs, elbows bent dynamically.
	var af := PI / 2.0 + c * 0.9 * speed_factor
	var afl := _limb(p["neck"], af, 22.0, af - 1.3, 20.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var ab := PI / 2.0 + s * 0.9 * speed_factor
	var abl := _limb(p["neck"], ab, 22.0, ab - 1.3, 20.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	
	# Head bob
	p["head"] += Vector2(0, absf(s) * 2.0 * speed_factor)
	return p

func _pose_jump(vel: Vector2) -> Dictionary:
	var rise := clampf(-vel.y / 1000.0, 0.0, 1.0)
	var hip := Vector2(0, -56.0)
	var p := _base(hip, 0.25 - rise * 0.1)
	var fl := _limb(hip, PI * 0.6 - rise * 0.6, 28.0, PI * 0.9, 26.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, PI * 0.4, 28.0, PI * 0.25, 26.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], -PI * 0.3, 22.0, -PI * 0.1, 20.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], PI * 0.9, 22.0, PI * 0.65, 20.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_fall(vel: Vector2) -> Dictionary:
	var drop := clampf(vel.y / 1400.0, 0.0, 1.0)
	var hip := Vector2(0, -54.0)
	var p := _base(hip, 0.1 - drop * 0.25)
	var fl := _limb(hip, PI * 0.5, 28.0, PI * 0.7 + drop * 0.4, 26.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, PI * 0.35, 28.0, PI * 0.45, 26.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], -PI * 0.5, 22.0, -PI * 0.8, 20.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], -PI * 0.8, 22.0, -PI * 1.0, 20.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_slide(vel: Vector2) -> Dictionary:
	var speed_factor := clampf(absf(vel.x) / 800.0, 0.5, 1.5)
	var hip := Vector2(-8 * speed_factor, -22.0)
	var neck := hip + Vector2(34.0 * speed_factor, -14.0)
	var p := {"hip": hip, "neck": neck, "head": neck + Vector2(14.0 * speed_factor, -10.0)}
	var fl := _limb(hip, -0.2, 32.0, 0.2, 28.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, 1.0, 26.0, -0.3, 26.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(neck, 0.6, 20.0, 1.3, 18.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(neck, 2.7, 20.0, 2.3, 18.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_roll() -> Dictionary:
	# Tucked ball, spun by the run phase for a tumbling read.
	var ang := _phase * 3.0
	var c := Vector2(0, -26.0)
	var p := {}
	p["hip"] = c + Vector2(cos(ang), sin(ang)) * 14.0
	p["neck"] = c + Vector2(cos(ang + PI), sin(ang + PI)) * 14.0
	p["head"] = p["neck"] + (p["neck"] - c).normalized() * 12.0
	var fl := _limb(p["hip"], ang + 2.3, 18.0, ang + 3.8, 16.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(p["hip"], ang + 2.7, 18.0, ang + 4.2, 16.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], ang - 0.7, 16.0, ang + 0.7, 14.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], ang - 1.1, 16.0, ang + 0.3, 14.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_vault() -> Dictionary:
	# Legs swept sideways over the obstacle, one arm planted down.
	var hip := Vector2(0, -48.0)
	var p := _base(hip, 0.6)
	var fl := _limb(hip, 0.3, 30.0, -0.2, 26.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, 0.8, 28.0, 0.4, 24.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(p["neck"], PI * 0.5, 24.0, PI * 0.55, 22.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(p["neck"], -PI * 0.35, 22.0, -PI * 0.2, 20.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_wallrun() -> Dictionary:
	# Body vertical against the wall, legs driving upward.
	var s := sin(_phase * 1.8)
	var hip := Vector2(8, -52.0)
	var neck := hip + Vector2(-18.0, -32.0)
	var p := {"hip": hip, "neck": neck, "head": neck + Vector2(-8.0, -14.0)}
	var fl := _limb(hip, 0.4 + s * 0.5, 28.0, 1.5 + s * 0.5, 26.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, 0.4 - s * 0.5, 28.0, 1.5 - s * 0.5, 26.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var afl := _limb(neck, -0.5, 22.0, 0.5, 20.0)
	p["elbow_f"] = afl[0]; p["hand_f"] = afl[1]
	var abl := _limb(neck, 2.9, 20.0, 2.5, 18.0)
	p["elbow_b"] = abl[0]; p["hand_b"] = abl[1]
	return p

func _pose_hang() -> Dictionary:
	# Hanging from the ledge by both hands, legs dangling.
	var sway := sin(_phase * 0.8) * 0.12
	var neck := Vector2(10, -78.0)
	var hip := neck + Vector2(sin(sway) * 12.0 - 5.0, 38.0)
	var p := {"hip": hip, "neck": neck, "head": neck + Vector2(3.0, -14.0)}
	var fl := _limb(hip, PI * 0.55 + sway, 26.0, PI * 0.65, 24.0)
	p["knee_f"] = fl[0]; p["foot_f"] = fl[1]
	var bl := _limb(hip, PI * 0.45 - sway, 26.0, PI * 0.4, 24.0)
	p["knee_b"] = bl[0]; p["foot_b"] = bl[1]
	var up := Vector2(22, -112.0) - neck
	p["elbow_f"] = neck + up * 0.5 + Vector2(5, 0)
	p["hand_f"] = neck + up + Vector2(7, 0)
	p["elbow_b"] = neck + up * 0.5 - Vector2(7, 0)
	p["hand_b"] = neck + up - Vector2(5, 0)
	return p

func _pose_climb() -> Dictionary:
	# Transition from hang to vault pose
	var t := sin(_phase * 2.0) * 0.5 + 0.5
	var hang := _pose_hang()
	var vault := _pose_vault()
	var p := {}
	for k in hang:
		p[k] = hang[k].lerp(vault[k], t)
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
	_sprite.position = Vector2(0, -54)
	add_child(_sprite)
	_sheet_map.clear()
	for anim in anim_for_state:
		if frames.has_animation(anim):
			_sheet_map[anim_for_state[anim]] = anim