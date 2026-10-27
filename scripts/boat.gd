class_name Riverboat
extends Node3D
## The paddle steamer, built in code: a red hull with a cream rub rail and a
## green sheer, a deck of yellow boards with orange dots (shaders/deck.gdshader),
## a low railing of red panels all round, and on it, from the stern forward:
## the bandstand (red and gold, with a scalloped valance and a string of bulbs
## that brighten with the music), the open dance floor, the side wheels in
## their housings painted with a sunburst, and the cabin with the pilot house
## on top and two tall black stacks with crowns, puffing smoke on the beat.
## Bunting runs from the stacks to the bandstand and down to the bow.
##
## It faces +Z and stays where it is: the river goes by it (River). Its deck is
## at DECK_Y; frogs stand on it (collision layer 1).

const DECK_Y := 1.3
const STAGE_Y := DECK_Y + 0.45
## The bandstand's floor: from the back wall forward to its front edge, and its half width.
const STAGE_BACK := -14.6
const STAGE_FRONT := -9.4
const STAGE_HALF := 4.2
## The dance floor, between the bandstand and the cabin.
const FLOOR_BACK := -8.6
const FLOOR_FRONT := 5.6
const HALF_WIDTH := 4.6
const STERN := -15.2
const BOW := 17.5
const CABIN_BACK := 6.4
const WHEEL_Z := -2.5

const RED := Color(0.70, 0.13, 0.11)
const DEEP_RED := Color(0.48, 0.08, 0.08)
const CREAM := Color(0.93, 0.86, 0.68)
const GOLD := Color(0.92, 0.70, 0.26)
const GREEN := Color(0.44, 0.55, 0.42)
const DARK_GREEN := Color(0.24, 0.33, 0.26)
const BLACK := Color(0.10, 0.09, 0.10)
const TEAL := Color(0.30, 0.60, 0.62)
const WINDOW := Color(1.0, 0.72, 0.38)
const FLAGS := [Color(0.82, 0.18, 0.14), Color(0.95, 0.88, 0.70), Color(0.30, 0.62, 0.64), Color(0.96, 0.76, 0.22),
		Color(0.93, 0.50, 0.18), Color(0.45, 0.62, 0.32)]

## Points on the bandstand's floor where the band stands (filled by the scene).
var wheels: Array[Node3D] = []
var stacks: Array[Node3D] = []
var _bulbs: ShaderMaterial
var _deck_material: ShaderMaterial
var _windows: StandardMaterial3D
var _smoke: Array[TrainSmoke] = []
var _materials := {}


func _ready() -> void:
	_hull()
	_deck()
	_railing()
	_bandstand()
	_wheel(1.0)
	_wheel(-1.0)
	_cabin()
	_bunting()


## The river's speed past it (m/s): the wheels turn to it, the smoke is left behind by it.
var speed := 2.5


func _process(delta: float) -> void:
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.RIGHT, -delta * speed / 2.3)
	var energy := Groove.energy if Groove.playing else 0.0
	if _bulbs:
		_bulbs.set_shader_parameter(&"glow", 0.5 + 1.6 * energy + 0.6 * Groove.pulse(5.0))
	if _deck_material:
		_deck_material.set_shader_parameter(&"glow", energy)
	for smoke in _smoke:
		# (a puff on every beat while the band plays; a steady plume when it does not)
		smoke.beat = Groove.bpm / 60.0 if Groove.playing else 0.8
		smoke.effort = 0.4 + 0.6 * energy
		smoke.air = Vector3(0.6, 0.3, -speed - 1.2)


# --- Materials ---

func _surface(colour: Color) -> Material:
	var key := colour.to_html()
	if not _materials.has(key):
		_materials[key] = Toon.surface(colour)
	return _materials[key]


