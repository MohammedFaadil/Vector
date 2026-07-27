class_name Coin
extends Area2D
## A floating light-shard collectible. Bobs, glows into the bloom pass,
## bursts into particles on pickup. Feeds the combo system.

var glow_color := Color(1.0, 0.85, 0.4)
var _t := 0.0
var _taken := false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body)
	_t = randf() * TAU   # desync bobbing between coins

func _process(delta: float) -> void:
	_t += delta * 3.0
	queue_redraw()

func _on_body(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	GameManager.collect_coin()
	set_deferred("monitoring", false)
	var burst := CPUParticles2D.new()
	burst.amount = int(10 * SettingsManager.particles_scale()) + 3
	burst.one_shot = true
	burst.emitting = true
	burst.lifetime = 0.4
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 220.0
	burst.gravity = Vector2.ZERO
	burst.color = glow_color
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.0
	add_child(burst)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)

func _draw() -> void:
	if _taken:
		return
	var bob := sin(_t) * 5.0
	var pulse := 0.8 + 0.2 * sin(_t * 2.0)
	# HDR-bright core + soft halo → bloom makes it a little lantern.
	draw_circle(Vector2(0, bob), 14.0, Color(glow_color, 0.12))
	draw_circle(Vector2(0, bob), 7.0, Color(glow_color.r * 1.6, glow_color.g * 1.6, glow_color.b * 1.6, pulse))
	draw_circle(Vector2(0, bob), 3.0, Color(2.0, 2.0, 1.8, 1.0))
