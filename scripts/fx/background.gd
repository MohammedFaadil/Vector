class_name GameBackground
extends ParallaxBackground
## The whole cinematic backdrop, 100% procedural — eight depth layers:
##   0 sky gradient · 1 star field · 2 sun/moon disc + volumetric god-rays
##   3 distant atmospheric haze · 4 far skyline (hazy) · 5 mid skyline
##   6 near skyline (sharp) · 7 drifting volumetric fog
## Atmospheric perspective comes from each skyline layer using a lighter,
## bluer color the further away it is. Theme changes crossfade smoothly.

const VIEW := Vector2(1920, 1080)
const PATTERN_W := 3840.0   # skyline strip width, mirrored for infinite scroll

var _sky_rect: TextureRect
var _sky_gradient: Gradient
var _sun: Node2D
var _stars: Node2D
var _rays: ColorRect
var _atmo_haze: ColorRect
var _fog: ColorRect
var _skylines: Array = []   # [SkylineLayer, depth 0..1]
var _cur := {}
var _target := {}
var _blend := 1.0
var _t := 0.0
var _clouds: Node2D
var _cloud_layer: ParallaxLayer

func _ready() -> void:
	scroll_ignore_camera_zoom = true
	_target = LevelThemes.get_theme("dusk")
	_cur = _target.duplicate()
	_build()
	GameManager.theme_changed.connect(_on_theme)
	SettingsManager.quality_changed.connect(func(_q):
		_rays.visible = SettingsManager.god_rays_enabled()
		_fog.visible = SettingsManager.fog_enabled()
		_atmo_haze.visible = SettingsManager.fog_enabled()
		_cloud_layer.visible = SettingsManager.particles_scale() > 0.5)
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

	# --- Layer 2: atmospheric haze (screen-space, behind skylines)
	var l2 := ParallaxLayer.new()
	l2.motion_scale = Vector2.ZERO
	_atmo_haze = ColorRect.new()
	_atmo_haze.size = VIEW
	_atmo_haze.material = ShaderMaterial.new()
	_atmo_haze.material.shader = load("res://shaders/atmo_haze.gdshader")
	_atmo_haze.visible = SettingsManager.fog_enabled()
	l2.add_child(_atmo_haze)
	add_child(l2)

	# --- Layers 3-5: skylines at increasing depth.
	for cfg in [
		[0.08, 0.0, 180.0],   # far: slow, low, hazy
		[0.22, 0.35, 280.0],  # mid
		[0.42, 0.75, 420.0],  # near: fast, tall, sharp
	]:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(cfg[0], cfg[0] * 0.3)
		layer.motion_mirroring = Vector2(PATTERN_W, 0)
		var sky := SkylineLayer.new()
		sky.depth = cfg[1]
		sky.max_h = cfg[2]
		sky.generate()
		layer.add_child(sky)
		add_child(layer)
		_skylines.append(sky)

	# --- Layer 6: procedural cloud layer (slow parallax)
	_cloud_layer = ParallaxLayer.new()
	_cloud_layer.motion_scale = Vector2(0.15, 0.05)
	_cloud_layer.motion_mirroring = Vector2(PATTERN_W * 2.0, 0)
	_clouds = CloudLayer.new()
	_clouds.generate()
	_cloud_layer.add_child(_clouds)
	add_child(_cloud_layer)
	_cloud_layer.visible = SettingsManager.particles_scale() > 0.5

	# --- Layer 7: drifting fog (screen-space shader).
	var l7 := ParallaxLayer.new()
	l7.motion_scale = Vector2.ZERO
	_fog = ColorRect.new()
	_fog.size = VIEW
	_fog.material = ShaderMaterial.new()
	_fog.material.shader = load("res://shaders/fog.gdshader")
	_fog.visible = SettingsManager.fog_enabled()
	l7.add_child(_fog)
	add_child(l7)

