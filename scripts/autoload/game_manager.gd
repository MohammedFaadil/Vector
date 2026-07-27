extends Node
## GameManager (autoload) — run state, scoring, combos, high-score persistence,
## slow-motion control, and the story/level-theme progression.

signal state_changed(new_state: int)
signal score_changed
signal combo_changed(combo: int)
signal theme_changed(theme_name: String)
signal player_died

enum State { MENU, PLAYING, PAUSED, DEAD }

const SAVE_PATH := "user://save.cfg"
const COMBO_WINDOW := 3.0  # seconds between pickups to keep the chain alive

## Theme rotation: each "level" is one themed stretch of the endless run.
const THEME_ORDER := ["dusk", "storm", "neon"]
const THEME_LENGTH_M := 400.0  # meters per theme before transitioning

## Story beats shown on the HUD as you cross distances (Vector-style intro text).
const STORY_BEATS := {
	0: "They watch everyone. They caught you once.",
	60: "Not again. RUN.",
	150: "The rooftops remember free men.",
	400: "Storm's coming. Good. It hides you.",
	800: "The neon district — almost out of the grid.",
	1200: "Keep running. Never stop running.",
}

var state: int = State.MENU
var distance_m: float = 0.0
var coins: int = 0
var combo: int = 0
var best_combo: int = 0
var score: int = 0
var high_score: int = 0
var best_distance: float = 0.0
var total_runs: int = 0
var _combo_timer: float = 0.0
var current_theme: String = "dusk"
var _shown_beats: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(combo)

## Difficulty 0..1 over the first ~3km, used by generator and speed ramp.
func difficulty() -> float:
	return clampf(distance_m / 3000.0, 0.0, 1.0)

func start_run() -> void:
	distance_m = 0.0
	coins = 0
	combo = 0
	score = 0
	_shown_beats.clear()
	_set_theme("dusk")
	Engine.time_scale = 1.0
	state = State.PLAYING
	total_runs += 1
	state_changed.emit(state)
	AudioManager.play_music("dusk")

func update_distance(meters: float) -> void:
	if meters <= distance_m:
		return
	distance_m = meters
	score = int(distance_m * 10.0) + coins * 25
	score_changed.emit()
	var want: String = THEME_ORDER[int(distance_m / THEME_LENGTH_M) % THEME_ORDER.size()]
	if want != current_theme:
		_set_theme(want)

func _set_theme(theme_name: String) -> void:
	current_theme = theme_name
	theme_changed.emit(theme_name)
	if state == State.PLAYING:
		AudioManager.play_music(theme_name)

## Returns a story line if the player just crossed a new beat, else "".
func poll_story_beat() -> String:
	for d in STORY_BEATS:
		if distance_m >= d and not _shown_beats.has(d):
			_shown_beats.append(d)
			return STORY_BEATS[d]
	return ""

func collect_coin() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	_combo_timer = COMBO_WINDOW
	coins += 1
	score = int(distance_m * 10.0) + coins * 25 + combo * combo * 5
	if combo > 1 and combo % 5 == 0:
		AudioManager.play("combo")
	else:
		AudioManager.play_varied("coin")
	score_changed.emit()
	combo_changed.emit(combo)

func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	state_changed.emit(state)

func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	state_changed.emit(state)

func on_player_death() -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	best_distance = maxf(best_distance, distance_m)
	if score > high_score:
		high_score = score
	save_game()
	AudioManager.play("death")
	AudioManager.stop_music(0.6)
	# Brief slow-motion on death, restored by whoever restarts.
	Engine.time_scale = 0.25
	get_tree().create_timer(0.35, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0)
	player_died.emit()
	state_changed.emit(state)

func to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	state = State.MENU
	state_changed.emit(state)
	AudioManager.play_music("menu")

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "best_distance", best_distance)
	cfg.set_value("progress", "best_combo", best_combo)
	cfg.set_value("progress", "total_runs", total_runs)
	cfg.save(SAVE_PATH)

func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = cfg.get_value("progress", "high_score", 0)
	best_distance = cfg.get_value("progress", "best_distance", 0.0)
	best_combo = cfg.get_value("progress", "best_combo", 0)
	total_runs = cfg.get_value("progress", "total_runs", 0)
