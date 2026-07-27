class_name Hud
extends CanvasLayer
## In-run HUD: distance, score, coins, combo flare, story-beat lines,
## and a "PERFECT" flash for well-timed parkour. Built entirely in code.

var _distance: Label
var _score: Label
var _coins: Label
var _combo: Label
var _story: Label
var _perfect: Label

func _ready() -> void:
	layer = 50
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 40)
	top.add_theme_constant_override("margin_right", 40)
	top.add_theme_constant_override("margin_top", 24)
	add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)

	_distance = _mk_label(40, Color(1, 1, 1, 0.95))
	row.add_child(_distance)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(right)
	_score = _mk_label(30, Color(1, 0.9, 0.6))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_score)
	_coins = _mk_label(22, Color(1, 0.85, 0.4, 0.9))
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_coins)

	# Fixed 1920x1080 design space (canvas_items stretch) → absolute coords
	# are safe on every monitor. Pivot at the label center for clean scaling.
	_combo = _mk_label(34, Color(1, 0.7, 0.2))
	_combo.size = Vector2(400, 50)
	_combo.position = Vector2(760, 100)
	_combo.pivot_offset = Vector2(200, 25)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.modulate.a = 0.0
	add_child(_combo)

	_story = _mk_label(26, Color(0.9, 0.92, 1.0))
	_story.size = Vector2(1000, 60)
	_story.position = Vector2(460, 720)
	_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story.modulate.a = 0.0
	add_child(_story)

	_perfect = _mk_label(30, Color(0.5, 1.0, 0.6))
	_perfect.text = "PERFECT"
	_perfect.size = Vector2(300, 50)
	_perfect.position = Vector2(810, 360)
	_perfect.pivot_offset = Vector2(150, 25)
	_perfect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perfect.modulate.a = 0.0
	add_child(_perfect)

	GameManager.score_changed.connect(_refresh)
	GameManager.combo_changed.connect(_on_combo)
	_refresh()

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _process(_delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_distance.text = "%d m" % int(GameManager.distance_m)
	var beat := GameManager.poll_story_beat()
	if beat != "":
		show_story(beat)

func _refresh() -> void:
	_score.text = "SCORE %d" % GameManager.score
	_coins.text = "✦ %d" % GameManager.coins

func _on_combo(combo: int) -> void:
	if combo < 2:
		var tw := create_tween()
		tw.tween_property(_combo, "modulate:a", 0.0, 0.3)
		return
	_combo.text = "COMBO ×%d" % combo
	_combo.modulate.a = 1.0
	_combo.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(_combo, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

func show_story(text: String) -> void:
	_story.text = text
	var tw := create_tween()
	tw.tween_property(_story, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.8)
	tw.tween_property(_story, "modulate:a", 0.0, 0.8)

func flash_perfect() -> void:
	_perfect.modulate.a = 1.0
	_perfect.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_perfect, "scale", Vector2.ONE, 0.15)
	tw.tween_property(_perfect, "modulate:a", 0.0, 0.7).set_delay(0.25)
