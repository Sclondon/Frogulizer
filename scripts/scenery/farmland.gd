class_name Farmland
extends RefCounted
## The land along the river besides the woods: each bank of a stretch of the river (River._segment)
## is laid out as a run of pieces of land, 40 to 80 m each, one after another, so that the boat
## passes woods, then a cornfield, a pumpkin patch, an open meadow of tall grass, woods again...
## (`plan`). This makes the farmland in them: River makes the woods.
##
## Made from what the other games have:
## - the corn: ScenicRoute's corn (scripts/scenery/corn_builder.gd, shaders/corn.gdshader, copied
##   from ScenicRoute, which took it from Warren's cornfield), in rows running back from the river;
## - the pumpkins, their vines and the split-rail fence: ScenicRoute's pumpkin patch
##   (amberwood.gd `_pumpkin_patch`, `_pumpkin_mesh`, `_rail`), painted with its prop shader
##   (shaders/prop.gdshader, copied); here drawn as MultiMeshes, many to a field;
## - the vines: the painted-woodland kit's leaf clumps (woodland/, Woodland); the meadow's tall
##   grass is Warren's grass, laid by River._grass.
## The scarecrows and the round hay bales are new, out of plain shapes in the same paint.

const CornBuilder := preload("res://scripts/scenery/corn_builder.gd")
const CORN := preload("res://shaders/corn.gdshader")
const PROP := preload("res://shaders/prop.gdshader")

const KINDS := ["woods", "corn", "pumpkins", "meadow"]
const CHANCE := {"woods": 0.34, "corn": 0.26, "pumpkins": 0.2, "meadow": 0.2}
## The fields reach this far back from the water's edge; the woods stand behind them.
const FIELD_NEAR := 5.0
const FIELD_FAR := 38.0

## The colour of the ground under each kind of land (the woods keep the bank's own).
const SOIL := {"corn": Color(0.52, 0.37, 0.22), "pumpkins": Color(0.40, 0.33, 0.17), "meadow": Color(0.84, 0.66, 0.30)}


## One bank's pieces of land along a stretch `length` long: [[from z, to z, kind], ...], never the
## same kind twice running.
static func plan(rng: RandomNumberGenerator, length: float) -> Array:
	var out: Array = []
	var z := 0.0
	var last := ""
	while z < length:
		var kind := last
		while kind == last:
			var roll := rng.randf()
			for k: String in KINDS:
				roll -= CHANCE[k]
				if roll <= 0.0:
					kind = k
					break
			if roll > 0.0:
				kind = "woods"
		var to := minf(z + rng.randf_range(40.0, 80.0), length)
		# (no scrap of a piece at the end)
		if length - to < 25.0:
			to = length
		out.append([z, to, kind])
		last = kind
		z = to
	return out


## What kind of land is at `z` on a bank laid out by `plan`, and how far inside its piece it is (m).
static func kind_at(pieces: Array, z: float) -> Array:
	for piece: Array in pieces:
		if z >= piece[0] and z <= piece[1]:
			return [piece[2], minf(z - float(piece[0]), float(piece[1]) - z)]
	return ["woods", 0.0]


## The bank's colour at `x` back from the water's edge (`back`), `z` along, with its land's soil.
static func ground_colour(pieces: Array, colour: Color, back: float, z: float) -> Color:
	var found := kind_at(pieces, z)
	if not SOIL.has(found[0]):
		return colour
	var amount := smoothstep(2.0, 4.5, back) * smoothstep(0.0, 6.0, found[1]) * (1.0 - smoothstep(FIELD_FAR + 2.0, FIELD_FAR + 12.0, back))
	return colour.lerp(SOIL[found[0]], amount * 0.85)


