// Volumetric light shafts radiating from the sun position, animated slowly.
// Runs on a screen-sized ColorRect in the background layer — additive feel
// via alpha, cheap enough for the 60fps budget.
shader_type canvas_item;

uniform vec2 sun_uv = vec2(0.68, 0.35);
uniform vec4 ray_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float time_s = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float decay : hint_range(0.8, 0.99) = 0.95;
uniform float weight : hint_range(0.1, 1.0) = 0.6;
uniform float exposure : hint_range(0.1, 2.0) = 1.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
               mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    v += noise(p) * 0.5;
    v += noise(p * 2.0) * 0.25;
    v += noise(p * 4.0) * 0.125;
    v += noise(p * 8.0) * 0.0625;
    return v;
}

void fragment() {
    vec2 d = UV - sun_uv;
    float ang = atan(d.y, d.x);
    float dist = length(d);
    
    // Layered rotating ray bands with noise modulation
    float rays = 0.0;
    rays += sin(ang * 9.0 + time_s * 0.11) * 0.5 + 0.5;
    rays += (sin(ang * 17.0 - time_s * 0.07) * 0.5 + 0.5) * 0.6;
    rays += (sin(ang * 5.0 + time_s * 0.05) * 0.5 + 0.5) * 0.3;
    rays *= 0.4;
    rays = pow(rays, 2.4);
    
    // Add volumetric noise for atmospheric scattering
    float atmo_noise = fbm(vec2(UV.x * 8.0 + time_s * 0.02, UV.y * 6.0 + time_s * 0.015));
    rays *= 0.7 + 0.3 * atmo_noise;
    
    // Fade with distance from sun, and never brighten the very bottom (gameplay area).
    float fall = smoothstep(1.1, 0.05, dist);
    float floor_fade = smoothstep(1.0, 0.55, UV.y);
    float a = rays * fall * floor_fade * strength * density;
    
    // Halo right at the sun with corona effect
    float corona = smoothstep(0.18, 0.0, dist) * 0.35 * strength;
    float corona_ring = smoothstep(0.25, 0.18, dist) * 0.15 * strength * (0.5 + 0.5 * sin(time_s * 2.0));
    a += corona + corona_ring;
    
    // Lens flare ghosting
    float ghost_dist = length(UV - (vec2(1.0) - sun_uv));
    float ghost = smoothstep(0.15, 0.0, ghost_dist) * 0.08 * strength * (1.0 - dist);
    
    vec3 final_color = ray_color.rgb * (a + ghost);
    final_color *= exposure;
    
    // Tone map the god rays
    final_color = final_color / (final_color + vec3(1.0));
    
    COLOR = vec4(final_color, a * ray_color.a + ghost * 0.5);
}