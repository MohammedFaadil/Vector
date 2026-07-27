class_name GameBackground
extends ParallaxBackground
## The whole cinematic backdrop, 100% procedural — six depth layers:
##   0 sky gradient · 1 sun + volumetric god-rays · 2 far skyline (hazy)
##   3 mid skyline · 4 near skyline · 5 drifting fog
## Atmospheric perspective comes from each skyline layer using a lighter,
## bluer color the further away it is. Theme changes crossfade smoothly.

const VIEW := Vector2(1920, 1080)
const PATTERN_W := 3840.0   # skyline strip width, mirrored for infinite scroll

var _sky_rect: TextureRect
var _sky_gradient: Gradient
var _sun: Node2D
var _stars: Node2D
var _rays: ColorRect
var _fog: ColorRect
var _skylines: Array = []   # [SkylineLayer, depth 0..1]
var _cur := {}
var _target := {}
var _blend := 1.0
var _t := 0.0

func _ready() -> void:
	scroll_ignore_camera_zoom = true
	_target = LevelThemes.get_theme("dusk")
	_cur = _target.duplicate()
	_build()
	GameManager.theme_changed.connect(_on_theme)
	SettingsManager.quality_changed.connect(func(_q):
		_rays.visible = SettingsManager.god_rays_enabled()
		_fog.visible = SettingsManager.fog_enabled())
	_apply_colors()

func _on_theme(theme_name: String) -> void:
	_target = LevelThemes.get_theme(theme_name)
	_blend = 0.0

func _build() -> void:
	# --- Layer 0: sky gradient (locked to screen).
	var l0 := ParallaxLayer.new()
	l0.motion_scale = Vector2.ZERO
	_sky_gradient = Gradient.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _sky_gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 16
	tex.height = 256
	_sky_rect = TextureRect.new()
	_sky_rect.texture = tex
	_sky_rect.size = VIEW
	_sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	l0.add_child(_sky_rect)
	add_child(l0)

	# --- Layer 1: star field + sun disc + god-rays shader.
	# MUST be screen-locked: the god-rays shader positions the sun in screen
	# UV space, and any motion scale would carry the whole layer off-screen
	# as distance accumulates.
	var l1 := ParallaxLayer.new()
	l1.motion_scale = Vector2.ZERO
	_stars = StarField.new()
	l1.add_child(_stars)
	_sun = SunDisc.new()
	l1.add_child(_sun)
	add_child(l1)
	_rays = ColorRect.new()
	_rays.size = VIEW
	_rays.material = ShaderMaterial.new()
	_rays.material.shader = load("res://shaders/god_rays.gdshader")
	_rays.visible = SettingsManager.god_rays_enabled()
	l1.add_child(_rays)

	# --- Layers 2-4: skylines at increasing depth.
	for cfg in [[0.12, 0.0, 210.0], [0.28, 0.45, 330.0], [0.5, 1.0, 470.0]]:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(cfg[0], cfg[0] * 0.4)
		layer.motion_mirroring = Vector2(PATTERN_W, 0)
		var sky := SkylineLayer.new()
		sky.depth = cfg[1]
		sky.max_h = cfg[2]
		sky.generate()
		layer.add_child(sky)
		add_child(layer)
		_skylines.append(sky)

	# --- Layer 5: drifting fog (screen-space shader).
	var l5 := ParallaxLayer.new()
	l5.motion_scale = Vector2.ZERO
	_fog = ColorRect.new()
	_fog.size = VIEW
	_fog.material = ShaderMaterial.new()
	_fog.material.shader = load("res://shaders/fog.gdshader")
	_fog.visible = SettingsManager.fog_enabled()
	l5.add_child(_fog)
	add_child(l5)

func _process(delta: float) -> void:
	_t += delta
	_rays.material.set_shader_parameter("time_s", _t)
	_fog.material.set_shader_parameter("time_s", _t)
	_fog.material.set_shader_parameter("cam_x", scroll_offset.x)
	if _blend < 1.0:
		_blend = minf(_blend + delta * 0.5, 1.0)   # 2-second crossfade
		for k in _target:
			var v = _target[k]
			if v is Color:
				_cur[k] = (_cur[k] as Color).lerp(v, delta * 2.0)
			elif v is float:
				_cur[k] = lerpf(_cur[k], v, delta * 2.0)
			elif v is Vector2:
				_cur[k] = (_cur[k] as Vector2).lerp(v, delta * 2.0)
		_apply_colors()

