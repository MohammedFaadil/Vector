class_name LevelGenerator
extends Node2D
## Endless procedural level builder. Spawns authored "chunks" ahead of the
## camera and frees everything that scrolls off behind — memory stays flat
## forever. Difficulty (gap width, hazard density, chunk selection) scales
## with GameManager.difficulty(). Add new patterns to CHUNKS to author content.

const GROUND_Y := 640.0
const SPAWN_AHEAD := 2600.0
const FREE_BEHIND := 1600.0
const MIN_Y := 260.0     # highest platform allowed
const MAX_Y := 820.0     # lowest platform allowed

var next_x := 0.0
var cur_y := GROUND_Y
var _active: Array = []          # [node, end_x]
var _rng := RandomNumberGenerator.new()
var _last_chunk := ""
var rim := Color(1, 0.6, 0.3, 0.35)
var glow := Color(1.0, 0.85, 0.4)
var ray := Color(1.0, 0.3, 0.2)

## name → [weight, min_difficulty, method]
var CHUNKS := {}

func _ready() -> void:
	_rng.randomize()
	CHUNKS = {
		"flat":          [3.0, 0.0, _chunk_flat],
		"gap":           [3.0, 0.0, _chunk_gap],
		"vault":         [2.5, 0.05, _chunk_vault],
		"slide":         [2.5, 0.1, _chunk_slide],
		"stairs_up":     [1.6, 0.1, _chunk_stairs_up],
		"drop":          [1.6, 0.1, _chunk_drop],
		"wall":          [2.0, 0.2, _chunk_wall],
		"spike_gap":     [1.6, 0.3, _chunk_spike_gap],
		"gauntlet":      [1.8, 0.45, _chunk_gauntlet],
		"tower_ledge":   [1.4, 0.35, _chunk_tower_ledge],
	}
	GameManager.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(GameManager.current_theme)

func _on_theme_changed(theme_name: String) -> void:
	var t := LevelThemes.get_theme(theme_name)
	rim = t["rim"]
	glow = Color(t["ray_color"], 1.0)
	ray = Color(1.0, 0.25, 0.2) if theme_name != "neon" else Color(0.3, 0.9, 1.0)

func reset() -> void:
	for entry in _active:
		if is_instance_valid(entry[0]):
			entry[0].queue_free()
	_active.clear()
	next_x = -600.0
	cur_y = GROUND_Y
	_last_chunk = ""
	# Guaranteed calm runway at the start of every run.
	_place(Pieces.platform(next_x, cur_y, 2200.0, rim), 2200.0)
	next_x += 2200.0

func update_generation(camera_x: float) -> void:
	while next_x < camera_x + SPAWN_AHEAD:
		_spawn_chunk()
	# Free everything fully behind the camera. Reverse loop → safe removal.
	for i in range(_active.size() - 1, -1, -1):
		if _active[i][1] < camera_x - FREE_BEHIND:
			if is_instance_valid(_active[i][0]):
				_active[i][0].queue_free()
			_active.remove_at(i)

func _place(node: Node2D, width: float) -> void:
	add_child(node)
	_active.append([node, node.position.x + width])

# -------------------------------------------------------------- chunk picker

func _spawn_chunk() -> void:
	var d := GameManager.difficulty()
	var total := 0.0
	var pool: Array = []
	for cname in CHUNKS:
		var c: Array = CHUNKS[cname]
		if d < c[1] or cname == _last_chunk:   # never the same chunk twice in a row
			continue
		pool.append(cname)
		total += c[0]
	var roll := _rng.randf() * total
	for cname in pool:
		roll -= CHUNKS[cname][0]
		if roll <= 0.0:
			_last_chunk = cname
			CHUNKS[cname][2].call(d)
			return

func _clamp_y() -> void:
	cur_y = clampf(cur_y, MIN_Y, MAX_Y)

func _coin_line(x: float, y: float, n: int, spacing: float = 70.0) -> void:
	for i in n:
		_place(Pieces.coin(x + i * spacing, y, glow), 20.0)

func _coin_arc(x: float, y: float, w: float, height: float) -> void:
	var n := 5
	for i in n:
		var t := float(i) / (n - 1)
		var cy := y - sin(t * PI) * height
		_place(Pieces.coin(x + t * w, cy, glow), 20.0)

# ------------------------------------------------------------------- chunks

func _chunk_flat(d: float) -> void:
	var w := _rng.randf_range(500.0, 850.0)
	_place(Pieces.platform(next_x, cur_y, w, rim), w)
	if _rng.randf() < 0.6:
		_coin_line(next_x + 120.0, cur_y - 70.0, _rng.randi_range(3, 5))
	next_x += w

func _chunk_gap(d: float) -> void:
	var run := _rng.randf_range(340.0, 520.0)
	_place(Pieces.platform(next_x, cur_y, run, rim), run)
	next_x += run
	var gap := lerpf(170.0, 340.0, d) * _rng.randf_range(0.85, 1.1)
	_coin_arc(next_x - 30.0, cur_y - 60.0, gap + 60.0, 130.0)
	next_x += gap
	cur_y += _rng.randf_range(-110.0, 130.0)
	_clamp_y()
	var land := _rng.randf_range(420.0, 640.0)
	_place(Pieces.platform(next_x, cur_y, land, rim), land)
	next_x += land

