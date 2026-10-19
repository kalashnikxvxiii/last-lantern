shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Godot-only: the walls and rocks of the 3D view (View3D.build_solids). Where they
// stand between the camera and the player they open a round hole, dithered at its
// edge, so the player is never lost behind them (View3D.seen_through).

uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 eye = vec3(0.0, -10000.0, 0.0);   // the middle of the player's sprite
uniform vec3 cam;
uniform float front = 10000.0;   // the player's place (z): the walls behind it cover nothing of them
uniform float radius = 20.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec3 d = normalize(cam - eye);
	float t = dot(wpos - eye, d);
	if (t > 0.0 && wpos.z > front) {
		float r = length(wpos - eye - d * t);
		// 4x4 ordered dither: the hole's last third thins out instead of a hard edge
		ivec2 f = ivec2(FRAGCOORD.xy) % 4;
		int b[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if (smoothstep(radius, radius * 0.66, r) > (float(b[f.y * 4 + f.x]) + 0.5) / 16.0) {
			discard;
		}
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
