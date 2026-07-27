extends Node
## SettingsManager (autoload) — quality presets, volumes, fullscreen.
## Persisted to user://settings.cfg. Loaded before everything else.

signal quality_changed(preset: int)

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const SAVE_PATH := "user://settings.cfg"

var quality: int = Quality.HIGH
var music_volume: float = 0.8   # 0..1
var sfx_volume: float = 0.9    # 0..1
var fullscreen: bool = true

## Per-preset feature switches, read by FX systems at (re)build time.
## Everything stays within the 60fps / 6GB VRAM budget even on ULTRA.
func particles_scale() -> float:
	return [0.35, 0.6, 1.0, 1.3][quality]

func glow_enabled() -> bool:
	return quality >= Quality.MEDIUM

func post_fx_enabled() -> bool:
	return quality >= Quality.MEDIUM

func god_rays_enabled() -> bool:
	return quality >= Quality.HIGH

func fog_enabled() -> bool:
	return quality >= Quality.MEDIUM

func trails_enabled() -> bool:
	return quality >= Quality.HIGH

func _ready() -> void:
	load_settings()
	apply_window()

func apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))

func set_quality(q: int) -> void:
	quality = clampi(q, Quality.LOW, Quality.ULTRA)
	save_settings()
	quality_changed.emit(quality)

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	save_settings()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_window()
	save_settings()

func _apply_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)

func apply_all_volumes() -> void:
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = cfg.get_value("video", "quality", Quality.HIGH)
	fullscreen = cfg.get_value("video", "fullscreen", true)
	music_volume = cfg.get_value("audio", "music", 0.8)
	sfx_volume = cfg.get_value("audio", "sfx", 0.9)
