shader_type canvas_item;
render_mode blend_add;
// Bagliore caldo additivo di drawLighting: gradiente dal colore al nero entro 0,8 r.

uniform int count = 0;
uniform vec4 lights[128];   // x, y, raggio, alfa
uniform vec4 colors[128];   // r, g, b, intensità (0 = nessun bagliore)

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < count; i++) {
		if (colors[i].a <= 0.0) continue;
		float r = lights[i].z * 0.8;
		float d = distance(p, lights[i].xy);
		if (d < r) sum += colors[i].rgb * colors[i].a * (1.0 - d / r);
	}
	COLOR = vec4(sum, 1.0);
}
