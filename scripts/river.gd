class_name River
extends Node3D
## The river the boat goes down, at the golden hour: the sun low ahead over the
## water, a painted sky (GameCommon's painted woodland), banks of dry grass and
## mud with reeds along the water, autumn woods on both sides (oaks, aspens,
## leaners and snags, from the same kit), hills going back in the haze, and
## leaves coming down over the deck.
##
## The boat stands still and the river goes by it: the banks are built in a
## stretch SEGMENT long, twice, end to end, and each is moved back past the boat
## and round to the front again when it has gone by. The water itself stays
## (its pattern runs past instead).

const SEGMENT := 260.0
## A stretch is moved round to the front once its far end is this far behind the boat.
const BEHIND := 110.0
## Where the water meets the bank, and how far the river's bed reaches.
const SHORE := 13.0
const SUN_DIR := Vector3(0.18, 0.11, 1.0)
const SUN_COLOR := Color(1.0, 0.78, 0.5)

## How fast the boat goes, m/s.
var speed := 2.5
var water: Water
var sun: DirectionalLight3D
var environment: Environment
var _segments: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 41
	_air()
	_water()
	var first := _segment()
	add_child(first)
	first.position.z = -BEHIND - 10.0
	_segments.append(first)
	var second := first.duplicate()
	add_child(second)
	second.position.z = first.position.z + SEGMENT
	_segments.append(second)
	_segments.append(second)
	_hills()
	_leaves()
	for drawn: Node in find_children("*", "MultiMeshInstance3D", false, false):
		(drawn as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	for segment in _segments:
		segment.position.z -= speed * delta
		if segment.position.z + SEGMENT < -BEHIND:
			segment.position.z += SEGMENT * 2.0


func _air() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Woodland.sky(SUN_DIR)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.50, 0.40, 0.36)
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = Color(0.80, 0.62, 0.46)
	environment.fog_density = 0.0055
	environment.fog_sun_scatter = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR.normalized(), Vector3.UP)


func _water() -> void:
	water = Water.new()
	water.size = Vector3(SHORE * 2.0 + 6.0, 4.0, 520.0)
	water.position = Vector3(0.0, 0.0, 40.0)
	water.shallow = Color(0.45, 0.42, 0.30)
	water.deep = Color(0.16, 0.20, 0.17)
	water.sky = Color(1.0, 0.76, 0.48)
	water.mirror = 0.6
	water.self_lit = 0.55
	water.flow = Vector2(0.0, -speed)
	water.foam = Color(0.98, 0.9, 0.78)
	water.foam_drift = 0.0
	water.lines = 0.25
	water.glint = 0.5
	water.swell_height = 0.05
	water.underwater = false
	water.drops = false
	add_child(water)