## Makes the farmland of one bank (`side` +1 or -1) into `holder`: `ground` is River._ground (how
## high the land is, given how far from the middle of the river and how far along).
static func add(holder: Node3D, side: float, pieces: Array, shore: float, ground: Callable, sun_dir: Vector3, sun_color: Color, rng: RandomNumberGenerator) -> void:
	var corn_near: Array = []
	var corn_far: Array = []
	var pumpkins: Array = [[], [], []]
	var vines: Array = []
	var bales: Array = []
	var fence: Array = []    # [from, to] runs of fence along the bank
	for piece: Array in pieces:
		var z0: float = piece[0] + 3.0
		var z1: float = piece[1] - 3.0
		match piece[2]:
			"corn":
				# Rows running back from the river, so that they open and shut as the boat goes by
				var z := z0
				var row := 0
				while z < z1:
					var x := shore + FIELD_NEAR + rng.randf_range(0.0, 0.6)
					row += 1
					while x < shore + FIELD_FAR:
						var near := x < shore + 12.0
						# (further back, where the rows are lost in each other, every other row is left out)
						if not near and row % 2 == 1:
							break
						var px := x + rng.randf_range(-0.12, 0.12)
						var pz := z + rng.randf_range(-0.12, 0.12)
						x += CornBuilder.STEP * (1.0 if near else 1.6)
						# (a ragged far edge, and gaps)
						if rng.randf() < 0.07 or (x > shore + FIELD_FAR - 4.0 and rng.randf() < 0.5):
							continue
						var s := rng.randf_range(0.9, 1.15) * (1.0 if near else 1.1)
						var tr := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(side * px, ground.call(px, pz) - 0.05, pz))
						(corn_near if near else corn_far).append(tr)
					z += CornBuilder.ROW
				fence.append([z0, z1])
				# a bale or two left at the corner of the field
				for k in rng.randi_range(0, 2):
					var bz := (z0 if k == 0 else z1) + rng.randf_range(-1.0, 1.0)
					var bx := shore + rng.randf_range(2.5, 3.2)
					bales.append([Vector3(side * bx, ground.call(bx, bz), bz), rng.randf() * TAU])
			"pumpkins":
				var area := (z1 - z0) * (FIELD_FAR - 10.0 - FIELD_NEAR)
				# the vines: low clumps of leaves going brown, all over the patch
				for k in int(area / 2.2):
					var x := shore + rng.randf_range(FIELD_NEAR - 0.5, FIELD_FAR - 10.0)
					var z := rng.randf_range(z0, z1)
					var size := rng.randf_range(0.7, 1.2)
					vines.append([Vector3(side * x, ground.call(x, z) + size * 0.2, z), Color(size, rng.randf(), rng.randf_range(0.2, 0.7), rng.randf())])
				# the pumpkins among them, big and small, a lot of them near the bank where they are seen
				for k in int(area / 4.0):
					var x := shore + FIELD_NEAR + pow(rng.randf(), 1.4) * (FIELD_FAR - 10.0 - FIELD_NEAR)
					var z := rng.randf_range(z0, z1)
					var size := rng.randf_range(0.22, 0.42) * (1.6 if rng.randf() < 0.06 else 1.0)
					var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
					var tr := Transform3D(basis.scaled(Vector3(size, size * rng.randf_range(0.75, 0.95), size)), Vector3(side * x, ground.call(x, z) + size * 0.3, z))
					pumpkins[rng.randi() % 3].append(tr)
				fence.append([z0, z1])
				_scarecrow(holder, side, shore + rng.randf_range(9.0, 14.0), rng.randf_range(z0 + 10.0, z1 - 10.0), ground, sun_dir, sun_color, rng)
			"meadow":
				# A few bales out in the tall grass (River._grass)
				for k in rng.randi_range(3, 7):
					var x := shore + rng.randf_range(8.0, FIELD_FAR)
					var z := rng.randf_range(z0 + 3.0, z1 - 3.0)
					bales.append([Vector3(side * x, ground.call(x, z), z), rng.randf() * TAU])
	_corn(holder, corn_near, corn_far, sun_dir, sun_color)
	_pumpkins(holder, pumpkins, sun_dir, sun_color)
	if not vines.is_empty():
		Woodland.add_leaf_clumps(holder, vines, Woodland.material(Woodland.FOLIAGE, sun_dir, sun_color,
				{"gold": Color(0.55, 0.52, 0.22), "orange": Color(0.45, 0.42, 0.16), "rust": Color(0.42, 0.3, 0.14), "leaf_scale": 4.0, "sway": 0.3, "darkness": 0.1}))
	_bales(holder, bales, sun_dir, sun_color, rng)
	_fences(holder, side, fence, shore, ground, sun_dir, sun_color, rng)