func _box(at: Vector3, size: Vector3, colour: Color, parent: Node3D = null, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(mesh, Transform3D(basis, at), _surface(colour), parent)


func _cylinder(at: Vector3, radius: float, height: float, colour: Color, parent: Node3D = null, basis := Basis.IDENTITY, top := -1.0, sides := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _put(mesh, Transform3D(basis, at), _surface(colour), parent)


func _put(mesh: Mesh, where: Transform3D, material: Material, parent: Node3D) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.mesh = mesh
	made.transform = where
	made.material_override = material
	(parent if parent else self).add_child(made)
	return made


# --- The hull ---

## Half the hull's width at `z` (along it), at deck height.
static func half_width(z: float) -> float:
	if z > 8.0:
		var t := clampf((z - 8.0) / (BOW - 8.0), 0.0, 1.0)
		return HALF_WIDTH * sqrt(maxf(1.0 - t * t, 0.0))
	if z < STERN + 1.0:
		var t := clampf((STERN + 1.0 - z) / 1.0, 0.0, 1.0)
		return HALF_WIDTH - 0.5 * (1.0 - sqrt(maxf(1.0 - t * t, 0.0)))
	return HALF_WIDTH


## The deck's edge, round from the stern's port quarter: points (x, z).
static func outline(steps := 64) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in steps + 1:
		var z := lerpf(STERN, BOW, float(k) / steps)
		points.append(Vector2(half_width(z), z))
	for k in range(steps, -1, -1):
		var z := lerpf(STERN, BOW, float(k) / steps)
		points.append(Vector2(-half_width(z), z))
	return points


func _hull() -> void:
	# In bands, from below the water up to the deck: red, a cream rub rail, green, a gold line
	var edge := outline()
	var bands := [[-1.0, 0.55, RED], [0.55, 0.78, CREAM], [0.78, DECK_Y - 0.06, DARK_GREEN], [DECK_Y - 0.06, DECK_Y + 0.04, GOLD]]
	for band: Array in bands:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var low: float = band[0]
		var high: float = band[1]
		for i in edge.size() - 1:
			var a := edge[i]
			var b := edge[i + 1]
			# (the sides flare out a little going up, and tuck in under the water)
			var flare_low := 0.92 + 0.08 * clampf((low + 1.0) / (DECK_Y + 1.0), 0.0, 1.0)
			var flare_high := 0.92 + 0.08 * clampf((high + 1.0) / (DECK_Y + 1.0), 0.0, 1.0)
			var a0 := Vector3(a.x * flare_low, low, a.y)
			var b0 := Vector3(b.x * flare_low, low, b.y)
			var a1 := Vector3(a.x * flare_high, high, a.y)
			var b1 := Vector3(b.x * flare_high, high, b.y)
			var normal := Vector3(b.y - a.y, 0.0, -(b.x - a.x)).normalized()
			if i >= edge.size() / 2:
				normal = -normal
			# (both faces, so which way round the outline goes does not matter)
			st.set_normal(normal)
			for p in [a0, b0, b1, a0, b1, a1]:
				st.add_vertex(p)
			st.set_normal(-normal)
			for p in [a0, b1, b0, a0, a1, b1]:
				st.add_vertex(p)
		_put(st.commit(), Transform3D.IDENTITY, _surface(band[2]), null)
	# The flat stern board, red, with a gold name band
	_box(Vector3(0.0, 0.15, STERN + 0.02), Vector3(HALF_WIDTH * 2.0 - 1.0, 2.3, 0.08), RED)
	_box(Vector3(0.0, 0.67, STERN - 0.03), Vector3(HALF_WIDTH * 2.0 - 1.2, 0.2, 0.04), CREAM)


func _deck() -> void:
	var edge := outline(48)
	# (without the points the outline repeats, where its two sides meet: they leave nothing to triangulate)
	var flat := PackedVector2Array()
	for p in edge:
		if flat.is_empty() or (p.distance_to(flat[-1]) > 0.01 and p.distance_to(flat[0]) > 0.01):
			flat.append(p)
	var indices := Geometry2D.triangulate_polygon(flat)
	if indices.is_empty():
		push_warning("the deck did not triangulate")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(0, indices.size(), 3):
		var corners: Array[Vector3] = []
		for j in 3:
			var p := flat[indices[k + j]]
			corners.append(Vector3(p.x, DECK_Y, p.y))
		# (each triangle wound to face up, whichever way the outline goes round: Godot's front faces are clockwise)
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).y > 0.0:
			corners.reverse()
		for corner in corners:
			st.add_vertex(corner)
	_deck_material = ShaderMaterial.new()
	_deck_material.shader = preload("res://shaders/deck.gdshader")
	var deck := _put(st.commit(), Transform3D.IDENTITY, _deck_material, null)
	deck.name = "Deck"
	# What the frogs stand on
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for block: Array in [[Vector3(0.0, DECK_Y - 0.25, 0.0), Vector3(HALF_WIDTH * 2.0, 0.5, BOW - STERN)],
			[Vector3(0.0, STAGE_Y - 0.25, (STAGE_BACK + STAGE_FRONT) * 0.5), Vector3(STAGE_HALF * 2.0, 0.5, STAGE_FRONT - STAGE_BACK)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = block[1]
		shape.shape = box
		shape.position = block[0]
		body.add_child(shape)


func _railing() -> void:
	# Round the deck from beside the bandstand, past the bow, and back: posts, a top rail and red panels between
	var edge := outline(40)
	var points: Array[Vector3] = []
	for p in edge:
		if p.y > STAGE_FRONT + 0.3 and p.y < CABIN_BACK - 0.3 or p.y > 13.2:
			points.append(Vector3(p.x * 0.985, DECK_Y, p.y))
	var height := 0.85
	var last := Vector3.INF
	for p in points:
		if last != Vector3.INF and last.distance_to(p) < 0.05:
			continue
		if last != Vector3.INF and last.distance_to(p) < 3.0:
			var mid := (last + p) * 0.5
			var along := p - last
			var basis := Basis.looking_at(along.normalized(), Vector3.UP)
			var length := along.length()
			_box(mid + Vector3.UP * height, Vector3(0.1, 0.08, length + 0.08), CREAM, null, basis)
			_box(mid + Vector3.UP * (height * 0.5), Vector3(0.06, height * 0.78, length - 0.12), CREAM, null, basis)
			_box(mid + Vector3.UP * (height * 0.5), Vector3(0.08, height * 0.6, length - 0.3), RED, null, basis)
		if last == Vector3.INF or last.distance_to(p) < 3.0:
			_box(p + Vector3.UP * (height * 0.5 + 0.03), Vector3(0.12, height + 0.06, 0.12), CREAM)
		last = p


# --- The bandstand ---

func _bandstand() -> void:
	var middle := (STAGE_BACK + STAGE_FRONT) * 0.5
	var depth := STAGE_FRONT - STAGE_BACK
	var top := STAGE_Y + 3.5
	# Its floor, a step up, red in front with a gold edge, and a round red rug in the middle
	_box(Vector3(0.0, (DECK_Y + STAGE_Y) * 0.5, middle), Vector3(STAGE_HALF * 2.0, STAGE_Y - DECK_Y, depth), RED)
	var stage_floor := _box(Vector3(0.0, STAGE_Y - 0.01, middle), Vector3(STAGE_HALF * 2.0, 0.02, depth), CREAM)
	stage_floor.material_override = _deck_material
	_box(Vector3(0.0, STAGE_Y - 0.03, STAGE_FRONT + 0.02), Vector3(STAGE_HALF * 2.0 + 0.04, 0.07, 0.08), GOLD)
	_cylinder(Vector3(0.0, STAGE_Y + 0.005, middle + 0.6), 2.1, 0.012, DEEP_RED, null, Basis.IDENTITY, -1.0, 40)
	# The back wall and the sides: red, panelled in cream with gold frames
	_box(Vector3(0.0, (STAGE_Y + top) * 0.5, STAGE_BACK - 0.12), Vector3(STAGE_HALF * 2.0 + 0.4, top - STAGE_Y, 0.24), RED)
	for k in 4:
		var x := -3.0 + k * 2.0
		_box(Vector3(x, STAGE_Y + 1.8, STAGE_BACK + 0.01), Vector3(1.5, 2.4, 0.04), GOLD)
		_box(Vector3(x, STAGE_Y + 1.8, STAGE_BACK + 0.03), Vector3(1.3, 2.2, 0.04), CREAM)
		_box(Vector3(x, STAGE_Y + 1.8, STAGE_BACK + 0.05), Vector3(1.0, 1.9, 0.04), DEEP_RED)
	for side: float in [1.0, -1.0]:
		var x := side * (STAGE_HALF + 0.1)
		_box(Vector3(x, (STAGE_Y + top) * 0.5, middle - 0.3), Vector3(0.24, top - STAGE_Y, depth - 0.6), RED)
		_box(Vector3(x - side * 0.13, STAGE_Y + 1.6, middle - 0.3), Vector3(0.04, 2.2, depth - 1.8), CREAM)
		_box(Vector3(x - side * 0.15, STAGE_Y + 1.6, middle - 0.3), Vector3(0.04, 1.9, depth - 2.2), DEEP_RED)
		# The front pillars: red, banded in gold, on gold feet
		var pillar := Vector3(side * (STAGE_HALF - 0.05), 0.0, STAGE_FRONT - 0.2)
		_cylinder(pillar + Vector3.UP * ((STAGE_Y + top) * 0.5), 0.2, top - STAGE_Y, RED)
		for y in [STAGE_Y + 0.15, top - 0.6, top - 0.3]:
			_cylinder(pillar + Vector3.UP * y, 0.24, 0.09, GOLD)
	# The header across the front, its gold mouldings, and the scalloped valance under it
	_box(Vector3(0.0, top - 0.35, STAGE_FRONT - 0.15), Vector3(STAGE_HALF * 2.0 + 0.6, 0.7, 0.4), RED)
	for y in [top - 0.05, top - 0.68]:
		_box(Vector3(0.0, y, STAGE_FRONT + 0.06), Vector3(STAGE_HALF * 2.0 + 0.6, 0.07, 0.06), GOLD)
	for k in 13:
		var x := -STAGE_HALF + 0.3 + k * (STAGE_HALF * 2.0 - 0.6) / 12.0
		_cylinder(Vector3(x, top - 0.72, STAGE_FRONT - 0.05), 0.33, 0.05, CREAM if k % 2 == 0 else RED, null, Basis(Vector3.RIGHT, PI / 2), -1.0, 18)
	# The roof, with a gold cornice and a crest
	_box(Vector3(0.0, top + 0.1, middle - 0.1), Vector3(STAGE_HALF * 2.0 + 0.9, 0.2, depth + 0.6), DEEP_RED)
	_box(Vector3(0.0, top + 0.24, STAGE_FRONT + 0.15), Vector3(STAGE_HALF * 2.0 + 0.9, 0.1, 0.14), GOLD)
	var crest := TorusMesh.new()
	crest.inner_radius = 1.0
	crest.outer_radius = 1.18
	crest.rings = 32
	crest.ring_segments = 8
	_put(crest, Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled(Vector3(1.0, 1.0, 0.6)), Vector3(0.0, top + 0.2, STAGE_FRONT - 0.1)), Toon.gold(GOLD), null)
	_box(Vector3(0.0, top + 0.75, STAGE_FRONT - 0.1), Vector3(1.9, 1.05, 0.12), RED)
	_box(Vector3(0.0, top + 0.6, STAGE_FRONT - 0.03), Vector3(1.3, 0.6, 0.04), CREAM)
	# A string of bulbs along the header, which brighten with the music
	_bulbs = ShaderMaterial.new()
	_bulbs.shader = preload("res://shaders/bulb.gdshader")
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	bulb.radial_segments = 8
	bulb.rings = 4
	bulb.material = _bulbs
	var lamps := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = bulb
	var places: Array[Vector3] = []
	for k in 25:
		places.append(Vector3(-STAGE_HALF - 0.1 + k * (STAGE_HALF * 2.0 + 0.2) / 24.0, top - 0.35, STAGE_FRONT + 0.08))
	for k in 9:
		for side: float in [1.0, -1.0]:
			places.append(Vector3(side * (STAGE_HALF - 0.05), STAGE_Y + 0.4 + k * 0.33, STAGE_FRONT + 0.03))
	multi.instance_count = places.size()
	for k in places.size():
		multi.set_instance_transform(k, Transform3D(Basis.IDENTITY, places[k]))
	lamps.multimesh = multi
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamps)
	# A warm light on the band from the bulbs
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, top - 0.6, STAGE_FRONT + 1.2)
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 0.45
	light.omni_range = 7.0
	add_child(light)