func _process(delta: float) -> void:
	_t += delta
	_rays.material.set_shader_parameter("time_s", _t)
	_rays.material.set_shader_parameter("sun_uv", _cur["sun_pos"])
	_atmo_haze.material.set_shader_parameter("time_s", _t)
	_fog.material.set_shader_parameter("time_s", _t)
	_fog.material.set_shader_parameter("cam_x", scroll_offset.x)
	
	# Update cloud positions
	if is_instance_valid(_clouds):
		_clouds.update_clouds(delta, scroll_offset.x)
	
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
	_rays.material.set_shader_parameter("ray_color", _cur["ray_color"])
	_rays.material.set_shader_parameter("strength", _cur["ray_strength"])
	_rays.material.set_shader_parameter("density", _cur.get("ray_density", 0.5))
	_rays.material.set_shader_parameter("exposure", _cur.get("ray_exposure", 1.0))
	_atmo_haze.material.set_shader_parameter("haze_color", _cur["fog_color"])
	_atmo_haze.material.set_shader_parameter("intensity", _cur.get("haze_intensity", 0.3))
	_fog.material.set_shader_parameter("fog_color", _cur["fog_color"])
	_fog.material.set_shader_parameter("density", _cur.get("fog_density", 0.5))
	_fog.material.set_shader_parameter("wind_speed", _cur.get("fog_wind", 0.02))
	_fog.material.set_shader_parameter("turbulence", _cur.get("fog_turbulence", 0.3))
	var depth_cols: Array = [_cur["skyline_far"], _cur["skyline_mid"], _cur["skyline_near"]]
	for i in _skylines.size():
		_skylines[i].set_colors(depth_cols[i], _cur["windows"])
	if is_instance_valid(_clouds):
		_clouds.set_colors(_cur["skyline_far"], _cur["skyline_mid"], _cur["skyline_near"])


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
	var _time := 0.0   # inner classes can't see the outer class's _t
	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 120:
			_pts.append([Vector2(rng.randf() * 1920.0, rng.randf() * 620.0),
				rng.randf_range(0.7, 1.8), rng.randf_range(0.25, 0.9),
				rng.randf_range(0.5, 2.0)])  # twinkle speed
	func _process(delta: float) -> void:
		if visible:
			_time += delta
			queue_redraw()   # live twinkle
	func _draw() -> void:
		for p in _pts:
			var twinkle: float = 0.5 + 0.5 * sin(_time * p[3] + p[0].x * 0.01)
			draw_circle(p[0], p[1], Color(0.9, 0.95, 1.0, p[2] * intensity * twinkle))


class SunDisc extends Node2D:
	## Soft-glowing sun/moon disc; HDR-bright core feeds the bloom pass.
	var color := Color(1, 0.85, 0.6):
		set(v):
			color = v
			queue_redraw()
	var _time := 0.0   # inner classes can't see the outer class's _t
	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()   # animate the corona spikes
	func _draw() -> void:
		# Outer glow
		draw_circle(Vector2.ZERO, 180.0, Color(color, color.a * 0.05))
		draw_circle(Vector2.ZERO, 130.0, Color(color, color.a * 0.12))
		draw_circle(Vector2.ZERO, 90.0, Color(color, color.a * 0.25))
		# Core - HDR bright for bloom
		var hdr_color := Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, color.a)
		draw_circle(Vector2.ZERO, 55.0, hdr_color)
		draw_circle(Vector2.ZERO, 35.0, Color(hdr_color.r * 1.5, hdr_color.g * 1.5, hdr_color.b * 1.5, 1.0))
		# Corona spikes
		for i in 8:
			var ang := i * TAU / 8.0 + _time * 0.1
			var len := 60.0 + 20.0 * sin(_time * 2.0 + i)
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * len, Color(color, 0.15), 2.0)


