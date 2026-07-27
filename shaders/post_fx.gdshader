// Full-screen post stack: vignette, film grain, chromatic aberration,
// speed-lines darkening at the edges, and a per-theme color grade
// (lift + tint). One cheap pass on a fullscreen ColorRect.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;
uniform float aberration : hint_range(0.0, 4.0) = 1.1;
uniform float speed_warp : hint_range(0.0, 1.0) = 0.0; // rises with run speed
uniform vec3 grade_lift = vec3(0.04, 0.02, 0.03);
uniform vec3 grade_tint = vec3(1.0, 0.96, 0.92);
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);

	// Chromatic aberration: split channels radially, stronger at speed.
	float ab = aberration * (1.0 + speed_warp * 2.0) * 0.0015 * r * 2.0;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ab).b;

	// Color grade: lift shadows toward the theme color, tint the whole frame.
	col = col * grade_tint + grade_lift * (1.0 - col);

	// Vignette, tightening slightly at speed for tunnel-vision.
	float vig = smoothstep(0.85, 0.35 - speed_warp * 0.1, r);
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	// Animated film grain.
	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(time_s * 60.0));
	col += (g - 0.5) * grain_strength;

	COLOR = vec4(col, 1.0);
}
