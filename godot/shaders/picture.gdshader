shader_type canvas_item;
// Godot-only: brightness, contrast and saturation like the environment
// adjustments (apply_bcs in Godot's tonemap shader), for the room's details that
// are drawn above the 3D view. The HUD has none of them.

uniform vec3 bcs = vec3(1.0);   // brightness, contrast, saturation

void fragment() {
	vec3 c = COLOR.rgb * bcs.x;
	c = mix(vec3(0.5), c, bcs.y);
	c = mix(vec3(dot(c, vec3(1.0)) / 3.0), c, bcs.z);
	COLOR.rgb = c;
}
