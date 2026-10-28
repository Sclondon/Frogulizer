// The inside of a frog's mouth (the mouth bag in tools/build_frogs.py): drawn from the inside
// only, so whatever lies in the mouth (the tongue) is seen in front of it. Deep red, darkest at
// the throat straight ahead, warmer round the sides, flat like the rest of the cartoon.
// With `skin` on it is the skin's second pass instead: the inside of the lips and the chin, seen
// over the lower lip when the jaw drops, as the inside of the mouth (only in the head: the
// vertex colour's green is at most 0.95 there, 1 on the body; see tools/build_frogs.py mouth_at).
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec3 albedo : source_color = vec3(0.45, 0.08, 0.1);
uniform vec3 throat : source_color = vec3(0.12, 0.02, 0.03);
uniform bool skin = false;

void fragment() {
	if (skin && COLOR.g > 0.975) {
		discard;
	}
	// (the far wall seen square on is the back of the throat; seen slanting, the sides)
	float straight = clamp(-dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(albedo, throat, smoothstep(0.55, 0.9, straight));
}
