class_name FarLand
extends Node3D
## The country beyond the banks, out to the horizon on both sides and far ahead and behind, so the
## world has no edge from any camera: a wide plain of ground going on from the banks (and carrying
## the river's banks on, plainly, past where River's own stretches end), painted into a patchwork
## of fields with hedges between them (shaders/far_ground.gdshader); woods in clumps of round crowns
## out over it; a farmstead or a windmill here and there; and long ridges of hills further back, all
## going into the sundown haze.
##
## Built in tiles TILE long, three end to end, each moved on to the front once it is far enough
## behind the boat (as River's stretches are). Everything in a tile is the same from one tile to
## the next where they meet: the ground does not change along the river, and the ridges' heights
## repeat every TILE.

const TILE := 600.0
## A tile is moved on once its far end is this far behind the boat.
const BEHIND := 700.0
## How far out the plain goes from the middle of the river.
const OUT := 2600.0
const RIDGE_FROM := 380.0
const RIDGE_TOP := 620.0
## Across the ridges, out from the river: where each line of the mesh runs, and how much of the
## ridge's height it has there.
const RIDGE_XS := [RIDGE_FROM, RIDGE_FROM + 70.0, RIDGE_FROM + 150.0, RIDGE_TOP, RIDGE_TOP + 160.0, RIDGE_TOP + 420.0]
const RIDGE_RISE := [0.0, 0.18, 0.55, 1.0, 0.85, 0.3]

var boat: Node3D
var sun_dir := Vector3(-0.75, 0.16, -1.0)
var sun_color := Color(1.0, 0.82, 0.62)
var _tiles: Array[Node3D] = []
var _sails: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 77
	var first := _tile()
	add_child(first)
	_tiles.append(first)
	for k in 2:
		var other: Node3D = first.duplicate()
		add_child(other)
		_tiles.append(other)
		for sail in other.find_children("Sails*", "Node3D", true, false):
			_sails.append(sail)
	for k in _tiles.size():
		_tiles[k].position.z = (k - 1) * TILE


func _process(delta: float) -> void:
	var at := boat.position.z if boat else 0.0
	for tile in _tiles:
		if tile.position.z + TILE < at - BEHIND:
			tile.position.z += TILE * _tiles.size()
		elif tile.position.z > at + TILE * 2.0:
			tile.position.z -= TILE * _tiles.size()
	for sail in _sails:
		sail.rotate_object_local(Vector3.FORWARD, delta * 0.35)


## How high the plain is `x` out from the middle of the river (it does not change along the river).
## Under River's banks it keeps a little below the lowest they go, so they always cover it; past
## them it goes on rising gently to the horizon.
static func height(x: float) -> float:
	var shore := River.SHORE + 1.3
	var cut := smoothstep(shore - 3.0, shore + 0.6, x) * 2.2 - 1.8
	var y := cut + maxf(minf(x, 420.0) - shore, 0.0) * 0.015 - 0.35
	return y + maxf(x - 420.0, 0.0) * 0.0045


## How high the land is with the ridges on it, `x` out on `side`, `z` along.
static func land(x: float, z: float, side: float) -> float:
	var rise := 0.0
	for c in RIDGE_XS.size() - 1:
		if x >= RIDGE_XS[c] and x <= RIDGE_XS[c + 1]:
			rise = lerpf(RIDGE_RISE[c], RIDGE_RISE[c + 1], (x - RIDGE_XS[c]) / (RIDGE_XS[c + 1] - RIDGE_XS[c]))
	return height(x) + maxf(ridge(z, side) * rise - 0.5, 0.0)


## The height of the ridges' tops at `z` (repeating every TILE), on one `side`.
static func ridge(z: float, side: float) -> float:
	var t := z / TILE * TAU
	var phase := 0.0 if side > 0.0 else 2.1
	return 34.0 + 14.0 * sin(t + phase) + 8.0 * sin(t * 3.0 + phase * 1.7) + 4.0 * sin(t * 7.0 + 0.4)


func _tile() -> Node3D:
	var tile := Node3D.new()
	tile.name = "FarTile"
	for side: float in [1.0, -1.0]:
		tile.add_child(_plain(side))
		tile.add_child(_ridges(side))
		_woods(tile, side)
		for k in _rng.randi_range(1, 2):
			_farmstead(tile, side)
	for drawn: Node in tile.find_children("*", "GeometryInstance3D", true, false):
		(drawn as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tile


func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"sun_dir", sun_dir.normalized())
	material.set_shader_parameter(&"sun_color", sun_color)
	return material


