class_name LevelThemes
extends RefCounted
## Per-theme mood data: every color and FX intensity for the three level moods.
## dusk  — warm orange sunset, long shadows, drifting haze.
## storm — cold slate blues, heavy fog, dim sun, rain streaks.
## neon  — deep night, cyan/magenta glow, lit windows, strong bloom.

const DATA := {
	"dusk": {
		"sky_top": Color(0.16, 0.09, 0.22),
		"sky_bottom": Color(0.98, 0.52, 0.24),
		"sun_color": Color(1.0, 0.85, 0.6, 0.95),
		"sun_pos": Vector2(0.68, 0.38),
		"skyline_far": Color(0.85, 0.45, 0.38),
		"skyline_mid": Color(0.45, 0.2, 0.28),
		"skyline_near": Color(0.16, 0.07, 0.13),
		"fog_color": Color(1.0, 0.6, 0.35, 0.10),
		"ray_color": Color(1.0, 0.75, 0.45),
		"ray_strength": 0.5,
		"rim": Color(1.0, 0.62, 0.3, 0.35),
		"world_tint": Color(1.0, 0.92, 0.88),
		"grade_lift": Color(0.06, 0.02, 0.04),
		"windows": 0.0,
		"stars": 0.0,
		"rain": 0.0,
	},
	"storm": {
		"sky_top": Color(0.07, 0.09, 0.13),
		"sky_bottom": Color(0.35, 0.42, 0.52),
		"sun_color": Color(0.8, 0.85, 0.95, 0.35),
		"sun_pos": Vector2(0.55, 0.3),
		"skyline_far": Color(0.42, 0.48, 0.58),
		"skyline_mid": Color(0.22, 0.26, 0.34),
		"skyline_near": Color(0.08, 0.1, 0.14),
		"fog_color": Color(0.7, 0.78, 0.9, 0.16),
		"ray_color": Color(0.75, 0.85, 1.0),
		"ray_strength": 0.25,
		"rim": Color(0.7, 0.85, 1.0, 0.3),
		"world_tint": Color(0.82, 0.88, 1.0),
		"grade_lift": Color(0.02, 0.03, 0.06),
		"windows": 0.15,
		"stars": 0.0,
		"rain": 1.0,
	},
	"neon": {
		"sky_top": Color(0.02, 0.01, 0.06),
		"sky_bottom": Color(0.16, 0.05, 0.28),
		"sun_color": Color(0.9, 0.95, 1.0, 0.5),   # moon
		"sun_pos": Vector2(0.78, 0.22),
		"skyline_far": Color(0.3, 0.12, 0.42),
		"skyline_mid": Color(0.14, 0.06, 0.24),
		"skyline_near": Color(0.05, 0.02, 0.1),
		"fog_color": Color(0.5, 0.2, 0.9, 0.12),
		"ray_color": Color(0.4, 0.9, 1.0),
		"ray_strength": 0.35,
		"rim": Color(0.35, 0.9, 1.0, 0.4),
		"world_tint": Color(0.85, 0.9, 1.05),
		"grade_lift": Color(0.03, 0.0, 0.07),
		"windows": 1.0,
		"stars": 1.0,
		"rain": 0.0,
	},
}

static func get_theme(theme_name: String) -> Dictionary:
	return DATA.get(theme_name, DATA["dusk"])
