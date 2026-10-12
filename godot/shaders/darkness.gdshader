shader_type canvas_item;
// Darkness layer from drawLighting (js/render.js): color #050309 with opacity amb;
// each light removes opacity with the JS radial gradient (inner radius 0.12 r,
// alpha stops a / 0.6 a / 0), and the lights combine by multiplying (destination-out).

uniform float amb = 0.68;
uniform int count = 0;
uniform vec4 lights[128];   // x, y, radius, alpha in 480x270 screen coordinates

const vec3 DARK = vec3(5.0, 3.0, 9.0) / 255.0;
const float R0 = 0.12;
const float R1 = 0.12 + 0.55 * 0.88;   // second gradient stop

float falloff(float k) {
	if (k <= R0) return 1.0;
	if (k <= R1) return mix(1.0, 0.6, (k - R0) / (R1 - R0));
	if (k < 1.0) return mix(0.6, 0.0, (k - R1) / (1.0 - R1));
	return 0.0;
}

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	float a = amb;
	for (int i = 0; i < count; i++) {
		vec4 L = lights[i];
		float d = distance(p, L.xy);
		if (d < L.z) a *= 1.0 - L.w * falloff(d / L.z);
	}
	COLOR = vec4(DARK, a);
}
