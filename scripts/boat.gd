class_name Riverboat
extends Node3D
## The paddle steamer, built in code, after the boat in Over the Garden Wall (inpsirationArt/
## Riverboat-25909.webp): a red hull with a cream rub rail and a green sheer; one long main cabin
## amidships, green with gold trim and warm windows, two tall black stacks with crowns on its
## roof and a pilot house up front; great side wheels in housings painted with a sunburst; and
## set into the back of the cabin, the bandstand (red and gold, a scalloped valance, a string of
## bulbs that brighten with the music) looking out over the open stern deck, where the crowd
## dances, on yellow boards with orange dots (shaders/deck.gdshader). Bunting runs from the
## stacks back to poles at the stern and forward to the bow.
##
## It faces +Z and goes down the river (`speed`), with everyone on it as its children: the
## River is still. Its deck is at DECK_Y (collision layer 1, for the rig's feet).

const DECK_Y := 1.3
const STAGE_Y := DECK_Y + 0.45
const HALF_WIDTH := 4.8
const STERN := -16.0
const BOW := 19.0
## The main cabin, from its back wall forward, and its half width.
const CABIN_BACK := -2.5
const CABIN_FRONT := 12.0
const CABIN_HALF := 3.7
const CABIN_HIGH := DECK_Y + 3.4
## The bandstand: an alcove in the back of the cabin, its floor a step up.
const STAGE_FRONT := CABIN_BACK
const STAGE_BACK := CABIN_BACK + 3.6
const STAGE_HALF := 3.2
const STAGE_TOP := STAGE_Y + 2.9
## The dance floor: the open deck behind the cabin.
const FLOOR_BACK := STERN + 1.2
const FLOOR_FRONT := CABIN_BACK - 0.4
## The wheels: where along, how big (their axles above the water).
const WHEEL_Z := 5.0
const WHEEL_RADIUS := 3.5
const WHEEL_Y := 1.4

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

## How fast it goes down the river, m/s.
var speed := 2.5
var wheels: Array[Node3D] = []
var stacks: Array[Node3D] = []
var _bulbs: ShaderMaterial
var _deck_material: ShaderMaterial
var _windows: StandardMaterial3D
var _smoke: Array[TrainSmoke] = []
var _materials := {}
var _time := 0.0


func _ready() -> void:
	_hull()
	_deck()
	_railing()
	_cabin()
	_bandstand()
	_wheel(1.0)
	_wheel(-1.0)
	_bunting()


func _process(delta: float) -> void:
	_time += delta
	position.z += speed * delta
	# (riding the swell: a slow lift and a little roll)
	position.y = sin(_time * 0.7) * 0.03
	rotation = Vector3(sin(_time * 0.53) * 0.006, 0.0, sin(_time * 0.41 + 1.0) * 0.008)
	for wheel in wheels:
		# (the top of each wheel goes forward, the bottom back: the paddles push the water astern)
		wheel.rotate_object_local(Vector3.RIGHT, delta * speed / (WHEEL_RADIUS * 0.8))
	var energy := Groove.energy if Groove.playing else 0.0
	if _bulbs:
		_bulbs.set_shader_parameter(&"glow", 0.5 + 1.6 * energy + 0.6 * Groove.pulse(5.0))
	if _deck_material:
		_deck_material.set_shader_parameter(&"glow", energy)
	for smoke in _smoke:
		# (a puff on every beat while the band plays; a steady plume when it does not. The puffs stay
		# where they are put in the air, so the boat leaves them behind.)
		smoke.beat = Groove.bpm / 60.0 if Groove.playing else 0.8
		smoke.effort = 0.4 + 0.6 * energy
		smoke.carried = Vector3(0.0, 0.0, speed * 0.3)
		smoke.air = Vector3(0.5, 0.2, -0.3)


# --- Materials and shapes ---

func _surface(colour: Color) -> Material:
	var key := colour.to_html()
	if not _materials.has(key):
		_materials[key] = FrogToon.material(colour)
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