## The plain on one side: the bank going down to the river bed, and the fields out to the horizon.
func _plain(side: float) -> MeshInstance3D:
	var xs: Array[float] = []
	for x: float in [River.SHORE - 8.0, River.SHORE - 3.0, River.SHORE - 1.0, River.SHORE + 0.5, River.SHORE + 1.5, River.SHORE + 3.0,
			River.SHORE + 6.0, River.SHORE + 12.0, River.SHORE + 24.0, River.SHORE + 54.0, River.SHORE + 94.0, River.SHORE + 144.0, River.SHORE + 204.0, 300.0, 400.0, 520.0, 700.0, 950.0,
			1300.0, 1800.0, OUT]:
		xs.append(x)
	var wet := Color(0.17, 0.13, 0.09)
	var mud := Color(0.36, 0.25, 0.15)
	var grass := Color(0.80, 0.60, 0.30)
	var far := Color(0.72, 0.54, 0.30)
	var shore := River.SHORE + 1.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 25.0
	for r in int(TILE / step):
		for c in xs.size() - 1:
			var quad := []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var x: float = xs[c + corner.x]
				var z := (r + corner.y) * step
				var colour := wet.lerp(mud, smoothstep(shore - 1.5, shore, x)).lerp(grass, smoothstep(shore + 0.4, shore + 1.6, x))
				colour = colour.lerp(far, smoothstep(River.SHORE + 64.0, River.SHORE + 184.0, x))
				quad.append([Vector3(side * x, height(x), z), colour])
			var order := [0, 1, 2, 0, 2, 3] if side < 0.0 else [0, 2, 1, 0, 3, 2]
			for k: int in order:
				st.set_color(quad[k][1])
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[k][0])
	var plain := MeshInstance3D.new()
	plain.mesh = st.commit()
	plain.material_override = _material(preload("res://shaders/far_ground.gdshader"))
	(plain.material_override as ShaderMaterial).set_shader_parameter(&"fields_from", Vector2(River.SHORE + 140.0, River.SHORE + 250.0))
	return plain


