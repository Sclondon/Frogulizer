// (Copied from ScenicRoute: shaders/corn.gdshader.)
// Corn stalks (corn_builder.gd), swaying: each stalk bent along its length as one curve by gusts rolling
// across the field and a sway of its own, the leaves' tips fluttering (Warren's corn shader, without
// anyone to push through it). Lit by hand: a warm wrap, dark low down among the stalks, and the leaves
// glowing at their edges with the sun behind them.
shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.55);
uniform float wind = 0.35;
uniform vec2 wind_dir = vec2(1.0, 0.35);

varying float v_up;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(whole), hash(whole + vec2(1.0, 0.0)), part.x),
			mix(hash(whole + vec2(0.0, 1.0)), hash(whole + vec2(1.0, 1.0)), part.x), part.y);
}

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float tall = length(MODEL_MATRIX[1].xyz) * 2.5;
	vec3 rel = VERTEX - root;
	float rnd = hash(root.xz * 3.1);
	vec2 wd = normalize(wind_dir + vec2(0.0001));
	vec2 g = root.xz / 24.0 - wd * TIME * (0.2 + wind * 0.6);
	float gust = smoothstep(0.2, 0.85, noise(g) * 0.65 + noise(g * 2.3 + 5.0) * 0.35);
	vec2 bend = wd * tall * (0.015 + wind * 0.11) * (0.3 + gust);
	bend += wd * tall * (0.008 + 0.03 * wind) * sin(TIME * (1.1 + rnd * 0.6) + rnd * 6.283);
	bend += vec2(-wd.y, wd.x) * tall * (0.005 + 0.015 * wind) * sin(TIME * 1.7 + rnd * 11.0);
	// bent along an arc: the whole of it turned through `a` by the top
	float lean = length(bend);
	vec2 dir = lean > 0.0001 ? bend / lean : wd;
	float curve = min(2.0 * lean / tall, 1.5) / tall;
	float s = max(rel.y, 0.0);
	float a = curve * s;
	float out_ = curve > 0.00001 ? (1.0 - cos(a)) / curve : 0.0;
	float up = curve > 0.00001 ? sin(a) / curve : s;
	float along = dot(rel.xz, dir);
	vec2 side = rel.xz - dir * along;
	vec3 moved = root + vec3(dir.x, 0.0, dir.y) * (out_ + along * cos(a)) + vec3(side.x, 0.0, side.y) + vec3(0.0, up - along * sin(a), 0.0);
	moved.y -= UV.x * UV.x * 0.18 * fract(rnd * 7.0);
	moved.y += sin(TIME * (2.4 + rnd) + UV.y * 6.283) * 0.03 * UV.x * (0.4 + wind + min(lean, 1.0));
	VERTEX = moved;
	v_up = s;
	world_pos = moved;
	world_normal = NORMAL;
}

void fragment() {
	vec3 colour = COLOR.rgb * vec3(1.35, 1.02, 0.5);
	colour *= mix(0.3, 1.0, smoothstep(0.1, 2.0, v_up));
	vec3 n = normalize(world_normal);
	vec3 sun = normalize(sun_dir);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float wrap = clamp(abs(dot(n, sun)) * 0.6 + 0.4, 0.0, 1.0);
	float back = pow(clamp(dot(-to_cam, sun), 0.0, 1.0), 3.0);
	vec3 lit = colour * (0.55 + 0.6 * wrap * sun_color);
	lit += colour * sun_color * back * 0.6 * smoothstep(0.5, 2.0, v_up);
	ALBEDO = lit;
}
