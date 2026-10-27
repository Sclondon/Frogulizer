class_name Instrument
extends Node3D
## What a frog in the band plays, built in code from tubes, cones, discs and
## boxes, cel shaded as the frogs are (Toon) with brass that shines (Toon.gold).
##
## Each is laid out in the frog's own model space (models/frog.glb as it
## stands: metres, Y up, facing +Z, +X its left; the mouth is at MOUTH, the
## shoulders at SHOULDER_Y) and carried by one of its joints (`anchor`: the
## chest, the head, or the rig itself for what stands on the deck). FrogRig
## puts it on that joint, puts the hands on its `grips`, and moves its moving
## parts (`bellows`, `bow`, `head`, `bell`...).

const MOUTH := Vector3(0.0, 0.985, 0.232)
const BRASS := Color(0.93, 0.72, 0.30)
const WOOD := Color(0.52, 0.30, 0.16)
const DARK_WOOD := Color(0.26, 0.15, 0.09)
const EBONY := Color(0.09, 0.08, 0.09)
const SILVER := Color(0.80, 0.80, 0.84)
const SKIN_HEAD := Color(0.93, 0.88, 0.76)
const RED := Color(0.62, 0.12, 0.11)

## Which joint carries it: &"chest", &"head" or &"root".
var anchor := &"chest"
## Where each hand goes (Marker3Ds: "grip_l", "grip_r"), and which way its elbow points ("pole_l", "pole_r", in the rig's space).
var grips := {}
var poles := {}
## Moving parts, by name.
var parts := {}
var kind := ""
var _brass: Array[MeshInstance3D] = []


static func make(part: String) -> Instrument:
	var made := Instrument.new()
	made.kind = part
	made.name = part.capitalize()
	match part:
		"tuba":
			made._tuba()
		"trumpet":
			made._trumpet()
		"clarinet":
			made._clarinet()
		"accordion":
			made._accordion()
		"fiddle":
			made._fiddle()
		"banjo":
			made._banjo()
		"drums":
			made._drums()
		"conductor":
			made._baton()
		_:
			return null
	made._shade()
	return made


func _shade() -> void:
	FrogToon.apply(self)
	for mesh in _brass:
		var colour: Color = mesh.get_meta(&"colour", BRASS)
		var shining := FrogToon.material(colour, "brass")
		shining.next_pass = FrogToon.line(colour)
		mesh.set_surface_override_material(0, shining)


# --- The instruments ---

func _tuba() -> void:
	anchor = &"chest"
	# The coil, standing in front of his belly, facing out
	_torus(Vector3(0.0, 0.69, 0.26), Basis(Vector3.RIGHT, PI / 2), 0.055, 0.135, BRASS)
	# Up from the coil to the bell, which stands over his left shoulder clear of his head
	_tube(Vector3(0.10, 0.72, 0.27), Vector3(0.20, 0.86, 0.24), 0.04, BRASS)
	_tube(Vector3(0.20, 0.86, 0.24), Vector3(0.25, 0.97, 0.20), 0.05, BRASS)
	parts.bell = _cone(Vector3(0.25, 0.96, 0.20), Vector3(0.33, 1.16, 0.14), 0.06, 0.18, BRASS)
	# The mouthpiece pipe, up to his lips
	_tube(Vector3(-0.02, 0.80, 0.27), Vector3(-0.01, 0.92, 0.25), 0.014, BRASS)
	_tube(Vector3(-0.01, 0.92, 0.25), MOUTH + Vector3(0.0, -0.01, 0.012), 0.011, BRASS)
	# Three valves on the right, where his fingers are
	for k in 3:
		_tube(Vector3(-0.10 + k * 0.026, 0.74, 0.31), Vector3(-0.10 + k * 0.026, 0.80, 0.31), 0.012, BRASS)
		_disc(Vector3(-0.10 + k * 0.026, 0.805, 0.31), 0.016, 0.006, SILVER)
	_grip("r", Vector3(-0.075, 0.82, 0.30), Vector3(-1.0, -0.6, -0.4))
	_grip("l", Vector3(0.13, 0.66, 0.28), Vector3(1.0, -0.8, -0.2))


