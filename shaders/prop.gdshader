// (Copied from ScenicRoute: shaders/prop.gdshader.)
// Things in the wood (pumpkins, rails, stones), painted the same way as the trees: a colour in two or
// three flat-ish tones by a soft wrap of the sun, a warm rim, and brushy noise. Vertex COLOR tints it.
shader_type spatial;
render_mode unshaded;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 color : source_color = vec3(0.85, 0.45, 0.12);
uniform vec3 shadow_color : source_color = vec3(0.3, 0.12, 0.05);
uniform float brush = 0.25;
uniform float gloss = 0.0;

varying vec3 world_normal;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 sun = normalize(sun_dir);
	vec3 base = color * COLOR.rgb;
	float strokes = vnoise(world_pos.xy * 6.0 + world_pos.z * 3.0) - 0.5;
	float wrap = clamp(dot(n, sun) * 0.5 + 0.5 + strokes * brush, 0.0, 1.0);
	vec3 col = mix(shadow_color * COLOR.rgb, base, smoothstep(0.2, 0.75, wrap));
	col = mix(col, base * sun_color * 1.3, smoothstep(0.75, 0.95, wrap));
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float rim = pow(1.0 - clamp(dot(n, to_cam), 0.0, 1.0), 3.0) * clamp(dot(n, sun) + 0.6, 0.0, 1.0);
	col += sun_color * rim * 0.4;
	float spec = pow(clamp(dot(reflect(-sun, n), to_cam), 0.0, 1.0), 24.0) * gloss;
	col += sun_color * spec;
	ALBEDO = col;
}
