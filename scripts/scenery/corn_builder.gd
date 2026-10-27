extends RefCounted
## (Copied from ScenicRoute: scripts/amberwood/corn_builder.gd.)
## Corn stalks, made in code: Warren's corn (TheClearing/scripts/corn.gd, after Inside's cornfield),
## its stalk and leaves as they are there. Tall dry stalks, 2.2 to 2.8 m, with drooping, twisted leaves,
## an ear in its husk and a tassel; `plain` is a lighter one for far off. corn.gdshader sways them.
##
## The mesh carries COLOR (the stalk's and leaves' own colours) and UV: x how far out along a leaf
## (0 at the stalk), y which part it is.

## Metres between the rows, and between the stalks along a row.
const ROW := 0.9
const STEP := 0.62


static func stalk(plain: bool) -> ArrayMesh:
	return _stalk(plain)


static func _stalk(plain: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 2.35
	var foot_colour := Color(0.3, 0.28, 0.22)
	var top_colour := Color(0.45, 0.42, 0.33)
	# The stalk.
	if plain:
		for turn: float in [0.0, PI * 0.5]:
			var side := Vector3(cos(turn), 0.0, sin(turn))
			var rows := [[0.0, 0.034], [1.2, 0.026], [top, 0.014]]
			for r in 2:
				var y0: float = rows[r][0]
				var y1: float = rows[r + 1][0]
				var w0: float = rows[r][1]
				var w1: float = rows[r + 1][1]
				var c0 := foot_colour.lerp(top_colour, y0 / top)
				var c1 := foot_colour.lerp(top_colour, y1 / top)
				_quad(tool, [Vector3(0, y0, 0) - side * w0, Vector3(0, y0, 0) + side * w0, Vector3(0, y1, 0) + side * w1, Vector3(0, y1, 0) - side * w1], [c0, c0, c1, c1], side.cross(Vector3.UP), 0.0, 0.0)
	else:
		var heights := [0.0, 0.35, 0.8, 1.3, 1.8, top]
		for r in heights.size() - 1:
			var y0: float = heights[r]
			var y1: float = heights[r + 1]
			var w0 := lerpf(0.03, 0.013, y0 / top)
			var w1 := lerpf(0.03, 0.013, y1 / top)
			for f in 3:
				var a := f * TAU / 3.0
				var b := (f + 1) * TAU / 3.0
				var pa := Vector3(cos(a), 0.0, sin(a))
				var pb := Vector3(cos(b), 0.0, sin(b))
				var out := ((pa + pb) * 0.5).normalized()
				# (darker at each joint)
				var c0 := foot_colour.lerp(top_colour, y0 / top) * 0.85
				var c1 := foot_colour.lerp(top_colour, y1 / top)
				_quad(tool, [pa * w0 + Vector3.UP * y0, pb * w0 + Vector3.UP * y0, pb * w1 + Vector3.UP * y1, pa * w1 + Vector3.UP * y1], [c0, c0, c1, c1], out, 0.0, 0.0)
	# The leaves.
	var leaves := 7 if plain else 11
	var first_turn := rng.randf() * TAU
	for l in leaves:
		var f := l / float(leaves - 1)
		var y := lerpf(0.25, 2.0, f) + rng.randf_range(-0.05, 0.05)
		var turn := first_turn + l * PI + rng.randf_range(-0.45, 0.45) + l * 0.35
		var long := lerpf(1.0, 0.6, f) * rng.randf_range(0.85, 1.15)
		var droop := rng.randf_range(1.0, 1.8) if rng.randf() < 0.8 else 2.6
		var grey := rng.randf() < 0.3
		var base := Color(0.42, 0.39, 0.31) if not grey else Color(0.39, 0.38, 0.34)
		var tip := Color(0.55, 0.51, 0.41) if not grey else Color(0.5, 0.49, 0.45)
		_leaf(tool, Vector3(0.0, y, 0.0), turn, long, (0.14 if plain else 0.095) * rng.randf_range(0.85, 1.15), droop, rng.randf_range(-1.3, 1.3), base, tip, 2 if plain else 5, rng.randf())
	if plain:
		return tool.commit()
	# The ear: a spindle in its husk leaning out from the stalk, silk at its tip.
	var ear_turn := first_turn + 0.9
	var lean := Vector3(cos(ear_turn), 0.0, sin(ear_turn))
	var axis := (lean * sin(0.45) + Vector3.UP * cos(0.45)).normalized()
	var across := lean.cross(Vector3.UP).normalized()
	var over := axis.cross(across).normalized()
	var foot := Vector3(0.0, 1.08, 0.0) + lean * 0.02
	var profile := [[0.0, 0.012], [0.05, 0.036], [0.15, 0.038], [0.24, 0.02], [0.29, 0.004]]
	var husk := Color(0.5, 0.45, 0.34)
	for r in profile.size() - 1:
		for f in 5:
			var a := f * TAU / 5.0
			var b := (f + 1) * TAU / 5.0
			var pa := across * cos(a) + over * sin(a)
			var pb := across * cos(b) + over * sin(b)
			var y0: float = profile[r][0]
			var y1: float = profile[r + 1][0]
			var w0: float = profile[r][1]
			var w1: float = profile[r + 1][1]
			_quad(tool, [foot + axis * y0 + pa * w0, foot + axis * y0 + pb * w0, foot + axis * y1 + pb * w1, foot + axis * y1 + pa * w1], [husk * 0.9, husk * 0.9, husk, husk], (pa + pb).normalized(), 0.0, 0.3)
	var silk := foot + axis * 0.29
	_tri(tool, silk - across * 0.012, silk + across * 0.012, silk + axis * 0.06 + lean * 0.05 + Vector3.DOWN * 0.03, Color(0.3, 0.23, 0.16), 0.5)
	# The tassel: a few thin spikes from the top, out and drooping.
	for t in 7:
		var a := t * TAU / 7.0 + 0.3
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := out.cross(Vector3.UP) * 0.007
		var from := Vector3(0.0, top - 0.02, 0.0)
		var mid := from + out * 0.08 + Vector3.UP * 0.15
		var end := from + out * 0.2 + Vector3.UP * 0.06
		var colour := Color(0.46, 0.39, 0.28)
		_tri(tool, from - side, from + side, mid, colour, 0.6)
		_tri(tool, mid - side * 0.7, mid + side * 0.7, end, colour, 0.6)
	return tool.commit()


## A leaf from `at` on the stalk, the `turn` way: up and out, then arching over and
## hanging down (`droop`), narrowing to a point, twisted `twist` radians along it.
static func _leaf(tool: SurfaceTool, at: Vector3, turn: float, long: float, wide: float, droop: float, twist: float, base: Color, tip: Color, pieces: int, which: float) -> void:
	var out := Vector3(cos(turn), 0.0, sin(turn))
	var flat := out.cross(Vector3.UP).normalized()
	var rows: Array = []
	for k in pieces + 1:
		var t := k / float(pieces)
		var middle := at + out * (0.02 + long * 0.85 * t) + Vector3.UP * long * (0.36 * t - droop * t * t)
		var along := (out * 0.85 + Vector3.UP * (0.36 - 2.0 * droop * t)).normalized()
		var normal := flat.cross(along).normalized()
		var side := flat * cos(twist * t) + normal * sin(twist * t)
		var half := wide * (0.45 + 0.55 * sin(minf(t * 2.2, 1.0) * PI * 0.5)) * pow(1.0 - t, 0.8)
		rows.append([middle - side * half, middle + side * half, base.lerp(tip, t), side.cross(along).normalized(), t])
	for k in pieces:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		_quad_each(tool, [a[0], a[1], b[1], b[0]], [a[2], a[2], b[2], b[2]], [a[3], a[3], b[3], b[3]], [a[4], a[4], b[4], b[4]], which)


static func _quad(tool: SurfaceTool, corners: Array, colours: Array, normal: Vector3, out: float, which: float) -> void:
	_quad_each(tool, corners, colours, [normal, normal, normal, normal], [out, out, out, out], which)


static func _quad_each(tool: SurfaceTool, corners: Array, colours: Array, normals: Array, outs: Array, which: float) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(colours[k])
		tool.set_normal(normals[k])
		tool.set_uv(Vector2(outs[k], which))
		tool.add_vertex(corners[k])


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, which: float) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		tool.set_color(colour)
		tool.set_normal(normal)
		tool.set_uv(Vector2(0.0, which))
		tool.add_vertex(p)
