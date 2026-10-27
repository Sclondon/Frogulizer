class_name River
extends Node3D
## The river the boat goes down, at the golden hour, standing still while the boat goes through
## it: the sun low behind the boat (so it lights the band's faces as they look back over the
## crowd), a painted sky and autumn woods on both banks (GameCommon's painted woodland), banks of
## dry grass with a cut of mud at the water, reeds and bushes along them, hills going back in the
## haze, leaves coming down, and the water itself: Salmon Run 2's (shaders/river_water.gdshader),
## with the boat's wake in it, two arms of foam opening out from the bow and froth astern.
##
## The banks are built in a stretch SEGMENT long, twice, end to end; when the boat has left one
## far enough behind, it is moved on to the front. Beyond them the country goes on to the horizon
## (FarLand: fields, woods, farms, ridges of hills, into the haze), and carries the banks on, plainly,
## ahead and behind past the two stretches. The water is a long plane that keeps up with
## the boat; its pattern is worked out from where it is in the world, so it does not move with it.

const SEGMENT := 260.0
## A stretch is moved round to the front once its far end is this far behind the boat.
const BEHIND := 120.0
## Where the water meets the bank, from the middle of the river.
const SHORE := 30.0
const SUN_DIR := Vector3(-0.75, 0.16, -1.0)
const SUN_COLOR := Color(1.0, 0.82, 0.62)
## The wake: how many points of the bow's trail the shader takes, and how long the wake lasts (s).
const WAKE_POINTS := 24
const WAKE_LIFE := 22.0

var boat: Riverboat
var water: MeshInstance3D
var water_material: ShaderMaterial
var sun: DirectionalLight3D
var environment: Environment
var _segments: Array[Node3D] = []
## What land each bank of the stretches is (both stretches are the same): {side: Farmland.plan}.
var _land := {}
var _rng := RandomNumberGenerator.new()
var _trail: Array = []   # [metres along, seconds when laid]
var _clock := 0.0
var _since := 0.0


func _ready() -> void:
	_rng.seed = 41
	_air()
	_water()
	var far := FarLand.new()
	far.boat = boat
	far.sun_dir = SUN_DIR
	far.sun_color = SUN_COLOR
	add_child(far)
	var first := _segment()
	add_child(first)
	first.position.z = -BEHIND - 10.0
	_segments.append(first)
	var second := first.duplicate()
	add_child(second)
	second.position.z = first.position.z + SEGMENT
	_segments.append(second)
	# (the grass is made for each stretch, not copied: a field fills itself in as the camera nears)
	for segment in _segments:
		_grass(segment)


func _process(delta: float) -> void:
	_clock += delta
	RenderingServer.global_shader_parameter_set(&"water_clock", _clock)
	var at := boat.position.z if boat else 0.0
	for segment in _segments:
		if segment.position.z + SEGMENT < at - BEHIND:
			segment.position.z += SEGMENT * 2.0
	# The water keeps up with the boat, a whole square of its grid at a time (so nothing on it swims)
	water.position.z = snappedf(at, 4.0)
	_wake(delta)


func _air() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Woodland.sky(SUN_DIR)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.42, 0.38)
	environment.ambient_light_energy = 0.5
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = Color(0.80, 0.62, 0.46)
	environment.fog_density = 0.0045
	environment.fog_sun_scatter = 0.3
	# (the sky only partly in the haze, so it keeps its colours overhead; its horizon painted the
	# haze's colour, so that the land going into the haze meets it without a line)
	environment.fog_sky_affect = 0.5
	(environment.sky.sky_material as ShaderMaterial).set_shader_parameter(&"horizon", environment.fog_light_color)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.88
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.light_color = SUN_COLOR
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_blur = 1.5
	# (the sun is low: a little more bias, so nothing grazed by it is speckled with its own shadow)
	sun.shadow_normal_bias = 1.8
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR.normalized(), Vector3.UP)