func _trumpet() -> void:
	anchor = &"head"
	var way := Vector3(0.0, -0.22, 1.0).normalized()
	var start := MOUTH + Vector3(0.0, -0.005, 0.0)
	_tube(start, start + way * 0.30, 0.011, BRASS)
	# (the loop of tubing under the valves)
	_tube(start + way * 0.07 + Vector3(0.0, -0.04, 0.0), start + way * 0.20 + Vector3(0.0, -0.04, 0.0), 0.01, BRASS)
	parts.bell = _cone(start + way * 0.24, start + way * 0.36, 0.013, 0.055, BRASS)
	for k in 3:
		var at := start + way * (0.10 + k * 0.025)
		_tube(at + Vector3(0.0, -0.045, 0.0), at + Vector3(0.0, 0.02, 0.0), 0.009, BRASS)
		_disc(at + Vector3(0.0, 0.026, 0.0), 0.012, 0.005, SILVER)
	_grip("r", start + way * 0.125 + Vector3(-0.005, 0.045, 0.0), Vector3(-1.0, -0.4, -0.3))
	_grip("l", start + way * 0.13 + Vector3(0.02, -0.06, 0.0), Vector3(1.0, -0.9, -0.3))


func _clarinet() -> void:
	anchor = &"head"
	var way := Vector3(0.0, -0.78, 0.62).normalized()
	var start := MOUTH + Vector3(0.0, -0.01, -0.01)
	_tube(start, start + way * 0.34, 0.0135, EBONY)
	parts.bell = _cone(start + way * 0.33, start + way * 0.41, 0.015, 0.035, EBONY)
	for t in [0.06, 0.16, 0.26]:
		_disc(start + way * t, 0.016, 0.006, SILVER, way)
	_grip("l", start + way * 0.13 + Vector3(0.0, 0.0, 0.015), Vector3(1.0, -0.5, -0.3))
	_grip("r", start + way * 0.25 + Vector3(0.0, 0.0, 0.015), Vector3(-1.0, -0.5, -0.3))


func _accordion() -> void:
	anchor = &"chest"
	var centre := Vector3(0.0, 0.72, 0.27)
	# The bellows, between the two ends (FrogRig stretches it)
	var bellows := Node3D.new()
	bellows.position = centre
	add_child(bellows)
	parts.bellows = bellows
	for k in 7:
		var x := -0.09 + k * 0.03
		_box(Vector3(x, 0.0, 0.0), Vector3(0.026, 0.22, 0.17), RED if k % 2 == 0 else Color(0.85, 0.80, 0.68), Basis.IDENTITY, bellows)
	# The ends, moved apart as it breathes: the right one with its keys, the left one with buttons
	for side: float in [1.0, -1.0]:
		var end := Node3D.new()
		end.position = centre + Vector3(side * 0.125, 0.0, 0.0)
		add_child(end)
		parts["end_l" if side > 0.0 else "end_r"] = end
		_box(Vector3.ZERO, Vector3(0.045, 0.25, 0.19), Color(0.15, 0.13, 0.14), Basis.IDENTITY, end)
		if side < 0.0:
			_box(Vector3(-0.026, 0.0, 0.03), Vector3(0.012, 0.22, 0.06), Color(0.95, 0.94, 0.90), Basis.IDENTITY, end)
		else:
			for b in 6:
				_disc(Vector3(0.026, -0.08 + b * 0.032, 0.0), 0.009, 0.006, SILVER, Vector3.RIGHT, end)
	_grip("l", centre + Vector3(0.17, 0.0, 0.0), Vector3(1.0, -0.7, -0.5))
	_grip("r", centre + Vector3(-0.17, 0.02, 0.03), Vector3(-1.0, -0.7, -0.5))


