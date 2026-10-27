class_name Passengers
extends Node
## The frogs about the rest of the boat, who are not on the dance floor (that is the Crowd's):
## strolling the walkways down either side of the cabin, leaning on the rails to watch the banks
## go by, up on the mezzanine looking down on the dancers, along the roof beside the second
## storey, and out at the bow looking ahead down the river. Each walks from one stop to another
## on its own level, stays a while facing whatever that stop faces, looks about, and now and then
## points something out, laughs or raises its hat; they cheer with everyone at the end of a song.
## They are the low-poly frogs (most are seen from a way off).

var boat: Riverboat
var frogs: Array[Frog] = []
var _rng := RandomNumberGenerator.new()
## Each level's stops: [point on the boat, which way to face there].
var _stops := {}
var _level := {}          # frog -> its level's name
var _wait := {}           # frog -> seconds left at its stop
var _pick_in := 3.0


## Only a few of them (the lighter version, in a browser).
var few := false


func _ready() -> void:
	_rng.seed = 404
	var deck := Riverboat.DECK_Y
	var roof := Riverboat.ROOF_Y
	var walk := Riverboat.CABIN_HALF + 0.85
	# (yaw 0 faces the bow, PI the stern, PI/2 to the left (+X))
	for side: float in [1.0, -1.0]:
		var name := "walk_l" if side > 0.0 else "walk_r"
		_stops[name] = []
		for z: float in [-1.6, 0.5, 2.6, 7.6, 9.6, 11.4]:
			_stops[name].append([Vector3(side * walk, deck, z), side * PI / 2])
		_stops[name].append([Vector3(side * (walk - 0.3), deck, -1.8), PI])
		var top := "roof_l" if side > 0.0 else "roof_r"
		_stops[top] = []
		for z: float in [0.0, 3.0, 6.0, 9.0]:
			_stops[top].append([Vector3(side * (Riverboat.CABIN_HALF - 0.05), roof, z), side * PI / 2])
	_stops["mezzanine"] = []
	for x: float in [-2.6, -1.3, 0.0, 1.3, 2.6]:
		_stops["mezzanine"].append([Vector3(x, roof, Riverboat.CABIN_BACK - 0.15), PI])
	_stops["bow"] = []
	for at: Vector3 in [Vector3(-1.7, deck, 13.6), Vector3(1.7, deck, 13.4), Vector3(-0.8, deck, 15.6), Vector3(0.9, deck, 15.9), Vector3(0.45, deck, 16.5)]:
		_stops["bow"].append([at, 0.0 + at.x * 0.15])
	# Who goes where
	var plan := ["walk_l", "walk_l", "walk_l", "walk_r", "walk_r", "walk_r", "mezzanine", "mezzanine", "mezzanine", "mezzanine",
			"roof_l", "roof_r", "bow", "bow", "bow"]
	if few:
		plan = ["mezzanine", "mezzanine"]
	var taken := {}
	for i in plan.size():
		var level: String = plan[i]
		var stop: Array = _free_stop(level, taken)
		var frog := Frog.new()
		frog.look = FrogLook.random(i + 2000)
		frog.droop = frog.look.get("droop", 0.25)
		frog.low = true
		frog.dance = "watch"
		frog.position = stop[0] + _jitter()
		frog.home_yaw = stop[1]
		boat.add_child(frog)
		frogs.append(frog)
		_level[frog] = level
		_wait[frog] = _rng.randf_range(1.0, 12.0)
		taken[frog] = stop
		frog.arrived.connect(func() -> void: _arrived(frog))


func _jitter() -> Vector3:
	return Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.25, 0.25))


## A stop on `level` that nobody else is at, or going to.
func _free_stop(level: String, taken: Dictionary) -> Array:
	var stops: Array = _stops[level]
	var free := stops.filter(func(stop: Array) -> bool: return not taken.values().has(stop))
	if free.is_empty():
		free = stops
	return free[_rng.randi() % free.size()]


func _arrived(frog: Frog) -> void:
	_wait[frog] = _rng.randf_range(5.0, 14.0)
	frog.turn_to(_stop_of(frog)[1])
	if _rng.randf() < 0.35:
		frog.frog_rig().emote(["point", "laugh", "bow", "coy"][_rng.randi() % 4], _rng.randf_range(2.0, 3.0))


var _going_to := {}


func _stop_of(frog: Frog) -> Array:
	return _going_to.get(frog, [frog.home, frog.home_yaw])


func _process(delta: float) -> void:
	# Now and then someone who has been standing a while moves on to another stop on its level
	_pick_in -= delta
	for frog: Frog in frogs:
		if not frog.is_going():
			_wait[frog] = float(_wait[frog]) - delta
	if _pick_in > 0.0:
		return
	_pick_in = _rng.randf_range(1.5, 4.0)
	var ready := frogs.filter(func(frog: Frog) -> bool: return not frog.is_going() and float(_wait[frog]) <= 0.0)
	if ready.is_empty():
		return
	var frog: Frog = ready[_rng.randi() % ready.size()]
	var stop := _free_stop(_level[frog], _going_to)
	_going_to[frog] = stop
	frog.go_to(stop[0] + _jitter())
	_wait[frog] = 999.0


## A cheer (the end of a song): hats and arms up.
func cheer(seconds := 3.0) -> void:
	for frog in frogs:
		if _rng.randf() < 0.7:
			frog.frog_rig().emote("cheer", seconds * _rng.randf_range(0.6, 1.1))
