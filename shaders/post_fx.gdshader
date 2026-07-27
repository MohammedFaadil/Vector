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
uniform float exposure : hint_range(0.5, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 bloom_threshold = vec3(1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

vec3 filmic_tonemap(vec3 color) {
	// ACES filmic tone mapping
	color *= exposure;
	vec3 x = max(vec3(0.0), color - 0.004);
	return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

vec3 apply_color_grading(vec3 color) {
	// Lift shadows
	color = color * grade_tint + grade_lift * (1.0 - color);
	
	// Contrast
	color = mix(vec3(0.5), color, contrast);
	
	// Saturation
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, saturation);
	
	return color;
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
	col = apply_color_grading(col);
	
	// Vignette, tightening slightly at speed for tunnel-vision.
	float vig = smoothstep(0.85, 0.35 - speed_warp * 0.1, r);
	col *= mix(1.0 - vignette_strength, 1.0, vig);
	
	// Speed lines / radial blur at edges when sprinting
	if (speed_warp > 0.1) {
		float speed_lines = smoothstep(0.7, 1.0, r) * speed_warp * 0.3;
		vec2 blur_uv = uv + c * speed_lines * 0.02;
		vec3 blur_col = texture(screen_tex, blur_uv).rgb;
		col = mix(col, blur_col, speed_lines);
	}
	
	// Animated film grain.
	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(time_s * 60.0));
	col += (g - 0.5) * grain_strength;
	
	// Subtle scanlines for cinematic feel
	float scanline = sin(uv.y * 1080.0 * 1.5 + time_s * 0.5) * 0.02;
	col += scanline;
	
	// Filmic tone mapping
	col = filmic_tonemap(col);
	
	// Gamma correction
	col = pow(col, vec3(1.0 / 2.2));
	
	COLOR = vec4(col, 1.0);
}