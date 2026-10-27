class_name FrogRig
extends CharacterRig
## A frog on the boy's rig (CharacterRig: the standing, breathing, weight
## shifting, looking about and walking are all its), with what a frog does over
## the top of it, laid on in `_pose_extra`:
##
## - Its eyes: heavy upper lids that droop (`droop`) and blink now and then,
##   and close in bliss when the music swells; its jaw, which drops to sing,
##   cheer and gasp, and its throat, which puffs out as it blows.
## - Playing (`part` one of Instrument.make's): the instrument on its chest or
##   head, its hands on it, each note struck (`strike`) seen in how it plays:
##   valves pressed and a puff of the throat, a strum, a bow drawn the other
##   way, the bellows pushed, a stick coming down. When it has the tune
##   (Groove.lead) it leans into it and plays out to the crowd.
## - Conducting: the baton beating time in the bar's pattern, the left hand
##   bringing in whoever takes the tune.
## - Dancing (`dance` one of DANCES), on the beat: bobbing at the knees and
##   swaying, clapping, arms up and waving, hands on hips kicking up its heels,
##   or holding a partner (`partner`) in a waltz. All of it scales with how hard
##   the band is playing (Groove.energy).
##
## Musicians and dancers keep their feet where the rig put them: whatever the
## hips do here, the legs are solved again to the same footing (_replant).

const DANCES := ["bounce", "sway", "clap", "wave", "jig", "partner", "watch"]
## The frog's own bones (tools/build_frogs.py): how far a lid turns to close, how far the jaw opens.
const LID_SHUT := 1.05
const JAW_WIDE := 0.42

## What it plays ("" for none: it dances).
var part := ""
var dance := "bounce"
## How far its lids hang over its eyes at rest, radians (sleepy frogs droop more).
var droop := 0.2
## Someone to dance with, for "partner".
var partner: FrogRig
## How far it is into the music: 0 standing about, 1 lost in it.
var keen := 1.0
var instrument: Instrument
## Mouth open, 0..1, from outside (a cheer, a gasp): it eases there.
var shout := 0.0

var _jaw: Node3D
var _lids: Array[Node3D] = []
var _blink := 0.0
var _blink_in := 2.0
var _hit := 0.0
var _hit_time := 10.0
var _bow_way := 1.0
var _bow_at := 0.5
var _throat := 0.0
var _feature := 0.0
var _mouth := 0.0
var _swing_phase := 0.0
var _clap_last := -1
var _cue := 0.0
var _cue_at := Vector3.ZERO
var _last_lead := ""
var _kick_foot := 0
var _stick_down := [10.0, 10.0]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng.seed = get_instance_id()
	_blink_in = _rng.randf_range(0.5, 4.0)
	if _has(&"jaw"):
		_jaw = _joint(_head, &"jaw", _rest(&"jaw"))
	for bone: StringName in [&"lid_l", &"lid_r"]:
		if _has(bone):
			_lids.append(_joint(_head, bone, _rest(bone)))
	if part != "":
		instrument = Instrument.make(part)
	if instrument:
		var joint: Node3D = {&"chest": _chest if _chest else _spine, &"head": _head, &"root": self}[instrument.anchor]
		var at := Vector3.ZERO if instrument.anchor == &"root" else _skeleton.get_bone_global_rest(_skeleton.find_bone(instrument.anchor)).origin
		joint.add_child(instrument)
		instrument.position = -at


## Something it plays has been struck (TrackPlayer.struck), this hard, 0..1.
## For the drums, `what` says which: "kick" or "cymbal".
func strike(loud: float, what := "") -> void:
	if loud < 0.08:
		return
	_hit = maxf(_hit * 0.5, loud)
	_hit_time = 0.0
	_bow_way = -_bow_way
	if part == "drums":
		var hand := 0 if what == "cymbal" else 1
		# (fast hits on the snare go hand to hand)
		if what != "cymbal" and _stick_down[1] < 0.18:
			hand = 0
		_stick_down[hand] = 0.0


func _pose_extra(delta: float) -> void:
	super(delta)
	if _ragdoll or _shoulders.size() < 2:
		return
	_hit_time += delta
	_hit = maxf(0.0, _hit - delta * 3.0)
	for i in 2:
		_stick_down[i] += delta
	var energy := Groove.energy * keen if Groove.playing else 0.0
	var leading := part != "" and (Groove.lead == part or Groove.second == part)
	_feature = _approach(_feature, 1.0 if leading else 0.0, 2.5, delta)
	_face(delta, energy)
	var feet := _footing()
	if part == "conductor":
		_body(delta, energy * 0.8, 0.012, 0.015)
		_replant(feet, 0.0)
		_conduct(delta, energy)
	elif part != "":
		_body(delta, energy, 0.008 + 0.012 * _feature, 0.01 + 0.02 * _feature)
		_replant(feet, 0.0)
		_play(delta, energy)
	else:
		_dance(delta, energy, feet)


