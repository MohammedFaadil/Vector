class_name Hazard
extends Area2D
## Glowing danger volume. lethal=true kills; otherwise it stumbles the player.
## Drawn as an animated energy beam (or spikes) — HDR-bright so bloom picks it up.

var lethal := true
var spikes := false
var beam_size := Vector2(100, 20)
var beam_color := Color(1.0, 0.3, 0.2)
var _t := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = beam_size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body(body: Node2D) -> void:
	if body is Player:
		if lethal:
			body.kill()
		else:
			body.stumble()

func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 9.0)
	# Values >1.0 push into HDR so the glow pass blooms them.
	var hot := Color(beam_color.r * 1.8, beam_color.g * 1.8, beam_color.b * 1.8, pulse)
	if spikes:
		var n := int(beam_size.x / 18.0)
		for i in n:
			var bx := -beam_size.x * 0.5 + i * 18.0 + 9.0
			var pts := PackedVector2Array([
				Vector2(bx - 8, beam_size.y * 0.5),
				Vector2(bx, -beam_size.y * 0.5 - 4.0 * pulse),
				Vector2(bx + 8, beam_size.y * 0.5)])
			draw_colored_polygon(pts, Color(0.02, 0.02, 0.035))
			draw_line(pts[0], pts[1], hot, 1.5)
			draw_line(pts[1], pts[2], hot, 1.5)
	else:
		draw_rect(Rect2(-beam_size * 0.5, beam_size), Color(beam_color, 0.12 * pulse))
		draw_rect(Rect2(-beam_size.x * 0.5, -2, beam_size.x, 4), hot)
