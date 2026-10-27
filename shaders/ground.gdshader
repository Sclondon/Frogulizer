// Ground painted rather than lit, as GameCommon's painted woodland is: its own
// colour (vertex colour, times `tint`), lighter facing the sun and darker away,
// warmed by the sun's colour. Unshaded, so it sits with the woodland's trees.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 sun_dir = vec3(0.18, 0.11, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.5);
instance uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_normal;
varying vec3 world;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 base = COLOR.rgb * tint;
	// (a scrub of tufts and stubble so it is not flat colour)
	float grain = hash(floor(world.xz * 3.0)) * 0.1 + hash(floor(world.xz * 0.7)) * 0.08;
	float lit = clamp(dot(world_normal, normalize(sun_dir)) * 1.6 + 0.55, 0.0, 1.0);
	ALBEDO = base * (0.92 + grain) * mix(vec3(0.42, 0.4, 0.48), sun_color * 0.88, lit);
}
