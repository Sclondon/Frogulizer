// A light bulb on the bandstand: warm, glowing as hard as `glow` says (the music).
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.78, 0.42);
uniform float glow = 1.0;

void fragment() {
	// (each bulb flickers a little on its own)
	vec3 at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float flicker = 0.9 + 0.1 * sin(TIME * 11.0 + at.x * 13.0 + at.y * 7.0);
	ALBEDO = colour * (0.6 + 0.5 * glow * flicker);
}