## The water: Salmon Run 2's, in the colours of a slow brown autumn river.
func _water() -> void:
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/river_water.gdshader")
	var settings := {
		"deep": Color(0.10, 0.14, 0.11), "shallow": Color(0.42, 0.38, 0.24), "foam_color": Color(0.98, 0.92, 0.80),
		"depth_range": 4.0, "alpha_shallow": 0.55, "alpha_deep": 0.95, "colour_ripple": 0.08, "view_clear": 0.3,
		"foam_amount": 0.04, "whitecaps": 0.03, "foam_scale": 1.0, "edge_foam": 0.5, "rapid_foam": 0.0,
		"rim_width": 0.5, "rim_ragged": 0.5, "flow": 0.25, "swell": 1.0, "swell_height": 0.06, "swell_length": 9.0,
		"swell_speed": 0.7, "roughness": 0.5, "specular": 0.15, "lines": 0.5, "ripple_scale": 0.5, "ripple_height": 0.12,
		"ripple_choppy": 1.4, "ripple_speed": 0.6, "across": (SHORE + 6.0) * 2.0,
		"wake_spread": 0.9, "wake_width": 1.3, "wake_ragged": 0.6, "wake_churn": 0.7, "wake_echo": 0.5, "wake_calm": 0.35,
		"wake_life": WAKE_LIFE, "foam_texture": preload("res://textures/foam_noise.png"),
	}
	for key: String in settings:
		water_material.set_shader_parameter(key, settings[key])
	var plane := PlaneMesh.new()
	plane.size = Vector2((SHORE + 6.0) * 2.0, 2400.0)
	plane.subdivide_width = int(SHORE + 6.0)
	plane.subdivide_depth = 599
	water = MeshInstance3D.new()
	water.mesh = plane
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(0.0, 0.0, 120.0)
	add_child(water)


## The bow's trail through the water, handed to the water shader, which draws the wake from it
## (as Salmon Run 2's fx/wake.gd does for its salmon).
func _wake(delta: float) -> void:
	if boat == null:
		return
	_since += delta
	var bow := boat.position.z + Riverboat.BOW - 1.0
	if _since >= WAKE_LIFE / (WAKE_POINTS - 3) or _trail.is_empty():
		_since = 0.0
		_trail.append([bow, _clock])
	while not _trail.is_empty() and _clock - float(_trail[0][1]) > WAKE_LIFE:
		_trail.pop_front()
	while _trail.size() > WAKE_POINTS - 1:
		_trail.pop_front()
	var points := PackedVector3Array()
	var middle := 0.5 + boat.position.x / ((SHORE + 6.0) * 2.0)
	for piece: Array in _trail + [[bow, _clock]]:
		points.append(Vector3(middle, piece[0], _clock - float(piece[1])))
	var count := points.size()
	points.resize(WAKE_POINTS)
	water_material.set_shader_parameter(&"wake_pts", points)
	water_material.set_shader_parameter(&"wake_count", count)
	water_material.set_shader_parameter(&"wake_span", Vector2(float(_trail[0][0]) - 40.0, bow + 2.0))
	# and the wash behind the stern and the wheels
	water_material.set_shader_parameter(&"wash", Vector4(boat.position.x, boat.position.z + Riverboat.STERN,
			boat.position.z + Riverboat.WHEEL_Z, Riverboat.HALF_WIDTH + 0.8))


