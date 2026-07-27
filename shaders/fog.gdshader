// Two layers of drifting procedural fog (value noise), parallax-scrolled
// by the camera via cam_x. Sits between background and gameplay.
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(1.0, 0.7, 0.4, 0.12);
uniform float time_s = 0.0;
uniform float cam_x = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float height_falloff : hint_range(0.1, 5.0) = 1.5;
uniform float wind_speed : hint_range(0.0, 0.1) = 0.02;
uniform float turbulence : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 6; i++) {
        if (i >= octaves) break;
        v += noise(p * freq) * a;
        a *= 0.5;
        freq *= 2.1;
    }
    return v;
}

float ridged_fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 5; i++) {
        float n = noise(p * freq);
        n = 1.0 - abs(n * 2.0 - 1.0); // Ridged noise
        n = n * n; // Sharpen ridges
        v += n * a;
        a *= 0.5;
        freq *= 2.0;
    }
    return v;
}

void fragment() {
    vec2 uv = UV;
    
    // Wind drift with camera parallax
    float drift = time_s * wind_speed + cam_x * 0.00006;
    
    // Layer 1: Low-lying ground fog (wider, slower)
    float n1 = fbm(vec2(uv.x * 3.0 + drift, uv.y * 2.0), 5);
    
    // Layer 2: Mid-height atmospheric haze (finer, faster opposite direction)
    float n2 = fbm(vec2(uv.x * 5.0 - drift * 1.6 + 7.0, uv.y * 3.5 + 3.0), 4);
    
    // Layer 3: High altitude wisps (ridged for cloud-like shapes)
    float n3 = ridged_fbm(vec2(uv.x * 2.0 + drift * 0.5, uv.y * 1.5 + 10.0));
    
    // Height-based fog distribution - hugs the lower-middle band of the frame
    float band = smoothstep(0.25, 0.55, uv.y) * smoothstep(1.05, 0.65, uv.y);
    
    // Add vertical gradient for ground-hugging fog
    float ground_fog = smoothstep(0.8, 0.4, uv.y);
    
    // Combine layers with different weights
    float a = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2);
    
    // Apply turbulence for organic movement
    a += turbulence * fbm(vec2(uv.x * 10.0 + time_s * 0.05, uv.y * 8.0), 3) * 0.1;
    
    // Smooth the fog edges
    a = smoothstep(0.25, 0.85, a) * band;
    
    // Add ground fog layer
    a = max(a, ground_fog * 0.3 * density * smoothstep(0.3, 0.8, n1));
    
    // Distance fog - increases with depth (simulated by Y position in 2.5D)
    float depth_fog = smoothstep(0.3, 0.8, uv.y) * 0.2 * density;
    a += depth_fog;
    
    // Clamp and apply color
    a = clamp(a * density, 0.0, 1.0);
    
    // Volumetric lighting interaction - fog catches light
    vec3 lit_color = fog_color.rgb;
    float light_catch = smoothstep(0.4, 0.7, uv.y) * 0.3; // Catch light from above
    lit_color += vec3(1.0, 0.8, 0.5) * light_catch * density * 0.5;
    
    COLOR = vec4(lit_color, a * fog_color.a);
}