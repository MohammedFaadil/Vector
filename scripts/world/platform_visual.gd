class_name PlatformVisual
extends Node2D
## Silhouette slab with a rim-lit top edge and detailed rooftop props
## (antennas, AC units, pipes, vents, solar panels). Drawn once; costs nothing per frame.

var _w := 100.0
var _h := 100.0
var _rim := Color(1, 0.6, 0.3, 0.35)
var _props: Array = []   # each: [type, x, y, w, h, ...]
var _body_color := Color(0.015, 0.015, 0.025)
var _detail_seed := 0

func setup(w: float, h: float, rim: Color, with_props: bool) -> void:
	_w = w
	_h = h
	_rim = rim
	_detail_seed = int(w * 31.0 + h * 7.0) + randi() % 1000
	if with_props and w > 180.0:
		_generate_props()

func _generate_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _detail_seed
	_props.clear()
	
	var num_props := rng.randi_range(1, maxi(1, int(_w / 200.0)))
	for i in num_props:
		var px := rng.randf_range(30.0, _w - 50.0)
		var prop_type := rng.randi_range(0, 7)
		
		match prop_type:
			0: # AC Unit
				var pw := rng.randf_range(35.0, 55.0)
				var ph := rng.randf_range(25.0, 40.0)
				_props.append(["ac", px, -ph, pw, ph])
			1: # Antenna
				var ph := rng.randf_range(40.0, 100.0)
				_props.append(["antenna", px, -ph, 0, ph])
			2: # Vent pipe
				var ph := rng.randf_range(20.0, 50.0)
				var pw := rng.randf_range(10.0, 18.0)
				_props.append(["vent", px, -ph, pw, ph])
			3: # Solar panel
				var pw := rng.randf_range(60.0, 120.0)
				var ph := rng.randf_range(15.0, 25.0)
				_props.append(["solar", px, -ph, pw, ph])
			4: # Satellite dish
				var ph := rng.randf_range(25.0, 40.0)
				_props.append(["dish", px, -ph, 0, ph])
			5: # Water tank
				var pw := rng.randf_range(30.0, 50.0)
				var ph := rng.randf_range(40.0, 70.0)
				_props.append(["tank", px, -ph, pw, ph])
			6: # Crane (on larger buildings)
				if _w > 300.0:
					var ph := rng.randf_range(80.0, 150.0)
					_props.append(["crane", px, -ph, 0, ph])
			7: # Stair access
				var pw := rng.randf_range(40.0, 60.0)
				var ph := rng.randf_range(20.0, 30.0)
				_props.append(["stairs", px, -ph, pw, ph])

func _draw() -> void:
	# Building body with subtle gradient
	draw_rect(Rect2(0, 0, _w, _h), _body_color)
	
	# Subtle vertical variation for depth
	for i in range(3):
		var x := _w * float(i) / 3.0
		var shade := Color(_body_color.r * 0.95, _body_color.g * 0.95, _body_color.b * 0.95, _body_color.a)
		draw_rect(Rect2(x, 0, 2.0, _h), shade)
	
	# Rim light along the top edge — sells the backlighting.
	draw_rect(Rect2(0, -3, _w, 4), _rim)
	
	# Secondary rim for extra pop
	draw_rect(Rect2(0, -1, _w, 2), Color(_rim.r * 1.2, _rim.g * 1.2, _rim.b * 1.2, _rim.a * 0.6))
	
	# Draw props
	for p in _props:
		var ptype: String = p[0]
		var px: float = p[1]
		var py: float = p[2]
		var pw: float = p[3]
		var ph: float = p[4]
		
		match ptype:
			"ac":
				_draw_ac_unit(px, py, pw, ph)
			"antenna":
				_draw_antenna(px, py, ph)
			"vent":
				_draw_vent(px, py, pw, ph)
			"solar":
				_draw_solar_panel(px, py, pw, ph)
			"dish":
				_draw_satellite_dish(px, py, ph)
			"tank":
				_draw_water_tank(px, py, pw, ph)
			"crane":
				_draw_crane(px, py, ph)
			"stairs":
				_draw_stairs(px, py, pw, ph)

func _draw_ac_unit(x: float, y: float, w: float, h: float) -> void:
	# Main body
	draw_rect(Rect2(x, y, w, h), _body_color)
	# Top rim
	draw_rect(Rect2(x, y - 2, w, 3), Color(_rim, _rim.a * 0.8))
	# Vent slats
	for i in range(int(w / 8.0)):
		var sx := x + 4.0 + i * 8.0
		draw_line(Vector2(sx, y + 4), Vector2(sx, y + h - 4), Color(0.1, 0.1, 0.15), 1.5)
	# Side panel
	draw_rect(Rect2(x + w - 6, y + 4, 4, h - 8), Color(0.15, 0.15, 0.2))
	# Fan hint
	draw_circle(Vector2(x + w * 0.5, y + h * 0.5), 4.0, Color(0.1, 0.1, 0.15))

func _draw_antenna(x: float, y: float, h: float) -> void:
	# Main pole
	draw_line(Vector2(x, y), Vector2(x, y + h), Color(0.12, 0.12, 0.18), 3.0)
	# Crossbars
	draw_line(Vector2(x - 10, y + h * 0.6), Vector2(x + 10, y + h * 0.6), Color(0.12, 0.12, 0.18), 2.0)
	draw_line(Vector2(x - 7, y + h * 0.8), Vector2(x + 7, y + h * 0.8), Color(0.12, 0.12, 0.18), 2.0)
	# Top beacon
	draw_circle(Vector2(x, y + h), 3.0, Color(1.0, 0.2, 0.2, 0.9))
	draw_circle(Vector2(x, y + h), 5.0, Color(1.0, 0.2, 0.2, 0.3))