# --- The face ---

func _face(delta: float, energy: float) -> void:
	# Blinks: down fast, up a little slower. In a swell of the music the lids sink, blissful.
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 1.0
		_blink_in = _rng.randf_range(1.5, 5.5)
	_blink = maxf(0.0, _blink - delta * 7.0)
	var shut := sin(_blink * PI) if _blink > 0.0 else 0.0
	var bliss := smoothstep(0.55, 0.95, energy) * 0.35 * (1.0 - _feature) if part != "" else 0.0
	for lid in _lids:
		lid.rotation.x = lerpf(droop + bliss, LID_SHUT, shut)
	# The mouth: a singer's or a cheerer's opens with the music; a blower's stays shut on the mouthpiece
	var blowing := part in ["tuba", "trumpet", "clarinet"]
	var open := shout
	if part == "" and dance != "watch":
		open = maxf(open, smoothstep(0.6, 1.0, energy) * 0.5 * (0.5 + 0.5 * sin(_time * 3.1 + get_instance_id())))
	if part in ["banjo", "accordion", "drums"]:
		# (they sing along, opening on the strong notes)
		open = maxf(open, _hit * 0.4 * energy)
	if blowing:
		open = 0.0
	_mouth = _approach(_mouth, open, 12.0, delta)
	# The throat puffs as a blower blows, and swells a little with each breath anyway
	var puff := 0.0
	if blowing:
		puff = Groove.level_of(part) * 0.7 + _hit * 0.5
	_throat = _approach(_throat, puff, 10.0 if puff > _throat else 4.0, delta)
	if _jaw:
		_jaw.rotation.x = _mouth * JAW_WIDE
		var swell := 1.0 + 0.16 * _throat + 0.012 * sin(_breath)
		_jaw.scale = Vector3(swell, 1.0 + 0.08 * _throat, swell)


# --- The body: the bob on the beat, the sway, the lean into a solo ---

func _body(delta: float, energy: float, bob: float, sway: float) -> void:
	var pulse := Groove.pulse(5.0) if Groove.playing else 0.0
	var beat := Groove.beat
	var drop := bob * (0.4 + energy) * (pulse + 0.2 * _hit)
	var side := sin(beat * PI) * sway * (0.3 + energy)
	_hips.position += Vector3(side, -drop, 0.025 * _feature)
	_hips.rotate_object_local(Vector3.FORWARD, side * 1.5)
	_spine.rotate_object_local(Vector3.RIGHT, 0.06 * _feature - 0.03 * _hit)
	if _chest:
		_chest.rotate_object_local(Vector3.FORWARD, -side * 2.0)
	_head.rotate_object_local(Vector3.RIGHT, 0.05 * pulse * (0.3 + energy))


## Each foot where the rig put it, in the rig's space, before the hips are moved.
func _footing() -> Array[Transform3D]:
	var feet: Array[Transform3D] = []
	for i in 2:
		feet.append(_hips.transform * _feet[i].transform)
	return feet