## One stretch of the banks, from z = 0 to SEGMENT (moved into place by its node).
func _segment() -> Node3D:
	var segment := Node3D.new()
	segment.name = "Banks"
	for side: float in [1.0, -1.0]:
		segment.add_child(_bank(side))
	# The woods: thick near the water, thinning back to the hills
	var variants: Array = []
	var kinds := ["oak", "oak", "tall", "leaner", "aspen", "aspen", "snag"]
	for k in kinds.size():
		variants.append(Woodland.variant(kinds[k], 300 + k))
	var cards: Array = []
	for side: float in [1.0, -1.0]:
		var z := 0.0
		while z < SEGMENT:
			z += _rng.randf_range(2.0, 6.5)
			var x := side * (SHORE + 4.0 + absf(_rng.randfn(0.0, 14.0)))
			if absf(x) > 90.0:
				continue
			var v: Dictionary = variants[_rng.randi() % variants.size()]
			var at := Vector3(x, _ground(absf(x), z) - 0.1, z)
			var tr := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3)), at)
			v["near" if absf(x) < SHORE + 22.0 else "far"].append(tr)
			if not v.bare:
				Woodland.crown_cards(v, tr, _rng, 3, cards)
	Woodland.add_trees(segment, variants, Woodland.material(Woodland.BARK, SUN_DIR, SUN_COLOR, {"moss": 0.4}),
		Woodland.material(Woodland.BARK, SUN_DIR, SUN_COLOR, {"birch": 1.0}))
	Woodland.add_leaf_clumps(segment, cards, Woodland.material(Woodland.FOLIAGE, SUN_DIR, SUN_COLOR))
	# Reeds and dry grass along the water's edge
	var reeds: Array = []
	for side: float in [1.0, -1.0]:
		var z := 0.0
		while z < SEGMENT:
			z += _rng.randf_range(0.5, 1.4)
			var x := side * (SHORE + _rng.randf_range(-0.6, 2.2))
			var size := _rng.randf_range(1.4, 2.6)
			reeds.append([Vector3(x, _ground(absf(x), z) + size * 0.45, z), size, _rng.randf()])
	var grass := Woodland.material(Woodland.FOLIAGE, SUN_DIR, SUN_COLOR, {"blades": 1.0})
	Woodland.add_leaf_clumps(segment, _reed_cards(reeds), grass)
	# (the woods are painted, not lit: they cast no shadows on the river or the boat)
	for drawn: Node in segment.find_children("*", "GeometryInstance3D", true, false):
		(drawn as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return segment


## Woodland's leaf-clump cards ([position, custom]: size, leaf + hue, how lit, a seed), as tufts of reed.
func _reed_cards(reeds: Array) -> Array:
	var cards := []
	for reed: Array in reeds:
		cards.append([reed[0], Color(reed[1], 0.05 + 0.25 * reed[2], _rng.randf_range(0.4, 0.8), _rng.randf())])
	return cards


## How high the ground is `x` from the middle of the river, `z` along it.
func _ground(x: float, z: float) -> float:
	if x < SHORE - 2.0:
		return -1.5
	var rise := smoothstep(SHORE - 2.0, SHORE + 2.5, x) * 1.6 - 1.2
	var roll := 0.0
	if x > SHORE + 3.0:
		roll = (sin(z * 0.045 + x * 0.03) * 1.2 + sin(z * 0.11 - x * 0.07) * 0.5 + 1.2) * smoothstep(SHORE + 3.0, SHORE + 30.0, x)
	return rise + roll + (x - SHORE) * 0.02


## A bank: a strip of ground from under the water up and back, mud at the edge, then dry gold grass.
func _bank(side: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array[float] = [SHORE - 3.0, SHORE - 1.0, SHORE, SHORE + 1.0, SHORE + 2.5, SHORE + 5.0, SHORE + 9.0, SHORE + 15.0, SHORE + 24.0, SHORE + 40.0, SHORE + 65.0, SHORE + 100.0]
	var step := 4.0
	var rows := int(SEGMENT / step) + 1
	var mud := Color(0.30, 0.22, 0.14)
	var wet := Color(0.22, 0.17, 0.11)
	var grass := Color(0.78, 0.58, 0.28)
	var dry := Color(0.66, 0.45, 0.22)
	for r in rows - 1:
		for c in xs.size() - 1:
			var quad := []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var x: float = xs[c + corner.x]
				var z := (r + corner.y) * step
				var y := _ground(x, z)
				var colour := wet.lerp(mud, smoothstep(SHORE - 1.0, SHORE + 0.5, x)).lerp(grass, smoothstep(SHORE + 0.5, SHORE + 3.0, x))
				var patch := 0.5 + 0.5 * sin(z * 0.21 + x * 0.17) * sin(z * 0.07 - x * 0.31)
				colour = colour.lerp(dry, patch * smoothstep(SHORE + 2.0, SHORE + 6.0, x) * 0.7)
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


## Hills far off on both sides, dark and soft in the haze, and a far ridge ahead under the sun.
func _hills() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ground.gdshader")
	material.set_shader_parameter(&"sun_dir", SUN_DIR.normalized())
	material.set_shader_parameter(&"sun_color", SUN_COLOR)
	for k in 14:
		var side := 1.0 if k % 2 == 0 else -1.0
		var mesh := SphereMesh.new()
		mesh.radius = _rng.randf_range(40.0, 80.0)
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 24
		mesh.rings = 12
		var hill := MeshInstance3D.new()
		hill.mesh = mesh
		hill.material_override = material
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var colour := Color(0.42, 0.30, 0.22).lerp(Color(0.62, 0.42, 0.30), _rng.randf())
		hill.set_instance_shader_parameter(&"tint", colour)
		hill.position = Vector3(side * _rng.randf_range(110.0, 170.0), -mesh.radius * 0.72, _rng.randf_range(-200.0, 300.0))
		hill.scale = Vector3(1.6, 0.6, 1.4)
		add_child(hill)


## Leaves coming down over the boat, carried back by the wind of its going.
func _leaves() -> void:
	var falling: Array = []
	for i in 90:
		falling.append(Woodland.leaf_card(_rng, Vector3(_rng.randf_range(-14, 14), Riverboat.DECK_Y, _rng.randf_range(-18, 18)), true))
	var box := AABB(Vector3(-16, 0, -20), Vector3(32, 20, 40))
	Woodland.add_leaves(self, falling, Woodland.material(Woodland.LEAF, SUN_DIR, SUN_COLOR, {"falling": 1.0}), box)
