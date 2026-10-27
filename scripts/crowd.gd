class_name Crowd
extends Node
## The frogs on the dance floor (the boat's stern deck), facing the bandstand: a crowd in their
## Sunday best, packed closest to the band, each with a dance of its own (FrogRig.DANCES) that it
## changes now and then, couples who waltz round each other, a few along the rails who only watch,
## and some who sing along. How hard they dance follows the music (FrogRig eases it): in the quiet
## bits they sway, when it is loud they are all going. And they react, as the frogs in the
## reference stills do: a bow and a raised hat to a neighbour, a coy clasp of the hands, a laugh,
## a gasp when the music suddenly swells, a panic of flailing arms and tongues at the loudest, a
## cheer at the end.

var boat: Riverboat
## How many dance.
var count := 26
var frogs: Array[Frog] = []
var _couples: Array = []   # [frog a, frog b, centre, angle]
var _rng := RandomNumberGenerator.new()
var _change_in := 4.0
var _last_energy := 0.0
var _playing_for := 0.0


func _ready() -> void:
	_rng.seed = 2026
	var places := _places()
	var paired := 0
	for i in places.size():
		var at: Vector3 = places[i]
		var frog := _frog(FrogLook.random(i + 100), at, _rng.randf_range(-0.3, 0.3) - at.x * 0.04)
		frog.frog_rig().dance = _pick_dance(0.5)
		frog.frog_rig().sings = 0.35 if _rng.randf() < 0.3 else 0.0
		# (a few couples, in the open middle of the floor)
		if paired < 3 and i % 6 == 3:
			var other := _frog(FrogLook.random(i + 500), at + Vector3(0.0, 0.0, 0.8), PI)
			frog.frog_rig().dance = "partner"
			other.frog_rig().dance = "partner"
			frog.frog_rig().partner = other.frog_rig()
			other.frog_rig().partner = frog.frog_rig()
			_couples.append([frog, other, at + Vector3(0.0, 0.0, 0.4), _rng.randf() * TAU])
			paired += 1
	# Watchers along the rails, leaning and swaying
	for spot: Array in [[Vector3(-4.1, Riverboat.DECK_Y, -6.0), -0.9], [Vector3(4.1, Riverboat.DECK_Y, -8.5), 0.9],
			[Vector3(-4.0, Riverboat.DECK_Y, -13.0), -0.5], [Vector3(3.9, Riverboat.DECK_Y, -13.5), 0.4]]:
		var frog := _frog(FrogLook.random(frogs.size() + 900), spot[0], spot[1])
		frog.frog_rig().dance = "watch"


func _frog(look: Dictionary, at: Vector3, yaw: float) -> Frog:
	var frog := Frog.new()
	frog.look = look
	frog.droop = look.get("droop", 0.25)
	frog.position = at
	frog.home_yaw = yaw
	boat.add_child(frog)
	frogs.append(frog)
	return frog


## Where each dancer stands: rows across the deck from just behind the conductor back towards the
## stern, a little jumbled.
func _places() -> Array:
	var out := []
	var rows := [[-5.2, 5], [-6.6, 6], [-8.0, 6], [-9.4, 5], [-10.8, 5], [-12.4, 4]]
	for row: Array in rows:
		var n: int = row[1]
		for i in n:
			if out.size() >= count:
				break
			var x := lerpf(-3.4, 3.4, (i + 0.5) / n) + _rng.randf_range(-0.3, 0.3)
			out.append(Vector3(x, Riverboat.DECK_Y, row[0] + _rng.randf_range(-0.3, 0.3)))
	return out


func _pick_dance(energy: float) -> String:
	var calm := ["sway", "clap", "watch", "sway", "two_step"]
	var lively := ["bounce", "two_step", "charleston", "clap", "wave", "jig", "shimmy", "strut"]
	var list := lively if _rng.randf() < energy + 0.25 else calm
	return list[_rng.randi() % list.size()]


func _process(delta: float) -> void:
	var energy := Groove.energy if Groove.playing else 0.0
	# Couples turn round each other, faster when the music is lively
	for couple: Array in _couples:
		var speed := (0.25 + 0.5 * energy) * (1.0 if Groove.playing else 0.0)
		couple[3] += delta * speed
		var a: Frog = couple[0]
		var b: Frog = couple[1]
		var centre: Vector3 = couple[2]
		var way := Vector3(sin(couple[3]), 0.0, cos(couple[3])) * 0.4
		var going := Vector3(cos(couple[3]), 0.0, -sin(couple[3])) * 0.4 * speed
		a.drive(centre - way, -going, atan2(way.x, way.z))
		b.drive(centre + way, going, atan2(-way.x, -way.z))
	# A sudden swell in the music: those nearest the band gasp, the keenest panic
	_playing_for = _playing_for + delta if Groove.playing else 0.0
	if _playing_for > 6.0 and Groove.energy - _last_energy > 0.25:
		for frog in frogs:
			if frog.frog_rig().emoting() == "" and _rng.randf() < 0.15:
				frog.frog_rig().emote("panic" if _rng.randf() < 0.4 else "shock", _rng.randf_range(1.5, 2.6))
	_last_energy = lerpf(_last_energy, Groove.energy, 1.0 - exp(-2.0 * delta))
	# Every so often someone changes how they dance, steps aside, or does a little something
	_change_in -= delta
	if _change_in <= 0.0:
		_change_in = _rng.randf_range(0.8, 2.5)
		var frog: Frog = frogs[_rng.randi() % frogs.size()]
		var rig := frog.frog_rig()
		if rig.dance == "partner":
			return
		var roll := _rng.randf()
		if roll < 0.2 and not frog.is_going():
			var step := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.4, 0.4))
			frog.go_to(frog.home + step)
			get_tree().create_timer(_rng.randf_range(2.0, 4.0)).timeout.connect(func() -> void: frog.go_to(frog.home))
		elif roll < 0.5 and rig.emoting() == "":
			var choices := ["bow", "coy", "laugh", "point", "cheer"] if energy > 0.4 else ["bow", "coy", "laugh", "point"]
			rig.emote(choices[_rng.randi() % choices.size()], _rng.randf_range(2.0, 3.5))
		elif roll < 0.62 and rig.emoting() == "":
			rig.expression = ["smile", "grin", "sly", "incredulous", "bliss"][_rng.randi() % 5]
		elif rig.dance != "watch":
			rig.dance = _pick_dance(energy)


## A new phrase in the music: a few of them start a new dance with it.
func on_phrase() -> void:
	for frog in frogs:
		var rig := frog.frog_rig()
		if rig.dance != "partner" and rig.dance != "watch" and _rng.randf() < 0.3:
			rig.dance = _pick_dance(Groove.energy)


## A cheer (the end of a song): arms up, mouths open, a panic or two.
func cheer(seconds := 3.0) -> void:
	for frog in frogs:
		frog.frog_rig().emote("panic" if _rng.randf() < 0.25 else "cheer", seconds * _rng.randf_range(0.7, 1.2))
