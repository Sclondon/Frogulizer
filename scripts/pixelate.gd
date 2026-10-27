class_name Pixelate
extends CanvasLayer
## A look laid over the whole picture: big square pixels (`size`, in screen pixels; 1 is off),
## and optionally fewer colours with an ordered dither between them (`levels`; 0 is off), as an
## old game's screen. Under the camera desk and the title, over the world.

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float size = 1.0;
uniform float levels = 0.0;

// A 4x4 Bayer matrix, for the dither between colour levels
float bayer(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[i.y * 4 + i.x]) / 16.0 - 0.5;
}

void fragment() {
	vec2 pixels = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 block = floor(SCREEN_UV * pixels / size);
	vec2 at = (block + 0.5) * size / pixels;
	vec3 colour = texture(screen, at).rgb;
	if (levels > 0.5) {
		colour = floor(colour * levels + 0.5 + bayer(block) / levels * levels * 0.9) / levels;
	}
	COLOR = vec4(colour, 1.0);
}
"""

## Pixel size (1: off) and colour levels per channel (0: off).
var size := 1.0:
	set(value):
		size = maxf(value, 1.0)
		_update()
var levels := 0.0:
	set(value):
		levels = value
		_update()

var _rect: ColorRect


func _ready() -> void:
	layer = 2
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	_rect.material = material
	add_child(_rect)
	_update()


func _update() -> void:
	if _rect == null:
		return
	_rect.visible = size > 1.0 or levels > 0.5
	(_rect.material as ShaderMaterial).set_shader_parameter(&"size", size)
	(_rect.material as ShaderMaterial).set_shader_parameter(&"levels", levels)
