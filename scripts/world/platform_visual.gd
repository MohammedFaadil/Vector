class_name PlatformVisual
extends Node2D
## Silhouette slab with a rim-lit top edge and optional rooftop props
## (antennas, AC units, pipes). Drawn once; costs nothing per frame.

var _w := 100.0
var _h := 100.0
var _rim := Color(1, 0.6, 0.3, 0.35)
var _props: Array = []   # each: [Rect2] or ["antenna", x, h]

func setup(w: float, h: float, rim: Color, with_props: bool) -> void:
	_w = w
	_h = h
	_rim = rim
	if with_props and w > 220.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(w * 31.0 + h * 7.0) + randi() % 1000
		var n := rng.randi_range(1, maxi(1, int(w / 300.0)))
		for i in n:
			var px := rng.randf_range(40.0, w - 80.0)
			if rng.randf() < 0.5:
				_props.append([Rect2(px, -rng.randf_range(18, 34), rng.randf_range(30, 56), 40)])
			else:
				_props.append(["antenna", px, rng.randf_range(40.0, 90.0)])

func _draw() -> void:
	var body := Color(0.02, 0.02, 0.035)
	draw_rect(Rect2(0, 0, _w, _h), body)
	# Rim light along the top edge — sells the backlighting.
	draw_rect(Rect2(0, -2, _w, 3), _rim)
	for p in _props:
		if p[0] is Rect2:
			draw_rect(p[0], body)
			draw_rect(Rect2(p[0].position.x, p[0].position.y - 2, p[0].size.x, 2),
				Color(_rim, _rim.a * 0.7))
		else:
			var x: float = p[1]
			var h: float = p[2]
			draw_line(Vector2(x, 0), Vector2(x, -h), body, 4.0)
			draw_line(Vector2(x - 10, -h * 0.6), Vector2(x + 10, -h * 0.6), body, 3.0)
			draw_circle(Vector2(x, -h), 3.0, Color(_rim, 0.8))