class CloudLayer extends Node2D:
	## Procedural cloud layer with multiple cloud formations
	var _clouds: Array = []  # [x, y, width, height, type, speed, opacity]
	var _colors: Array = []
	
	func generate() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		_clouds.clear()
		
		# Generate cloud formations
		for i in range(15):
			var x := rng.randf() * PATTERN_W * 2.0
			var y := rng.randf_range(50.0, 400.0)
			var w := rng.randf_range(200.0, 500.0)
			var h := rng.randf_range(60.0, 150.0)
			var cloud_type := rng.randi_range(0, 2)  # 0=stratus, 1=cumulus, 2=cirrus
			var speed := rng.randf_range(0.005, 0.02)
			var opacity := rng.randf_range(0.15, 0.4)
			_clouds.append([x, y, w, h, cloud_type, speed, opacity])
	
	func set_colors(far: Color, mid: Color, near: Color) -> void:
		_colors = [far, mid, near]
		queue_redraw()
	
	func update_clouds(delta: float, cam_x: float) -> void:
		for c in _clouds:
			c[0] -= c[5] * delta * 60.0  # Move clouds slowly
			# Wrap around
			if c[0] + c[2] < cam_x * 0.15 - 500:
				c[0] += PATTERN_W * 2.0
			elif c[0] > cam_x * 0.15 + VIEW.x + 500:
				c[0] -= PATTERN_W * 2.0
		queue_redraw()
	
	func _draw() -> void:
		for c in _clouds:
			var x: float = c[0]
			var y: float = c[1]
			var w: float = c[2]
			var h: float = c[3]
			var ctype: int = c[4]
			var opacity: float = c[6]
			
			# Choose color based on cloud type (height)
			var base_color: Color = _colors[mini(ctype, _colors.size() - 1)]
			var cloud_color := Color(base_color, opacity)
			var highlight_color := Color(base_color.r * 1.3, base_color.g * 1.3, base_color.b * 1.3, opacity * 0.5)
			
			match ctype:
				0: # Stratus - flat, layered
					_draw_stratus(x, y, w, h, cloud_color, highlight_color)
				1: # Cumulus - puffy
					_draw_cumulus(x, y, w, h, cloud_color, highlight_color)
				2: # Cirrus - wispy
					_draw_cirrus(x, y, w, h, cloud_color)
	
	func _draw_stratus(x: float, y: float, w: float, h: float, color: Color, highlight: Color) -> void:
		var layers := 3
		for i in layers:
			var ly := y + i * h / layers * 0.5
			var lw := w * (1.0 - i * 0.15)
			var lh := h / layers * 0.8
			var lx := x + (w - lw) * 0.5
			var c := color.lerp(highlight, float(i) / layers * 0.3)
			draw_rect(Rect2(lx, ly, lw, lh), c)
			# Soft edges
			draw_rect(Rect2(lx, ly, lw, 4.0), Color(c, c.a * 0.5))
			draw_rect(Rect2(lx, ly + lh - 4.0, lw, 4.0), Color(c, c.a * 0.5))
	
	func _draw_cumulus(x: float, y: float, w: float, h: float, color: Color, highlight: Color) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(x * 100.0 + y * 10.0)
		var num_puffs := rng.randi_range(5, 10)
		for i in num_puffs:
			var px := x + rng.randf() * w * 0.8
			var py := y + rng.randf() * h * 0.6
			var pr := rng.randf_range(w * 0.15, w * 0.35)
			var c := color.lerp(highlight, rng.randf() * 0.4)
			draw_circle(Vector2(px, py), pr, c)
			# Overlapping puffs for volume
			if i > 0:
				var px2 := x + rng.randf() * w * 0.8
				var py2 := y + rng.randf() * h * 0.6
				var pr2 := rng.randf_range(w * 0.1, w * 0.25)
				draw_circle(Vector2(px2, py2), pr2, Color(c, c.a * 0.7))
	
	func _draw_cirrus(x: float, y: float, w: float, h: float, color: Color) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(x * 100.0 + y * 10.0) + 1000
		var num_streaks := rng.randi_range(8, 15)
		for i in num_streaks:
			var sx := x + rng.randf() * w
			var sy := y + rng.randf() * h
			var len := rng.randf_range(w * 0.3, w * 0.8)
			var angle := rng.randf_range(-0.3, 0.3)
			var thickness := rng.randf_range(2.0, 6.0)
			var streak_color := Color(color, color.a * rng.randf_range(0.3, 0.6))
			for j in range(3):
				var offset := (j - 1) * thickness * 0.5
				draw_line(
					Vector2(sx, sy + offset),
					Vector2(sx + cos(angle) * len, sy + sin(angle) * len + offset),
					streak_color, thickness
				)