# --- The wheels ---

func _wheel(side: float) -> void:
	var centre := Vector3(side * (HALF_WIDTH + 0.75), 1.1, WHEEL_Z)
	var wheel := Node3D.new()
	wheel.position = centre
	add_child(wheel)
	wheels.append(wheel)
	var radius := 2.35
	for k in 12:
		var a := TAU * k / 12.0
		var spoke := Basis(Vector3.RIGHT, a)
		_box(spoke * Vector3(0.0, radius * 0.5, 0.0), Vector3(0.08, radius, 0.1), BLACK, wheel, spoke)
		_box(spoke * Vector3(0.0, radius - 0.25, 0.0), Vector3(1.1, 0.55, 0.07), RED, wheel, spoke)
	for x in [-0.5, 0.5]:
		var rim := TorusMesh.new()
		rim.inner_radius = radius - 0.06
		rim.outer_radius = radius + 0.06
		rim.rings = 36
		rim.ring_segments = 6
		_put(rim, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(x, 0.0, 0.0)), _surface(BLACK), wheel)
	_cylinder(Vector3.ZERO, 0.22, 1.4, GOLD, wheel, Basis(Vector3.FORWARD, PI / 2))
	# The housing over its top half: a drum of green, its outer face painted with a sunburst
	var housing := Node3D.new()
	housing.position = centre
	add_child(housing)
	var outer := 2.75
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rays := 11
	var face_x := side * 0.72
	for k in rays:
		var a0 := PI * k / rays
		var a1 := PI * (k + 1) / rays
		st.set_color(CREAM if k % 2 == 0 else [TEAL, Color(0.96, 0.76, 0.22), RED][k / 2 % 3])
		st.set_normal(Vector3(side, 0.0, 0.0))
		var hub := Vector3(face_x, 0.0, 0.0)
		var p0 := Vector3(face_x, sin(a0) * outer, cos(a0) * outer)
		var p1 := Vector3(face_x, sin(a1) * outer, cos(a1) * outer)
		for p in ([hub, p0, p1] if side > 0.0 else [hub, p1, p0]):
			st.add_vertex(p)
	var face_material := StandardMaterial3D.new()
	face_material.vertex_color_use_as_albedo = true
	face_material.roughness = 1.0
	_put(st.commit(), Transform3D.IDENTITY, face_material, housing)
	_cylinder(Vector3(face_x + side * 0.02, 0.0, 0.0), 0.55, 0.05, Color(0.96, 0.76, 0.22), housing, Basis(Vector3.FORWARD, PI / 2), -1.0, 24)
	# its curved top: boards round the half-circle
	for k in 14:
		var a := PI * (k + 0.5) / 14.0
		var at := Vector3(0.0, sin(a) * outer, cos(a) * outer)
		_box(at, Vector3(1.5, 0.12, outer * PI / 14.0 + 0.04), DARK_GREEN, housing, Basis(Vector3.RIGHT, -(a - PI / 2)))
	var rim := TorusMesh.new()
	rim.inner_radius = outer - 0.08
	rim.outer_radius = outer + 0.08
	rim.rings = 36
	rim.ring_segments = 6
	_put(rim, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(face_x, 0.0, 0.0)), Toon.gold(GOLD), housing)
	# (the bottom of the housing: a beam along the hull)
	_box(Vector3(0.0, 0.02, 0.0), Vector3(1.5, 0.14, outer * 2.0 + 0.2), DARK_GREEN, housing)