static func _corn(holder: Node3D, near: Array, far: Array, sun_dir: Vector3, sun_color: Color) -> void:
	var material := Woodland.material(CORN, sun_dir, sun_color, {"wind": 0.3})
	for set: Array in [[near, CornBuilder.stalk(false)], [far, CornBuilder.stalk(true)]]:
		var placed: Array = set[0]
		if placed.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = set[1]
		mm.instance_count = placed.size()
		for i in placed.size():
			mm.set_instance_transform(i, placed[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		# (the stalks in all their leaves are not drawn from far off, where they would be specks)
		if placed == near:
			mmi.visibility_range_end = 160.0
		holder.add_child(mmi)


static func _pumpkins(holder: Node3D, sets: Array, sun_dir: Vector3, sun_color: Color) -> void:
	var material := Woodland.material(PROP, sun_dir, sun_color, {"color": Color(0.92, 0.48, 0.12), "shadow_color": Color(0.38, 0.12, 0.04), "gloss": 0.25})
	var stem_material := Woodland.material(PROP, sun_dir, sun_color, {"color": Color(0.42, 0.4, 0.2), "shadow_color": Color(0.12, 0.1, 0.05)})
	var stem := CylinderMesh.new()
	stem.top_radius = 0.05
	stem.bottom_radius = 0.09
	stem.height = 0.3
	stem.radial_segments = 5
	stem.rings = 1
	var stems: Array = []
	var shapes := [_pumpkin_mesh(1.0, 10), _pumpkin_mesh(0.8, 8), _pumpkin_mesh(1.25, 12)]
	# (each a little different: deeper orange, paler, one in a while gone pale yellow)
	var tints := [Color(1.0, 1.0, 1.0), Color(0.9, 0.78, 0.8), Color(1.04, 1.25, 1.6), Color(0.95, 0.9, 0.95)]
	for k in 3:
		var placed: Array = sets[k]
		if placed.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = shapes[k]
		mm.instance_count = placed.size()
		for i in placed.size():
			var tr: Transform3D = placed[i]
			mm.set_instance_transform(i, tr)
			mm.set_instance_color(i, tints[(i * 7 + k) % tints.size()] if i % 13 != 0 else tints[2])
			stems.append(tr * Transform3D(Basis(Vector3(1.0, 0.0, 0.3).normalized(), 0.35), Vector3(0.0, 0.62 * (0.8 if k == 1 else 1.0), 0.0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		holder.add_child(mmi)
	if stems.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = stem
	mm.instance_count = stems.size()
	for i in stems.size():
		mm.set_instance_transform(i, stems[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = stem_material
	holder.add_child(mmi)


## A pumpkin: a squashed sphere with deep ribs, `ribs` of them (ScenicRoute's `_pumpkin_mesh`).
static func _pumpkin_mesh(squash: float, ribs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := ribs * 3
	var verts: Array = []
	for j in rings + 1:
		var theta := float(j) / rings * PI
		var row: Array = []
		for i in segs + 1:
			var phi := float(i) / segs * TAU
			var rib := 1.0 - 0.09 * pow(absf(sin(phi * ribs * 0.5)), 0.6) * sin(theta)
			var r := sin(theta) * rib
			var y := cos(theta) * 0.8 * squash
			row.append(Vector3(cos(phi) * r, y * (1.0 - 0.25 * pow(absf(cos(theta)), 8.0)), sin(phi) * r))
		verts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = verts[j][i]
			var b: Vector3 = verts[j][i + 1]
			var c: Vector3 = verts[j + 1][i]
			var d: Vector3 = verts[j + 1][i + 1]
			for p in [a, c, b, b, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## Round bales of hay lying on their sides: [where, which way], with a darker band round each.
static func _bales(holder: Node3D, bales: Array, sun_dir: Vector3, sun_color: Color, rng: RandomNumberGenerator) -> void:
	if bales.is_empty():
		return
	var material := Woodland.material(PROP, sun_dir, sun_color, {"color": Color(0.80, 0.58, 0.27), "shadow_color": Color(0.36, 0.21, 0.08), "brush": 0.6})
	var bale := CylinderMesh.new()
	bale.top_radius = 0.72
	bale.bottom_radius = 0.72
	bale.height = 1.15
	bale.radial_segments = 14
	bale.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bale
	mm.instance_count = bales.size()
	for i in bales.size():
		var at: Vector3 = bales[i][0]
		var basis := Basis(Vector3.UP, bales[i][1]) * Basis(Vector3.FORWARD, PI / 2)
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.9, 1.1)), at + Vector3(0.0, 0.62, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	holder.add_child(mmi)


## Split-rail fences along the top of the bank in front of the fields, zig-zagging, a rail fallen
## here and there (ScenicRoute's).
static func _fences(holder: Node3D, side: float, runs: Array, shore: float, ground: Callable, sun_dir: Vector3, sun_color: Color, rng: RandomNumberGenerator) -> void:
	if runs.is_empty():
		return
	var pieces: Array = []
	for run: Array in runs:
		var z: float = run[0]
		var zig := 0
		var prev := Vector3.ZERO
		while z <= float(run[1]):
			var x := shore + 3.4 + 0.45 * float(zig % 2)
			var p := Vector3(side * x, ground.call(x, z), z)
			var lean := Basis(Vector3.UP, rng.randf()) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.BACK, rng.randf_range(-0.1, 0.1))
			pieces.append(Transform3D(lean.scaled(Vector3(0.14, 1.3, 0.14)), p + Vector3(0.0, 0.55, 0.0)))
			if zig > 0:
				for h: float in [0.45, 0.9]:
					if h > 0.6 and rng.randf() < 0.2:
						continue
					var a := prev + Vector3(0.0, h, 0.0)
					var b := p + Vector3(0.0, h + rng.randf_range(-0.06, 0.06), 0.0)
					var basis := Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.BACK, rng.randf_range(-0.3, 0.3))
					pieces.append(Transform3D(basis.scaled(Vector3(0.12, 0.1, a.distance_to(b) + 0.4)), (a + b) * 0.5))
			prev = p
			zig += 1
			z += 2.6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = pieces.size()
	for i in pieces.size():
		mm.set_instance_transform(i, pieces[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Woodland.material(PROP, sun_dir, sun_color, {"color": Color(0.40, 0.30, 0.21), "shadow_color": Color(0.1, 0.07, 0.05), "brush": 0.5})
	holder.add_child(mmi)


## A scarecrow in the pumpkin patch: a post and a crossbar, an old checked shirt with its arms out
## on the bar, a sack for a head with a battered hat, straw at its cuffs.
static func _scarecrow(holder: Node3D, side: float, x: float, z: float, ground: Callable, sun_dir: Vector3, sun_color: Color, rng: RandomNumberGenerator) -> void:
	var figure := Node3D.new()
	figure.position = Vector3(side * x, ground.call(x, z), z)
	# (facing the river, a little askew)
	figure.rotation = Vector3(0.0, -side * PI / 2 + rng.randf_range(-0.5, 0.5), rng.randf_range(-0.06, 0.06))
	holder.add_child(figure)
	var paint := func(colour: Color, shadow: Color) -> ShaderMaterial:
		return Woodland.material(PROP, sun_dir, sun_color, {"color": colour, "shadow_color": shadow, "brush": 0.6})
	var wood: ShaderMaterial = paint.call(Color(0.40, 0.30, 0.21), Color(0.1, 0.07, 0.05))
	var shirt: ShaderMaterial = paint.call([Color(0.62, 0.18, 0.14), Color(0.30, 0.38, 0.55), Color(0.55, 0.45, 0.2)][rng.randi() % 3], Color(0.15, 0.06, 0.05))
	var sack: ShaderMaterial = paint.call(Color(0.80, 0.68, 0.46), Color(0.32, 0.24, 0.14))
	var straw: ShaderMaterial = paint.call(Color(0.92, 0.76, 0.38), Color(0.45, 0.30, 0.12))
	var hat: ShaderMaterial = paint.call(Color(0.30, 0.24, 0.18), Color(0.08, 0.06, 0.05))
	var box := func(size: Vector3, at: Vector3, material: Material, turn := Basis.IDENTITY) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = material
		part.transform = Transform3D(turn, at)
		figure.add_child(part)
	box.call(Vector3(0.1, 2.3, 0.1), Vector3(0.0, 1.05, 0.0), wood)
	box.call(Vector3(1.6, 0.08, 0.08), Vector3(0.0, 1.62, 0.0), wood)
	box.call(Vector3(0.5, 0.72, 0.28), Vector3(0.0, 1.35, 0.0), shirt, Basis(Vector3.BACK, 0.04))
	box.call(Vector3(1.25, 0.2, 0.22), Vector3(0.0, 1.6, 0.0), shirt)
	for s: float in [1.0, -1.0]:
		box.call(Vector3(0.12, 0.16, 0.16), Vector3(s * 0.7, 1.55, 0.0), straw, Basis(Vector3.BACK, s * 0.5))
	box.call(Vector3(0.12, 0.14, 0.12), Vector3(0.0, 0.95, 0.0), straw)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.42
	head.radial_segments = 10
	head.rings = 6
	var face := MeshInstance3D.new()
	face.mesh = head
	face.material_override = sack
	face.position = Vector3(0.0, 1.95, 0.0)
	figure.add_child(face)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.34
	brim.bottom_radius = 0.34
	brim.height = 0.03
	brim.radial_segments = 12
	var crown := CylinderMesh.new()
	crown.top_radius = 0.12
	crown.bottom_radius = 0.17
	crown.height = 0.24
	crown.radial_segments = 10
	for part: Array in [[brim, Vector3(0.0, 2.12, 0.0)], [crown, Vector3(0.0, 2.24, 0.0)]]:
		var piece := MeshInstance3D.new()
		piece.mesh = part[0]
		piece.material_override = hat
		piece.transform = Transform3D(Basis(Vector3.BACK, 0.18), part[1])
		figure.add_child(piece)
