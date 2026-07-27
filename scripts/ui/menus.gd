class_name Menus
extends CanvasLayer
## Main menu, pause, settings, and game-over screens — all code-built,
## all keyboard/mouse friendly. Runs while the tree is paused.

signal play_pressed
signal restart_pressed
signal menu_pressed
signal quit_pressed

var _main: Control
var _pause: Control
var _settings: Control
var _game_over: Control
var _go_score: Label
var _go_best: Label
var _stats: Label
var _title_t := 0.0
var _title: Label

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = _build_main()
	_pause = _build_pause()
	_settings = _build_settings()
	_game_over = _build_game_over()
	for c in [_main, _pause, _settings, _game_over]:
		add_child(c)
		c.visible = false

func show_only(which: Control) -> void:
	for c in [_main, _pause, _settings, _game_over]:
		c.visible = c == which
	if which:
		AudioManager.play("ui_click", -8.0)

func show_main() -> void:
	# Stats must be re-read every visit — a run may have just updated them.
	_stats.text = "BEST %d   ·   %d m   ·   %d RUNS" % [
		GameManager.high_score, int(GameManager.best_distance), GameManager.total_runs]
	show_only(_main)
func show_pause() -> void: show_only(_pause)
func hide_all() -> void: show_only(null)

func show_game_over() -> void:
	_go_score.text = "SCORE  %d      DISTANCE  %d m" % [GameManager.score, int(GameManager.distance_m)]
	var is_record := GameManager.score >= GameManager.high_score and GameManager.score > 0
	_go_best.text = ("NEW RECORD!" if is_record else "BEST  %d" % GameManager.high_score)
	show_only(_game_over)

func _process(delta: float) -> void:
	if _main.visible and _title:
		_title_t += delta
		_title.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(_title_t * 2.0))

# ------------------------------------------------------------------ builders

func _dim_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	return root

func _vbox_center(root: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	return v

func _mk_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 56)
	b.add_theme_font_size_override("font_size", 26)
	b.flat = true
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.35))
	b.pressed.connect(func():
		AudioManager.play("ui_click")
		cb.call())
	b.mouse_entered.connect(func(): AudioManager.play("ui_hover", -10.0))
	return b

func _mk_title(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.5, 0.15, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_main() -> Control:
	var root := _dim_panel()
	var v := _vbox_center(root)
	_title = _mk_title("V E C T O R", 92)
	v.add_child(_title)
	var sub := _mk_title("S H A D O W   R U N N E R", 24)
	sub.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 0.9))
	v.add_child(sub)
	v.add_child(_spacer(30))
	v.add_child(_mk_button("RUN", func(): play_pressed.emit()))
	v.add_child(_mk_button("SETTINGS", func(): show_only(_settings)))
	v.add_child(_mk_button("QUIT", func(): quit_pressed.emit()))
	v.add_child(_spacer(24))
	_stats = _mk_title("", 18)
	_stats.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.6))
	_stats.text = "BEST %d   ·   %d m   ·   %d RUNS" % [
		GameManager.high_score, int(GameManager.best_distance), GameManager.total_runs]
	v.add_child(_stats)
	var hint := _mk_title("SPACE / W — jump & parkour      S / CTRL — slide & fast-fall", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	v.add_child(hint)
	return root

func _build_pause() -> Control:
	var root := _dim_panel()
	var v := _vbox_center(root)
	v.add_child(_mk_title("PAUSED", 56))
	v.add_child(_spacer(20))
	v.add_child(_mk_button("RESUME", func():
		hide_all()
		GameManager.resume_game()))
	v.add_child(_mk_button("SETTINGS", func(): show_only(_settings)))
	v.add_child(_mk_button("MAIN MENU", func(): menu_pressed.emit()))
	return root

func _build_game_over() -> Control:
	var root := _dim_panel()
	var v := _vbox_center(root)
	v.add_child(_mk_title("CAUGHT", 72))
	v.add_child(_spacer(10))
	_go_score = _mk_title("", 30)
	v.add_child(_go_score)
	_go_best = _mk_title("", 24)
	_go_best.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	v.add_child(_go_best)
	v.add_child(_spacer(24))
	v.add_child(_mk_button("RUN AGAIN  (R)", func(): restart_pressed.emit()))
	v.add_child(_mk_button("MAIN MENU", func(): menu_pressed.emit()))
	return root

func _build_settings() -> Control:
	var root := _dim_panel()
	var v := _vbox_center(root)
	v.add_child(_mk_title("SETTINGS", 48))
	v.add_child(_spacer(16))

	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 12)
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(qrow)
	qrow.add_child(_mk_small_label("QUALITY"))
	var qopt := OptionButton.new()
	for qname in ["LOW", "MEDIUM", "HIGH", "ULTRA"]:
		qopt.add_item(qname)
	qopt.selected = SettingsManager.quality
	qopt.custom_minimum_size = Vector2(200, 44)
	qopt.item_selected.connect(func(i): SettingsManager.set_quality(i))
	qrow.add_child(qopt)

	v.add_child(_mk_slider_row("MUSIC", SettingsManager.music_volume,
		func(val): SettingsManager.set_music_volume(val)))
	v.add_child(_mk_slider_row("SFX", SettingsManager.sfx_volume,
		func(val): SettingsManager.set_sfx_volume(val)))

	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 12)
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(frow)
	frow.add_child(_mk_small_label("FULLSCREEN"))
	var fchk := CheckButton.new()
	fchk.button_pressed = SettingsManager.fullscreen
	fchk.toggled.connect(func(on): SettingsManager.set_fullscreen(on))
	frow.add_child(fchk)

	v.add_child(_spacer(20))
	v.add_child(_mk_button("BACK", func():
		if GameManager.state == GameManager.State.PAUSED:
			show_only(_pause)
		elif GameManager.state == GameManager.State.DEAD:
			show_game_over()
		else:
			show_only(_main)))
	return root

func _mk_small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 0.85))
	l.custom_minimum_size = Vector2(150, 0)
	return l

func _mk_slider_row(label_text: String, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_mk_small_label(label_text))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 32)
	s.value_changed.connect(cb)
	row.add_child(s)
	return row

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