func _wire(from: Vector3, to: Vector3, radius: float, colour: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 4
	mesh.rings = 1
	var made := _put(mesh, Transform3D(Instrument._along(to - from), (from + to) * 0.5), _surface(colour), null)
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- The hull and the deck ---

## Half the hull's width at `z` (along it), at deck height.
static func half_width(z: float) -> float:
	if z > 9.0:
		var t := clampf((z - 9.0) / (BOW - 9.0), 0.0, 1.0)
		return HALF_WIDTH * sqrt(maxf(1.0 - t * t, 0.0))
	if z < STERN + 1.2:
		var t := clampf((STERN + 1.2 - z) / 1.2, 0.0, 1.0)
		return HALF_WIDTH - 0.6 * (1.0 - sqrt(maxf(1.0 - t * t, 0.0)))
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
	var bands := [[-1.2, 0.55, RED], [0.55, 0.78, CREAM], [0.78, DECK_Y - 0.06, DARK_GREEN], [DECK_Y - 0.06, DECK_Y + 0.04, GOLD]]
	for band: Array in bands:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var low: float = band[0]
		var high: float = band[1]
		for i in edge.size() - 1:
			var a := edge[i]
			var b := edge[i + 1]
			# (the sides flare out a little going up, and tuck in under the water)
			var flare_low := 0.9 + 0.1 * clampf((low + 1.2) / (DECK_Y + 1.2), 0.0, 1.0)
			var flare_high := 0.9 + 0.1 * clampf((high + 1.2) / (DECK_Y + 1.2), 0.0, 1.0)
			var a0 := Vector3(a.x * flare_low, low, a.y)
			var b0 := Vector3(b.x * flare_low, low, b.y)
			var a1 := Vector3(a.x * flare_high, high, a.y)
			var b1 := Vector3(b.x * flare_high, high, b.y)
			var normal := Vector3(a.x + b.x, 0.0, 0.0).normalized() if absf(a.x + b.x) > 0.01 else Vector3(0.0, 0.0, signf(a.y))
			# (both faces, so which way round the outline goes does not matter)
			st.set_normal(normal)
			for p in [a0, b0, b1, a0, b1, a1]:
				st.add_vertex(p)
			st.set_normal(-normal)
			for p in [a0, b1, b0, a0, a1, b1]:
				st.add_vertex(p)
		_put(st.commit(), Transform3D.IDENTITY, _surface(band[2]), null)
	# The flat stern board, red, with a cream name band
	_box(Vector3(0.0, 0.05, STERN + 0.02), Vector3(HALF_WIDTH * 2.0 - 1.2, 2.5, 0.08), RED)
	_box(Vector3(0.0, 0.67, STERN - 0.03), Vector3(HALF_WIDTH * 2.0 - 1.4, 0.2, 0.04), CREAM)


func _deck() -> void:
	var edge := outline(48)
	# (without the points the outline repeats, where its two sides meet: they leave nothing to triangulate)
	var flat := PackedVector2Array()
	for p in edge:
		if flat.is_empty() or (p.distance_to(flat[-1]) > 0.01 and p.distance_to(flat[0]) > 0.01):
			flat.append(p)
	var indices := Geometry2D.triangulate_polygon(flat)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in range(0, indices.size(), 3):
		var corners: Array[Vector3] = []
		for j in 3:
			var p := flat[indices[k + j]]
			corners.append(Vector3(p.x, DECK_Y, p.y))
		# (each triangle wound to face up: Godot's front faces are clockwise)
		if (corners[1] - corners[0]).cross(corners[2] - corners[0]).y > 0.0:
			corners.reverse()
		for corner in corners:
			st.add_vertex(corner)
	_deck_material = ShaderMaterial.new()
	_deck_material.shader = preload("res://shaders/deck.gdshader")
	var deck := _put(st.commit(), Transform3D.IDENTITY, _deck_material, null)
	deck.name = "Deck"
	# What the frogs' rigs feel for under their feet
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for block: Array in [[Vector3(0.0, DECK_Y - 0.25, (STERN + BOW) * 0.5), Vector3(HALF_WIDTH * 2.0, 0.5, BOW - STERN)],
			[Vector3(0.0, STAGE_Y - 0.25, (STAGE_BACK + STAGE_FRONT) * 0.5), Vector3(STAGE_HALF * 2.0, 0.5, STAGE_BACK - STAGE_FRONT)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = block[1]
		shape.shape = box
		shape.position = block[0]
		body.add_child(shape)


func _railing() -> void:
	# Round the stern deck and round the bow: posts, a top rail and red panels between
	var edge := outline(48)
	var runs: Array = [[], []]
	for p in edge:
		var at := Vector3(p.x * 0.985, DECK_Y, p.y)
		if p.y < CABIN_BACK - 0.2:
			runs[0].append(at)
		elif p.y > CABIN_FRONT + 0.4:
			runs[1].append(at)
	for run: Array in runs:
		# (the stern run goes round from one side to the other: sorted round the middle of the boat)
		run.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.x, a.z - 2.0) < atan2(b.x, b.z - 2.0))
		var height := 0.85
		var last := Vector3.INF
		for p: Vector3 in run:
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
			_box(p + Vector3.UP * (height * 0.5 + 0.03), Vector3(0.12, height + 0.06, 0.12), CREAM)
			last = p
	# Lamp posts at the stern corners, with lanterns, carrying the bunting
	for side: float in [1.0, -1.0]:
		var post := Vector3(side * (HALF_WIDTH - 0.5), DECK_Y, STERN + 0.8)
		_cylinder(post + Vector3.UP * 2.3, 0.06, 4.6, CREAM)
		_cylinder(post + Vector3.UP * 4.65, 0.1, 0.1, GOLD)
		var lamp := _cylinder(post + Vector3.UP * 2.4 + Vector3(side * -0.25, 0.0, 0.0), 0.12, 0.3, WINDOW)
		lamp.material_override = _glow_material()


func _glow_material() -> StandardMaterial3D:
	if _windows == null:
		_windows = StandardMaterial3D.new()
		_windows.albedo_color = WINDOW * 0.5
		_windows.emission_enabled = true
		_windows.emission = WINDOW
		_windows.emission_energy_multiplier = 0.9
	return _windows


# --- The main cabin, the pilot house and the stacks ---

func _cabin() -> void:
	var mid := (CABIN_BACK + CABIN_FRONT) * 0.5
	var length := CABIN_FRONT - CABIN_BACK
	var stage_middle := (STAGE_FRONT + STAGE_BACK) * 0.5
	# Its walls, leaving the alcove at the back open: the sides, the front, and the back on either side of it
	for side: float in [1.0, -1.0]:
		_box(Vector3(side * CABIN_HALF, (DECK_Y + CABIN_HIGH) * 0.5, mid), Vector3(0.2, CABIN_HIGH - DECK_Y, length), GREEN)
		var cheek := (CABIN_HALF - STAGE_HALF - 0.1)
		_box(Vector3(side * (STAGE_HALF + 0.1 + cheek * 0.5), (DECK_Y + CABIN_HIGH) * 0.5, CABIN_BACK), Vector3(cheek, CABIN_HIGH - DECK_Y, 0.2), GREEN)
		# its windows down each side, lit warm from within
		for k in 6:
			var z := STAGE_BACK + 0.8 + k * 1.45
			var pane := _box(Vector3(side * (CABIN_HALF + 0.11), DECK_Y + 1.7, z), Vector3(0.04, 1.0, 0.75), CREAM)
			pane.material_override = _glow_material()
			_box(Vector3(side * (CABIN_HALF + 0.1), DECK_Y + 1.7, z), Vector3(0.05, 1.16, 0.91), CREAM)
		# and a life ring on the back wall beside the bandstand
		var ring := TorusMesh.new()
		ring.inner_radius = 0.2
		ring.outer_radius = 0.34
		_put(ring, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(side * (STAGE_HALF + 0.25), DECK_Y + 1.6, CABIN_BACK - 0.13)), _surface(Color(0.95, 0.94, 0.9)), null)
		for k in 4:
			var turn := Basis(Vector3.BACK, k * PI / 2 + PI / 4)
			_box(Vector3(side * (STAGE_HALF + 0.25), DECK_Y + 1.6, CABIN_BACK - 0.15) + turn * Vector3(0.27, 0.0, 0.0), Vector3(0.12, 0.13, 0.13), RED, null, turn)
	_box(Vector3(0.0, (DECK_Y + CABIN_HIGH) * 0.5, CABIN_FRONT), Vector3(CABIN_HALF * 2.0, CABIN_HIGH - DECK_Y, 0.2), GREEN)
	# Its skirting, its gold cornice
	_box(Vector3(0.0, DECK_Y + 0.15, mid), Vector3(CABIN_HALF * 2.0 + 0.04, 0.3, length + 0.04), RED)
	_box(Vector3(0.0, CABIN_HIGH - 0.1, mid), Vector3(CABIN_HALF * 2.0 + 0.1, 0.14, length + 0.1), GOLD)
	# The roof (the texas deck), with a rail round it
	var roof := CABIN_HIGH + 0.1
	_box(Vector3(0.0, roof, mid), Vector3(CABIN_HALF * 2.0 + 1.0, 0.2, length + 1.4), CREAM)
	_box(Vector3(0.0, roof + 0.12, mid), Vector3(CABIN_HALF * 2.0 + 1.02, 0.05, length + 1.42), GOLD)
	for side: float in [1.0, -1.0]:
		_box(Vector3(side * (CABIN_HALF + 0.45), roof + 0.5, mid), Vector3(0.06, 0.06, length + 1.2), CREAM)
		for k in 15:
			_box(Vector3(side * (CABIN_HALF + 0.45), roof + 0.28, CABIN_BACK - 0.5 + k * 1.0), Vector3(0.05, 0.42, 0.05), CREAM)
	# The pilot house at the front of the roof
	var house := Vector3(0.0, roof + 1.05, CABIN_FRONT - 1.6)
	_box(house, Vector3(2.8, 1.8, 2.4), CREAM)
	for side: float in [1.0, -1.0]:
		var pane := _box(house + Vector3(side * 1.41, 0.25, 0.0), Vector3(0.04, 0.7, 1.8), CREAM)
		pane.material_override = _glow_material()
	var front_pane := _box(house + Vector3(0.0, 0.25, 1.21), Vector3(2.3, 0.7, 0.04), CREAM)
	front_pane.material_override = _glow_material()
	_box(house + Vector3(0.0, 1.0, 0.0), Vector3(3.2, 0.16, 2.8), RED)
	_cylinder(house + Vector3(0.0, 1.25, 0.0), 0.2, 0.35, GOLD)
	# The stacks: tall and black, banded in gold, crowned, side by side ahead of the middle
	for side: float in [1.0, -1.0]:
		var foot := Vector3(side * 1.6, roof, CABIN_FRONT - 4.6)
		var height := 9.5
		_cylinder(foot + Vector3.UP * (height * 0.5), 0.45, height, BLACK)
		for y in [1.6, 6.6]:
			_cylinder(foot + Vector3.UP * y, 0.49, 0.22, GOLD)
		var crown := foot + Vector3.UP * height
		_cylinder(crown + Vector3.UP * 0.3, 0.47, 0.6, BLACK, null, Basis.IDENTITY, 0.75, 16)
		for k in 8:
			var a := TAU * k / 8.0
			_box(crown + Vector3(cos(a) * 0.66, 0.72, sin(a) * 0.66), Vector3(0.12, 0.35, 0.12), BLACK, null, Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.25))
		var mouth := Node3D.new()
		mouth.position = crown + Vector3.UP * 0.7
		add_child(mouth)
		stacks.append(mouth)
		var smoke := TrainSmoke.new()
		mouth.add_child(smoke)
		_smoke.append(smoke)
		for z in [-2.8, 2.8]:
			_wire(crown + Vector3(0.0, -1.0, 0.0), Vector3(side * 3.2, roof + 0.2, foot.z + z), 0.015, BLACK)
	# A flagstaff at the bow
	var staff := Vector3(0.0, DECK_Y, BOW - 1.8)
	_cylinder(staff + Vector3.UP * 2.5, 0.05, 5.0, CREAM)
	_cylinder(staff + Vector3.UP * 5.05, 0.09, 0.1, GOLD)


