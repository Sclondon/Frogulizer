// The house cartoon look, for the frogs, their instruments and the boat: lit in three flat
// tones (shadow, light, a little highlight) with hard edges between, the shadow not just darker
// but cooler (a painted shadow, `shade`), a warm rim where the low sun catches an edge from
// behind, and an optional glint (eyes, brass). Its partner `outline.gdshader` draws the ink line.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
// A paler colour laid where the model's vertex colour says (its red over a half): a frog's
// throat and belly. 0 leaves the vertex colour alone.
uniform vec3 pale : source_color = vec3(1.0);
uniform float use_pale = 0.0;
// The mouth, drawn on the skin (its second texture coordinates say where: how far round the mouth
// -1..1, and how far below its line): shut, a black line curling up at its corners; open, the band
// just under the line that the jaw stretches (`mouth_band`) is the inside of the mouth, the tongue
// at the bottom of it. `mouth` turns it on, `open` says how far open (0..1).
uniform float mouth = 0.0;
uniform float open = 0.0;
// The corners: up in a smile (1), down in a frown (-1). The line runs on a little past the
// corners of the cut, curling, as a drawn mouth does.
uniform float smile = 0.0;
// How long this frog's drawn mouth is, against the cut of it (1): shorter or longer, each its own.
uniform float mouth_reach = 1.0;
uniform float mouth_band = 0.02;
uniform vec3 mouth_colour : source_color = vec3(0.30, 0.07, 0.09);
uniform vec3 tongue_colour : source_color = vec3(0.86, 0.46, 0.48);
uniform vec3 ink_colour : source_color = vec3(0.05, 0.03, 0.03);
// The shadow side's colour, as a tint over the albedo (cool and a little deeper).
uniform vec3 shade : source_color = vec3(0.55, 0.52, 0.72);
// Where light turns to shadow (a share of facing the light, -1..1), and how soft that edge is.
uniform float cut = 0.05;
uniform float softness = 0.03;
// A third, brighter tone where the light falls full on, and how much brighter.
uniform float highlight_cut = 0.72;
uniform float highlight = 0.12;
// A rim of light along the edges facing away from the camera on the lit side.
uniform float rim = 0.35;
uniform float rim_width = 0.28;
// A small hard glint (eyes, brass): how bright, and how small (higher is smaller).
uniform float glint = 0.0;
uniform float glint_size = 120.0;
// How much the shadow takes the scene's ambient light (0: flat painted shade).
uniform float ambient = 0.6;

void fragment() {
	vec3 painted = COLOR.rgb;
	float paler = use_pale * smoothstep(0.42, 0.58, painted.r);
	vec3 colour = mix(albedo, pale, paler);
	// (where it is against the mouth comes in the vertex colour's green and blue: tools/build_frogs.py add_paleness)
	float round_mouth = (painted.g - 0.5) * 4.0;
	if (mouth > 0.5 && abs(round_mouth) < 1.9) {
		float a = abs(round_mouth);
		float d = painted.b * 0.08 - 0.03;
		float px = max(fwidth(d), 0.00005);
		// the line, tapering towards the corners, which curl up a little
		float corner = smoothstep(0.95 * mouth_reach, 1.25 * mouth_reach, a);
		float curl = -0.007 * smoothstep(0.82, 1.08, a) - smile * 0.03 * corner * corner;
		// (never thinner than about a pixel and a half, however far off)
		float reach = mouth_reach * (1.08 + 0.12 * abs(smile));
		float width = max(0.0045 * (1.0 - smoothstep(reach - 0.17, reach, a)) + 0.0012, px * 1.2);
		float ink = (1.0 - smoothstep(width - px, width + px, abs(d - curl))) * step(a, reach);
		// (the skin is cut along the line, so when the jaw drops both lips keep it: the inside of
		// the mouth is a real one, behind)
		colour = mix(colour, ink_colour, ink);
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float lit = smoothstep(cut - softness, cut + softness, facing) * smoothstep(0.08, 0.35, reach);
	float bright = smoothstep(highlight_cut - softness, highlight_cut + softness, facing) * lit;
	// The shadow tone is laid in by the light itself: where it does not reach, the surface is its shaded colour.
	vec3 tone = mix(shade * 0.55, vec3(1.0), lit) + bright * highlight;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(1.0 - rim_width - 0.02, 1.0 - rim_width + 0.02, graze) * smoothstep(-0.3, 0.2, dot(-VIEW, LIGHT));
	DIFFUSE_LIGHT += tone * LIGHT_COLOR * mix(reach, 1.0, 0.7) / PI;
	SPECULAR_LIGHT += (edge * rim + glint * smoothstep(0.5, 0.55, pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), glint_size)) * lit) * LIGHT_COLOR * albedo / PI;
}