func _draw_vent(x: float, y: float, w: float, h: float) -> void:
	# Cylindrical vent
	draw_rect(Rect2(x, y, w, h), _body_color)
	draw_rect(Rect2(x, y - 2, w, 3), Color(_rim, _rim.a * 0.7))
	# Vent slots
	for i in range(int(h / 12.0)):
		var sy := y + 6.0 + i * 12.0
		draw_line(Vector2(x + 2, sy), Vector2(x + w - 2, sy), Color(0.08, 0.08, 0.12), 2.0)

func _draw_solar_panel(x: float, y: float, w: float, h: float) -> void:
	# Panel frame
	draw_rect(Rect2(x, y, w, h), Color(0.08, 0.08, 0.12))
	# Cells
	var cols := int(w / 20.0)
	var rows := int(h / 20.0)
	for cx in range(cols):
		for cy in range(rows):
			var cell_x := x + 4.0 + cx * 20.0
			var cell_y := y + 4.0 + cy * 20.0
			draw_rect(Rect2(cell_x, cell_y, 14, 14), Color(0.15, 0.2, 0.35))
	# Rim highlight
	draw_rect(Rect2(x, y - 2, w, 2), Color(_rim, _rim.a * 0.6))

func _draw_satellite_dish(x: float, y: float, h: float) -> void:
	# Support arm
	draw_line(Vector2(x, y), Vector2(x, y + h * 0.5), Color(0.15, 0.15, 0.2), 4.0)
	# Dish parabola
	var dish_y := y + h * 0.5
	for i in range(10):
		var t := float(i) / 9.0
		var dx := (t - 0.5) * 30.0
		var dy := -t * t * 15.0 + 7.5
		if i > 0:
			var pt := float(i - 1) / 9.0
			var pdx := (pt - 0.5) * 30.0
			var pdy := -pt * pt * 15.0 + 7.5
			draw_line(Vector2(x + pdx, dish_y + pdy), Vector2(x + dx, dish_y + dy), Color(0.12, 0.12, 0.18), 2.0)
	# LNB (receiver)
	draw_line(Vector2(x, dish_y), Vector2(x, dish_y - 15), Color(0.15, 0.15, 0.2), 2.0)
	draw_circle(Vector2(x, dish_y - 15), 3.0, Color(0.1, 0.1, 0.15))

func _draw_water_tank(x: float, y: float, w: float, h: float) -> void:
	# Cylindrical tank
	draw_rect(Rect2(x, y, w, h), _body_color)
	draw_rect(Rect2(x, y - 3, w, 4), Color(_rim, _rim.a * 0.8))
	# Bands
	for i in range(3):
		var by := y + h * float(i + 1) / 4.0
		draw_line(Vector2(x, by), Vector2(x + w, by), Color(0.1, 0.1, 0.15), 2.0)
	# Ladder
	draw_line(Vector2(x + w - 5, y), Vector2(x + w - 5, y + h), Color(0.15, 0.15, 0.2), 1.5)
	for i in range(int(h / 15.0)):
		var ry := y + 5.0 + i * 15.0
		draw_line(Vector2(x + w - 10, ry), Vector2(x + w, ry), Color(0.15, 0.15, 0.2), 1.0)

func _draw_crane(x: float, y: float, h: float) -> void:
	# Vertical mast
	draw_line(Vector2(x, y), Vector2(x, y + h), Color(0.18, 0.18, 0.22), 5.0)
	# Horizontal jib
	var jib_len := h * 0.7
	draw_line(Vector2(x, y + h * 0.2), Vector2(x + jib_len, y + h * 0.2), Color(0.18, 0.18, 0.22), 4.0)
	# Counter-jib
	draw_line(Vector2(x, y + h * 0.2), Vector2(x - jib_len * 0.3, y + h * 0.2), Color(0.18, 0.18, 0.22), 3.0)
	# Cable
	draw_line(Vector2(x + jib_len * 0.8, y + h * 0.2), Vector2(x + jib_len * 0.8, y + h * 0.6), Color(0.12, 0.12, 0.15), 1.0)
	# Hook
	draw_circle(Vector2(x + jib_len * 0.8, y + h * 0.6), 4.0, Color(0.2, 0.2, 0.25))

func _draw_stairs(x: float, y: float, w: float, h: float) -> void:
	# Stair access structure
	draw_rect(Rect2(x, y, w, h), _body_color)
	draw_rect(Rect2(x, y - 2, w, 3), Color(_rim, _rim.a * 0.7))
	# Steps
	for i in range(int(h / 8.0)):
		var sy := y + h - 4.0 - i * 8.0
		draw_line(Vector2(x + 4, sy), Vector2(x + w - 4, sy), Color(0.1, 0.1, 0.15), 2.0)
	# Railing
	draw_line(Vector2(x + 4, y), Vector2(x + 4, y + h), Color(0.15, 0.15, 0.2), 2.0)
	draw_line(Vector2(x + w - 4, y), Vector2(x + w - 4, y + h), Color(0.15, 0.15, 0.2), 2.0)