# --- The bandstand, set into the back of the cabin ---

func _bandstand() -> void:
	var middle := (STAGE_FRONT + STAGE_BACK) * 0.5
	var depth := STAGE_BACK - STAGE_FRONT
	# Its floor, a step up, red in front with a gold edge, with a round red rug
	_box(Vector3(0.0, (DECK_Y + STAGE_Y) * 0.5, middle), Vector3(STAGE_HALF * 2.0, STAGE_Y - DECK_Y, depth), RED)
	var stage_floor := _box(Vector3(0.0, STAGE_Y - 0.01, middle), Vector3(STAGE_HALF * 2.0, 0.02, depth), CREAM)
	stage_floor.material_override = _deck_material
	_box(Vector3(0.0, STAGE_Y - 0.03, STAGE_FRONT - 0.02), Vector3(STAGE_HALF * 2.0 + 0.04, 0.07, 0.08), GOLD)
	_cylinder(Vector3(0.0, STAGE_Y + 0.005, middle - 0.3), 1.8, 0.012, DEEP_RED, null, Basis.IDENTITY, -1.0, 40)
	# The alcove: back wall and sides red, panelled cream and gold, and a ceiling
	_box(Vector3(0.0, (STAGE_Y + STAGE_TOP) * 0.5, STAGE_BACK + 0.1), Vector3(STAGE_HALF * 2.0, STAGE_TOP - STAGE_Y, 0.2), RED)
	for k in 3:
		var x := -2.1 + k * 2.1
		_box(Vector3(x, STAGE_Y + 1.4, STAGE_BACK - 0.01), Vector3(1.5, 2.0, 0.04), GOLD)
		_box(Vector3(x, STAGE_Y + 1.4, STAGE_BACK - 0.03), Vector3(1.3, 1.8, 0.04), CREAM)
		_box(Vector3(x, STAGE_Y + 1.4, STAGE_BACK - 0.05), Vector3(1.0, 1.5, 0.04), DEEP_RED)
	for side: float in [1.0, -1.0]:
		_box(Vector3(side * (STAGE_HALF + 0.1), (STAGE_Y + STAGE_TOP) * 0.5, middle), Vector3(0.2, STAGE_TOP - STAGE_Y, depth), RED)
		_box(Vector3(side * (STAGE_HALF - 0.01), STAGE_Y + 1.4, middle + 0.2), Vector3(0.04, 1.8, depth - 1.2), CREAM)
	_box(Vector3(0.0, STAGE_TOP + 0.1, middle), Vector3(STAGE_HALF * 2.4, 0.2, depth), DEEP_RED)
	# The front of it on the cabin's back wall: red pillars banded in gold, a header with gold
	# mouldings and a scalloped valance, a crest above, the wall above it up to the cornice
	for side: float in [1.0, -1.0]:
		var pillar := Vector3(side * (STAGE_HALF + 0.05), 0.0, STAGE_FRONT - 0.15)
		_cylinder(pillar + Vector3.UP * ((DECK_Y + STAGE_TOP) * 0.5), 0.2, STAGE_TOP - DECK_Y, RED)
		for y in [STAGE_Y + 0.05, STAGE_TOP - 0.55, STAGE_TOP - 0.25]:
			_cylinder(pillar + Vector3.UP * y, 0.24, 0.09, GOLD)
	_box(Vector3(0.0, (STAGE_TOP + CABIN_HIGH) * 0.5, CABIN_BACK), Vector3(STAGE_HALF * 2.2, CABIN_HIGH - STAGE_TOP, 0.2), GREEN)
	_box(Vector3(0.0, STAGE_TOP - 0.25, STAGE_FRONT - 0.12), Vector3(STAGE_HALF * 2.0 + 0.6, 0.55, 0.3), RED)
	for y in [STAGE_TOP + 0.02, STAGE_TOP - 0.52]:
		_box(Vector3(0.0, y, STAGE_FRONT - 0.28), Vector3(STAGE_HALF * 2.0 + 0.6, 0.07, 0.06), GOLD)
	for k in 11:
		var x := -STAGE_HALF + 0.3 + k * (STAGE_HALF * 2.0 - 0.6) / 10.0
		_cylinder(Vector3(x, STAGE_TOP - 0.58, STAGE_FRONT - 0.2), 0.3, 0.05, CREAM if k % 2 == 0 else RED, null, Basis(Vector3.RIGHT, PI / 2), -1.0, 18)
	var crest := TorusMesh.new()
	crest.inner_radius = 0.9
	crest.outer_radius = 1.06
	crest.rings = 32
	crest.ring_segments = 8
	_put(crest, Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled(Vector3(1.0, 1.0, 0.6)), Vector3(0.0, CABIN_HIGH - 0.2, CABIN_BACK - 0.12)), Toon.gold(GOLD), null)
	_box(Vector3(0.0, CABIN_HIGH + 0.45, CABIN_BACK - 0.05), Vector3(1.8, 0.9, 0.12), RED)
	_box(Vector3(0.0, CABIN_HIGH + 0.38, CABIN_BACK - 0.12), Vector3(1.2, 0.5, 0.04), CREAM)
	# A string of bulbs round its opening, which brighten with the music
	_bulbs = ShaderMaterial.new()
	_bulbs.shader = preload("res://shaders/bulb.gdshader")
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	bulb.radial_segments = 8
	bulb.rings = 4
	bulb.material = _bulbs
	var places: Array[Vector3] = []
	for k in 21:
		places.append(Vector3(-STAGE_HALF - 0.1 + k * (STAGE_HALF * 2.0 + 0.2) / 20.0, STAGE_TOP - 0.25, STAGE_FRONT - 0.3))
	for k in 8:
		for side: float in [1.0, -1.0]:
			places.append(Vector3(side * (STAGE_HALF + 0.05), STAGE_Y + 0.35 + k * 0.3, STAGE_FRONT - 0.37))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = bulb
	multi.instance_count = places.size()
	for k in places.size():
		multi.set_instance_transform(k, Transform3D(Basis.IDENTITY, places[k]))
	var lamps := MultiMeshInstance3D.new()
	lamps.multimesh = multi
	lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamps)
	# A warm light on the band from inside the alcove
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, STAGE_TOP - 0.4, STAGE_FRONT + 0.6)
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 0.35
	light.omni_range = 6.0
	add_child(light)


