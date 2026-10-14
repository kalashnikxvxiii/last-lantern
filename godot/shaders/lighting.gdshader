shader_type canvas_item;
render_mode blend_premul_alpha;
// Darkness and warm glow from drawLighting (js/render.js) in a single pass.
// Darkness: color #050309 with opacity amb; each light removes opacity with the JS
// radial gradient (inner radius 0.12 r, alpha stops a / 0.6 a / 0), and the lights
// combine by multiplying (destination-out). Glow: additive gradient from the light
// color to black within 0.8 r. With premultiplied alpha the result is
// dst * (1 - a) + DARK * a + glow, the same as the two JS layers.
// Godot-only: the first shadow_n lights cast soft shadows through the occluder
// mask (walls, rocks, barrels), and ambient occlusion darkens the floor next to them.
// Godot-only: the glow depends on the material. On matte rock (sheen 0) it tints
// the colors under it, so dark cracks stay dark; on glossy ground (sheen 1) it is
// added over them like in the JS.

uniform float amb = 0.68;
uniform int count = 0;
uniform vec4 lights[128];   // x, y, radius, alpha in 480x270 screen coordinates
uniform vec4 colors[128];   // r, g, b, intensity (0 = no glow)
uniform int shadow_n = 0;
uniform int shadow_steps = 0;
uniform float ao = 0.0;
uniform sampler2D occ : filter_linear, repeat_disable;
uniform vec2 room_pos;      // top-left corner of the room on screen
uniform float sheen = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

const vec3 DARK = vec3(5.0, 3.0, 9.0) / 255.0;
const float R0 = 0.12;
const float R1 = 0.12 + 0.55 * 0.88;   // second gradient stop
const vec2 ROOM = vec2(29.0 * 16.0, 15.0 * 16.0);
const float DIFFUSE = 4.0;   // matte glow on a typical floor (albedo ~0.25) as bright as the added one

float falloff(float k) {
	if (k <= R0) return 1.0;
	if (k <= R1) return mix(1.0, 0.6, (k - R0) / (R1 - R0));
	if (k < 1.0) return mix(0.6, 0.0, (k - R1) / (1.0 - R1));
	return 0.0;
}

float occ_at(vec2 p) {
	vec2 uv = (p - room_pos) / ROOM;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return texture(occ, uv).r;
}

// light reaching p from l: marches from the light to the pixel; a pixel that is
// itself on an occluder stops a little early, so the side facing the light is lit
float visibility(vec2 p, vec2 l, float self_occ, float jitter) {
	vec2 d = p - l;
	float len = length(d);
	float end = len - (self_occ > 0.5 ? 8.0 : 1.0);
	float start = 3.0;
	if (end <= start) return 1.0;
	vec2 dir = d / len;
	float stp = (end - start) / float(shadow_steps);
	float vis = 1.0;
	for (int i = 0; i < shadow_steps; i++) {
		float t = start + (float(i) + jitter) * stp;
		vis *= 1.0 - occ_at(l + dir * t);
		if (vis < 0.01) return 0.0;
	}
	return vis;
}

float ambient_occlusion(vec2 p) {
	float s = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.39;
		vec2 o = vec2(cos(a), sin(a));
		s += occ_at(p + o * 5.0) + occ_at(p + o * 10.0) * 0.6;
	}
	return clamp(s / 8.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * vec2(480.0, 270.0);
	float self_occ = shadow_steps > 0 || ao > 0.0 ? occ_at(p) : 0.0;
	float jitter = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	float a = amb;
	vec3 sum = vec3(0.0);
	for (int i = 0; i < count; i++) {
		vec4 L = lights[i];
		float d = distance(p, L.xy);
		if (d >= L.z) continue;
		float vis = 1.0;
		if (i < shadow_n && shadow_steps > 0) vis = visibility(p, L.xy, self_occ, jitter);
		a *= 1.0 - L.w * falloff(d / L.z) * vis;
		vec4 C = colors[i];
		float r = L.z * 0.8;
		if (C.a > 0.0 && d < r) sum += C.rgb * C.a * (1.0 - d / r) * vis;
	}
	if (ao > 0.0 && self_occ < 0.5) a = 1.0 - (1.0 - a) * (1.0 - ao * ambient_occlusion(p));
	if (sheen < 1.0) sum *= mix(texture(screen_tex, SCREEN_UV).rgb * DIFFUSE, vec3(1.0), sheen);
	COLOR = vec4(DARK * a + sum, a);
}
