// (Copied from SalmonRun2: shaders/splash.gdshader; `round` renamed `around`, as a built-in's name.)
// One tube of a splash: a wall of water with a ragged crest. UV.x goes once round the tube,
// UV.y from the water (0) to the top (1). The water in it streams down the wall.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 white : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec4 pale : source_color = vec4(0.62, 0.9, 0.98, 1.0);
uniform vec4 blue : source_color = vec4(0.25, 0.62, 0.86, 1.0);
// How many waves there are in the crest, where they start, and how deep they cut (0 to 1).
uniform float waves = 7.0;
uniform float phase = 0.0;
uniform float ragged = 0.3;
// 0 as the tube goes up, 1 as it has fallen back: it thins out into shreds on the way down.
uniform float spent = 0.0;

// (worked out in whole numbers, so that every square of the noise agrees about its corners:
// see hash in water.gdshader)
float hash(vec2 p) {
	ivec2 c = ivec2(round(p));
	uint h = uint(c.x) * 668265261u ^ (uint(c.y) * 374761393u);
	h ^= h >> 15u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float around = UV.x * 6.2832;
	// the crest: big waves with smaller ones on them, cut out of the top of the wall
	float crest = 1.0 - ragged * (0.5 + 0.35 * sin(around * waves + phase) + 0.15 * sin(around * waves * 2.7 + phase * 1.9));
	if (UV.y > crest) {
		discard;
	}
	// streaks of water running down the wall, in three flat tones
	float streak = noise(vec2(UV.x * waves * 3.0, UV.y * 2.2 + TIME * 3.0 + phase));
	// as it falls back, holes open in it from the bottom up
	if (streak < spent * (1.25 - UV.y * 0.6) - 0.1) {
		discard;
	}
	vec3 col = streak > 0.62 ? white.rgb : (streak > 0.36 ? pale.rgb : blue.rgb);
	// foam along the crest
	col = mix(col, white.rgb, step(crest - 0.1, UV.y));
	ALBEDO = col;
}