func _fiddle() -> void:
	anchor = &"chest"
	# On his left shoulder under his chin, pointing forward and out to his left
	var along := Vector3(0.45, 0.06, 0.89).normalized()
	var across := Vector3(0.89, 0.0, -0.45).normalized()
	var up := along.cross(across).normalized() * -1.0
	var centre := Vector3(0.10, 0.875, 0.15)
	var fiddle := Basis(across, up, along)
	# Its body: the lower bout, the narrower upper bout, a waist between, and the black fingerboard up its middle
	_ellipsoid(centre - along * 0.045, Vector3(0.062, 0.02, 0.06), WOOD, fiddle)
	_ellipsoid(centre + along * 0.055, Vector3(0.052, 0.02, 0.05), WOOD, fiddle)
	_ellipsoid(centre + along * 0.005, Vector3(0.04, 0.021, 0.05), WOOD, fiddle)
	_box(centre + along * 0.12 + up * 0.022, Vector3(0.02, 0.01, 0.2), EBONY, fiddle)
	_tube(centre + along * 0.1, centre + along * 0.25, 0.01, DARK_WOOD)
	_sphere(centre + along * 0.26, 0.016, DARK_WOOD)
	_box(centre - along * 0.02 + up * 0.026, Vector3(0.035, 0.012, 0.004), Color(0.9, 0.8, 0.6), fiddle)
	# The strings, and the bridge they cross where the bow plays
	_box(centre + along * 0.075 + up * 0.019, Vector3(0.022, 0.003, 0.24), Color(0.85, 0.85, 0.80), fiddle)
	var contact := centre - along * 0.025 + up * 0.03
	parts.contact = contact
	parts.across = across.rotated(along, 0.1)
	# The bow: a stick with its hair, placed each frame by FrogRig through the
	# right hand and across the strings
	var bow := Node3D.new()
	add_child(bow)
	parts.bow = bow
	_tube(Vector3.ZERO, Vector3(0.0, 0.0, 0.5), 0.005, DARK_WOOD, bow)
	_tube(Vector3(0.0, -0.012, 0.02), Vector3(0.0, -0.012, 0.49), 0.003, Color(0.95, 0.94, 0.88), bow)
	_box(Vector3(0.0, -0.008, 0.02), Vector3(0.01, 0.02, 0.03), EBONY, Basis.IDENTITY, bow)
	_grip("l", centre + along * 0.21 + Vector3(0.0, -0.02, 0.0), Vector3(0.6, -1.0, -0.2))
	_grip("r", contact - across * 0.15, Vector3(-1.0, -0.5, -0.4))


func _banjo() -> void:
	anchor = &"chest"
	var pot := Vector3(-0.06, 0.69, 0.25)
	var face := Vector3(0.0, 0.25, 1.0).normalized()
	_disc(pot, 0.115, 0.05, SILVER, face)
	_disc(pot + face * 0.026, 0.105, 0.004, SKIN_HEAD, face)
	_disc(pot - face * 0.02, 0.108, 0.02, DARK_WOOD, face)
	var neck_end := Vector3(0.28, 0.93, 0.24)
	_tube(pot + face * 0.02, neck_end + face * 0.02, 0.018, DARK_WOOD)
	_box(neck_end + Vector3(0.025, 0.02, 0.02), Vector3(0.05, 0.08, 0.02), DARK_WOOD, Basis(Vector3.BACK, -0.8))
	parts.strum = pot + face * 0.06
	_grip("l", pot.lerp(neck_end, 0.78) + face * 0.035, Vector3(1.0, -0.8, -0.3))
	_grip("r", pot + face * 0.07 + Vector3(0.0, 0.02, 0.0), Vector3(-1.0, -0.4, -0.5))


