extends Node2D
## Main orchestrator. Builds the entire game at runtime — background, world,
## player, camera, FX, HUD, menus — wires the signals, and drives the
## menu → run → death → restart loop. This is the only scene in the project.

const SPAWN := Vector2(200, 640)   # exactly on the starting rooftop

var player: Player
var cam: GameCamera
var generator: LevelGenerator
var background: GameBackground
var effects: EffectsManager
var hud: Hud
var menus: Menus
var world: Node2D

func _ready() -> void:
	# Must keep processing while the tree is paused, or the pause/restart keys
	# go dead the moment we pause. Gameplay itself is state-guarded, not
	# pause-guarded, so this is safe.
	process_mode = Node.PROCESS_MODE_ALWAYS

	background = GameBackground.new()
	add_child(background)

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	generator = LevelGenerator.new()
	world.add_child(generator)

	player = Player.build()
	world.add_child(player)

	cam = GameCamera.new()
	cam.target = player
	add_child(cam)

	effects = EffectsManager.new()
	add_child(effects)
	effects.setup(player, cam, world)

	hud = Hud.new()
	add_child(hud)

	menus = Menus.new()
	add_child(menus)
	menus.play_pressed.connect(_start_run)
	menus.restart_pressed.connect(_start_run)
	menus.menu_pressed.connect(_to_menu)
	menus.quit_pressed.connect(func(): get_tree().quit())

	player.died.connect(_on_player_died)
	player.did_move.connect(func(_m, perfect):
		if perfect:
			hud.flash_perfect())

	# Boot state: menu over a frozen, pretty world.
	generator.reset()
	player.reset(SPAWN)
	cam.snap_to(player.global_position)
	GameManager.to_menu()
	menus.show_main()

func _start_run() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	generator.reset()
	player.reset(SPAWN)
	cam.snap_to(player.global_position)
	menus.hide_all()
	GameManager.start_run()

func _to_menu() -> void:
	GameManager.to_menu()
	generator.reset()
	player.reset(SPAWN)
	cam.snap_to(player.global_position)
	menus.show_main()

func _on_player_died() -> void:
	# Let the slow-mo dissolve play, then bring up the results screen.
	get_tree().create_timer(1.1, true, false, true).timeout.connect(func():
		if GameManager.state == GameManager.State.DEAD:
			menus.show_game_over())

func _process(_delta: float) -> void:
	generator.update_generation(cam.global_position.x)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match GameManager.state:
			GameManager.State.PLAYING:
				GameManager.pause_game()
				menus.show_pause()
			GameManager.State.PAUSED:
				menus.hide_all()
				GameManager.resume_game()
	elif event.is_action_pressed("restart"):
		if GameManager.state == GameManager.State.DEAD or GameManager.state == GameManager.State.PLAYING:
			_start_run()