# --- The wheels ---

func _wheel(side: float) -> void:
	var centre := Vector3(side * (HALF_WIDTH + 0.8), WHEEL_Y, WHEEL_Z)
	var wheel := Node3D.new()
	wheel.position = centre
	add_child(wheel)
	wheels.append(wheel)
	var radius := WHEEL_RADIUS
	for k in 16:
		var a := TAU * k / 16.0
		var spoke := Basis(Vector3.RIGHT, a)
		_box(spoke * Vector3(0.0, radius * 0.5, 0.0), Vector3(0.1, radius, 0.12), BLACK, wheel, spoke)
		_box(spoke * Vector3(0.0, radius - 0.3, 0.0), Vector3(1.3, 0.62, 0.08), RED, wheel, spoke)
	for x in [-0.6, 0.6]:
		var rim := TorusMesh.new()
		rim.inner_radius = radius - 0.07
		rim.outer_radius = radius + 0.07
		rim.rings = 40
		rim.ring_segments = 6
		_put(rim, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(x, 0.0, 0.0)), _surface(BLACK), wheel)
	_cylinder(Vector3.ZERO, 0.25, 1.6, GOLD, wheel, Basis(Vector3.FORWARD, PI / 2))
	# The housing over its top: a drum of green, its outer face painted with a sunburst
	var housing := Node3D.new()
	housing.position = centre
	add_child(housing)
	var outer := radius + 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rays := 13
	var face_x := side * 0.85
	for k in rays:
		var a0 := PI * k / rays
		var a1 := PI * (k + 1) / rays
		st.set_color(CREAM if k % 2 == 0 else [TEAL, Color(0.96, 0.76, 0.22), RED][k / 2 % 3])
		st.set_normal(Vector3(side, 0.0, 0.0))
		var hub := Vector3(face_x, 0.0, 0.0)
		var p0 := Vector3(face_x, sin(a0) * outer, cos(a0) * outer)
		var p1 := Vector3(face_x, sin(a1) * outer, cos(a1) * outer)
		for p in ([hub, p1, p0] if side > 0.0 else [hub, p0, p1]):
			st.add_vertex(p)
	var face_material := StandardMaterial3D.new()
	face_material.vertex_color_use_as_albedo = true
	face_material.roughness = 1.0
	face_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_put(st.commit(), Transform3D.IDENTITY, face_material, housing)
	_cylinder(Vector3(face_x + side * 0.02, 0.0, 0.0), 0.7, 0.05, Color(0.96, 0.76, 0.22), housing, Basis(Vector3.FORWARD, PI / 2), -1.0, 24)
	for k in 18:
		var a := PI * (k + 0.5) / 18.0
		var at := Vector3(0.0, sin(a) * outer, cos(a) * outer)
		_box(at, Vector3(1.75, 0.12, outer * PI / 18.0 + 0.04), DARK_GREEN, housing, Basis(Vector3.RIGHT, -(a - PI / 2)))
	var rim := TorusMesh.new()
	rim.inner_radius = outer - 0.09
	rim.outer_radius = outer + 0.09
	rim.rings = 40
	rim.ring_segments = 6
	_put(rim, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(face_x, 0.0, 0.0)), Toon.gold(GOLD), housing)
	_box(Vector3(-side * 0.3, 0.02, 0.0), Vector3(1.0, 0.14, outer * 2.0 + 0.2), DARK_GREEN, housing)


