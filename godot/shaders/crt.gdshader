shader_type canvas_item;
// Godot-only CRT filter over everything (game, HUD, menus): slight barrel curvature,
// a scanline on every game pixel row, an aperture-grille mask and soft corners.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float curve = 0.035;
uniform float scan = 0.28;      // how dark the gap between rows is
uniform float mask = 0.12;      // strength of the RGB stripes

void fragment() {
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	c *= 1.0 + curve * dot(c, c);
	vec2 uv = c * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 col = texture(screen_tex, uv).rgb;
		// rows of the 480x270 game: darker towards the edge of each row
		float row = fract(uv.y * 270.0);
		col *= 1.0 - scan * smoothstep(0.55, 1.0, abs(row - 0.5) * 2.0);
		int stripe = int(mod(FRAGCOORD.x, 3.0));
		vec3 m = stripe == 0 ? vec3(1.0, 1.0 - mask, 1.0 - mask) : (stripe == 1 ? vec3(1.0 - mask, 1.0, 1.0 - mask) : vec3(1.0 - mask, 1.0 - mask, 1.0));
		col *= m * (1.0 + mask * 0.6);
		// soft corners
		vec2 e = smoothstep(vec2(1.0), vec2(0.96), abs(c));
		COLOR = vec4(col * e.x * e.y, 1.0);
	}
}
