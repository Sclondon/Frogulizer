// Shared PS1-style helpers: vertex snapping to a coarse screen grid ("wobble").
uniform float snap_res = 200.0;
// How much of the wobble is applied (0 is steady, 1 is the full PS1 jitter); an option.
global uniform float psx_wobble;

vec4 psx_snap(vec4 clip, vec2 viewport) {
	vec2 grid = vec2(snap_res * viewport.x / viewport.y, snap_res) * 0.5;
	clip.xy = mix(clip.xy, round(clip.xy / clip.w * grid) / grid * clip.w, psx_wobble);
	return clip;
}

// Vertex colours are authored in sRGB.
vec3 srgb_to_linear(vec3 c) {
	return pow(c, vec3(2.2));
}
