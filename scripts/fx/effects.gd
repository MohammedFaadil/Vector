class_name EffectsManager
extends Node
## The "juice" rig: WorldEnvironment glow (HDR 2D bloom), the post-FX screen
## shader (vignette/grain/aberration/color grade), run dust, speed lines,
## landing bursts, perfect-move sparks, storm rain, screen flashes, and
## camera trauma wiring.

var player: Player
var cam: GameCamera

var _env: WorldEnvironment
var _post: ColorRect
var _post_layer: CanvasLayer
var _dust: CPUParticles2D
var _rain: CPUParticles2D
var _speed_lines: CPUParticles2D
var _t := 0.0
var _grade_lift := Color(0.06, 0.02, 0.04)
var _grade_tint := Color(1.0, 0.92, 0.88)

## Builds a Gradient from parallel offset/color arrays (Gradient.set_color
## takes an int point INDEX — passing 0.5 as an "offset" truncates to 0).
static func _ramp(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

func setup(p_player: Player, p_cam: GameCamera, _world_root: Node2D) -> void:
	player = p_player
	cam = p_cam

	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = SettingsManager.glow_enabled()
	env.glow_intensity = 0.8
	env.glow_strength = 1.2
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.05   # only HDR-bright pixels bloom (lasers, coins, sun)
	# Bicubic glow upscale is no longer a per-Environment flag (removed in 4.2);
	# it lives in project settings as rendering/environment/glow/upscale_mode.
	_env.environment = env
	add_child(_env)

	_post_layer = CanvasLayer.new()
	_post_layer.layer = 90
	_post = ColorRect.new()
	_post.material = ShaderMaterial.new()
	_post.material.shader = load("res://shaders/post_fx.gdshader")
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.visible = SettingsManager.post_fx_enabled()
	_post_layer.add_child(_post)
	add_child(_post_layer)

	# Run dust: constant low-rate puffs at the feet while grounded.
	_dust = CPUParticles2D.new()
	_dust.amount = int(20 * SettingsManager.particles_scale()) + 4
	_dust.lifetime = 0.6
	_dust.direction = Vector2(-1, -0.3)
	_dust.spread = 30.0
	_dust.initial_velocity_min = 50.0
	_dust.initial_velocity_max = 140.0
	_dust.gravity = Vector2(0, -40)
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.5
	_dust.color = Color(0.7, 0.65, 0.62, 0.4)
	_dust.color_ramp = _ramp([0.0, 0.3, 1.0], [
		Color(0.8, 0.75, 0.7, 0.5), Color(0.6, 0.55, 0.5, 0.3), Color(0.4, 0.35, 0.3, 0.0)])
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 1.5))
	scale_curve.add_point(Vector2(1.0, 0.3))
	_dust.scale_amount_curve = scale_curve
	player.add_child(_dust)

	# Speed lines: horizontal streaks that appear at sprint velocity.
	_speed_lines = CPUParticles2D.new()
	_speed_lines.amount = maxi(int(30 * SettingsManager.particles_scale()), 6)
	_speed_lines.lifetime = 0.3
	_speed_lines.direction = Vector2(-1, 0)
	_speed_lines.spread = 5.0
	_speed_lines.initial_velocity_min = 800.0
	_speed_lines.initial_velocity_max = 1200.0
	_speed_lines.gravity = Vector2.ZERO
	_speed_lines.scale_amount_min = 0.5
	_speed_lines.scale_amount_max = 2.0
	_speed_lines.color = Color(1.0, 0.9, 0.7, 0.3)
	_speed_lines.emitting = false
	player.add_child(_speed_lines)

	# Storm rain: streaks falling in camera space, only visible in "storm".
	_rain = CPUParticles2D.new()
	_rain.amount = int(200 * SettingsManager.particles_scale())
	_rain.lifetime = 0.8
	_rain.preprocess = 0.8
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(1600, 30)
	_rain.position = Vector2(200, -800)
	_rain.direction = Vector2(-0.3, 1)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 1800.0
	_rain.initial_velocity_max = 2200.0
	_rain.gravity = Vector2.ZERO
	_rain.scale_amount_min = 0.5
	_rain.scale_amount_max = 1.5
	_rain.color = Color(0.65, 0.75, 0.95, 0.3)
	_rain.color_ramp = _ramp([0.0, 0.5, 1.0], [
		Color(0.7, 0.8, 1.0, 0.4), Color(0.6, 0.7, 0.9, 0.2), Color(0.5, 0.6, 0.8, 0.0)])
	_rain.emitting = false
	cam.add_child(_rain)

	player.landed.connect(_on_landed)
	player.did_move.connect(_on_move)
	player.died.connect(_on_died)
	GameManager.theme_changed.connect(_on_theme)
	SettingsManager.quality_changed.connect(_on_quality)
	_on_theme(GameManager.current_theme)

