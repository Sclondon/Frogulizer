// The riverboat's deck: wooden planks running fore and aft, each its own shade of honey brown with
// a wavy grain along it and the odd knot, dark seams between them and butt joints staggered along
// each. Laid in the deck's own space, so the boards go along with the boat. Lit in two flat tones,
// as the frogs are (FrogToon), so it sits with them.
shader_type spatial;

uniform vec3 board : source_color = vec3(0.74, 0.50, 0.27);
uniform vec3 board_alt : source_color = vec3(0.86, 0.62, 0.35);
uniform vec3 grain_colour : source_color = vec3(0.50, 0.30, 0.15);
uniform vec3 seam : source_color = vec3(0.28, 0.16, 0.08);
uniform float board_width = 0.2;
uniform float board_length = 2.6;
// The deck lights up a little with the music (from the scene: Groove.energy).
uniform float glow = 0.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 at = local.xz;
	// how big a pixel is on the deck (m): far off, where a board is only a pixel or two across, each
	// fine thing goes over to its average, so the boards do not shimmer as the boat moves
	float px = max(length(fwidth(at)), 0.0005);
	float far = smoothstep(0.004, 0.02, px);
	float row = floor(at.x / board_width);
	float offset = hash(vec2(row, 3.0)) * 7.0;
	float along = at.y / board_length + offset;
	float plank = floor(along);
	float shade = mix(hash(vec2(row, plank)), 0.5, smoothstep(0.02, 0.06, px));
	vec3 colour = mix(board, board_alt, shade);
	// The grain: long wavy lines along the board
	float across = fract(at.x / board_width);
	float wave = across * 7.0 + noise(vec2(at.y * 1.3, row * 3.1)) * 2.2 + shade * 13.0;
	float grain = smoothstep(0.8, 1.0, abs(sin(wave * 3.14159)));
	colour = mix(colour, grain_colour, mix(grain, 0.12, far) * 0.32);
	// A knot now and then
	vec2 knot_at = vec2((row + 0.25 + 0.5 * hash(vec2(row, plank + 4.0))) * board_width,
			(plank + 0.2 + 0.6 * hash(vec2(row, plank + 9.0)) - offset) * board_length);
	float knot = step(0.8, hash(vec2(row * 1.7, plank))) * (1.0 - smoothstep(0.014, 0.03, length((at - knot_at) * vec2(1.0, 0.4))));
	colour = mix(colour, grain_colour * 0.85, knot * (1.0 - far));
	// The seams between the boards and the joints at their ends
	float side_gap = min(across, 1.0 - across) * board_width;
	float end_gap = min(fract(along), 1.0 - fract(along)) * board_length;
	float seam_line = 1.0 - smoothstep(0.007 - px, 0.007 + px, min(side_gap, end_gap));
	// (a seam is 1.4 cm of every 20: far off, that much of the colour)
	colour = mix(colour, seam, mix(seam_line, 0.075, smoothstep(0.006, 0.02, px)) * 0.85);
	ALBEDO = colour;
	EMISSION = colour * glow * 0.1;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = (dot(NORMAL, LIGHT) + 0.3) / 1.3;
	float amount = facing * smoothstep(0.1, 0.6, clamp(ATTENUATION, 0.0, 1.0));
	float lit = smoothstep(0.03, 0.08, amount);
	DIFFUSE_LIGHT += mix(0.35, 1.0, lit) * LIGHT_COLOR / PI * mix(clamp(ATTENUATION, 0.0, 1.0), 1.0, 0.7);
}
