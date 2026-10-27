class_name Director
extends Camera3D
## The camera, cutting between shots of the show as a music film would: from
## behind the crowd looking up at the bandstand, from the stage out over the
## crowd into the sunset, close on whoever has the tune, over the conductor's
## shoulder, from the bank as the boat goes by, from high up, from down by the
## wheel. Each shot drifts slowly while it is held; it cuts on a new phrase of
## the music (and to the soloist when the tune changes hands), and holds
## longer when the music is quiet. It keeps what it frames the same width on a
## phone held upright as on a wide screen.

## Each shot: where the eye goes from and to over the shot (in the boat's
## space), what it looks at, how wide a view it keeps (metres across at what it
## looks at), and whether the eye is on the bank (going by with the river).
const SHOTS := {
	"audience": {"from": Vector3(-2.2, 2.9, 1.2), "to": Vector3(1.8, 2.7, 0.0), "look": Vector3(0.0, 2.6, -12.0), "width": 10.5},
	"stage": {"from": Vector3(-1.4, 3.9, -14.2), "to": Vector3(1.4, 3.7, -13.9), "look": Vector3(0.0, 2.0, 8.0), "width": 12.0},
	"floor": {"from": Vector3(0.9, 2.75, -1.2), "to": Vector3(-0.9, 2.7, -1.6), "look": Vector3(0.0, 2.6, -11.5), "width": 7.5},
	"crane": {"from": Vector3(13.0, 15.0, -24.0), "to": Vector3(15.0, 13.0, -12.0), "look": Vector3(0.0, 2.0, -3.0), "width": 26.0},
	"bank": {"from": Vector3(24.0, 3.0, 40.0), "to": Vector3(24.0, 3.0, 40.0), "look": Vector3(0.0, 4.0, 0.0), "width": 34.0, "bank": true},
	"wheel": {"from": Vector3(8.5, 0.7, 9.0), "to": Vector3(8.8, 0.9, 6.5), "look": Vector3(3.0, 2.2, -10.0), "width": 13.0},
	"bow": {"from": Vector3(0.0, 4.0, 16.0), "to": Vector3(0.0, 4.6, 14.0), "look": Vector3(0.0, 2.6, -8.0), "width": 13.0},
	"conductor": {"width": 3.6},
	"lead": {"width": 1.9},
}
## Which shots come up in turn (the soloist and the conductor are cut to by the music).
const ROTATION := ["audience", "stage", "floor", "crane", "audience", "bank", "conductor", "wheel", "stage", "bow"]

## "auto" cuts by itself; otherwise the name of one shot to hold.
var mode := "auto"
var boat: Riverboat
var river: River
## Who is who, for the shots of people: part -> Frog.
var band := {}
var conductor: Frog

var _shot := "audience"
var _held := 0.0
var _length := 9.0
var _turn := 0
var _bank_offset := 0.0
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
	_bank_offset = 0.0
	_aim(0.0)


## A new phrase of the music: cut (now and then to whoever has the tune).
func on_phrase() -> void:
	if mode != "auto" or _held < 3.0:
		return
	if Groove.lead != _last_lead and band.has(Groove.lead) and _rng.randf() < 0.7:
		_last_lead = Groove.lead
		cut_to("lead")
	elif _rng.randf() < 0.75:
		cut_to()


func _process(delta: float) -> void:
	_held += delta
	if mode == "auto":
		if _held > _length + 4.0 or (_held > _length and not Groove.playing):
			cut_to()
	elif _shot != mode:
		cut_to(mode)
	_aim(delta)


func _aim(delta: float) -> void:
	var shot: Dictionary = SHOTS[_shot]
	var t := clampf(_held / _length, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var eye := Vector3.ZERO
	var target := Vector3.ZERO
	match _shot:
		"lead":
			var frog: Frog = band.get(Groove.lead, band.get("trumpet"))
			var head := frog.global_position + Vector3.UP * 1.5
			var front := Vector3(sin(frog.facing_yaw), 0.0, cos(frog.facing_yaw))
			var across := front.cross(Vector3.UP)
			eye = head + front * 2.3 + across * lerpf(-0.9, 0.9, eased) + Vector3.UP * 0.1
			target = head + Vector3.DOWN * 0.35
		"conductor":
			var at := conductor.global_position
			eye = at + Vector3(lerpf(1.5, 1.1, eased), 2.75, 2.3)
			target = at + Vector3(0.0, 1.4, -4.0)
		_:
			var from: Vector3 = shot.from
			var to: Vector3 = shot.to
			eye = from.lerp(to, eased)
			if shot.get("bank", false):
				# On the bank: it stays put on the shore while the boat goes on past it
				_bank_offset -= delta * (river.speed if river else 2.5)
				eye.z += _bank_offset
			target = shot.look
	# (a little sway, as if held by hand on a boat)
	eye += Vector3(sin(Time.get_ticks_msec() * 0.0007), sin(Time.get_ticks_msec() * 0.0011) * 0.6, 0.0) * 0.04
	look_at_from_position(eye, target)
	# Keep the width the shot asks for, whatever shape the screen is
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var distance := eye.distance_to(target)
	# (upright, a little closer: the height of the screen shows the rest)
	var width: float = shot.width * lerpf(0.7, 1.0, clampf(aspect, 0.0, 1.0))
	var vertical := 2.0 * atan(width * 0.5 / distance / aspect)
	# (and a push in on the beat, slight)
	var kick := Groove.bass * 0.012 if Groove.playing else 0.0
	fov = clampf(rad_to_deg(vertical) * (1.0 - kick), 18.0, 82.0)
