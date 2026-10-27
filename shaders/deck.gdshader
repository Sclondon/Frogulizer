// The riverboat's deck, as the boats in Over the Garden Wall have it: warm
// yellow-orange boards running fore and aft, dark seams between them and butt
// joints staggered along each, and big soft orange dots scattered over it all.
// Lit in two flat tones, as the frogs are (Toon), so it sits with them.
shader_type spatial;

uniform vec3 board : source_color = vec3(0.93, 0.62, 0.25);
uniform vec3 board_alt : source_color = vec3(0.97, 0.70, 0.31);
uniform vec3 seam : source_color = vec3(0.55, 0.30, 0.12);
uniform vec3 dot_colour : source_color = vec3(0.91, 0.45, 0.16);
uniform float board_width = 0.22;
uniform float board_length = 3.1;
uniform float dot_spacing = 1.6;
// The deck lights up a little with the music (from the scene: Groove.energy).
uniform float glow = 0.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 at = world.xz;
	float row = floor(at.x / board_width);
	float along = at.y / board_length + hash(vec2(row, 3.0)) * 7.0;
	float plank = floor(along);
	vec3 colour = mix(board, board_alt, hash(vec2(row, plank)) * 0.8);
	// (a grain of faint streaks along each board)
	colour *= 0.94 + 0.06 * sin(at.x * 180.0 + hash(vec2(row, plank)) * 30.0 + sin(at.y * 3.0) * 2.0);
	float across = abs(fract(at.x / board_width) - 0.5) * board_width;
	float end = abs(fract(along) - 0.5) * board_length;
	float px = max(fwidth(at.x), 0.0005);
	float line = 1.0 - smoothstep(board_width * 0.5 - 0.012 - px, board_width * 0.5 - 0.012 + px, board_width * 0.5 - across);
	float joint = 1.0 - smoothstep(board_length * 0.5 - 0.012 - px, board_length * 0.5 - 0.012 + px, board_length * 0.5 - end);
	// The dots: one in each cell of a jittered grid, some bigger, some smaller
	vec2 cell = floor(at / dot_spacing);
	vec2 centre = (cell + 0.2 + 0.6 * vec2(hash(cell), hash(cell + 17.0))) * dot_spacing;
	float radius = dot_spacing * (0.12 + 0.08 * hash(cell + 5.0));
	float spot = 1.0 - smoothstep(radius - px * 1.5, radius + px * 1.5, length((at - centre) * vec2(1.0, 0.7)));
	spot *= step(0.25, hash(cell + 9.0));
	colour = mix(colour, dot_colour, spot * 0.85);
	colour = mix(colour, seam, max(line, joint) * 0.75);
	ALBEDO = colour;
	EMISSION = colour * glow * 0.12;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = (dot(NORMAL, LIGHT) + 0.3) / 1.3;
	float amount = facing * smoothstep(0.1, 0.6, clamp(ATTENUATION, 0.0, 1.0));
	float lit = smoothstep(0.03, 0.08, amount);
	DIFFUSE_LIGHT += mix(0.35, 1.0, lit) * LIGHT_COLOR / PI * mix(clamp(ATTENUATION, 0.0, 1.0), 1.0, 0.7);
}
