class_name FrogToon
## The house cartoon look (shaders/toon.gdshader, and shaders/outline.gdshader for the ink line),
## put on a model in place of the materials it was made with. Each material keeps its colour
## (or takes one from `colours`, by the material's name, as FrogLook gives them) and is shaded
## by what it is: eyes wet and glinting, brass shining, skin softer at the turn of the light, the
## ink of the mouth flat black with no line round it.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const EYE := preload("res://shaders/eye.gdshader")
const TONGUE := preload("res://shaders/tongue.gdshader")
const MOUTH := preload("res://shaders/mouth.gdshader")
## Materials drawn with no ink line round them (they sit inside or on top of others).
const NO_LINE := ["eye_l", "eye_r", "eyewhite", "pupil", "ink", "mouth", "tongue", "trim", "tie", "band"]
## Settings by material name.
const KINDS := {
	"skin": {"cut": -0.05, "softness": 0.05, "rim": 0.4},
	"belly": {"cut": -0.08, "softness": 0.05, "rim": 0.3},
	"eyewhite": {"cut": -0.4, "glint": 0.9, "glint_size": 160.0, "rim": 0.0},
	"pupil": {"glint": 1.2, "glint_size": 220.0, "rim": 0.0},
	"ink": {"cut": 2.0, "shade": Color(0.0, 0.0, 0.0), "rim": 0.0, "ambient": 0.0},
	"mouth": {"rim": 0.0},
	"tongue": {"glint": 0.4, "glint_size": 60.0},
	"brass": {"glint": 1.2, "glint_size": 40.0, "highlight": 0.35, "rim": 0.5},
}

static var _lines := {}


## Reshades every mesh under `model`. `outline` adds the ink line.
static func apply(model: Node, colours := {}, outline := true) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var named := original.resource_name
			var colour: Color = colours.get(named, original.albedo_color)
			var made := material(colour, named)
			if named == "eye_l" or named == "eye_r":
				# (drawn by its own shader: the white, the pupil, the lids in the skin's colour)
				made = ShaderMaterial.new()
				made.shader = EYE
				made.set_shader_parameter(&"lid_colour", colours.get("skin", Color(0.42, 0.52, 0.25)))
			if named == "mouth":
				# (the inside of the mouth, drawn from inside)
				made = ShaderMaterial.new()
				made.shader = MOUTH
			if named == "tongue":
				# (its own shader: wet, glossy, rippling)
				made = ShaderMaterial.new()
				made.shader = TONGUE
				made.set_shader_parameter(&"albedo", colour)
			if named == "skin":
				made.set_shader_parameter(&"mouth", 1.0)
				# (the throat and belly, painted on the model as a vertex colour)
				made.set_shader_parameter(&"use_pale", 1.0)
				made.set_shader_parameter(&"pale", colours.get("belly", Color(0.62, 0.68, 0.40)))
			# (no line round the warts: ringed, they would look like holes)
			if outline and not named in NO_LINE and not String(part.name).contains("warts"):
				made.next_pass = line(colour)
			part.set_surface_override_material(surface, made)


## A toon material of a colour, set up for a kind of material (a key of KINDS, or anything).
static func material(colour: Color, kind := "") -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = TOON
	made.set_shader_parameter(&"albedo", colour)
	var settings: Dictionary = KINDS.get(kind, {})
	for key: String in settings:
		made.set_shader_parameter(key, settings[key])
	return made


## The ink line for a surface of this colour: near black, a little of the colour in it.
static func line(colour: Color) -> ShaderMaterial:
	var key := colour.to_html()
	if not _lines.has(key):
		var made := ShaderMaterial.new()
		made.shader = OUTLINE
		made.set_shader_parameter(&"ink", colour.darkened(0.82).lerp(Color(0.05, 0.03, 0.03), 0.5))
		_lines[key] = made
	return _lines[key]
