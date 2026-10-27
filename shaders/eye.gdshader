// A frog's eye, drawn rather than modelled, so its white is always a clean oval: on the cap of
// the eyeball (tools/build_frogs.py `eye_cap`, texture coordinates across it), the white inked
// round its edge, the black pupil where it looks (`pupil`), and the upper lid coming down over it
// as skin with an ink edge (`lid`: 0 open, 1 shut), tipped for anger or doubt (`lid_tilt`), and
// a lower lid coming up for a smile or a squint (`lower`). Lit in the same flat tones as the skin.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 white : source_color = vec3(0.96, 0.94, 0.84);
uniform vec3 pupil_colour : source_color = vec3(0.03, 0.03, 0.04);
uniform vec3 lid_colour : source_color = vec3(0.42, 0.52, 0.25);
uniform vec3 ink : source_color = vec3(0.06, 0.04, 0.04);
uniform vec2 pupil = vec2(0.0);
uniform float pupil_size = 0.36;
uniform float lid = 0.25;
uniform float lid_tilt = 0.0;
uniform float lower = 0.0;
uniform vec3 shade : source_color = vec3(0.55, 0.52, 0.72);

varying float is_skin;

float line(float value, float edge, float width) {
	float pixel = max(fwidth(value), 0.0001);
	return 1.0 - smoothstep(width - pixel, width + pixel, abs(value - edge));
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	// The upper lid's edge: high when open, down across when shut, tipped by lid_tilt, a little arched
	float top = mix(1.08, -1.15, lid) + lid_tilt * c.x - 0.18 * c.x * c.x * (1.0 - lid);
	float bottom = mix(-1.08, 0.15, lower) + 0.12 * c.x * c.x;
	float under_lid = smoothstep(top - 0.02, top + 0.02, c.y) + 1.0 - smoothstep(bottom - 0.02, bottom + 0.02, c.y);
	under_lid = clamp(under_lid, 0.0, 1.0);
	vec2 look = pupil * (1.0 - pupil_size - 0.1);
	float in_pupil = 1.0 - smoothstep(pupil_size - 0.03, pupil_size + 0.03, length(c - look));
	float glint = 1.0 - smoothstep(0.08, 0.11, length(c - look - vec2(0.13, 0.15)));
	vec3 colour = mix(white, pupil_colour, in_pupil);
	colour = mix(colour, vec3(1.0), glint * in_pupil * 0.85);
	colour = mix(colour, lid_colour, under_lid);
	// Ink round the white, and along each lid's edge
	float edge = max(line(r, 1.0, 0.07), max(line(c.y, top, 0.05) * step(r, 1.0), line(c.y, bottom, 0.035) * step(r, 1.0) * step(0.05, lower)));
	colour = mix(colour, ink, edge);
	is_skin = under_lid;
	ALBEDO = colour;
	ROUGHNESS = 1.0;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	// (the white is wet and catches light all round; the lid is skin, and shades as skin does)
	float lit = mix(smoothstep(-0.55, -0.45, facing), smoothstep(-0.1, 0.0, facing), is_skin) * smoothstep(0.08, 0.35, reach);
	DIFFUSE_LIGHT += mix(shade * 0.55, vec3(1.0), lit) * LIGHT_COLOR * mix(reach, 1.0, 0.7) / PI;
}