func _apply_colors() -> void:
	_sky_gradient.set_color(0, _cur["sky_top"])
	_sky_gradient.set_color(1, _cur["sky_bottom"])
	_sun.color = _cur["sun_color"]
	_sun.position = Vector2(_cur["sun_pos"].x * VIEW.x, _cur["sun_pos"].y * VIEW.y)
	_stars.intensity = _cur.get("stars", 0.0)
	_rays.material.set_shader_parameter("sun_uv", _cur["sun_pos"])
	_rays.material.set_shader_parameter("ray_color", _cur["ray_color"])
	_rays.material.set_shader_parameter("strength", _cur["ray_strength"])
	_fog.material.set_shader_parameter("fog_color", _cur["fog_color"])
	var depth_cols: Array = [_cur["skyline_far"], _cur["skyline_mid"], _cur["skyline_near"]]
	for i in _skylines.size():
		_skylines[i].set_colors(depth_cols[i], _cur["windows"])


class StarField extends Node2D:
	## Sparse twinkling stars for the night theme; fades out entirely by day.
	var intensity := 0.0:
		set(v):
			var changed := absf(v - intensity) > 0.01
			intensity = v
			visible = v > 0.02
			if changed:
				queue_redraw()
	var _pts: Array = []
	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 90:
			_pts.append([Vector2(rng.randf() * 1920.0, rng.randf() * 620.0),
				rng.randf_range(0.7, 1.8), rng.randf_range(0.25, 0.9)])
	func _draw() -> void:
		for p in _pts:
			draw_circle(p[0], p[1], Color(0.9, 0.95, 1.0, p[2] * intensity))


class SunDisc extends Node2D:
	## Soft-glowing sun/moon disc; HDR-bright core feeds the bloom pass.
	var color := Color(1, 0.85, 0.6):
		set(v):
			color = v
			queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 150.0, Color(color, color.a * 0.08))
		draw_circle(Vector2.ZERO, 95.0, Color(color, color.a * 0.18))
		draw_circle(Vector2.ZERO, 58.0, Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, color.a))


class SkylineLayer extends Node2D:
	## One strip of procedural building silhouettes, PATTERN_W wide, mirrored
	## by its ParallaxLayer for infinite scroll. Windows light up in neon theme.
	var depth := 0.0        # 0 = farthest
	var max_h := 300.0
	var color := Color(0.3, 0.2, 0.25)
	var window_amount := 0.0
	var _buildings: Array = []   # [x, w, h, style]
	var _windows: Array = []     # per building: array of lit Rect2

	func generate() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + int(depth * 97.0)
		var x := 0.0
		while x < GameBackground.PATTERN_W:
			var w := rng.randf_range(90.0, 240.0)
			var h := rng.randf_range(max_h * 0.35, max_h)
			_buildings.append([x, w, h, rng.randi_range(0, 2)])
			var lit: Array = []
			var cols := int(w / 26.0)
			var rows := int(h / 34.0)
			for cx in cols:
				for cy in rows:
					if rng.randf() < 0.22:
						lit.append(Rect2(x + 8 + cx * 26.0, -h + 12 + cy * 34.0, 10, 14))
			_windows.append(lit)
			x += w + rng.randf_range(6.0, 40.0)

	func set_colors(c: Color, windows: float) -> void:
		color = c
		window_amount = windows
		queue_redraw()

	func _draw() -> void:
		var base_y := 1080.0
		for i in _buildings.size():
			var b: Array = _buildings[i]
			# Building body reaches the bottom of the frame.
			draw_rect(Rect2(b[0], base_y - b[2], b[1], b[2] + 40.0), color)
			match int(b[3]):   # simple roof variety
				1: draw_rect(Rect2(b[0] + b[1] * 0.3, base_y - b[2] - 22.0, b[1] * 0.4, 22.0), color)
				2: draw_line(Vector2(b[0] + b[1] * 0.5, base_y - b[2]),
					Vector2(b[0] + b[1] * 0.5, base_y - b[2] - 46.0), color, 3.0)
			if window_amount > 0.01:
				var win := Color(1.0, 0.85, 0.5, 0.9 * window_amount) if window_amount < 0.5 \
					else Color(0.5, 0.95, 1.0, 0.9 * window_amount)
				for r in _windows[i]:
					draw_rect(Rect2(r.position + Vector2(0, base_y), r.size), win)