# --- The cabin, the pilot house and the stacks ---

func _cabin() -> void:
	var back := CABIN_BACK
	var front := 13.4
	var mid := (back + front) * 0.5
	var high := DECK_Y + 2.5
	var half := 3.3
	_box(Vector3(0.0, (DECK_Y + high) * 0.5, mid), Vector3(half * 2.0, high - DECK_Y, front - back), GREEN)
	_box(Vector3(0.0, high - 0.1, mid), Vector3(half * 2.0 + 0.06, 0.12, front - back + 0.06), GOLD)
	_box(Vector3(0.0, DECK_Y + 0.15, mid), Vector3(half * 2.0 + 0.04, 0.3, front - back + 0.04), RED)
	# Its windows, lit warm from within, and a red door in the middle of the back wall, with a life ring by it
	_windows = StandardMaterial3D.new()
	_windows.albedo_color = WINDOW * 0.5
	_windows.emission_enabled = true
	_windows.emission = WINDOW
	_windows.emission_energy_multiplier = 0.9
	for k in 4:
		var x := -2.5 + k * 1.66
		if absf(x) < 0.6:
			continue
		var pane := _box(Vector3(x, DECK_Y + 1.4, back - 0.02), Vector3(0.8, 0.9, 0.04), CREAM)
		pane.material_override = _windows
		_box(Vector3(x, DECK_Y + 1.4, back - 0.01), Vector3(0.96, 1.06, 0.03), CREAM)
	for side: float in [1.0, -1.0]:
		for k in 4:
			var pane := _box(Vector3(side * (half + 0.02), DECK_Y + 1.4, back + 0.9 + k * 1.6), Vector3(0.04, 0.8, 0.8), CREAM)
			pane.material_override = _windows
	_box(Vector3(0.0, DECK_Y + 1.0, back - 0.03), Vector3(1.0, 2.0, 0.06), RED)
	_box(Vector3(0.0, DECK_Y + 1.0, back - 0.02), Vector3(1.16, 2.1, 0.05), GOLD)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.34
	_put(ring, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-1.6, DECK_Y + 1.5, back - 0.1)), _surface(Color(0.95, 0.94, 0.9)), null)
	for k in 4:
		_box(Vector3(-1.6, DECK_Y + 1.5, back - 0.12) + Basis(Vector3.BACK, k * PI / 2 + PI / 4) * Vector3(0.27, 0.0, 0.0), Vector3(0.12, 0.13, 0.13), RED, null, Basis(Vector3.BACK, k * PI / 2 + PI / 4))
	# The deck over it (the texas), its railing, and the pilot house
	var roof := high + 0.15
	_box(Vector3(0.0, roof, mid - 0.4), Vector3(half * 2.0 + 0.8, 0.2, front - back + 1.6), CREAM)
	_box(Vector3(0.0, roof + 0.12, mid - 0.4), Vector3(half * 2.0 + 0.82, 0.05, front - back + 1.62), GOLD)
	for side: float in [1.0, -1.0]:
		_box(Vector3(side * (half + 0.35), roof + 0.45, mid - 0.4), Vector3(0.06, 0.06, front - back + 1.5), CREAM)
		for k in 9:
			_box(Vector3(side * (half + 0.35), roof + 0.25, back - 1.1 + k * 1.0), Vector3(0.05, 0.42, 0.05), CREAM)
	var house := Vector3(0.0, roof + 1.05, 10.8)
	_box(house, Vector3(2.6, 1.8, 2.4), CREAM)
	for side: float in [1.0, -1.0]:
		var pane := _box(house + Vector3(side * 1.31, 0.25, 0.0), Vector3(0.04, 0.7, 1.8), CREAM)
		pane.material_override = _windows
	var pane := _box(house + Vector3(0.0, 0.25, 1.21), Vector3(2.1, 0.7, 0.04), CREAM)
	pane.material_override = _windows
	_box(house + Vector3(0.0, 1.0, 0.0), Vector3(3.0, 0.16, 2.8), RED)
	_cylinder(house + Vector3(0.0, 1.25, 0.0), 0.2, 0.35, GOLD)
	# The stacks: tall and black, banded in gold, crowned
	for side: float in [1.0, -1.0]:
		var foot := Vector3(side * 1.55, roof, 8.0)
		var height := 9.0
		_cylinder(foot + Vector3.UP * (height * 0.5), 0.42, height, BLACK)
		for y in [1.6, 6.2]:
			_cylinder(foot + Vector3.UP * y, 0.46, 0.22, GOLD)
		var crown := foot + Vector3.UP * height
		_cylinder(crown + Vector3.UP * 0.3, 0.44, 0.6, BLACK, null, Basis.IDENTITY, 0.7, 16)
		for k in 8:
			var a := TAU * k / 8.0
			_box(crown + Vector3(cos(a) * 0.62, 0.72, sin(a) * 0.62), Vector3(0.12, 0.35, 0.12), BLACK, null, Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.25))
		var mouth := Node3D.new()
		mouth.position = crown + Vector3.UP * 0.7
		add_child(mouth)
		stacks.append(mouth)
		var smoke := TrainSmoke.new()
		mouth.add_child(smoke)
		_smoke.append(smoke)
		# (guy wires from the stacks to the deck below)
		for z in [-2.6, 2.6]:
			_wire(crown + Vector3(0.0, -1.0, 0.0), Vector3(side * 2.9, roof + 0.2, 8.0 + z), 0.015, BLACK)
	# A flagstaff at the bow with a long pennant
	var staff := Vector3(0.0, DECK_Y, BOW - 1.6)
	_cylinder(staff + Vector3.UP * 2.5, 0.05, 5.0, CREAM)
	_cylinder(staff + Vector3.UP * 5.05, 0.09, 0.1, GOLD)