func _process(delta: float) -> void:
	_t += delta
	if _post.visible:
		var speed_warp := 0.0
		if is_instance_valid(player) and GameManager.state == GameManager.State.PLAYING:
			speed_warp = clampf((absf(player.velocity.x) - 450.0) / 400.0, 0.0, 1.0)
		var m := _post.material as ShaderMaterial
		m.set_shader_parameter("time_s", _t)
		m.set_shader_parameter("speed_warp", speed_warp)
		m.set_shader_parameter("grade_lift", Vector3(_grade_lift.r, _grade_lift.g, _grade_lift.b))
		m.set_shader_parameter("grade_tint", Vector3(_grade_tint.r, _grade_tint.g, _grade_tint.b))
		m.set_shader_parameter("exposure", 1.0 + speed_warp * 0.15)
		m.set_shader_parameter("contrast", 1.1 + speed_warp * 0.1)
		m.set_shader_parameter("saturation", 1.05 - speed_warp * 0.05)

	if is_instance_valid(player):
		_dust.emitting = GameManager.state == GameManager.State.PLAYING \
			and player.is_on_floor() and absf(player.velocity.x) > 180.0

		# Speed lines at high velocity, scaled to how fast we're actually going.
		var show_speed_lines := GameManager.state == GameManager.State.PLAYING \
			and absf(player.velocity.x) > 650.0
		_speed_lines.emitting = show_speed_lines
		if show_speed_lines:
			_speed_lines.position = Vector2(0, -30)
			_speed_lines.initial_velocity_min = absf(player.velocity.x) * 1.2
			_speed_lines.initial_velocity_max = absf(player.velocity.x) * 1.6

func _on_theme(theme_name: String) -> void:
	var t := LevelThemes.get_theme(theme_name)
	_grade_lift = t["grade_lift"]
	_grade_tint = t["world_tint"]
	_rain.emitting = t["rain"] > 0.5
	player.visual.rim_color = t["rim"]

	# Dust picks up the mood of each theme.
	if theme_name == "storm":
		_dust.color = Color(0.6, 0.65, 0.75, 0.35)
		_dust.color_ramp = _ramp([0.0, 0.3, 1.0], [
			Color(0.7, 0.75, 0.9, 0.4), Color(0.55, 0.6, 0.75, 0.25), Color(0.4, 0.45, 0.6, 0.0)])
	elif theme_name == "neon":
		_dust.color = Color(0.4, 0.3, 0.5, 0.35)
		_dust.color_ramp = _ramp([0.0, 0.3, 1.0], [
			Color(0.6, 0.4, 0.8, 0.4), Color(0.45, 0.3, 0.65, 0.25), Color(0.3, 0.2, 0.5, 0.0)])
	else:   # dusk
		_dust.color = Color(0.7, 0.65, 0.62, 0.4)
		_dust.color_ramp = _ramp([0.0, 0.3, 1.0], [
			Color(0.8, 0.75, 0.7, 0.5), Color(0.6, 0.55, 0.5, 0.3), Color(0.4, 0.35, 0.3, 0.0)])

