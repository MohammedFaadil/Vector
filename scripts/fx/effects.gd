class_name EffectsManager
extends Node
## The "juice" rig: WorldEnvironment glow (HDR 2D bloom), the post-FX screen
## shader (vignette/grain/aberration/color grade), run dust, landing bursts,
## perfect-move sparks, storm rain, and camera trauma wiring.

var player: Player
var cam: GameCamera

var _env: WorldEnvironment
var _post: ColorRect
var _post_layer: CanvasLayer
var _dust: CPUParticles2D
var _rain: CPUParticles2D
var _t := 0.0
var _grade_lift := Color(0.06, 0.02, 0.04)
var _grade_tint := Color(1.0, 0.92, 0.88)

func setup(p_player: Player, p_cam: GameCamera, world_root: Node2D) -> void:
	player = p_player
	cam = p_cam

	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = SettingsManager.glow_enabled()
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.05   # only HDR-bright pixels bloom (lasers, coins, sun)
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
	_dust.amount = int(14 * SettingsManager.particles_scale()) + 2
	_dust.lifetime = 0.55
	_dust.direction = Vector2(-1, -0.3)
	_dust.spread = 25.0
	_dust.initial_velocity_min = 40.0
	_dust.initial_velocity_max = 110.0
	_dust.gravity = Vector2(0, -30)
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 3.5
	_dust.color = Color(0.75, 0.7, 0.68, 0.35)
	player.add_child(_dust)

	# Storm rain: streaks falling in camera space, only visible in "storm".
	_rain = CPUParticles2D.new()
	_rain.amount = int(140 * SettingsManager.particles_scale())
	_rain.lifetime = 0.7
	_rain.preprocess = 0.7
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(1400, 20)
	_rain.position = Vector2(200, -700)
	_rain.direction = Vector2(-0.25, 1)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 1500.0
	_rain.initial_velocity_max = 1900.0
	_rain.gravity = Vector2.ZERO
	_rain.scale_amount_min = 0.8
	_rain.scale_amount_max = 1.4
	_rain.color = Color(0.7, 0.8, 1.0, 0.25)
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
			speed_warp = clampf((absf(player.velocity.x) - 500.0) / 400.0, 0.0, 1.0)
		var m := _post.material as ShaderMaterial
		m.set_shader_parameter("time_s", _t)
		m.set_shader_parameter("speed_warp", speed_warp)
		m.set_shader_parameter("grade_lift", Vector3(_grade_lift.r, _grade_lift.g, _grade_lift.b))
		m.set_shader_parameter("grade_tint", Vector3(_grade_tint.r, _grade_tint.g, _grade_tint.b))
	if is_instance_valid(player):
		_dust.emitting = GameManager.state == GameManager.State.PLAYING \
			and player.is_on_floor() and absf(player.velocity.x) > 200.0

func _on_theme(theme_name: String) -> void:
	var t := LevelThemes.get_theme(theme_name)
	_grade_lift = t["grade_lift"]
	_grade_tint = t["world_tint"]
	_rain.emitting = t["rain"] > 0.5
	player.visual.rim_color = t["rim"]

func _on_quality(_q: int) -> void:
	_env.environment.glow_enabled = SettingsManager.glow_enabled()
	_post.visible = SettingsManager.post_fx_enabled()
	_dust.amount = int(14 * SettingsManager.particles_scale()) + 2
	_rain.amount = maxi(int(140 * SettingsManager.particles_scale()), 8)

func _on_landed(impact: float) -> void:
	if impact > 500.0:
		_burst(player.global_position, Color(0.7, 0.65, 0.6, 0.5),
			int(clampf(impact / 90.0, 6.0, 22.0)), 160.0)
	if impact > player.HARD_LANDING_SPEED:
		cam.add_trauma(0.55)
	elif impact > 700.0:
		cam.add_trauma(0.25)

func _on_move(move_name: String, perfect: bool) -> void:
	if perfect:
		_burst(player.global_position + Vector2(0, -40),
			Color(1.0, 0.9, 0.4, 0.9), 16, 260.0)
		cam.add_trauma(0.12)
	elif move_name == "wall_jump":
		_burst(player.global_position + Vector2(20, -40),
			Color(0.8, 0.85, 1.0, 0.6), 10, 200.0)

func _on_died() -> void:
	cam.add_trauma(0.9)

func _burst(pos: Vector2, color: Color, amount: int, speed: float) -> void:
	var b := CPUParticles2D.new()
	b.amount = maxi(int(amount * SettingsManager.particles_scale()), 3)
	b.one_shot = true
	b.emitting = true
	b.lifetime = 0.5
	b.explosiveness = 1.0
	b.direction = Vector2(0, -1)
	b.spread = 70.0
	b.initial_velocity_min = speed * 0.4
	b.initial_velocity_max = speed
	b.gravity = Vector2(0, 600)
	b.scale_amount_min = 1.5
	b.scale_amount_max = 3.0
	b.color = color
	b.global_position = pos
	player.get_parent().add_child(b)
	get_tree().create_timer(0.8).timeout.connect(b.queue_free)