# --- Bunting ---

## Strings of little flags, each sagging between its ends: from the stacks back to the stern posts
## and forward to the bow, and across the stern.
func _bunting() -> void:
	var lines: Array = []
	var roof := CABIN_HIGH + 0.1
	for side: float in [1.0, -1.0]:
		var stack := Vector3(side * 1.6, roof + 9.2, CABIN_FRONT - 4.6)
		var post := Vector3(side * (HALF_WIDTH - 0.5), DECK_Y + 4.6, STERN + 0.8)
		lines.append([stack, post, 2.0])
		lines.append([stack, Vector3(0.0, DECK_Y + 5.0, BOW - 1.8), 1.0])
		lines.append([Vector3(side * (CABIN_HALF + 0.4), roof + 0.6, CABIN_BACK - 0.5), post, 0.9])
	lines.append([Vector3(HALF_WIDTH - 0.5, DECK_Y + 4.6, STERN + 0.8), Vector3(-(HALF_WIDTH - 0.5), DECK_Y + 4.6, STERN + 0.8), 0.8])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for line: Array in lines:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var sag: float = line[2]
		var count := int(a.distance_to(b) / 0.55)
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
			var seed := rng.randf()
			for corner: Array in [[p0, 0.0], [p1, 0.0], [tip, 1.0]]:
				st.set_uv(Vector2(seed, corner[1]))
				st.add_vertex(corner[0])
		for k in 12:
			_wire(point.call(k / 12.0), point.call((k + 1) / 12.0), 0.012, Color(0.3, 0.25, 0.2))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/bunting.gdshader")
	var flags := _put(st.commit(), Transform3D.IDENTITY, material, null)
	flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
