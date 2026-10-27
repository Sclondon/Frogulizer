class_name Splash
extends Node3D
## A splash: Salmon Run 2's (scripts/fx/splash.gd, with its shader shaders/splash.gdshader and the
## meshes from its scripts/world/props.gd), here thrown up by the riverboat's paddles (WheelSpray).
## Three tubes of water, one inside the other like the tiers of a cake (the outer one wide and low,
## the inner one narrow and tall), that shoot up out of the surface with ragged crests and drop back
## into it, ripples spreading across the water, and a burst of splattery drops.
##
## It stays where it was thrown up (top level, in the world), so the boat leaves it behind. Whoever
## uses them keeps a few and starts them in turn: making them afresh each time is slow.

const LIFE := 1.0
## Each tube, from the inside out: how far out, how tall, how many waves in its crest, and when it
## goes up.
const TUBES := [[0.5, 2.7, 5.0, 0.0], [1.15, 1.75, 7.0, 0.05], [1.9, 0.95, 10.0, 0.1]]
const TUBE_TIME := 0.62
## Each ripple: when it starts, and how wide it gets.
const RIPPLES := [[0.0, 3.2], [0.14, 4.4], [0.3, 5.6]]
const RIPPLE_TIME := 0.75
## Each burst of drops: which mesh, how many, how big, and how fast they are flung (slowest and fastest).
const BURSTS := [["drop", 12, 0.26, 5.0, 11.0], ["splat", 9, 0.34, 3.5, 8.0], ["dot", 26, 0.11, 4.0, 13.0]]
const WHITE := Color(0.96, 0.98, 1.0)
const BLUE := Color(0.62, 0.78, 0.9)

static var _meshes := {}
static var _mat: StandardMaterial3D

var strength := 1.0
## How the tubes are drawn out across (x) and along (z): a paddle throws up a sheet, wider than deep.
var spread := Vector2.ONE

var _t := 0.0
var _tubes: Array[MeshInstance3D] = []
var _ripples: Array[MeshInstance3D] = []
var _bursts: Array[CPUParticles3D] = []


## Plain water, unlit, coloured by the mesh (and the particles' colour).
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


static func mesh(key: String) -> Mesh:
	if _meshes.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		_meshes["tube"] = _tube()
		_meshes["ring"] = _ring()
		_meshes["drop"] = _blobs(rng, [[Vector3.ZERO, Vector3(0.5, 0.5, 0.5), WHITE]], 0.25)
		_meshes["splat"] = _blobs(rng, [[Vector3.ZERO, Vector3(0.5, 0.3, 0.42), WHITE], [Vector3(-0.5, 0.05, 0.0), Vector3(0.28, 0.16, 0.2), BLUE],
				[Vector3(-0.85, 0.1, 0.05), Vector3(0.13, 0.1, 0.1), WHITE]], 0.3)
		var dot_mesh := SphereMesh.new()
		dot_mesh.radius = 0.5
		dot_mesh.height = 1.0
		dot_mesh.radial_segments = 6
		dot_mesh.rings = 3
		_meshes["dot"] = dot_mesh
	return _meshes[key]


func _init() -> void:
	top_level = true
	visible = false
	set_process(false)
	for i in TUBES.size():
		var node := MeshInstance3D.new()
		node.mesh = mesh("tube")
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/splash.gdshader")
		mat.set_shader_parameter("waves", TUBES[i][2])
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		_tubes.append(node)
	for i in RIPPLES.size():
		var node := MeshInstance3D.new()
		node.mesh = mesh("ring")
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.0)
		mat.render_priority = 1
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_ripples.append(node)
	for b: Array in BURSTS:
		_bursts.append(_burst(b[0], b[1], b[2]))


## Throws it up at `where` (in the world; its up is the water's), `how_big`, in the water's colours.
func start(where: Transform3D, how_big: float, water: Color, foam: Color) -> void:
	strength = how_big
	_t = 0.0
	for node in _tubes:
		node.visible = false
		var mat := node.material_override as ShaderMaterial
		mat.set_shader_parameter("phase", randf() * TAU)
		mat.set_shader_parameter("white", foam)
		mat.set_shader_parameter("pale", water.lerp(foam, 0.55))
		mat.set_shader_parameter("blue", water.lerp(foam, 0.15))
	for node in _ripples:
		node.visible = false
		(node.material_override as StandardMaterial3D).albedo_color = Color(foam, 0.0)
	for i in _bursts.size():
		var p := _bursts[i]
		p.initial_velocity_min = float(BURSTS[i][3]) * sqrt(strength)
		p.initial_velocity_max = float(BURSTS[i][4]) * sqrt(strength)
		p.scale_amount_min = float(BURSTS[i][2]) * 0.6 * sqrt(strength)
		p.scale_amount_max = float(BURSTS[i][2]) * 1.3 * sqrt(strength)
		p.color = water.lerp(foam, 0.7)
		p.restart()
		p.emitting = true
	global_transform = where
	visible = true
	set_process(true)


