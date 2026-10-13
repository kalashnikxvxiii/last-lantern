shader_type canvas_item;
// Godot-only post-processing of the game world, above the overlay and below the HUD:
// shockwave distortion, chromatic aberration on hits, biome color grading.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int ring_count = 0;
uniform vec4 rings[8];             // x, y, radius, strength (game pixels)
uniform float aberration = 0.0;    // game pixels at the screen edge
uniform bool grading = false;
uniform vec3 shadows = vec3(0.0);  // added to the dark tones
uniform vec3 highlights = vec3(0.0);   // added to the bright tones
uniform float sat = 1.0;
uniform float contrast = 1.0;

const vec2 GAME = vec2(480.0, 270.0);
const float BAND = 7.0;            // half width of a shockwave ring

void fragment() {
	vec2 uv = SCREEN_UV;
	// shockwaves push the picture outwards along their front
	vec2 p = uv * GAME;
	vec2 push = vec2(0.0);
	for (int i = 0; i < ring_count; i++) {
		vec2 d = p - rings[i].xy;
		float dist = length(d);
		float k = 1.0 - smoothstep(0.0, BAND, abs(dist - rings[i].z));
		if (k > 0.0 && dist > 0.001) push += d / dist * k * rings[i].w;
	}
	uv -= push / GAME;
	vec3 col;
	if (aberration > 0.0) {
		vec2 dir = (uv - 0.5) * 2.0 * aberration / GAME;
		col = vec3(texture(screen_tex, uv + dir).r, texture(screen_tex, uv).g, texture(screen_tex, uv - dir).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (grading) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(lum), col, sat);
		col = (col - 0.18) * contrast + 0.18;   // pivot on the room's dark tones, not mid grey
		col += shadows * (1.0 - lum) * (1.0 - lum) + highlights * lum * lum;
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
