// A frog's tongue: wet and glossy, pink with a darker groove down the middle of its top and a
// fine stipple of little bumps, a ripple running down it to the tip, and the hard bright glints
// of something wet, in the same flat tones as the rest (FrogToon). Its texture coordinates go
// along it (x, root 0 to tip 1) and round it (y).
shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(0.88, 0.45, 0.50);
uniform vec3 groove : source_color = vec3(0.62, 0.22, 0.30);
uniform vec3 shade : source_color = vec3(0.55, 0.40, 0.62);
// The ripple: how high (m), how many waves along it, how fast they run to the tip.
uniform float ripple = 0.0025;
uniform float waves = 5.0;
uniform float speed = 9.0;
// Where round it the top is (texture y), for the groove.
uniform float top = 0.25;

varying float along;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	along = UV.x;
	// (more towards the tip; none at the root, inside the mouth)
	VERTEX += NORMAL * sin(UV.x * waves * 6.2831853 - TIME * speed) * ripple * smoothstep(0.05, 0.6, UV.x);
}

void fragment() {
	float round_it = fract(UV.y - top + 0.5) - 0.5;
	float in_groove = 1.0 - smoothstep(0.02, 0.06, abs(round_it));
	vec3 colour = mix(albedo, groove, in_groove * 0.7 * smoothstep(0.05, 0.2, along) * (1.0 - smoothstep(0.85, 0.97, along)));
	// the little bumps
	vec2 cell = floor(vec2(UV.x * 90.0, UV.y * 40.0));
	colour *= 0.93 + 0.07 * step(0.6, hash(cell));
	ALBEDO = colour;
	ROUGHNESS = 0.2;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float lit = smoothstep(-0.05, 0.05, facing) * smoothstep(0.08, 0.35, reach);
	vec3 tone = mix(shade, vec3(1.0), lit);
	DIFFUSE_LIGHT += tone * LIGHT_COLOR * mix(reach, 1.0, 0.7) / PI;
	// wet: two hard glints, a broad one and a pin-point, and a bright rim
	vec3 half_way = normalize(LIGHT + VIEW);
	float spec = max(dot(NORMAL, half_way), 0.0);
	float glints = step(0.93, spec) * 0.6 + step(0.985, spec) * 0.9;
	float rim = smoothstep(0.62, 0.72, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * lit * 0.35;
	SPECULAR_LIGHT += (glints * lit + rim) * LIGHT_COLOR;
}