func _drums() -> void:
	anchor = &"root"
	# A bass drum facing out, a snare on its stand, a cymbal on a pole to his left
	var bass := Node3D.new()
	bass.position = Vector3(-0.05, 0.23, 0.48)
	add_child(bass)
	parts.bass = bass
	_disc(Vector3.ZERO, 0.22, 0.2, RED, Vector3.BACK, bass)
	_disc(Vector3(0.0, 0.0, 0.102), 0.205, 0.004, SKIN_HEAD, Vector3.BACK, bass)
	_disc(Vector3(0.0, 0.0, 0.105), 0.07, 0.002, Color(0.85, 0.65, 0.2), Vector3.BACK, bass)
	for side: float in [1.0, -1.0]:
		_disc(Vector3(0.0, 0.0, side * 0.1), 0.225, 0.02, BRASS, Vector3.BACK, bass)
	var snare := Vector3(-0.05, 0.56, 0.28)
	_tube(Vector3(-0.05, 0.0, 0.28), snare - Vector3(0.0, 0.04, 0.0), 0.01, SILVER)
	_disc(snare, 0.12, 0.08, SILVER)
	_disc(snare + Vector3(0.0, 0.041, 0.0), 0.115, 0.004, SKIN_HEAD)
	parts.snare = snare + Vector3(0.0, 0.045, 0.0)
	var cymbal := Node3D.new()
	cymbal.position = Vector3(0.22, 0.80, 0.30)
	add_child(cymbal)
	parts.cymbal = cymbal
	_tube(Vector3(0.22, 0.0, 0.30), Vector3(0.22, 0.79, 0.30), 0.009, SILVER)
	var plate := _disc(Vector3.ZERO, 0.13, 0.006, BRASS, Vector3.UP, cymbal)
	plate.set_meta(&"colour", Color(0.95, 0.78, 0.35))
	parts.cymbal_top = cymbal.position + Vector3(-0.06, 0.01, 0.0)
	# The sticks, one in each fist (FrogRig carries them)
	for hand: String in ["l", "r"]:
		var stick := Node3D.new()
		add_child(stick)
		parts["stick_" + hand] = stick
		_tube(Vector3.ZERO, Vector3(0.0, 0.0, 0.3), 0.007, Color(0.86, 0.72, 0.48), stick)
	_grip("l", parts.cymbal_top + Vector3(0.0, 0.1, -0.2), Vector3(1.0, -0.6, -0.6))
	_grip("r", parts.snare + Vector3(0.0, 0.1, -0.2), Vector3(-1.0, -0.6, -0.6))


func _baton() -> void:
	anchor = &"root"
	var baton := Node3D.new()
	add_child(baton)
	parts.baton = baton
	_tube(Vector3.ZERO, Vector3(0.0, 0.0, 0.3), 0.005, Color(0.96, 0.95, 0.9), baton)
	_tube(Vector3(0.0, 0.0, -0.01), Vector3(0.0, 0.0, 0.04), 0.011, DARK_WOOD, baton)


# --- Shapes ---

func _grip(hand: String, at: Vector3, pole: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Grip_" + hand
	marker.position = at
	add_child(marker)
	grips[hand] = marker
	poles[hand] = pole.normalized()


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.resource_name = "instrument"
	return material


func _put(mesh: Mesh, at: Vector3, basis: Basis, colour: Color, parent: Node3D) -> MeshInstance3D:
	(mesh as PrimitiveMesh).material = _material(colour)
	var made := MeshInstance3D.new()
	made.mesh = mesh
	made.transform = Transform3D(basis, at)
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(made)
	if colour == BRASS:
		_brass.append(made)
	return made


## A basis whose Y points along `way`.
static func _along(way: Vector3) -> Basis:
	var y := way.normalized()
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _tube(from: Vector3, to: Vector3, radius: float, colour: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 10
	mesh.rings = 1
	return _put(mesh, (from + to) * 0.5, _along(to - from), colour, parent)


func _cone(from: Vector3, to: Vector3, r0: float, r1: float, colour: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r0
	mesh.top_radius = r1
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 16
	mesh.rings = 2
	return _put(mesh, (from + to) * 0.5, _along(to - from), colour, parent)


func _disc(at: Vector3, radius: float, thickness: float, colour: Color, facing := Vector3.UP, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = 20
	mesh.rings = 1
	return _put(mesh, at, _along(facing), colour, parent)


func _torus(at: Vector3, basis: Basis, inner: float, outer: float, colour: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 10
	return _put(mesh, at, basis, colour, null)


func _box(at: Vector3, size: Vector3, colour: Color, basis := Basis.IDENTITY, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(mesh, at, basis, colour, parent)


func _ellipsoid(at: Vector3, radii: Vector3, colour: Color, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _put(mesh, at, basis * Basis.from_scale(radii), colour, null)


func _sphere(at: Vector3, radius: float, colour: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _put(mesh, at, Basis.IDENTITY, colour, null)