func _burst(key: String, amount: int, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh(key)
	p.material_override = material()
	p.amount = amount
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.8
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 62.0
	p.gravity = Vector3(0, -24, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		visible = false
		set_process(false)
		return
	for i in _tubes.size():
		var u := (_t - float(TUBES[i][3])) / TUBE_TIME
		var node := _tubes[i]
		node.visible = u > 0.0 and u < 1.0
		if not node.visible:
			continue
		# up fast, hang at the top, then drop back: the key pose is the top, a fifth of the way in
		var rise := sin(minf(u / 0.2, 1.0) * PI * 0.5) if u < 0.2 else 1.0 - pow((u - 0.2) / 0.8, 2.0)
		var r := float(TUBES[i][0]) * sqrt(strength) * (1.0 + 0.3 * u)
		node.scale = Vector3(r * spread.x, maxf(float(TUBES[i][1]) * strength * rise, 0.01), r * spread.y)
		(node.material_override as ShaderMaterial).set_shader_parameter("spent", smoothstep(0.3, 1.0, u))
	for i in _ripples.size():
		var u := (_t - float(RIPPLES[i][0])) / RIPPLE_TIME
		var node := _ripples[i]
		node.visible = u > 0.0 and u < 1.0
		if not node.visible:
			continue
		var r := lerpf(0.5, float(RIPPLES[i][1]) * sqrt(strength), 1.0 - pow(1.0 - u, 2.5))
		node.scale = Vector3(r * spread.x, 1.0, r * spread.y)
		(node.material_override as StandardMaterial3D).albedo_color.a = (1.0 - u) * 0.55


# --- The meshes (Salmon Run 2's props.gd: splash_tube, splash_ring, droplet, splat) ---

## A tube of water, a little flared at the top: UV.x round it, UV.y up it (0 to 1 high).
static func _tube() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 28
	var rows := 4
	for j in rows + 1:
		var v := float(j) / rows
		var radius := 1.0 + 0.16 * v * v
		for i in seg + 1:
			var a := TAU * i / seg
			st.set_uv(Vector2(float(i) / seg, v))
			st.add_vertex(Vector3(cos(a) * radius, v, sin(a) * radius))
	for j in rows:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			for k: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(k)
	return st.commit()


## A flat ring on the water, 1 across at its outside.
static func _ring() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 20
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		for p: Vector3 in [d0 * 0.84, d1, d1 * 0.84, d0 * 0.84, d0, d1]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()


## Lumpy blobs of water ([centre, radii, colour] each), never quite round, never square.
static func _blobs(rng: RandomNumberGenerator, parts: Array, lumpy: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 6
	var rings := 4
	for part: Array in parts:
		var centre: Vector3 = part[0]
		var radii: Vector3 = part[1]
		var colour: Color = part[2]
		var bumps: Array = []
		for j in rings + 1:
			var row: Array = []
			for i in seg:
				row.append(1.0 + rng.randf_range(-lumpy, lumpy) * (0.0 if j == 0 or j == rings else 1.0))
			bumps.append(row)
		var at := func(j: int, i: int) -> Vector3:
			var v := PI * j / rings
			var a := TAU * (i % seg) / seg
			var bump: float = bumps[j][i % seg]
			return centre + Vector3(sin(v) * cos(a) * radii.x, cos(v) * radii.y, sin(v) * sin(a) * radii.z) * bump
		for j in rings:
			for i in seg:
				var a: Vector3 = at.call(j, i)
				var b: Vector3 = at.call(j, i + 1)
				var c: Vector3 = at.call(j + 1, i)
				var d: Vector3 = at.call(j + 1, i + 1)
				for p: Vector3 in [a, b, c, b, d, c]:
					st.set_color(colour)
					st.add_vertex(p)
	st.generate_normals()
	return st.commit()
