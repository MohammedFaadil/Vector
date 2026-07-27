// Atmospheric haze shader - distant atmospheric scattering effect
// Runs behind skylines to add depth and atmosphere
shader_type canvas_item;

uniform vec4 haze_color : source_color = vec4(1.0, 0.7, 0.4, 0.12);
uniform float time_s = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float sun_influence : hint_range(0.0, 1.0) = 0.5;

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
    v += noise(p) * 0.5;
    v += noise(p * 2.1) * 0.25;
    v += noise(p * 4.3) * 0.125;
    v += noise(p * 8.5) * 0.0625;
    return v;
}

void fragment() {
    vec2 uv = UV;
    
    // Atmospheric haze is strongest at horizon, fades upward
    float horizon = smoothstep(0.3, 0.6, uv.y);
    float zenith = 1.0 - smoothstep(0.6, 0.9, uv.y);
    float vertical_falloff = horizon * zenith;
    
    // Noise for atmospheric variation
    float drift = time_s * 0.005;
    float n1 = fbm(vec2(uv.x * 2.0 + drift, uv.y * 1.5));
    float n2 = fbm(vec2(uv.x * 4.0 - drift * 1.5 + 5.0, uv.y * 2.5 + 2.0));
    
    // Combine noise layers
    float atmo = (n1 * 0.6 + n2 * 0.4);
    atmo = smoothstep(0.3, 0.8, atmo);
    
    // Sun glow influence (brightens haze near sun position)
    // This would ideally receive sun_uv from the background
    float sun_glow = 0.0;
    // Approximate sun position based on time
    vec2 approx_sun = vec2(0.68, 0.35);
    float sun_dist = length(uv - approx_sun);
    sun_glow = smoothstep(0.4, 0.0, sun_dist) * sun_influence;
    
    // Final haze intensity
    float a = atmo * vertical_falloff * density * intensity;
    a += sun_glow * vertical_falloff * 0.3 * intensity;
    
    // Color - warmer near horizon, cooler at zenith
    vec3 col = haze_color.rgb;
    float temp = smoothstep(0.4, 0.7, uv.y);
    col = mix(col, vec3(1.0, 0.9, 0.7), temp * 0.5); // Warmer at horizon
    col = mix(col, vec3(0.6, 0.7, 0.9), (1.0 - temp) * 0.3); // Cooler at zenith
    
    COLOR = vec4(col, a * haze_color.a);
}