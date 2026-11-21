shader_type canvas_item;
// KFMod-era grit (DESIGN_DOC §7): animated film grain + subtle vignette
// applied over the finished frame via a fullscreen ColorRect.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.42;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	// fract(TIME) keeps the hash input small — large TIME values degrade
	// sin() precision and the grain freezes into a static pattern.
	float n = hash(SCREEN_UV * 977.0 + vec2(fract(TIME * 13.37) * 100.0)) - 0.5;
	col += n * grain_strength;
	float d = length(SCREEN_UV - vec2(0.5));
	col *= 1.0 - smoothstep(vignette_start, 0.95, d) * vignette_strength;
	COLOR = vec4(col, 1.0);
}
