// The riverboat's paint: the house toon look (toon.gdshader's three flat tones, cool painted shade
// and warm rim; the same light() and the same uniforms, so FrogToon's settings work on it) over
// paint that is not quite flat: a soft mottle, faint brush strokes running along the boards, the
// lines between the boards of the cabin's clapboard and the hull's planks (`boards`), and here
// and there a chip where the paint has worn to the cream undercoat. All of it is laid in the
// part's own space, so it goes along with the boat; the finer of it fades out far off, where it
// would only shimmer.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 shade : source_color = vec3(0.55, 0.52, 0.72);
uniform float cut = 0.05;
uniform float softness = 0.03;
uniform float highlight_cut = 0.72;
uniform float highlight = 0.12;
uniform float rim = 0.35;
uniform float rim_width = 0.28;
uniform float glint = 0.0;
uniform float glint_size = 120.0;
uniform float ambient = 0.6;
// How strong the paint's texture is (0: flat), how far apart the boards are (m; 0: no boards),
// and how worn it is.
uniform float texture_amount = 1.0;
uniform float boards = 0.0;
uniform float wear = 1.0;
uniform vec3 undercoat : source_color = vec3(0.86, 0.78, 0.60);

varying vec3 local;
varying vec3 local_normal;

void vertex() {
	local = VERTEX;
	local_normal = NORMAL;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void fragment() {
	vec3 colour = albedo;
	vec3 n = normalize(local_normal);
	// how big a pixel is here, in metres: the fine detail goes as it gets small
	float px = max(length(fwidth(local)), 0.0005);
	float fine = 1.0 - smoothstep(0.012, 0.04, px);
	// a soft mottle, as paint laid on by hand
	float mottle = noise3(local * 1.7) * 0.6 + noise3(local * 4.3 + 11.0) * 0.4;
	colour *= 1.0 + (mottle - 0.5) * 0.12 * texture_amount;
	// brush strokes, long along the boards: across a wall they run level, on a floor or a roof
	// they run fore and aft
	vec3 stretch = abs(n.y) > 0.6 ? vec3(5.0, 1.0, 0.6) : vec3(0.7, 9.0, 0.7);
	float stroke = noise3(local * stretch * 2.0 + 3.0);
	colour *= 1.0 + (stroke - 0.5) * 0.07 * texture_amount * fine;
	// the lines between the boards, on the upright faces, with the bottom edge of each board
	// a little darker (the lap of the clapboard)
	if (boards > 0.0 && abs(n.y) < 0.5) {
		float along = local.y / boards;
		float within = fract(along);
		float gap = 1.0 - smoothstep(0.0, max(fwidth(along) * 1.5, 0.04), min(within, 1.0 - within));
		float lap = smoothstep(0.75, 1.0, within) * 0.06;
		// (gone when a board is only a few pixels high)
		colour *= 1.0 - (gap * 0.34 + lap) * texture_amount * (1.0 - smoothstep(0.12, 0.3, px / boards));
	}
	// chips worn through to the undercoat, few, in clusters
	float chips = step(0.82, noise3(local * 17.0 + 5.0)) * step(0.66, noise3(local * 1.3 + 2.0));
	colour = mix(colour, undercoat, chips * 0.22 * wear * texture_amount * fine);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float lit = smoothstep(cut - softness, cut + softness, facing) * smoothstep(0.08, 0.35, reach);
	float bright = smoothstep(highlight_cut - softness, highlight_cut + softness, facing) * lit;
	vec3 tone = mix(shade * 0.55, vec3(1.0), lit) + bright * highlight;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(1.0 - rim_width - 0.02, 1.0 - rim_width + 0.02, graze) * smoothstep(-0.3, 0.2, dot(-VIEW, LIGHT));
	DIFFUSE_LIGHT += tone * LIGHT_COLOR * mix(reach, 1.0, 0.7) / PI;
	SPECULAR_LIGHT += (edge * rim + glint * smoothstep(0.5, 0.55, pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), glint_size)) * lit) * LIGHT_COLOR * albedo / PI;
}