## Long ridges of hills a way back, their tops rising and falling along the river, dusky with woods.
func _ridges(side: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 10.0
	var xs := RIDGE_XS
	var rise := RIDGE_RISE
	for r in int(TILE / step):
		for c in xs.size() - 1:
			var corners := []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var x: float = xs[c + corner.x]
				var z := (r + corner.y) * step
				var y := height(x) - 0.5 + ridge(z, side) * float(rise[c + corner.x])
				corners.append(Vector3(side * x, y, z))
			var a: Vector3 = corners[0]
			var normal: Vector3 = (corners[1] - a).cross(corners[3] - a).normalized()
			if normal.y < 0.0:
				normal = -normal
			var order := [0, 1, 2, 0, 2, 3] if side < 0.0 else [0, 2, 1, 0, 3, 2]
			for k: int in order:
				# (darker up on the wooded tops)
				var top := float(rise[c + (1 if k in [1, 2] else 0)])
				st.set_color(Color(0.66, 0.46, 0.30).lerp(Color(0.46, 0.30, 0.22), top))
				st.set_normal(normal)
				st.add_vertex(corners[k])
	var ridges := MeshInstance3D.new()
	ridges.mesh = st.commit()
	ridges.material_override = _material(preload("res://shaders/ground.gdshader"))
	return ridges


## Woods out over the plain: clumps of round crowns in autumn colours, and a few lone trees.
func _woods(tile: Node3D, side: float) -> void:
	var crowns: Array = []
	var colours := [Color(0.80, 0.44, 0.16), Color(0.88, 0.62, 0.22), Color(0.62, 0.30, 0.14), Color(0.70, 0.52, 0.22), Color(0.52, 0.36, 0.18)]
	for patch in _rng.randi_range(6, 9):
		# (out past where River's banks lie down into the plain)
		var size := Vector2(_rng.randf_range(25.0, 80.0), _rng.randf_range(30.0, 110.0))
		var centre := Vector2(_rng.randf_range(River.SHORE + 194.0 + size.x, 600.0), _rng.randf_range(0.0, TILE))
		for k in int(size.x * size.y / 70.0):
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf())
			var p := centre + Vector2(cos(a) * size.x, sin(a) * size.y) * r
			if p.y < 0.0 or p.y > TILE:
				continue
			crowns.append([p, _rng.randf_range(0.8, 1.3)])
	for k in 40:
		crowns.append([Vector2(_rng.randf_range(River.SHORE + 194.0, 650.0), _rng.randf_range(0.0, TILE)), _rng.randf_range(0.9, 1.2)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var crown := SphereMesh.new()
	crown.radial_segments = 8
	crown.rings = 5
	mm.mesh = crown
	# (each crown a cluster of lumps, not one ball: a big one in the middle, smaller ones round it,
	# all in one colour)
	var lumps := [[Vector3(0.0, 5.0, 0.0), 1.0], [Vector3(4.2, 3.6, 0.8), 0.72], [Vector3(-3.6, 3.8, -1.5), 0.68],
			[Vector3(0.8, 3.4, 4.0), 0.6], [Vector3(-0.6, 8.2, 0.4), 0.55]]
	mm.instance_count = crowns.size() * lumps.size()
	var i := 0
	for placed: Array in crowns:
		var p: Vector2 = placed[0]
		var s: float = placed[1]
		var x := p.x
		var foot := Vector3(side * x, land(x, p.y, side), p.y)
		var turn := Basis(Vector3.UP, _rng.randf() * TAU)
		var colour: Color = colours[_rng.randi() % colours.size()].darkened(_rng.randf_range(0.0, 0.2))
		for lump: Array in lumps:
			var size: float = lump[1] * s * _rng.randf_range(0.85, 1.15)
			var basis := turn.scaled(Vector3(6.0, 5.4, 6.0) * size)
			mm.set_instance_transform(i, Transform3D(basis, foot + turn * (lump[0] as Vector3) * s))
			mm.set_instance_color(i, colour.lightened(0.08 * (lump[0] as Vector3).y / 8.0))
			i += 1
	var woods := MultiMeshInstance3D.new()
	woods.multimesh = mm
	woods.material_override = _material(preload("res://shaders/ground.gdshader"))
	tile.add_child(woods)


## A farmstead out in the fields: a red barn and a silo, or a windmill with its sails going round.
func _farmstead(tile: Node3D, side: float) -> void:
	var x := _rng.randf_range(River.SHORE + 199.0, River.SHORE + 344.0)
	var z := _rng.randf_range(40.0, TILE - 40.0)
	var holder := Node3D.new()
	holder.position = Vector3(side * x, height(x), z)
	holder.rotation.y = _rng.randf() * TAU
	tile.add_child(holder)
	var ground := preload("res://shaders/ground.gdshader")
	var paint := func(mesh: Mesh, at: Vector3, colour: Color, turn := Basis.IDENTITY, parent: Node3D = holder) -> MeshInstance3D:
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = _material(ground)
		part.set_instance_shader_parameter(&"tint", colour)
		part.transform = Transform3D(turn, at)
		parent.add_child(part)
		return part
	if _rng.randf() < 0.6:
		# the barn: red, a high roof, a silo beside it
		var body := BoxMesh.new()
		body.size = Vector3(10.0, 6.0, 16.0)
		paint.call(body, Vector3(0.0, 3.0, 0.0), Color(0.70, 0.22, 0.14))
		var roof := PrismMesh.new()
		roof.size = Vector3(11.4, 4.0, 16.8)
		paint.call(roof, Vector3(0.0, 8.0, 0.0), Color(0.36, 0.26, 0.22))
		var silo := CylinderMesh.new()
		silo.top_radius = 2.4
		silo.bottom_radius = 2.4
		silo.height = 13.0
		silo.radial_segments = 12
		paint.call(silo, Vector3(8.5, 6.5, -4.0), Color(0.78, 0.72, 0.62))
		var cap := SphereMesh.new()
		cap.radius = 2.4
		cap.height = 2.4
		cap.is_hemisphere = true
		cap.radial_segments = 12
		paint.call(cap, Vector3(8.5, 13.0, -4.0), Color(0.55, 0.50, 0.48))
	else:
		# the windmill: a tapering tower, a cap, four sails turning
		var tower := CylinderMesh.new()
		tower.top_radius = 1.8
		tower.bottom_radius = 3.2
		tower.height = 14.0
		tower.radial_segments = 8
		paint.call(tower, Vector3(0.0, 7.0, 0.0), Color(0.82, 0.74, 0.60))
		var cap := SphereMesh.new()
		cap.radius = 2.2
		cap.height = 3.0
		cap.radial_segments = 8
		paint.call(cap, Vector3(0.0, 14.2, 0.0), Color(0.40, 0.28, 0.22))
		var sails := Node3D.new()
		sails.name = "Sails"
		sails.position = Vector3(0.0, 13.6, 2.6)
		holder.add_child(sails)
		_sails.append(sails)
		var blade := BoxMesh.new()
		blade.size = Vector3(1.6, 9.0, 0.15)
		for k in 4:
			var turn := Basis(Vector3.FORWARD, k * PI / 2.0)
			paint.call(blade, turn * Vector3(0.0, 5.0, 0.0), Color(0.86, 0.80, 0.68), turn, sails)
	# a few trees round it
	var crown := SphereMesh.new()
	crown.radial_segments = 8
	crown.rings = 5
	for k in 4:
		var a := _rng.randf() * TAU
		var s := _rng.randf_range(5.0, 7.0)
		var tree := paint.call(crown, Vector3(cos(a) * 18.0, s * 0.9, sin(a) * 18.0), Color(0.80, 0.50, 0.20).darkened(_rng.randf() * 0.2)) as MeshInstance3D
		tree.scale = Vector3(s, s * 0.95, s)
