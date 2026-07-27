// Two layers of drifting procedural fog (value noise), parallax-scrolled
// by the camera via cam_x. Sits between background and gameplay.
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(1.0, 0.7, 0.4, 0.12);
uniform float time_s = 0.0;
uniform float cam_x = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += noise(p) * 0.55;
	v += noise(p * 2.1) * 0.28;
	v += noise(p * 4.3) * 0.17;
	return v;
}

void fragment() {
	vec2 uv = UV;
	float drift = time_s * 0.02 + cam_x * 0.00006;
	float n1 = fbm(vec2(uv.x * 3.0 + drift, uv.y * 2.0));
	float n2 = fbm(vec2(uv.x * 5.0 - drift * 1.6 + 7.0, uv.y * 3.5 + 3.0));
	// Fog hugs the lower-middle band of the frame.
	float band = smoothstep(0.25, 0.65, uv.y) * smoothstep(1.05, 0.7, uv.y);
	float a = (n1 * 0.6 + n2 * 0.4);
	a = smoothstep(0.35, 0.85, a) * band;
	COLOR = vec4(fog_color.rgb, a * fog_color.a);
}
