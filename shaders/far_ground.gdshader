// The far country (FarLand), painted as ground.gdshader paints the banks: its own colour (vertex
// colour) lit by hand, unshaded. Out past the banks it is laid over with a patchwork of fields in the
// world's own coordinates (so they stay put as the boat goes by): stubble, ploughed earth in
// furrows, pale straw, pasture gone gold, with dark hedges between them. The haze does the rest.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

uniform vec3 sun_dir = vec3(0.18, 0.11, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.5);
// Where the patchwork begins, out from the middle of the river (m), and where it is all patchwork.
uniform vec2 fields_from = vec2(150.0, 260.0);

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// The fields: a grid turned a little, each row of it slid along by its own amount
	vec2 at = mat2(vec2(0.96, 0.28), vec2(-0.28, 0.96)) * world.xz;
	vec2 cell_size = vec2(64.0, 42.0);
	float row = floor(at.y / cell_size.y);
	vec2 shifted = vec2(at.x + hash(vec2(row, 1.0)) * cell_size.x, at.y);
	vec2 cell = floor(shifted / cell_size);
	vec2 inside = fract(shifted / cell_size) * cell_size;
	float pick = hash(cell);
	vec3 field = vec3(0.80, 0.62, 0.32);                       // stubble
	if (pick < 0.22) {
		field = vec3(0.50, 0.34, 0.20);                        // ploughed earth, in furrows
		field *= 0.9 + 0.12 * step(0.5, fract(inside.x / 2.2));
	} else if (pick < 0.42) {
		field = vec3(0.88, 0.74, 0.44);                        // pale straw
	} else if (pick < 0.62) {
		field = vec3(0.62, 0.56, 0.28);                        // pasture, gone gold
	} else if (pick < 0.72) {
		field = vec3(0.70, 0.42, 0.20);                        // rust
	}
	field *= 0.94 + 0.08 * hash(cell + 7.0);
	// the hedges round them
	float px = max(fwidth(at.x), 0.02);
	float edge = min(min(inside.x, cell_size.x - inside.x), min(inside.y, cell_size.y - inside.y));
	float hedge = 1.0 - smoothstep(1.2, 1.2 + px * 1.5, edge);
	field = mix(field, vec3(0.36, 0.24, 0.14), hedge * 0.8);
	float out_x = abs(world.x);
	base = mix(base, field, smoothstep(fields_from.x, fields_from.y, out_x));
	float grain = hash(floor(world.xz * 3.0)) * 0.1 + hash(floor(world.xz * 0.7)) * 0.08;
	// (flat ground, lit as ground.gdshader lights the banks' flat tops)
	float lit = clamp(normalize(sun_dir).y * 1.6 + 0.55, 0.0, 1.0);
	ALBEDO = base * (0.92 + grain) * mix(vec3(0.42, 0.4, 0.48), sun_color * 0.88, lit);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
