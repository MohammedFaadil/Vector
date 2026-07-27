extends Node
## AudioManager (autoload) — audio buses, pooled SFX players, music crossfade.
## SFX players are pooled (12 voices) so rapid parkour never allocates at runtime.

const SFX_VOICES := 12

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_track := ""
var _music_tw: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # audio keeps working while paused
	_build_buses()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	_active_music = _music_a
	SettingsManager.apply_all_volumes()

func _build_buses() -> void:
	# Master already exists at index 0; add Music and SFX routed into it.
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# Gentle limiter on Master so stacked SFX never clip harshly.
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.0
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, lim)

## Play a named one-shot from SfxFactory (or any AudioStream you swapped in).
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = SfxFactory.sounds.get(sound_name)
	if stream == null:
		return
	var p := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## Slight random pitch keeps repeated sounds (footsteps, coins) organic.
func play_varied(sound_name: String, volume_db: float = 0.0) -> void:
	play(sound_name, volume_db, randf_range(0.92, 1.08))

## Crossfade to a looping theme pad ("dusk" / "storm" / "neon" / "menu").
func play_music(track: String, fade_time: float = 2.0) -> void:
	if track == _current_track:
		return
	_current_track = track
	var stream: AudioStream = SfxFactory.music.get(track)
	if stream == null:
		return
	var incoming := _music_b if _active_music == _music_a else _music_a
	var outgoing := _active_music
	# Kill any in-flight crossfade: its pending stop() callback targets the
	# player we are about to reuse and would silence the new track.
	if _music_tw and _music_tw.is_valid():
		_music_tw.kill()
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_music_tw = create_tween()
	_music_tw.set_parallel(true)
	_music_tw.tween_property(incoming, "volume_db", 0.0, fade_time)
	_music_tw.tween_property(outgoing, "volume_db", -40.0, fade_time)
	_music_tw.chain().tween_callback(outgoing.stop)
	_active_music = incoming

func stop_music(fade_time: float = 1.0) -> void:
	_current_track = ""
	if _music_tw and _music_tw.is_valid():
		_music_tw.kill()
	_music_tw = create_tween()
	_music_tw.tween_property(_active_music, "volume_db", -40.0, fade_time)
	_music_tw.tween_callback(_active_music.stop)