func _wire(from: Vector3, to: Vector3, radius: float, colour: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 4
	mesh.rings = 1
	_put(mesh, Transform3D(Instrument._along(to - from), (from + to) * 0.5), _surface(colour), null)


# --- Bunting ---

## Strings of little flags: stacks to bandstand, stacks to bow, along the cabin, each sagging between its ends.
func _bunting() -> void:
	var stage_top := STAGE_Y + 3.6
	var lines: Array = []
	for side: float in [1.0, -1.0]:
		var stack := Vector3(side * 1.55, DECK_Y + 2.65 + 8.5, 8.0)
		lines.append([stack, Vector3(side * (STAGE_HALF + 0.3), stage_top + 0.2, STAGE_FRONT - 0.1), 1.6])
		lines.append([stack, Vector3(0.0, DECK_Y + 5.0, BOW - 1.6), 1.0])
		lines.append([Vector3(side * (STAGE_HALF + 0.3), stage_top + 0.2, STAGE_FRONT - 0.1), Vector3(side * (HALF_WIDTH - 0.1), DECK_Y + 2.2, CABIN_BACK - 0.6), 0.6])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour := 0
	for line: Array in lines:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var sag: float = line[2]
		var length := a.distance_to(b)
		var count := int(length / 0.55)
		var point := func(t: float) -> Vector3: return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		for k in count:
			var t0 := (k + 0.15) / count
			var t1 := (k + 0.85) / count
			var p0: Vector3 = point.call(t0)
			var p1: Vector3 = point.call(t1)
			var tip: Vector3 = point.call((t0 + t1) * 0.5) + Vector3.DOWN * 0.32
			st.set_color(FLAGS[colour % FLAGS.size()])
			colour += 1
			# (UV.y: 0 on the string, 1 at the tip, for the flutter; UV.x a seed)
			var seed := randf()
			st.set_uv(Vector2(seed, 0.0))
			st.add_vertex(p0)
			st.set_uv(Vector2(seed, 0.0))
			st.add_vertex(p1)
			st.set_uv(Vector2(seed, 1.0))
			st.add_vertex(tip)
		# the string itself
		for k in 12:
			_wire(point.call(k / 12.0), point.call((k + 1) / 12.0), 0.012, Color(0.3, 0.25, 0.2))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/bunting.gdshader")
	var flags := _put(st.commit(), Transform3D.IDENTITY, material, null)
	flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
