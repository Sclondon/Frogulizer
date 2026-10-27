class_name TrainSmoke
extends MultiMeshInstance3D
## (From Outside, unchanged: here it is the riverboat's smokestacks.)
## The smoke of a locomotive, after `Dust` and the smoke of `Fire`: round
## two-toned clouds turned to the camera, all drawn at once. Put one where the
## top of the chimney is (a `TrainVehicle` does, at its marker `Chimney`).
##
## Standing, a thin wisp goes straight up. Working, it comes in beats, four to
## a turn of the driving wheels (`beat`, beats a second: the `Train` says), each
## a ball of dark smoke thrown up hard that swells, pales and is left behind,
## so that the smoke lies back along the train. The puffs stay where they are
## in the world, so a train that moves leaves them behind of itself; for a
## train that stands still while the world goes by, `air` is the wind that
## carries them back. `steam` lets off white steam somewhere else (the
## cylinders, as it starts). At night `sparks` go up with the smoke.

const COUNT := 110

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

uniform vec3 soot : source_color = vec3(0.17, 0.16, 0.16);
uniform vec3 pale : source_color = vec3(0.6, 0.59, 0.58);
uniform vec3 white : source_color = vec3(0.95, 0.95, 0.93);
uniform vec3 spark : source_color = vec3(1.0, 0.6, 0.15);
uniform float thickness = 0.6;

varying float age;
varying float seed;
varying float kind;

void vertex() {
	age = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	kind = INSTANCE_CUSTOM.z;
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	vec2 at = UV * 2.0 - 1.0;
	if (kind > 1.5) {
		// A spark: a small bright fleck that winks and goes out.
		float fleck = cut(0.5 - (abs(at.x) + abs(at.y)), 0.0);
		float wink = 0.6 + 0.4 * sin(TIME * (17.0 + seed * 23.0) + seed * 90.0);
		ALBEDO = vec3(0.0);
		EMISSION = mix(spark, spark * vec3(0.8, 0.3, 0.15), age) * 2.0 * wink;
		ALPHA = fleck * (1.0 - smoothstep(0.6, 1.0, age));
	} else {
		// A cloud: a circle with a few bumps round it, a lighter side and a darker.
		float around = atan(at.y, at.x);
		float rim = 0.84 + 0.11 * sin(around * 5.0 + seed * 40.0) + 0.05 * sin(around * 9.0 - seed * 23.0);
		float from_middle = length(at) / rim;
		float body = cut(1.0 - from_middle, 0.0);
		float shade = cut(at.y - at.x * 0.4 + 0.2, 0.0);
		vec3 colour = mix(mix(soot, pale, smoothstep(0.0, 0.7, age)), white, step(0.5, kind));
		ALBEDO = colour * mix(0.78, 1.0, shade);
		// It thins from the middle as it goes, and is gone.
		float hole = smoothstep(0.55, 1.0, age) * 1.05;
		ALPHA = body * cut(from_middle, hole) * thickness * (1.0 - smoothstep(0.6, 1.0, age)) * mix(1.0, 0.75, step(0.5, kind));
	}
}

void light() {
	DIFFUSE_LIGHT += clamp(ATTENUATION, 0.0, 1.0) * LIGHT_COLOR / PI * 0.7;
}
"""

static var _shader: Shader

## Beats a second (0: standing, a wisp).
var beat := 0.0
## How hard it is working, 0..1: how big and dark the beats are.
var effort := 0.0
## How its own chimney is moving through the world.
var carried := Vector3.ZERO
## The wind over it besides (the whole of it, when the train stands and the world goes by).
var air := Vector3.ZERO
## Sparks with the smoke, 0..1.
var sparks := 0.0
## No smoke at all.
var cold := false

var _at := PackedVector3Array()
var _going := PackedVector3Array()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _kind := PackedFloat32Array()
var _next := 0
var _due := 0.0
var _mouth: Node3D


func _ready() -> void:
	_mouth = get_parent() as Node3D
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE
	disc.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = disc
	multimesh.instance_count = COUNT
	_at.resize(COUNT)
	_going.resize(COUNT)
	_size.resize(COUNT)
	_age.resize(COUNT)
	_life.resize(COUNT)
	_seed.resize(COUNT)
	_kind.resize(COUNT)
	_age.fill(1.0)
	_life.fill(1.0)
	for i in COUNT:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## One puff: where, which way it is thrown, how big it grows, how long it lasts, and what it is (0 smoke, 1 steam, 2 a spark).
func puff(at: Vector3, going: Vector3, size: float, life: float, kind := 0.0) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	_at[i] = at
	_going[i] = going
	_size[i] = size
	_age[i] = 0.0
	_life[i] = life
	_seed[i] = randf()
	_kind[i] = kind


## White steam let off at a place (in the world), blown out along `way`.
func steam(at: Vector3, way: Vector3, amount := 3) -> void:
	for k in amount:
		puff(at + way * randf_range(0.0, 0.3), way * randf_range(1.5, 3.5) + carried * 0.6 + Vector3.UP * randf_range(0.2, 1.0), randf_range(0.6, 1.3), randf_range(0.5, 0.9), 1.0)


func _process(delta: float) -> void:
	if _mouth and not cold:
		_due -= delta
		if _due <= 0.0:
			var mouth := _mouth.global_position
			if beat > 0.3:
				# A beat: a ball of smoke thrown straight up, with what the chimney was doing
				_due = 1.0 / minf(beat, 14.0)
				var hard := lerpf(0.5, 1.0, effort)
				puff(mouth, Vector3(randf_range(-0.3, 0.3), randf_range(4.0, 6.0) * hard, randf_range(-0.3, 0.3)) + carried * 0.85,
						randf_range(1.5, 2.3) * hard, randf_range(1.8, 2.6))
				if sparks > 0.0 and randf() < sparks:
					for k in 2:
						puff(mouth, Vector3(randf_range(-1.0, 1.0), randf_range(3.0, 6.0), randf_range(-1.0, 1.0)) + carried * 0.8, randf_range(0.06, 0.12), randf_range(0.6, 1.3), 2.0)
			else:
				_due = 0.3
				puff(mouth, Vector3(randf_range(-0.1, 0.1), randf_range(0.9, 1.3), randf_range(-0.1, 0.1)) + carried, randf_range(0.6, 0.9), 2.4)
	for i in COUNT:
		if _age[i] >= 1.0:
			continue
		_age[i] = minf(_age[i] + delta / _life[i], 1.0)
		if _age[i] >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _at[i]))
			continue
		var age := _age[i]
		# The air takes hold of it: it loses what threw it, and goes with the wind, rising slowly.
		var drift := air + Vector3.UP * (0.7 if _kind[i] < 1.5 else -2.0)
		_going[i] = _going[i].lerp(drift, 1.0 - exp(-(2.2 if _kind[i] < 1.5 else 0.8) * delta))
		_at[i] += _going[i] * delta
		var grown := _size[i] * (0.3 + 0.7 * (1.0 - pow(1.0 - minf(age * 2.5, 1.0), 2.0)) + 0.5 * age) if _kind[i] < 1.5 else _size[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * grown), _at[i]))
		multimesh.set_instance_custom_data(i, Color(age, _seed[i], _kind[i], 0.0))