## The legs solved again so the feet stay where they were, the hips wherever they are now.
func _replant(feet: Array[Transform3D], splay: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_solve_leg(i, side, to_hips * feet[i].origin, (to_hips.basis * feet[i].basis).orthonormalized(), side * splay)


# --- Playing ---

func _play(delta: float, energy: float) -> void:
	var grip_l: Vector3 = instrument.grips.l.global_position
	var grip_r: Vector3 = instrument.grips.r.global_position
	var to_world := global_basis.orthonormalized()
	var pole_l: Vector3 = (to_world * (instrument.poles.l as Vector3)).normalized()
	var pole_r: Vector3 = (to_world * (instrument.poles.r as Vector3)).normalized()
	var size := global_basis.get_scale().y
	var since := _hit_time
	var jab := exp(-since * 14.0) * _hit
	match part:
		"tuba", "trumpet", "clarinet":
			# Fingers press on the notes; the bell lifts as it plays out
			var lift := 0.1 * _feature + 0.06 * Groove.level_of(part)
			if instrument.anchor == &"head":
				_head.rotate_object_local(Vector3.RIGHT, -lift)
			_curl[0] = 1.1
			_curl[1] = lerpf(0.5, 1.2, jab)
			grip_r += global_basis.y.normalized() * (-0.012 * jab * size)
		"accordion":
			# The bellows breathe: drawn out across a bar, pushed in across the next, and squeezed on each note
			var breath := 0.5 - 0.5 * cos(Groove.bar_phase() * TAU) if Groove.playing else 0.3
			var spread := 0.03 + 0.07 * breath * (0.4 + energy) - 0.02 * jab
			var bellows: Node3D = instrument.parts.bellows
			bellows.scale.x = 1.0 + spread / 0.1
			instrument.parts.end_l.position.x = 0.125 + spread * 0.5
			instrument.parts.end_r.position.x = -0.125 - spread * 0.5
			grip_l += global_basis.x.normalized() * spread * 0.5 * size
			grip_r -= global_basis.x.normalized() * spread * 0.5 * size
			_curl[0] = 0.9
			_curl[1] = lerpf(0.4, 1.0, jab)
		"banjo":
			# The right hand strums down across the strings with each note
			var strum := 0.05 * (1.0 - exp(-since * 20.0)) - 0.025
			grip_r += global_basis.y.normalized() * (-strum * 2.0 * size) * (1.0 if _hit > 0.05 else 0.3)
			_curl[0] = 1.2
			_curl[1] = 0.8
		"fiddle":
			# The bow is drawn one way for one note and back for the next, across the strings
			var across: Vector3 = instrument.parts.across
			var contact: Vector3 = instrument.parts.contact
			var target := 0.75 if _bow_way > 0.0 else 0.25
			_bow_at = _approach(_bow_at, target, 3.0 + 6.0 * _hit, delta)
			var bow: Node3D = instrument.parts.bow
			var hand_local := contact - across * lerpf(0.06, 0.34, _bow_at) + Vector3(0.0, 0.035, 0.0)
			grip_r = instrument.to_global(hand_local)
			bow.position = hand_local + Vector3(0.0, -0.01, 0.0)
			bow.basis = Basis.looking_at(across, Vector3.UP, true)
			_curl[0] = lerpf(0.9, 1.3, jab)
			_curl[1] = 1.0
			# (a fiddler sways with the bow)
			if _chest:
				_chest.rotate_object_local(Vector3.UP, (_bow_at - 0.5) * 0.15)
		"drums":
			_drum_hands(delta)
			return
	_solve_arm(0, 1.0, grip_l, _forearm + 0.05, 1.0, pole_l)
	_solve_arm(1, -1.0, grip_r, _forearm + 0.05, 1.0, pole_r)
	_pose_fingers(0, 1.0)
	_pose_fingers(1, -1.0)


func _drum_hands(_delta: float) -> void:
	var size := global_basis.get_scale().y
	var targets: Array[Vector3] = [instrument.to_global(instrument.parts.cymbal_top), instrument.to_global(instrument.parts.snare)]
	var to_world := global_basis.orthonormalized()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var t: float = _stick_down[i]
		# Down onto the drum in a flash, then back up slower
		var up := 1.0 - exp(-t * 9.0) if t < 2.0 else 1.0
		if t < 0.045:
			up = 1.0 - t / 0.045
		var aim := (to_world * Vector3(0.0, -0.35 - 0.5 * (1.0 - up), 1.0)).normalized()
		var tip := targets[i] + to_world * Vector3(0.0, 0.11 * up + 0.01, -0.02 * up) * size
		var hand := tip - aim * 0.27 * size
		_solve_arm(i, side, hand, _forearm + 0.05, 1.0, (to_world * Vector3(side, -0.7, -0.5)).normalized())
		_curl[i] = 1.3
		_pose_fingers(i, side)
		var stick: Node3D = instrument.parts["stick_" + ("l" if i == 0 else "r")]
		var palm := _hands[i].global_transform * Vector3(0.0, -0.045, 0.0)
		stick.global_transform = Transform3D(Basis.looking_at(aim, Vector3.UP, true).scaled(Vector3.ONE * size), palm - aim * 0.04 * size)
	# The bass drum's head throbs with the kick, the cymbal tips and shivers
	var bass: Node3D = instrument.parts.bass
	var kick := Groove.level_of("kick")
	bass.scale = Vector3(1.0, 1.0, 1.0 + 0.06 * kick)
	var cymbal: Node3D = instrument.parts.cymbal
	var ring := exp(-_stick_down[0] * 4.0)
	cymbal.rotation = Vector3(sin(_time * 30.0) * 0.12 * ring, 0.0, 0.15 * ring)


# --- Conducting ---

## Where the baton's tip is in each beat of the bar (in his own space: left +X), for 4 and 3.
const PATTERN_4 := [Vector3(0.0, 0.72, 0.30), Vector3(0.12, 0.80, 0.28), Vector3(-0.24, 0.80, 0.26), Vector3(-0.06, 1.0, 0.26)]
const PATTERN_3 := [Vector3(0.0, 0.72, 0.30), Vector3(-0.24, 0.80, 0.26), Vector3(-0.06, 1.0, 0.26)]


func _conduct(delta: float, energy: float) -> void:
	var size := global_basis.get_scale().y
	var pattern: Array = PATTERN_3 if Groove.meter == 3 else PATTERN_4
	var b := Groove.beat if Groove.playing else _time * 0.3
	var n := pattern.size()
	var which := posmod(int(floorf(b)), n)
	var into := b - floorf(b)
	var from: Vector3 = pattern[which]
	var to: Vector3 = pattern[(which + 1) % n]
	# Each beat lands with a flick (the ictus) and rebounds on its way to the next
	var eased := smoothstep(0.0, 1.0, pow(into, 0.7))
	var tip: Vector3 = from.lerp(to, eased) + Vector3(0.0, 0.06 * sin(into * PI) * (0.5 + energy), 0.0)
	var amp := 0.6 + 0.6 * energy
	tip = Vector3(tip.x * amp, 0.86 + (tip.y - 0.86) * amp, tip.z)
	var hand := to_global(tip)
	_solve_arm(1, -1.0, hand, _forearm + 0.05, 1.0, (global_basis.orthonormalized() * Vector3(-1.0, -0.4, -0.3)).normalized())
	_curl[1] = 1.2
	_pose_fingers(1, -1.0)
	var baton: Node3D = instrument.parts.baton
	var palm := _hands[1].global_transform * Vector3(0.0, -0.045, 0.0)
	var aim := (global_basis.orthonormalized() * Vector3(-0.1, 0.35, 1.0)).normalized()
	baton.global_transform = Transform3D(Basis.looking_at(aim, Vector3.UP, true).scaled(Vector3.ONE * size), palm)
	# The left hand brings in whoever takes the tune: out towards them, palm up, for a bar
	if Groove.lead != _last_lead:
		_last_lead = Groove.lead
		for frog: Node in get_tree().get_nodes_in_group(&"band"):
			if frog is Frog and frog.part == Groove.lead:
				_cue_at = frog.global_position + Vector3.UP * 0.9 * size
				_cue = 1.0
	_cue = maxf(0.0, _cue - delta * 0.4)
	var rest := to_global(Vector3(0.12, 0.78, 0.2))
	var reach := global_position.lerp(_cue_at, 0.32) if _cue > 0.0 else rest
	var left := rest.lerp(reach, smoothstep(0.0, 0.3, _cue))
	_solve_arm(0, 1.0, left + Vector3.UP * 0.05 * energy * size, _forearm + 0.05, 0.85, Vector3.ZERO)
	_curl[0] = 0.3
	_splay[0] = 0.6
	_pose_fingers(0, 1.0)
	# (and his whole body is in it: up on the beat, leaning into the loud bits)
	_spine.rotate_object_local(Vector3.RIGHT, 0.08 * energy)


# --- Dancing ---

func _dance(delta: float, energy: float, feet: Array[Transform3D]) -> void:
	var size := global_basis.get_scale().y
	var playing := Groove.playing
	var b := Groove.beat if playing else _time * 0.5
	var pulse := Groove.pulse(4.0) if playing else 0.0
	var e := energy if playing else 0.0
	var forward := global_basis.z.normalized()
	var left := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	match dance:
		"watch":
			# Swaying gently where it stands, nodding along
			_body(delta, e * 0.5, 0.006, 0.012)
			_replant(feet, 0.0)
		"bounce", "clap", "wave":
			# Down at the knees on every beat, a twist of the hips with it
			var drop := (0.02 + 0.05 * e) * pulse
			_hips.position += Vector3(0.0, -drop, 0.0)
			_hips.rotate_object_local(Vector3.UP, sin(b * PI) * 0.18 * e)
			_spine.rotate_object_local(Vector3.RIGHT, 0.05 * pulse * e)
			_head.rotate_object_local(Vector3.RIGHT, 0.12 * pulse * e)
			_replant(feet, 0.25)
			if dance == "clap":
				# Clapping on the off-beats (on every beat when it is going well)
				var every := 1 if e > 0.65 else 2
				var into := fposmod(b - (1.0 if every == 2 else 0.0), every)
				var apart := clampf(into / every, 0.0, 1.0)
				var gap := 0.015 + 0.13 * sin(minf(apart * 1.2, 1.0) * PI * 0.5 + 0.0) * (1.0 - exp(-apart * 8.0))
				var centre := to_global(Vector3(0.0, 0.8 + 0.12 * e, 0.24))
				for i in 2:
					var side := 1.0 if i == 0 else -1.0
					_solve_arm(i, side, centre + left * side * gap * size, _forearm + 0.02, 1.0, Vector3.ZERO)
					_curl[i] = 0.1
					_splay[i] = 0.1
					_lay_hand(i, side, -left * side, up, 1.0)
					_pose_fingers(i, side)
			elif dance == "wave":
				# Arms up over its head, swept from side to side together (higher the louder)
				var sweep := sin(b * PI * 0.5)
				var high := 0.2 + 0.18 * e
				for i in 2:
					var side := 1.0 if i == 0 else -1.0
					var from := _shoulders[i].global_position
					var hand := from + (up * high + left * (side * 0.1 + sweep * 0.12) + forward * 0.05) * size
					_solve_arm(i, side, hand, _forearm, smoothstep(0.15, 0.5, maxf(e, shout)), left * side + Vector3.DOWN * 0.3)
					_curl[i] = 0.2
					_pose_fingers(i, side)
		"sway":
			# Side to side over the bar, arms loose and swinging
			var lean := sin(b * PI * 2.0 / maxf(Groove.meter, 1)) * (0.03 + 0.04 * e)
			_hips.position += Vector3(lean, -0.01 * pulse, 0.0)
			_hips.rotate_object_local(Vector3.FORWARD, lean * 2.5)
			if _chest:
				_chest.rotate_object_local(Vector3.FORWARD, -lean * 3.5)
			_head.rotate_object_local(Vector3.FORWARD, -lean * 2.0)
			_replant(feet, 0.1)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var swing := sin(b * PI + (0.0 if i == 0 else PI)) * 0.12 * (0.4 + e)
				var hand := to_global(Vector3(side * 0.22 - lean * 0.5, 0.52 + 0.06 * absf(swing), swing))
				_solve_arm(i, side, hand, _forearm + 0.04, 0.8, Vector3.ZERO)
		"jig":
			# Hands on hips, elbows out; up on the beat, kicking up a heel (one, then the other)
			var hop := (0.015 + 0.04 * e) * pulse
			_hips.position += Vector3(0.0, -0.02 + hop, 0.0)
			var which := posmod(int(floorf(b)), 2)
			var kick := sin(clampf(fposmod(b, 1.0) * 1.4, 0.0, 1.0) * PI) * (0.4 + e)
			var lifted := feet.duplicate()
			var foot: Transform3D = lifted[which]
			foot.origin += Vector3(0.0, 0.07 * kick, 0.05 * kick)
			foot.basis = Basis(Vector3.RIGHT, -0.4 * kick) * foot.basis
			lifted[which] = foot
			_replant(lifted, 0.3)
			_spine.rotate_object_local(Vector3.FORWARD, (0.06 if which == 0 else -0.06) * e)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var hip := to_global(Vector3(side * 0.18, 0.62, 0.02))
				_solve_arm(i, side, hip, _forearm, 1.0, left * side + Vector3.UP * 0.2 - forward * 0.3)
				_curl[i] = 1.2
				_pose_fingers(i, side)
		"partner":
			# Holding a partner: the left hand on their shoulder, the right holding their hand out to the side
			_body(delta, e * 0.6, 0.01, 0.008)
			_replant(feet, 0.0)
			if is_instance_valid(partner):
				var mine := global_position
				var theirs := partner.global_position
				var between := mine.lerp(theirs, 0.5)
				var shoulder: Vector3 = partner._shoulders[1].global_position if partner._shoulders.size() > 1 else theirs + up
				_solve_arm(0, 1.0, mine.lerp(shoulder, 0.75) + up * 0.02 * size, _forearm, 1.0, Vector3.ZERO)
				var out := (theirs - mine).cross(up).normalized()
				var held := between + up * 0.82 * size - out * 0.16 * size
				_solve_arm(1, -1.0, held, _forearm + 0.04, 1.0, Vector3.ZERO)
				_curl[1] = 0.9
				_pose_fingers(1, -1.0)
