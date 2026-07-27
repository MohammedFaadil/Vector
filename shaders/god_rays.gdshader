// Volumetric light shafts radiating from the sun position, animated slowly.
// Runs on a screen-sized ColorRect in the background layer — additive feel
// via alpha, cheap enough for the 60fps budget.
shader_type canvas_item;

uniform vec2 sun_uv = vec2(0.68, 0.35);
uniform vec4 ray_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float time_s = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 d = UV - sun_uv;
	float ang = atan(d.y, d.x);
	float dist = length(d);
	// Layered rotating ray bands.
	float rays = 0.0;
	rays += sin(ang * 9.0 + time_s * 0.11) * 0.5 + 0.5;
	rays += (sin(ang * 17.0 - time_s * 0.07) * 0.5 + 0.5) * 0.6;
	rays *= 0.625;
	rays = pow(rays, 2.4);
	// Fade with distance from sun, and never brighten the very bottom (gameplay area).
	float fall = smoothstep(1.1, 0.05, dist);
	float floor_fade = smoothstep(1.0, 0.55, UV.y);
	float a = rays * fall * floor_fade * strength;
	// Halo right at the sun.
	a += smoothstep(0.18, 0.0, dist) * 0.35 * strength;
	COLOR = vec4(ray_color.rgb, a * ray_color.a);
}
