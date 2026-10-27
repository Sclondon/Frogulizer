// The ink line round a figure: the surface drawn again behind itself, pushed out along its
// normals and flat dark, so only a rim of it shows round the edges. It keeps about the same
// width on screen near and far (grows a little with distance), like a pen line.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, specular_disabled;

uniform vec3 ink : source_color = vec3(0.07, 0.05, 0.05);
// How thick, in metres at a few metres off; and how much thicker it gets further away.
uniform float width = 0.006;
uniform float grow = 0.06;

void vertex() {
	float distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	// (the model may be drawn larger than it was made: the push is in metres on screen, not the model's units)
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += normalize(NORMAL) * width * (0.5 + clamp(distance, 0.5, 40.0) * grow) / max(scale, 0.001);
}

void fragment() {
	ALBEDO = ink;
}
