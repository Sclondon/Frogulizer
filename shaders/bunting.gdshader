// Little flags on a string, fluttering in the wind of the boat's going: each
// swings back and twists a little, the tip most (UV.y: 0 on the string, 1 at
// the tip; UV.x: each flag's own seed). Two tones of light, as everything is.
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 wind = vec3(0.0, 0.0, -1.0);

void vertex() {
	float tip = UV.y;
	float t = TIME * (5.0 + UV.x * 3.0) + UV.x * 40.0;
	VERTEX += (wind * (0.12 + 0.06 * sin(t)) + vec3(sin(t * 1.3), 0.0, 0.0) * 0.05) * tip;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = abs(dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += mix(0.55, 1.0, smoothstep(0.1, 0.3, facing)) * LIGHT_COLOR * ATTENUATION / PI;
}
