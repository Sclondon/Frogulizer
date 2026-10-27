class_name WheelSpray
extends Node3D
## The water a paddle wheel throws about (put it on the boat where the wheel's paddles meet the
## water, at the water line): a Splash (Salmon Run 2's) thrown up behind the wheel each time a
## paddle comes up out of the water, a smaller one each time one goes in ahead; a steady spray of
## drops flung up and back off the paddles as they rise, and water streaming down off them as they
## climb away. Everything it throws is left in the air and on the water where it was thrown, so the
## boat goes on and leaves it behind.

## How many paddles the wheel has, its radius, and how far ahead and behind the middle of the wheel
## the paddles meet the water.
var paddles := 16
var radius := 3.5
var reach := 3.1
## How hard the boat is going (m/s; it sets how fast the paddles come round).
var speed := 2.5
var water := Color(0.42, 0.38, 0.24)
var foam := Color(0.98, 0.92, 0.80)

var _pool: Array[Splash] = []
var _next := 0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for k in 8:
		var splash := Splash.new()
		splash.spread = Vector2(0.75, 1.15)
		add_child(splash)
		_pool.append(splash)
	# a steady spray off the rising paddles, up and back
	_spray("drop", 70, Vector3(0.0, 0.1, -reach), Vector3(0.5, 0.15, 0.5), Vector3(0.0, 1.0, -0.55), 22.0, Vector2(3.0, 6.5), Vector2(0.08, 0.2))
	_spray("dot", 120, Vector3(0.0, 0.1, -reach), Vector3(0.6, 0.15, 0.6), Vector3(0.0, 1.0, -0.4), 35.0, Vector2(4.0, 8.0), Vector2(0.04, 0.09))
	# water streaming down off the paddles as they climb away behind
	_spray("splat", 50, Vector3(0.0, 1.2, -reach + 0.6), Vector3(0.55, 0.9, 0.35), Vector3(0.0, -1.0, -0.2), 15.0, Vector2(0.2, 1.0), Vector2(0.07, 0.16))
	# and a little thrown forward where they go in
	_spray("dot", 40, Vector3(0.0, 0.05, reach), Vector3(0.5, 0.1, 0.3), Vector3(0.0, 1.0, 0.3), 30.0, Vector2(1.5, 3.5), Vector2(0.04, 0.08))


func _spray(key: String, amount: int, at: Vector3, box: Vector3, way: Vector3, spread: float, fast: Vector2, size: Vector2) -> void:
	var p := CPUParticles3D.new()
	p.mesh = Splash.mesh(key)
	p.material_override = Splash.material()
	p.amount = amount
	p.lifetime = 0.9
	p.position = at
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = way.normalized()
	p.spread = spread
	p.initial_velocity_min = fast.x
	p.initial_velocity_max = fast.y
	p.gravity = Vector3(0.0, -16.0, 0.0)
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.7))
	shrink.add_point(Vector2(0.2, 1.0))
	shrink.add_point(Vector2(1.0, 0.1))
	p.scale_amount_curve = shrink
	p.color = water.lerp(foam, 0.75)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


func _process(delta: float) -> void:
	# a paddle comes up every so often, as fast as the wheel goes round
	var turn := speed / (radius * 0.8)
	var every := TAU / paddles / maxf(turn, 0.01)
	_clock += delta
	if _clock < every:
		return
	_clock = fmod(_clock, every)
	var flat := Basis(Vector3.UP, global_basis.get_euler().y)
	# behind, where it comes out: a big one
	_throw(Transform3D(flat, global_position + flat * Vector3(_rng.randf_range(-0.2, 0.2), 0.0, -reach + _rng.randf_range(-0.3, 0.3))),
			_rng.randf_range(0.32, 0.5))
	# ahead, where it goes in: a little one
	_throw(Transform3D(flat, global_position + flat * Vector3(_rng.randf_range(-0.2, 0.2), 0.0, reach + _rng.randf_range(-0.2, 0.2))),
			_rng.randf_range(0.12, 0.2))


func _throw(where: Transform3D, how_big: float) -> void:
	var splash := _pool[_next]
	_next = (_next + 1) % _pool.size()
	where.origin.y = 0.03
	splash.start(where, how_big, water, foam)
