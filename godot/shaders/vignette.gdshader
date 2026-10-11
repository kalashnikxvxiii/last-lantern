shader_type canvas_item;
// Vignettatura di drawLighting: da trasparente a nero 0,55 tra 0,35 H e 0,95 H dal punto (W/2, H/2 + 14).

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	float d = distance(p, vec2(240.0, 149.0));
	float t = clamp((d - 270.0 * 0.35) / (270.0 * 0.6), 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, 0.55 * t);
}