## One stretch of the banks, from z = 0 to SEGMENT (moved into place by its node).
func _segment() -> Node3D:
	var segment := Node3D.new()
	segment.name = "Banks"
	# What land each bank is, piece by piece: woods, cornfields, pumpkin patches, meadows (Farmland)
	var land := {1.0: Farmland.plan(_rng, SEGMENT), -1.0: Farmland.plan(_rng, SEGMENT)}
	_land = land
	var woods := func(side: float, z: float) -> bool: return Farmland.kind_at(land[side], z)[0] == "woods"
	for side: float in [1.0, -1.0]:
		segment.add_child(_bank(side, land[side]))
		Farmland.add(segment, side, land[side], SHORE, _ground, SUN_DIR, SUN_COLOR, _rng)
	# The woods: thick behind the bank, thinning back towards the hills (behind the fields, a line
	# of trees at their far edge; a lone tree or two out in a meadow)
	var variants: Array = []
	var kinds := ["oak", "oak", "tall", "leaner", "aspen", "aspen", "snag"]
	for k in kinds.size():
		variants.append(Woodland.variant(kinds[k], 300 + k))
	var cards: Array = []
	for side: float in [1.0, -1.0]:
		var z := 0.0
		while z < SEGMENT:
			z += _rng.randf_range(2.5, 6.5)
			var x := side * (SHORE + 6.0 + absf(_rng.randfn(0.0, 16.0)))
			if absf(x) > SHORE + 79.0:
				continue
			if not woods.call(side, z):
				var kind: String = Farmland.kind_at(land[side], z)[0]
				var lone := kind == "meadow" and absf(x) > SHORE + 12.0 and _rng.randf() < 0.05
				if absf(x) < SHORE + Farmland.FIELD_FAR + 3.0 and not lone:
					continue
			var v: Dictionary = variants[_rng.randi() % variants.size()]
			var at := Vector3(x, _ground(absf(x), z) - 0.1, z)
			var tr := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.35)), at)
			v["near" if absf(x) < SHORE + 26.0 else "far"].append(tr)
			if not v.bare:
				Woodland.crown_cards(v, tr, _rng, 3, cards)
	Woodland.add_trees(segment, variants, Woodland.material(Woodland.BARK, SUN_DIR, SUN_COLOR, {"moss": 0.4}),
		Woodland.material(Woodland.BARK, SUN_DIR, SUN_COLOR, {"birch": 1.0}))
	Woodland.add_leaf_clumps(segment, cards, Woodland.material(Woodland.FOLIAGE, SUN_DIR, SUN_COLOR))
	# Reeds along the water's edge (the grass over the bank is Grass: _grass)
	var tufts: Array = []
	for side: float in [1.0, -1.0]:
		var z := 0.0
		while z < SEGMENT:
			z += _rng.randf_range(0.4, 1.1)
			var x := side * (SHORE + _rng.randf_range(-1.4, 0.6))
			var size := _rng.randf_range(1.5, 2.6)
			tufts.append([Vector3(x, maxf(_ground(absf(x), z), -0.3) + size * 0.45, z), Color(size, 0.05 + 0.2 * _rng.randf(), _rng.randf_range(0.4, 0.8), _rng.randf())])
	Woodland.add_leaf_clumps(segment, tufts, Woodland.material(Woodland.FOLIAGE, SUN_DIR, SUN_COLOR, {"blades": 1.0}))
	# Bushes along the top of the bank
	var bushes := {"ember": [], "bronze": [], "bracken": [], "shadow": []}
	for side: float in [1.0, -1.0]:
		var z := 0.0
		while z < SEGMENT:
			z += _rng.randf_range(4.0, 11.0)
			var x := side * (SHORE + _rng.randf_range(2.5, 9.0))
			if Farmland.kind_at(land[side], z)[0] in ["corn", "pumpkins"]:
				continue
			var kind: String = bushes.keys()[_rng.randi() % bushes.size()]
			bushes[kind].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.6)), Vector3(x, _ground(absf(x), z), z)))
	Woodland.add_bushes(segment, bushes, SUN_DIR, SUN_COLOR)
	# Leaves coming down over the water and the banks
	var falling: Array = []
	for k in 260:
		falling.append(Woodland.leaf_card(_rng, Vector3(_rng.randf_range(-SHORE - 10.0, SHORE + 10.0), 0.0, _rng.randf() * SEGMENT), true))
	Woodland.add_leaves(segment, falling, Woodland.material(Woodland.LEAF, SUN_DIR, SUN_COLOR, {"falling": 1.0}),
		AABB(Vector3(-SHORE - 12.0, -1.0, 0.0), Vector3((SHORE + 12.0) * 2.0, 18.0, SEGMENT)))
	# (the woods are painted, not lit: they cast no shadows on the river or the boat)
	for drawn: Node in segment.find_children("*", "GeometryInstance3D", true, false):
		(drawn as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return segment


## The grass over the banks of a stretch: Warren's grass (Grass), blade by blade, swaying in the
## wind. Short and dry along the top of the bank and through the woods, tall and gold over the
## meadows; none on the mud below the lip, in the corn or among the pumpkins.
func _grass(segment: Node3D) -> void:
	var colours := {"ground": Color(0.42, 0.3, 0.14), "body": Color(0.56, 0.44, 0.2), "tip": Color(0.8, 0.66, 0.36),
			"dry": Color(0.72, 0.48, 0.2), "dryness": 0.55, "wind_dir": Vector2(0.3, 1.0), "wind": 0.35, "flutter": 0.08,
			"petals": [Color(0.96, 0.92, 0.8), Color(0.98, 0.78, 0.22), Color(0.82, 0.5, 0.75)], "translucency": 0.2}
	# (desktop only: the finest grass)
	Grass.quality = Grass.Quality.HIGH
	var wide := Farmland.FIELD_FAR + 8.0
	for side: float in [1.0, -1.0]:
		var pieces: Array = _land[side]
		var area := Rect2(SHORE - 1.0 if side > 0.0 else -SHORE + 1.0 - wide, 0.0, wide, SEGMENT)
		var height := func(p: Vector2) -> float: return _ground(absf(p.x), p.y) - 0.03
		# (how far up from the water: none on the cut of mud, coming in over the lip)
		var bank := func(p: Vector2) -> float:
			var shore := SHORE + sin(p.y * 0.06) * 0.9 + sin(p.y * 0.17 + 1.3) * 0.4
			return smoothstep(shore + 0.6, shore + 1.0, absf(p.x))
		var short := func(p: Vector2) -> float:
			var found := Farmland.kind_at(pieces, p.y)
			var back := absf(p.x) - SHORE
			var keep := 1.0
			match found[0]:
				"meadow":
					keep = 1.0 - smoothstep(2.5, 6.0, back) * smoothstep(0.0, 4.0, found[1])
				"corn", "pumpkins":
					keep = 1.0 - smoothstep(Farmland.FIELD_NEAR - 2.5, Farmland.FIELD_NEAR - 1.0, back) * smoothstep(0.0, 3.0, found[1])
				_:
					keep = 1.0 - 0.5 * smoothstep(10.0, wide, back)
			return bank.call(p) * keep
		var tall := func(p: Vector2) -> float:
			var found := Farmland.kind_at(pieces, p.y)
			if found[0] != "meadow":
				return 0.0
			var back := absf(p.x) - SHORE
			return bank.call(p) * smoothstep(2.5, 6.0, back) * smoothstep(0.0, 4.0, found[1])
		var low := colours.duplicate()
		low.merge({"mask": short, "height": height, "seed": 11 + int(side), "flowers": 0.02, "blade_height": 0.5, "blade_width": 0.04})
		Grass.field(segment, area, 1.0, low)
		var high := colours.duplicate()
		high.merge({"mask": tall, "height": height, "seed": 21 + int(side), "flowers": 0.0, "blade_height": 1.05, "blade_width": 0.05,
				"lean": 0.45, "body": Color(0.64, 0.48, 0.22), "tip": Color(0.86, 0.7, 0.4), "dryness": 0.7})
		Grass.field(segment, area, 0.8, high)


## How high the ground is `x` from the middle of the river, `z` along it: the river's bed, a
## cut bank of mud rising out of the water, a lip, and dry grassland rolling away.
func _ground(x: float, z: float) -> float:
	var wobble := sin(z * 0.06) * 0.9 + sin(z * 0.17 + 1.3) * 0.4
	var shore := SHORE + wobble
	if x < shore - 3.0:
		# (the bed: a channel deepest down the middle, with long low humps of silt along it)
		var silt := (sin(z * 0.05 + x * 0.21) * 0.5 + 0.5) * sin(z * 0.013 - x * 0.05) * 0.35
		return -1.8 - 1.4 * (1.0 - smoothstep(0.0, shore - 3.0, absf(x))) + silt * smoothstep(0.0, 6.0, shore - 3.0 - x)
	var cut := smoothstep(shore - 3.0, shore + 0.6, x) * 2.2 - 1.8
	var lip := 0.25 * exp(-pow((x - shore - 1.0) / 0.9, 2.0))
	var roll := 0.0
	if x > shore + 2.0:
		roll = (sin(z * 0.045 + x * 0.03) * 1.2 + sin(z * 0.11 - x * 0.07) * 0.5 + 1.75) * smoothstep(shore + 2.0, shore + 30.0, x)
		# (and lies down again at the outer edge, to meet FarLand's plain, which it always keeps above)
		roll *= 1.0 - smoothstep(SHORE + 110.0, SHORE + 165.0, x)
	return cut + lip + roll + maxf(x - shore, 0.0) * 0.015


## A bank: from under the water up the cut of mud to the grass, and back to the hills.
func _bank(side: float, land: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array[float] = []
	# (from the middle of the river, under the water, out across the bank)
	for x: float in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 23.5, SHORE - 5.0, SHORE - 3.5, SHORE - 2.5, SHORE - 1.6, SHORE - 0.8, SHORE, SHORE + 0.6, SHORE + 1.2, SHORE + 2.0, SHORE + 3.5,
			SHORE + 6.0, SHORE + 10.0, SHORE + 16.0, SHORE + 26.0, SHORE + 42.0, SHORE + 70.0, SHORE + 110.0, SHORE + 140.0, SHORE + 175.0]:
		xs.append(x)
	var step := 2.0
	var rows := int(SEGMENT / step) + 1
	var wet := Color(0.17, 0.13, 0.09)
	var silt := Color(0.30, 0.25, 0.16)
	var weed := Color(0.16, 0.2, 0.09)
	var mud := Color(0.36, 0.25, 0.15)
	var grass := Color(0.80, 0.60, 0.30)
	var dry := Color(0.64, 0.44, 0.22)
	var green := Color(0.48, 0.48, 0.24)
	for r in rows - 1:
		for c in xs.size() - 1:
			var quad := []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var z := (r + corner.y) * step
				var shore := SHORE + sin(z * 0.06) * 0.9 + sin(z * 0.17 + 1.3) * 0.4
				var x: float = xs[c + corner.x] + (shore - SHORE) * (1.0 - smoothstep(SHORE + 6.0, SHORE + 20.0, xs[c + corner.x]))
				var y := _ground(x, z)
				var colour := wet.lerp(mud, smoothstep(shore - 1.5, shore, x)).lerp(grass, smoothstep(shore + 0.4, shore + 1.6, x))
				# (the bed: pale silt in drifts, dark weed between)
				var drift := 0.5 + 0.5 * sin(z * 0.09 + x * 0.4) * sin(z * 0.031 - x * 0.13)
				var under := 1.0 - smoothstep(shore - 4.0, shore - 2.0, x)
				colour = colour.lerp(silt.lerp(weed, smoothstep(0.55, 0.8, 1.0 - drift)), under)
				var patch := 0.5 + 0.5 * sin(z * 0.21 + x * 0.17) * sin(z * 0.07 - x * 0.31)
				colour = colour.lerp(dry, patch * smoothstep(shore + 2.0, shore + 6.0, x) * 0.7)
				colour = colour.lerp(green, (1.0 - patch) * 0.35 * smoothstep(shore + 3.0, shore + 12.0, x))
				colour = Farmland.ground_colour(land, colour, x - shore, z)
				# (going over to the far country's colour at the outer edge, where its plain takes over)
				colour = colour.lerp(Color(0.72, 0.54, 0.30), smoothstep(SHORE + 60.0, SHORE + 170.0, x))
				quad.append([Vector3(side * x, y, z), colour])
			var order := [0, 1, 2, 0, 2, 3] if side < 0.0 else [0, 2, 1, 0, 3, 2]
			var a: Vector3 = quad[order[0]][0]
			var b: Vector3 = quad[order[1]][0]
			var c3: Vector3 = quad[order[2]][0]
			var normal := (b - a).cross(c3 - a).normalized()
			if normal.y < 0.0:
				normal = -normal
			for k in order:
				st.set_color(quad[k][1])
				st.set_normal(normal)
				st.add_vertex(quad[k][0])
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ground.gdshader")
	material.set_shader_parameter(&"sun_dir", SUN_DIR.normalized())
	material.set_shader_parameter(&"sun_color", SUN_COLOR)
	var bank := MeshInstance3D.new()
	bank.mesh = st.commit()
	bank.material_override = material
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bank