func _chunk_vault(d: float) -> void:
	var w := _rng.randf_range(620.0, 900.0)
	_place(Pieces.platform(next_x, cur_y, w, rim), w)
	var boxes := 1 + (1 if d > 0.4 and _rng.randf() < 0.5 else 0)
	for i in boxes:
		var bx := next_x + w * (0.4 + 0.3 * i)
		_place(Pieces.vault_box(bx, cur_y, rim), 64.0)
		_place(Pieces.coin(bx + 32.0, cur_y - 120.0, glow), 20.0)
	next_x += w

func _chunk_slide(d: float) -> void:
	var w := _rng.randf_range(640.0, 880.0)
	_place(Pieces.platform(next_x, cur_y, w, rim), w)
	_place(Pieces.slide_barrier(next_x + w * 0.5, cur_y, ray), 120.0)
	_coin_line(next_x + w * 0.5 + 10.0, cur_y - 28.0, 3, 50.0)
	next_x += w

func _chunk_stairs_up(d: float) -> void:
	var steps := _rng.randi_range(2, 3)
	for i in steps:
		var w := _rng.randf_range(300.0, 420.0)
		_place(Pieces.platform(next_x, cur_y, w, rim), w)
		if _rng.randf() < 0.4:
			_place(Pieces.coin(next_x + w * 0.5, cur_y - 80.0, glow), 20.0)
		next_x += w + lerpf(120.0, 200.0, d)
		cur_y -= _rng.randf_range(90.0, 140.0)
		_clamp_y()

func _chunk_drop(d: float) -> void:
	var w := _rng.randf_range(360.0, 520.0)
	_place(Pieces.platform(next_x, cur_y, w, rim), w)
	next_x += w + _rng.randf_range(80.0, 160.0)
	cur_y += _rng.randf_range(180.0, 300.0)   # big drop → tests the landing roll
	_clamp_y()
	var land := _rng.randf_range(500.0, 700.0)
	_place(Pieces.platform(next_x, cur_y, land, rim), land)
	_coin_line(next_x + 150.0, cur_y - 60.0, 3)
	next_x += land

func _chunk_wall(d: float) -> void:
	var run := _rng.randf_range(400.0, 560.0)
	_place(Pieces.platform(next_x, cur_y, run, rim), run)
	next_x += run
	# Wall rises from the current ground — wall-run or mantle up it.
	# Hard cap ~240px: wall-run rise (160) + ledge-catch window (86) is the
	# guaranteed auto-climb ceiling; a well-timed wall-jump clears far more.
	var h := lerpf(120.0, 215.0, d) * _rng.randf_range(0.9, 1.1)
	var wall_w := _rng.randf_range(320.0, 480.0)
	_place(Pieces.wall(next_x, cur_y, h, wall_w, rim), wall_w)
	_place(Pieces.coin(next_x + wall_w * 0.5, cur_y - h - 70.0, glow), 20.0)
	next_x += wall_w
	cur_y -= h
	_clamp_y()

func _chunk_spike_gap(d: float) -> void:
	var run := _rng.randf_range(380.0, 520.0)
	_place(Pieces.platform(next_x, cur_y, run, rim), run)
	next_x += run
	# Hazard floor below a jumpable pit — falling short is fatal.
	var pit := lerpf(200.0, 330.0, d)
	_place(Pieces.platform(next_x, cur_y + 150.0, pit, rim, false), pit)
	_place(Pieces.floor_hazard(next_x, cur_y + 150.0, pit, ray), pit)
	_coin_arc(next_x - 20.0, cur_y - 50.0, pit + 40.0, 120.0)
	next_x += pit
	var land := _rng.randf_range(460.0, 640.0)
	_place(Pieces.platform(next_x, cur_y, land, rim), land)
	next_x += land

func _chunk_gauntlet(d: float) -> void:
	# Late-game combo: vault box → laser → gap, back to back.
	var w := 1050.0
	_place(Pieces.platform(next_x, cur_y, w, rim), w)
	_place(Pieces.vault_box(next_x + 260.0, cur_y, rim), 64.0)
	_place(Pieces.slide_barrier(next_x + 620.0, cur_y, ray), 120.0)
	_coin_line(next_x + 640.0, cur_y - 28.0, 3, 50.0)
	next_x += w
	var gap := lerpf(200.0, 320.0, d)
	next_x += gap
	var land := _rng.randf_range(480.0, 660.0)
	_place(Pieces.platform(next_x, cur_y, land, rim), land)
	next_x += land

func _chunk_tower_ledge(d: float) -> void:
	# A gap onto a tall tower face: you hit the wall mid-air → ledge grab → climb.
	var run := _rng.randf_range(380.0, 500.0)
	_place(Pieces.platform(next_x, cur_y, run, rim), run)
	next_x += run
	var gap := lerpf(180.0, 260.0, d)
	next_x += gap
	var h := _rng.randf_range(60.0, 130.0)   # tower top slightly above current ground
	var tw := _rng.randf_range(360.0, 520.0)
	_place(Pieces.wall(next_x, cur_y, h, tw, rim), tw)
	_place(Pieces.coin(next_x + 60.0, cur_y - h - 70.0, glow), 20.0)
	next_x += tw
	cur_y -= h
	_clamp_y()