class SkylineLayer extends Node2D:
	## One strip of procedural building silhouettes, PATTERN_W wide, mirrored
	## by its ParallaxLayer for infinite scroll. Windows light up in neon theme.
	var depth := 0.0        # 0 = farthest
	var max_h := 300.0
	var color := Color(0.3, 0.2, 0.25)
	var window_amount := 0.0
	var _buildings: Array = []   # [x, w, h, style, roof_style, detail_level]
	var _windows: Array = []     # per building: array of lit Rect2
	var _building_details: Array = []  # antennas, AC units, etc.

	func generate() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + int(depth * 97.0)
		var x := 0.0
		_buildings.clear()
		_windows.clear()
		_building_details.clear()
		
		while x < PATTERN_W:
			var w := rng.randf_range(80.0, 280.0)
			var h := rng.randf_range(max_h * 0.3, max_h)
			var style := rng.randi_range(0, 3)
			var roof_style := rng.randi_range(0, 4)
			var detail_level := rng.randi_range(0, 2)
			_buildings.append([x, w, h, style, roof_style, detail_level])
			
			# Generate windows
			var lit: Array = []
			var cols := int(w / 22.0)
			var rows := int(h / 28.0)
			for cx in cols:
				for cy in rows:
					if rng.randf() < 0.18 + depth * 0.1:  # More windows on nearer buildings
						lit.append(Rect2(x + 6 + cx * 22.0, -h + 8 + cy * 28.0, 12, 16))
			_windows.append(lit)
			
			# Generate building details (antennas, AC units, vents, etc.)
			var details: Array = []
			if detail_level > 0 and w > 120.0:
				var num_details := detail_level + rng.randi_range(0, 2)
				for d in num_details:
					var dx := x + rng.randf_range(20.0, w - 20.0)
					var dtype := rng.randi_range(0, 4)
					details.append([dtype, dx, rng.randf_range(10.0, 60.0)])
			_building_details.append(details)
			
			x += w + rng.randf_range(4.0, 50.0)

	func set_colors(c: Color, windows: float) -> void:
		color = c
		window_amount = windows
		queue_redraw()

	func _draw() -> void:
		var base_y := 1080.0
		for i in _buildings.size():
			var b: Array = _buildings[i]
			var bx: float = b[0]
			var bw: float = b[1]
			var bh: float = b[2]
			var style := int(b[3])
			var roof_style := int(b[4])
			var detail_level := int(b[5])
			
			# Building body reaches bottom of frame
			draw_rect(Rect2(bx, base_y - bh, bw, bh + 40.0), color)
			
			# Building style variations
			match style:
				0: # Standard rectangular
					pass
				1: # Stepped/tiered
					var steps := 3
					for s in steps:
						var sw := bw * (1.0 - s * 0.15)
						var sh := bh / steps
						var sx := bx + (bw - sw) * 0.5
						var sy := base_y - bh + s * sh
						draw_rect(Rect2(sx, sy, sw, sh + 2.0), Color(color, color.a * 0.9))
				2: # Rounded corners
					# Draw as rect with rounded top (simulated with smaller rects)
					draw_rect(Rect2(bx + 4, base_y - bh, bw - 8, bh - 8), color)
				3: # Tapered
					draw_polygon([
						Vector2(bx, base_y),
						Vector2(bx + bw, base_y),
						Vector2(bx + bw * 0.7, base_y - bh),
						Vector2(bx + bw * 0.3, base_y - bh)
					], [color])
			
			# Roof details
			_draw_roof(bx, bw, bh, base_y, roof_style)
			
			# Building details (antennas, AC units, etc.)
			for det in _building_details[i]:
				_draw_detail(det[0], det[1], base_y - bh, det[2])
			
			# Windows
			if window_amount > 0.01:
				var win_color := Color(1.0, 0.85, 0.5, 0.9 * window_amount) if window_amount < 0.5 \
					else Color(0.5, 0.95, 1.0, 0.9 * window_amount)
				for r in _windows[i]:
					draw_rect(Rect2(r.position + Vector2(0, base_y), r.size), win_color)
					# Window glow
					draw_rect(Rect2(r.position + Vector2(0, base_y) - Vector2(2, 2), r.size + Vector2(4, 4)), Color(win_color, win_color.a * 0.3))

	func _draw_roof(bx: float, bw: float, bh: float, base_y: float, roof_style: int) -> void:
		var roof_y := base_y - bh
		match roof_style:
			0: # Flat with parapet
				draw_rect(Rect2(bx, roof_y - 6, bw, 6), Color(color, color.a * 0.8))
				draw_rect(Rect2(bx + bw * 0.2, roof_y - 18, bw * 0.6, 12), Color(color, color.a * 0.6))
			1: # Peaked
				draw_polygon([
					Vector2(bx, roof_y),
					Vector2(bx + bw * 0.5, roof_y - 30),
					Vector2(bx + bw, roof_y)
				], [Color(color, color.a * 0.9)])
			2: # Domed
				for i in range(15):
					var t := float(i) / 14.0
					var rx := bx + t * bw
					var ry := roof_y - sin(t * PI) * 20.0
					if i > 0:
						var pt := float(i - 1) / 14.0
						var px := bx + pt * bw
						var py := roof_y - sin(pt * PI) * 20.0
						draw_line(Vector2(px, py), Vector2(rx, ry), Color(color, color.a * 0.8), 3.0)
			3: # Helipad
				draw_rect(Rect2(bx + bw * 0.25, roof_y - 4, bw * 0.5, 4), Color(0.2, 0.2, 0.25))
				# H marker
				draw_line(Vector2(bx + bw * 0.4, roof_y - 2), Vector2(bx + bw * 0.6, roof_y - 2), Color(1, 1, 1, 0.5), 2.0)
				draw_line(Vector2(bx + bw * 0.5, roof_y - 6), Vector2(bx + bw * 0.5, roof_y + 2), Color(1, 1, 1, 0.5), 2.0)
			4: # Garden/terraced
				for t in range(3):
					var ty := roof_y - 8 - t * 10
					var tw := bw * (0.8 - t * 0.15)
					draw_rect(Rect2(bx + (bw - tw) * 0.5, ty, tw, 6), Color(0.15, 0.25, 0.15, 0.7))

	func _draw_detail(dtype: int, x: float, roof_y: float, height: float) -> void:
		match dtype:
			0: # Antenna
				draw_line(Vector2(x, roof_y), Vector2(x, roof_y - height), Color(0.15, 0.15, 0.2), 3.0)
				draw_line(Vector2(x - 8, roof_y - height * 0.6), Vector2(x + 8, roof_y - height * 0.6), Color(0.15, 0.15, 0.2), 2.0)
				draw_circle(Vector2(x, roof_y - height), 3.0, Color(1.0, 0.2, 0.2, 0.8))
			1: # AC unit
				draw_rect(Rect2(x - 15, roof_y - height, 30, height), Color(0.2, 0.2, 0.25))
				draw_rect(Rect2(x - 12, roof_y - height + 4, 24, 4), Color(0.3, 0.3, 0.35))
			2: # Vent pipe
				draw_rect(Rect2(x - 6, roof_y - height, 12, height), Color(0.25, 0.25, 0.3))
				draw_rect(Rect2(x - 8, roof_y - height - 4, 16, 4), Color(0.3, 0.3, 0.35))
			3: # Satellite dish
				draw_polygon([
					Vector2(x - 12, roof_y),
					Vector2(x + 12, roof_y),
					Vector2(x + 8, roof_y - height),
					Vector2(x - 8, roof_y - height)
				], [Color(0.2, 0.2, 0.25)])
				draw_line(Vector2(x, roof_y - height * 0.5), Vector2(x, roof_y - height * 1.5), Color(0.15, 0.15, 0.2), 2.0)
			4: # Crane (construction)
				draw_line(Vector2(x, roof_y), Vector2(x, roof_y - height), Color(0.3, 0.3, 0.35), 4.0)
				draw_line(Vector2(x, roof_y - height), Vector2(x + height * 0.7, roof_y - height * 0.3), Color(0.3, 0.3, 0.35), 3.0)
				draw_line(Vector2(x + height * 0.7, roof_y - height * 0.3), Vector2(x + height * 0.7, roof_y - height * 0.8), Color(0.3, 0.3, 0.35), 2.0)