func _on_quality(_q: int) -> void:
	_env.environment.glow_enabled = SettingsManager.glow_enabled()
	_post.visible = SettingsManager.post_fx_enabled()
	_dust.amount = int(20 * SettingsManager.particles_scale()) + 4
	_rain.amount = maxi(int(200 * SettingsManager.particles_scale()), 10)
	_speed_lines.amount = maxi(int(30 * SettingsManager.particles_scale()), 6)

func _on_landed(impact: float) -> void:
	if impact > 400.0:
		_burst(player.global_position, Color(0.7, 0.65, 0.6, 0.6),
			int(clampf(impact / 70.0, 8.0, 30.0)), 200.0, true)
		player.visual.trigger_impact_flash()
	if impact > player.HARD_LANDING_SPEED:
		cam.add_trauma(0.6)
		_screen_flash(Color(1.0, 0.3, 0.1, 0.3), 0.15)
	elif impact > 700.0:
		cam.add_trauma(0.3)
		_screen_flash(Color(1.0, 0.5, 0.2, 0.2), 0.1)

func _on_move(move_name: String, perfect: bool) -> void:
	if perfect:
		_burst(player.global_position + Vector2(0, -40),
			Color(1.0, 0.95, 0.3, 1.0), 24, 320.0, false)
		_burst(player.global_position + Vector2(0, -40),
			Color(1.0, 0.7, 0.1, 0.8), 12, 180.0, true)
		cam.add_trauma(0.15)
		player.visual.trigger_perfect_flash()
		_screen_flash(Color(1.0, 0.9, 0.4, 0.4), 0.08)
	elif move_name == "wall_jump":
		_burst(player.global_position + Vector2(20, -40),
			Color(0.7, 0.85, 1.0, 0.8), 14, 240.0, false)
		cam.add_trauma(0.1)
	elif move_name == "vault" or move_name == "mantle":
		_burst(player.global_position + Vector2(0, -30),
			Color(0.8, 0.9, 1.0, 0.6), 10, 160.0, false)
	elif move_name == "roll":
		_burst(player.global_position + Vector2(0, -10),
			Color(0.6, 0.55, 0.5, 0.7), 12, 140.0, true)

func _on_died() -> void:
	cam.add_trauma(1.0)
	_screen_flash(Color(1.0, 0.1, 0.05, 0.6), 0.3)

func _burst(pos: Vector2, color: Color, amount: int, speed: float, gravity_affected: bool) -> void:
	var b := CPUParticles2D.new()
	b.amount = maxi(int(amount * SettingsManager.particles_scale()), 4)
	b.one_shot = true
	b.emitting = true
	b.lifetime = 0.6
	b.explosiveness = 1.0
	b.direction = Vector2(0, -1)
	b.spread = 80.0
	b.initial_velocity_min = speed * 0.3
	b.initial_velocity_max = speed
	b.gravity = Vector2(0, 800.0 if gravity_affected else 200.0)
	b.scale_amount_min = 2.0
	b.scale_amount_max = 4.0
	b.color = color
	b.color_ramp = _ramp([0.0, 0.5, 1.0], [
		color,
		Color(color.r, color.g, color.b, color.a * 0.5),
		Color(color.r, color.g, color.b, 0.0)])
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1.0, 0.2))
	b.scale_amount_curve = sc
	b.global_position = pos
	player.get_parent().add_child(b)
	get_tree().create_timer(1.0).timeout.connect(b.queue_free)

func _screen_flash(color: Color, duration: float) -> void:
	# ColorRect is not a CanvasLayer — it has no "layer" property, so the
	# flash gets its own top layer and the whole thing is freed together.
	var layer := CanvasLayer.new()
	layer.layer = 100
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, duration)
	tw.tween_callback(layer.queue_free)
