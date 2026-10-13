shader_type canvas_item;
render_mode blend_add;
// Godot-only bloom: bright, colored pixels of the lit scene spill a soft halo.
// The threshold is applied to every tap before blurring, so small bright things
// (projectiles, embers) glow too; grey and white pixels (bones, text) barely count.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 1.0;
uniform float threshold = 0.45;
uniform float radius = 10.0;   // in game pixels

const int TAPS = 32;
const float GOLDEN = 2.39996323;

vec3 bright(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
	return c * smoothstep(threshold, 1.0, mx) * sqrt(sat);
}

void fragment() {
	// one game pixel in screen UV (the game is 480x270)
	vec2 px = vec2(1.0 / 480.0, 1.0 / 270.0);
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float k = (float(i) + 0.5) / float(TAPS);
		float r = sqrt(k) * radius;
		float a = float(i) * GOLDEN;
		vec2 uv = SCREEN_UV + vec2(cos(a), sin(a)) * r * px;
		float w = exp(-2.5 * k);
		sum += bright(textureLod(screen_tex, uv, 1.0).rgb) * w;
		wsum += w;
	}
	COLOR = vec4(sum / wsum * intensity * 3.5, 1.0);
}
