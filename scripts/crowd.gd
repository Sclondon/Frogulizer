class_name Crowd
extends Node3D
## The frogs on the dance floor: a crowd in their Sunday best, packed closest to
## the bandstand, each with a way of dancing (FrogRig.DANCES) that changes now
## and then, couples who waltz round each other, and some along the rails who
## only watch and sway. How hard they dance follows the music (Groove.energy):
## in the quiet bits they stand and sway, and when it is loud they are all
## going. Now and then one wanders a step or two and comes back.

## How many frogs dance, and how many of those far back use the low-poly model.
var count := 22
var low_from := 14
var frogs: Array[Frog] = []
var _couples: Array = []   # [frog a, frog b, centre, angle]
var _rng := RandomNumberGenerator.new()
var _change_in := 6.0


func _ready() -> void:
	_rng.seed = 2026
	var places := _places()
	var k := 0
	var paired := 0
	for i in places.size():
		var at: Vector3 = places[i]
		var frog := Frog.new()
		frog.look = FrogLook.random(i + 100)
		frog.low = i >= low_from
		frog.droop = _rng.randf_range(0.1, 0.45)
		frog.dance = _pick_dance(0.5)
		# (a few couples near the middle)
		if paired < 3 and i % 5 == 2 and i + 1 < places.size():
			frog.dance = "partner"
		frog.position = at
		add_child(frog)
		frog.turn_to(PI + _rng.randf_range(-0.35, 0.35) - at.x * 0.05)
		frogs.append(frog)
		if frog.dance == "partner":
			var other := Frog.new()
			other.look = FrogLook.random(i + 500)
			other.low = frog.low
			other.dance = "partner"
			other.position = at + Vector3(0.0, 0.0, 0.75)
			add_child(other)
			frog.frog_rig().partner = other.frog_rig()
			other.frog_rig().partner = frog.frog_rig()
			frogs.append(other)
			_couples.append([frog, other, at + Vector3(0.0, 0.0, 0.375), _rng.randf() * TAU])
			paired += 1
		k += 1
	# Watchers along the rails and up by the cabin, leaning and swaying
	for spot: Array in [[Vector3(-4.0, Riverboat.DECK_Y, 3.8), -PI * 0.75], [Vector3(4.0, Riverboat.DECK_Y, 3.0), PI * 0.75],
			[Vector3(-3.9, Riverboat.DECK_Y, -6.5), -PI * 0.6], [Vector3(2.6, Riverboat.DECK_Y, 5.5), PI]]:
		var frog := Frog.new()
		frog.look = FrogLook.random(frogs.size() + 900)
		frog.dance = "watch"
		frog.low = true
		frog.position = spot[0]
		add_child(frog)
		frog.turn_to(spot[1])
		frogs.append(frog)


## Where each dancer stands: rows across the floor from just in front of the
## bandstand back towards the cabin, a little jumbled.
func _places() -> Array:
	var out := []
	var rows := [[-7.6, 5], [-6.3, 6], [-5.0, 5], [-3.7, 4], [-2.3, 4]]
	for row: Array in rows:
		var n: int = row[1]
		for i in n:
			if out.size() >= count:
				break
			var x := lerpf(-3.4, 3.4, (i + 0.5) / n) + _rng.randf_range(-0.3, 0.3)
			out.append(Vector3(x, Riverboat.DECK_Y, row[0] + _rng.randf_range(-0.3, 0.3)))
	return out


func _pick_dance(energy: float) -> String:
	var calm := ["sway", "clap", "watch", "sway"]
	var lively := ["bounce", "bounce", "clap", "wave", "jig", "sway"]
	var list := lively if _rng.randf() < energy + 0.2 else calm
	return list[_rng.randi() % list.size()]


func _process(delta: float) -> void:
	var energy := Groove.energy if Groove.playing else 0.0
	# Couples turn round each other, faster when the music is lively
	for couple: Array in _couples:
		couple[3] += delta * (0.25 + 0.5 * energy) * (1.0 if Groove.playing else 0.0)
		var a: Frog = couple[0]
		var b: Frog = couple[1]
		var centre: Vector3 = couple[2]
		var way := Vector3(sin(couple[3]), 0.0, cos(couple[3])) * 0.38
		a.go_to(centre - way)
		b.go_to(centre + way)
		a.turn_to(atan2(way.x, way.z))
		b.turn_to(atan2(-way.x, -way.z))
	# Every so often someone changes how they dance, or steps aside and back
	_change_in -= delta
	if _change_in <= 0.0:
		_change_in = _rng.randf_range(1.5, 4.0)
		var frog: Frog = frogs[_rng.randi() % frogs.size()]
		var rig := frog.frog_rig()
		if rig.dance == "partner" or rig.dance == "watch" and frog.low:
			return
		if _rng.randf() < 0.3 and not frog.is_going():
			var step := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.4, 0.4))
			frog.go_to(frog.home + step)
			get_tree().create_timer(_rng.randf_range(2.0, 4.0)).timeout.connect(func() -> void: frog.go_to(frog.home))
		else:
			rig.dance = _pick_dance(energy)


## A cheer (the end of a song): every mouth open, arms up.
func cheer(seconds := 3.0) -> void:
	for frog in frogs:
		var rig := frog.frog_rig()
		if rig.dance == "partner":
			continue
		var was := rig.dance
		rig.dance = "wave"
		rig.shout = 0.8
		get_tree().create_timer(seconds * _rng.randf_range(0.7, 1.2)).timeout.connect(func() -> void:
			if is_instance_valid(rig):
				rig.dance = was
				rig.shout = 0.0)
