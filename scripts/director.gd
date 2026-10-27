class_name Director
extends Camera3D
## The camera, cutting between shots of the show as a music film would: from behind the crowd up
## at the bandstand, from inside the bandstand out over the crowd into the sunset, among the
## dancers, close on whoever has the tune or on the singer, over the conductor's shoulder, from
## the bank as the boat goes by, from high up, from down by the wheel, and broadside from the
## water. Each shot drifts slowly while it is held; it cuts on a new phrase of the music (and to
## the soloist when the tune changes hands), and holds longer when the music is quiet. It keeps
## what it frames the same width whatever the shape of the picture.

## Each shot: where the eye goes from and to over the shot and what it looks at (on the boat, which
## moves: they go with it), and how wide a view it keeps (metres across at what it looks at).
## "bank": the eye is put on the shore and stays there as the boat goes past.
const SHOTS := {
	"audience": {"from": Vector3(-2.2, 3.0, -15.0), "to": Vector3(1.8, 2.8, -13.5), "look": Vector3(0.0, 2.9, -0.5), "width": 9.5},
	"stage": {"from": Vector3(-1.2, 3.9, 0.9), "to": Vector3(1.2, 3.7, 0.7), "look": Vector3(0.0, 2.0, -16.0), "width": 12.0},
	"floor": {"from": Vector3(1.0, 2.8, -9.0), "to": Vector3(-1.0, 2.7, -8.0), "look": Vector3(0.0, 2.8, -0.5), "width": 7.5},
	"crane": {"from": Vector3(14.0, 15.0, -28.0), "to": Vector3(16.0, 13.0, -16.0), "look": Vector3(0.0, 2.0, -5.0), "width": 26.0},
	"bank": {"from": Vector3(19.5, 4.6, 45.0), "to": Vector3(19.5, 4.6, 45.0), "look": Vector3(0.0, 4.0, 0.0), "width": 38.0, "bank": true},
	"wheel": {"from": Vector3(10.0, 0.9, -5.0), "to": Vector3(10.4, 1.2, -2.0), "look": Vector3(4.5, 2.4, 9.0), "width": 15.0},
	"broadside": {"from": Vector3(12.5, 1.5, -10.0), "to": Vector3(12.5, 1.7, 0.0), "look": Vector3(0.0, 3.5, -3.0), "width": 32.0},
	"bow": {"from": Vector3(0.0, 6.6, 21.0), "to": Vector3(0.0, 7.0, 19.0), "look": Vector3(0.0, 4.0, -10.0), "width": 18.0},
	"conductor": {"width": 3.6},
	"lead": {"width": 2.6},
	"singer": {"width": 2.4},
}
## Which shots come up in turn (the soloist, the singer and the conductor are cut to by the music).
const ROTATION := ["audience", "stage", "floor", "singer", "crane", "audience", "bank", "conductor", "broadside", "wheel", "stage", "bow"]

## "auto" cuts by itself; otherwise the name of one shot to hold; "manual" leaves the camera alone.
var mode := "auto"
var boat: Riverboat
var river: River
## Who is who, for the shots of people: part -> Frog.
var band := {}
var conductor: Frog
var singer: Frog
## The part of the window that is the film (the camera desk's frame), or empty for all of it.
var crop := Rect2()

var _shot := "audience"
var _held := 0.0
var _length := 9.0
var _turn := 0
var _bank_eye := Vector3.ZERO
var _last_lead := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	near = 0.1
	far = 900.0
	cut_to("audience")


## Cuts to a shot by name (or to the next in turn with "").
func cut_to(shot := "") -> void:
	if shot == "":
		_turn = (_turn + 1) % ROTATION.size()
		shot = ROTATION[_turn]
	_shot = shot
	_held = 0.0
	_length = _rng.randf_range(7.0, 12.0) * (1.4 if Groove.energy < 0.3 else 1.0)
	if SHOTS[shot].get("bank", false) and boat:
		# (put on the shore ahead of the boat, which then goes past it)
		_bank_eye = boat.to_global(SHOTS[shot].from)
	_aim()


## A new phrase of the music: cut (now and then to whoever has the tune).
func on_phrase() -> void:
	if mode != "auto" or _held < 3.0:
		return
	if Groove.lead != _last_lead and band.has(Groove.lead) and _rng.randf() < 0.6:
		_last_lead = Groove.lead
		cut_to("lead")
	elif _rng.randf() < 0.75:
		cut_to()


func _process(delta: float) -> void:
	if mode == "manual":
		return
	_held += delta
	if mode == "auto":
		if _held > _length + 4.0 or (_held > _length and not Groove.playing):
			cut_to()
	elif _shot != mode:
		cut_to(mode)
	_aim()


func _aim() -> void:
	if boat == null:
		return
	var shot: Dictionary = SHOTS[_shot]
	var t := clampf(_held / _length, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	match _shot:
		"lead", "singer":
			var frog: Frog = singer if _shot == "singer" else band.get(Groove.lead, band.get("trumpet"))
			var head := frog.global_position + Vector3.UP * frog.size * 1.1
			var front := boat.global_basis.orthonormalized() * Vector3(sin(frog.facing_yaw), 0.0, cos(frog.facing_yaw))
			var across := front.cross(Vector3.UP)
			eye = head + front * 2.6 + across * lerpf(-0.9, 0.9, eased) + Vector3.UP * 0.2
			target = head + Vector3.DOWN * 0.2
		"conductor":
			var at := conductor.global_position
			eye = at + boat.global_basis * Vector3(lerpf(-1.4, -1.0, eased), 2.7, -2.2)
			target = at + boat.global_basis * Vector3(0.0, 1.5, 4.0)
		_:
			if shot.get("bank", false):
				eye = _bank_eye
			else:
				eye = boat.to_global((shot.from as Vector3).lerp(shot.to, eased))
			target = boat.to_global(shot.look)
	# (a little sway, as if held by hand)
	var now := Time.get_ticks_msec()
	eye += Vector3(sin(now * 0.0007), sin(now * 0.0011) * 0.6, 0.0) * 0.04
	look_at_from_position(eye, target)
	frame(eye.distance_to(target), shot.width)


## Sets the lens so that `width` metres across fit at `distance`, whatever the shape of the picture.
func frame(distance: float, width: float) -> void:
	var window := get_viewport().get_visible_rect().size
	var size := crop.size if crop.has_area() else window
	var aspect := size.x / maxf(size.y, 1.0)
	# (upright, a little closer: the height of the picture shows the rest)
	width *= lerpf(0.7, 1.0, clampf(aspect, 0.0, 1.0))
	var vertical := 2.0 * atan(width * 0.5 / distance / aspect)
	var kick := Groove.bass * 0.012 if Groove.playing else 0.0
	# (the camera sees the whole window, of which the film is the middle)
	vertical = 2.0 * atan(tan(vertical * 0.5) * window.y / maxf(size.y, 1.0))
	fov = clampf(rad_to_deg(vertical) * (1.0 - kick), 12.0, 100.0)
