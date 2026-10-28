class_name FrogRig
extends CharacterRig
## A frog on the boy's rig (CharacterRig: the standing, breathing, weight shifting, looking about
## and walking are all its), with what a frog does laid over the top of it in `_pose_extra`.
##
## Its face: heavy upper lids that droop (`droop`), blink, close in bliss and fly open in shock,
## each on its own; a jaw that drops to sing, grin, gasp and shout; three mouth shapes in the model
## (`wide`, `round`, `frown`: tools/build_frogs.py) that, with the jaw, make every expression and
## every vowel; a throat that puffs as it blows; and a long tongue that flails when it panics.
## `expression` names one of EXPRESSIONS and the face eases into it.
##
## Its body, three ways, by `part`:
## - Playing (an Instrument part): the instrument on its chest or head, hands on it, each note
##   struck (`strike`) seen in how it plays; bobbing, swaying and tapping a foot to the beat; and
##   when it has the tune (Groove.lead), leaning into it and playing out.
## - Conducting ("conductor") and singing ("singer"): beating time; singing to the voice in the
##   song (Groove.voice and Groove.vowel make the mouth's shapes) with arms that go out on the
##   long notes.
## - Dancing (anything else): one of DANCES, each a figure of steps and arm moves that goes round
##   with the beat, drawn as smooth curves of it so it cannot jitter, bigger the louder the band;
##   or one of MOVES, a dance captured from life (GameCommon's MoveClip, played by CharacterRig in
##   the frog's own build), laid on the song's beat.
##
## Over any of them an emote (`emote(name)`: one of EMOTES) plays for a while and gives way again:
## a bow with the hat raised, a coy clasp of the hands, a belly laugh, a gasp, a panic with the
## tongue out and the arms waving, a cheer. The feet keep where the dance puts them (the legs are
## solved again after the hips are moved: `_replant`).

const DANCES := ["bounce", "two_step", "charleston", "sway", "wave", "jig", "shimmy", "strut", "clap", "watch"]
## Dances captured from life (moves/, GameCommon's): the dance's name, and its clip.
const MOVES := {
	"move_charleston": "res://moves/charleston.res", "move_fancy_charleston": "res://moves/fancy_charleston.res",
	"move_lindy_hop": "res://moves/lindy_hop.res", "move_twist": "res://moves/twist.res", "move_salsa": "res://moves/salsa.res",
	"move_lambada": "res://moves/lambada.res", "move_macarena": "res://moves/macarena.res",
	"move_chicken_dance": "res://moves/chicken_dance.res", "move_mickey": "res://moves/mickey.res",
}
const EMOTES := ["bow", "coy", "laugh", "shock", "panic", "cheer", "point"]
## Faces: jaw open (0..1 of JAW_WIDE), the mouth shapes, each lid (+ more closed, - wide open, on
## top of its droop), the tongue out (0..1), and the head tipped (back +, to its left +).
const EXPRESSIONS := {
	"neutral": {},
	"smile": {"wide": 0.9},
	"grin": {"wide": 1.0, "jaw": 0.4},
	"bliss": {"wide": 0.9, "jaw": 0.12, "lid_l": 1.0, "lid_r": 1.0, "tilt": 0.18, "back": 0.12},
	"shock": {"jaw": 0.8, "round": 0.5, "lid_l": -0.6, "lid_r": -0.6, "back": 0.14},
	"gasp": {"jaw": 0.55, "round": 0.9, "lid_l": -0.45, "lid_r": -0.45},
	"incredulous": {"frown": 0.8, "lid_l": -0.45, "lid_r": 0.55, "brow_r": 0.5, "tilt": -0.22, "jaw": 0.03},
	"laugh": {"jaw": 0.7, "wide": 0.9, "lid_l": 0.8, "lid_r": 0.8, "back": 0.3},
	"panic": {"jaw": 1.0, "round": 0.3, "lid_l": -0.6, "lid_r": -0.6, "tongue": 1.0, "back": 0.55},
	"frown": {"frown": 0.9, "lid_l": 0.35, "lid_r": 0.35},
	"sly": {"wide": 0.6, "lid_l": 0.7, "lid_r": 0.25, "tilt": 0.12},
	"angry": {"frown": 0.8, "lid_l": 0.3, "lid_r": 0.3, "brow_l": 0.7, "brow_r": 0.7, "jaw": 0.05},
	"sad": {"frown": 0.6, "lid_l": 0.35, "lid_r": 0.35, "brow_l": -0.6, "brow_r": -0.6, "tilt": -0.1},
}
## How far the lids turn to close, how far the jaw opens at most.
const LID_SHUT := 1.05
const JAW_WIDE := 0.7
## As it opens the jaw slides forward (and a little down), metres for each of the hinge's turn (its
## sine): the hinge is behind and above the chin, so turning alone swings the chin back into the
## throat, which folds up over the open mouth. This keeps the chin where it was and drops the lip.
const JAW_SLIDE := Vector3(0.0, -0.015, 0.1)

## What it plays ("" for none: it dances).
var part := ""
var dance := "bounce"
## How far its lids hang over its eyes at rest, radians (sleepy frogs droop more).
var droop := 0.2
## Someone to dance with (the couples): it holds them, and is moved round by the Crowd.
var partner: FrogRig
## How far it is into the music, 0..1: a wallflower sways, a keen one gives it everything.
var keen := 1.0
var instrument: Instrument
## The face it wears, of EXPRESSIONS (an emote or the singing may put on another for a while).
var expression := "neutral"
## How much it sings along with the voice in the song, 0..1 (the singer 1; some of the crowd a little).
var sings := 0.0
## How big its head is against the model's (a little different on everyone).
var head_size := 1.0
## How far it is off the beat, in beats (no two dance quite alike).
var lag := 0.0
## What it may look at (Node3Ds; Frogs are looked at in the face): the bandstand's frogs, its
## neighbours. It picks one every few seconds, the one with the tune most often (`look_lead`).
var look_around: Array = []
var look_lead: Callable
## Where it is looking now: its eyes dart there first, its head and neck come round after.
var _look_target: Node3D
var _look_next := 0.0
var _gaze_eyes := Vector2.ZERO    # yaw, pitch the eyes are on (radians, from straight ahead)
var _gaze_head := Vector2.ZERO    # and the head

var _jaw: Node3D
var _jaw_rest := Vector3.ZERO
## The soft parts, jiggled on springs as the body moves (`_jiggle`): [bone, its rest, how far it
## is off it, how fast it is going, how loose].
var _jiggles: Array = []
var _last_hips := Vector3.INF
var _hips_going := Vector3.ZERO
var _head_lag := Vector3.ZERO
var _head_lag_going := Vector3.ZERO
var _lids: Array[Node3D] = []
var _tongue: Array[Node3D] = []
var _shapes: Array = []          # [MeshInstance3D, wide, round, frown, gape blend shape indexes]
## The materials the face is drawn with (shaders/toon.gdshader's mouth, shaders/eye.gdshader): see `bind_face`.
var _skin_materials: Array[ShaderMaterial] = []
var _eye_materials: Array[ShaderMaterial] = [null, null]
var _face := {}                  # what the face is now, eased towards what it should be
## Blinking: how long a blink takes (seconds, down and up), how long the second eye is behind the
## first (seconds; a lazy blinker's eyes go one after the other), and how long between blinks
## (seconds, from, to: picked afresh each time).
var blink_time := 0.16
## Inside the open mouth: the tongue lying in it (short, broad and pink, going with the jaw), or
## only the dark of the mouth. For every frog (the viewer's and the camera desk's switch).
static var tongue_in_mouth := true
var blink_gap := 0.0
var blink_every := Vector2(1.5, 5.5)
var _blinks: Array[float] = [10.0, 10.0]   # seconds since each eye began its last blink
var _blink_in := 2.0
var _hit := 0.0
var _hit_now := 0.0
var _hit_time := 10.0
var _bow_way := 1.0
var _bow_at := 0.5
var _throat := 0.0
var _feature := 0.0
var _groove := 0.0               # the music's loudness, eased slowly: how big the moves are
var _dancing := 0.0              # eased in when the music starts
var _still := 1.0                # eased out while it walks: a dance gives way to the rig's walk
var _emote := ""
var _emote_time := 0.0
var _emote_length := 0.0
var _emote_amount := 0.0
var _cue := 0.0
var _cue_at := Vector3.ZERO
var _last_lead := ""
var _stick_down := [10.0, 10.0]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng.seed = get_instance_id()
	_blink_in = _rng.randf_range(0.5, 4.0)
	if _has(&"jaw"):
		_jaw = _joint(_head, &"jaw", _rest(&"jaw"))
		_jaw_rest = _jaw.position
		var parent := _jaw
		for k in 8:
			var bone := StringName("tongue%d" % k)
			if not _has(bone):
				break
			parent = _joint(parent, bone, _rest(bone))
			_tongue.append(parent)
	for soft: Array in [[&"belly", _spine, 0.45], [&"throat", _neck, 0.7]]:
		if _has(soft[0]) and soft[1] != null:
			var node := _joint(soft[1], soft[0], _rest(soft[0]))
			_jiggles.append([node, node.position, Vector3.ZERO, Vector3.ZERO, soft[2]])
	for bone: StringName in [&"lid_l", &"lid_r"]:
		if _has(bone):
			_lids.append(_joint(_head, bone, _rest(bone)))
	for mesh: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is ArrayMesh and mesh.find_blend_shape_by_name(&"wide") >= 0:
			_shapes.append([mesh, mesh.find_blend_shape_by_name(&"wide"), mesh.find_blend_shape_by_name(&"round"), mesh.find_blend_shape_by_name(&"frown"), mesh.find_blend_shape_by_name(&"gape")])
	if part != "" and part != "singer":
		instrument = Instrument.make(part)
	if instrument:
		var joint: Node3D = {&"chest": _chest if _chest else _spine, &"head": _head, &"root": self}[instrument.anchor]
		var at := Vector3.ZERO if instrument.anchor == &"root" else _skeleton.get_bone_global_rest(_skeleton.find_bone(instrument.anchor)).origin
		joint.add_child(instrument)
		instrument.position = -at


## Finds the materials its face is drawn with, once FrogToon has put them on.
func bind_face() -> void:
	_skin_materials.clear()
	for mesh: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var made := mesh.mesh.surface_get_material(surface)
			var shaded := mesh.get_surface_override_material(surface) as ShaderMaterial
			if made == null or shaded == null:
				continue
			match made.resource_name:
				"skin":
					_skin_materials.append(shaded)
				"eye_l":
					_eye_materials[0] = shaded
				"eye_r":
					_eye_materials[1] = shaded


## Something it plays has been struck (TrackPlayer.struck), this hard, 0..1. For the drums,
## `what` says which: "kick" or "cymbal".
func strike(loud: float, what := "") -> void:
	if loud < 0.08:
		return
	_hit_now = maxf(_hit_now, loud)
	_hit_time = 0.0
	_bow_way = -_bow_way
	if part == "drums":
		var hand := 0 if what == "cymbal" else 1
		if what != "cymbal" and _stick_down[1] < 0.18:
			hand = 0
		_stick_down[hand] = 0.0


## Blinks now (the second eye `blink_gap` behind the first; which goes first is chance).
func blink() -> void:
	var first := _rng.randi() % 2
	_blinks[first] = 0.0
	_blinks[1 - first] = -blink_gap


## Plays an emote (one of EMOTES) for about `seconds`, over whatever else it is doing.
func emote(name: String, seconds := 3.0) -> void:
	_emote = name
	_emote_time = 0.0
	_emote_length = seconds
	expression = {"bow": "grin", "coy": "bliss", "laugh": "laugh", "shock": "shock", "panic": "panic", "cheer": "grin", "point": "smile"}.get(name, expression)


func emoting() -> String:
	return _emote if _emote_amount > 0.05 else ""


func _pose_extra(delta: float) -> void:
	super(delta)
	if _ragdoll or _shoulders.size() < 2:
		return
	_hit_time += delta
	# (a strike rises fast but not in one frame, and falls away smoothly)
	_hit = _approach(_hit, _hit_now, 30.0, delta)
	_hit_now = maxf(0.0, _hit_now - delta * 4.0)
	for i in 2:
		_stick_down[i] += delta
	var playing := Groove.playing
	_groove = _approach(_groove, (Groove.energy if playing else 0.0) * keen, 1.6, delta)
	_dancing = _approach(_dancing, 1.0 if playing else 0.0, 1.5, delta)
	var going: Vector3 = _player.velocity if _player else Vector3.ZERO
	_still = _approach(_still, 0.0 if Vector2(going.x, going.z).length() > 0.12 else 1.0, 4.0, delta)
	var leading := part != "" and (Groove.lead == part or Groove.second == part)
	_feature = _approach(_feature, 1.0 if leading else 0.0, 2.0, delta)
	# The emote's envelope: in, held, out
	if _emote != "":
		_emote_time += delta
		if _emote_time > _emote_length:
			_emote = ""
			expression = "neutral"
	_emote_amount = _approach(_emote_amount, 1.0 if _emote != "" else 0.0, 5.0, delta)
	if _head:
		_head.scale = Vector3.ONE * head_size
	var feet := _footing()
	match part:
		"conductor":
			_play_body(0.6)
			_replant(feet, 0.0)
			_conduct(delta)
		"singer":
			_sing_body()
		"":
			_dance()
		_:
			_play_body(1.0)
			_replant(_tapping(feet), 0.0)
			_play(delta)
	if _emote_amount > 0.01:
		_emote_pose()
	_gaze(delta)
	_jiggle(delta)
	_face_pose(delta)
	_dance_move()


## A dance of MOVES: its clip played (by CharacterRig, after this) on the song's beat. Its own beat is
## taken at whichever of half, as it is or double comes nearest the song's, so it is never far off its
## own speed; each frog starts it at its own bar. Given way to while walking or emoting.
func _dance_move() -> void:
	var path: String = MOVES.get(dance, "") if part == "" else ""
	if path == "":
		clip_weight = 0.0
		return
	if clip == null or clip.resource_path != path:
		clip = load(path)
	clip_weight = _dancing * _still * (1.0 - _emote_amount)
	var song_beat := 60.0 / maxf(Groove.bpm, 30.0) if Groove.playing else 0.5
	var each := pow(2.0, roundf(log(song_beat / clip.beat) / log(2.0)))
	var b := (Groove.beat if Groove.playing else _time * 2.0) + lag + 4.0 * (get_instance_id() % 4)
	clip_time = clip.first_beat + b * each * clip.beat


# --- Jiggle ---

## Frogs are jiggly: the belly and the throat's pouch on springs, left behind by every bounce and
## turn of the body and wobbling back, and the head lagging and overshooting on its neck. (Driven
## by how the hips are pushed about, so the livelier the dance, the more it all wobbles.)
func _jiggle(delta: float) -> void:
	if delta <= 0.0 or _hips == null:
		return
	var at := _hips.global_position
	if _last_hips == Vector3.INF:
		_last_hips = at
	var going := (at - _last_hips) / delta
	var push := ((going - _hips_going) / delta).limit_length(60.0)
	_last_hips = at
	_hips_going = going
	# (felt in the figure's own space and size)
	var felt := global_basis.orthonormalized().inverse() * push / maxf(global_basis.get_scale().y, 0.01)
	for soft: Array in _jiggles:
		var offset: Vector3 = soft[2]
		var speed: Vector3 = soft[3]
		speed += (-offset * 260.0 - speed * 8.0 - felt * float(soft[4])) * delta
		offset = (offset + speed * delta).limit_length(0.025)
		soft[2] = offset
		soft[3] = speed
		(soft[0] as Node3D).position = soft[1] + offset
	_head_lag_going += (-_head_lag * 140.0 - _head_lag_going * 7.0 - felt * 0.5) * delta
	_head_lag = (_head_lag + _head_lag_going * delta).limit_length(0.35)
	if _head:
		_head.rotate_object_local(Vector3.RIGHT, _head_lag.z * 0.9 - _head_lag.y * 0.6)
		_head.rotate_object_local(Vector3.BACK, -_head_lag.x * 0.9)


# --- Arms ---

## How broad each body's trunk is (tools/build_frogs.py BODIES `broad`).
const BROAD := {"round": 1.12, "slim": 0.92, "squat": 1.32}


## CharacterRig's arm, solved for a frog. A frog is stout and the poses were made for the slim
## boy, so a hand is kept out of the trunk (and its clothes) and the elbows go out from the sides.
## And each arm bone is turned the shortest way from its rest: the boy's arm takes its roll from
## the way he faces, which flips over (and twists the hands round) when a forearm points ahead,
## as the band's mostly do.
func _solve_arm(i: int, side: float, point: Vector3, fore_length: float, weight: float, pole := Vector3.ZERO) -> void:
	var forward := global_basis.z.normalized()
	var left := global_basis.x.normalized()
	point = _clear_of_body(point)
	if pole == Vector3.ZERO:
		pole = Vector3.DOWN + left * side * 0.6 - forward * 0.3
	pole = (pole.normalized() + left * side * 0.7).normalized()
	var shoulder := _shoulders[i]
	var from := shoulder.global_position
	var to := point - from
	var size := global_basis.get_scale().y
	var upper_length := _upper_arm * size
	fore_length *= size
	var reach := clampf(to.length(), 0.1 * size, upper_length + fore_length - 0.005 * size)
	var direction := to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	var hinge := direction.cross(pole)
	hinge = hinge.normalized() if hinge.length_squared() > 0.0001 else (left - direction * left.dot(direction)).normalized()
	var angle := acos(clampf((upper_length * upper_length + reach * reach - fore_length * fore_length) / (2.0 * upper_length * reach), -1.0, 1.0))
	var upper_direction := direction.rotated(hinge, angle)
	var elbow_at := from + upper_direction * upper_length
	var fore_direction := (from + direction * reach - elbow_at).normalized()
	# (each bone turned the shortest way from how it rests to where it must point: the upper arm
	# swings at the shoulder without rolling round its length, which would twist the shoulder's
	# skin, and the forearm folds at the elbow about its hinge, so the hands never flip over)
	# (a bone of the rig lies along its own -Y: unturned, an arm hangs straight down)
	var parent := (shoulder.get_parent() as Node3D).global_basis.orthonormalized()
	var swing := Basis(Quaternion((parent * Vector3.DOWN).normalized(), upper_direction))
	shoulder.basis = shoulder.basis.orthonormalized().slerp((parent.inverse() * swing * parent).orthonormalized(), weight)
	var elbow := _elbows[i]
	var upper := shoulder.global_basis.orthonormalized()
	var fold := Basis(Quaternion((upper * Vector3.DOWN).normalized(), fore_direction))
	elbow.basis = elbow.basis.orthonormalized().slerp((upper.inverse() * fold * upper).orthonormalized(), weight)


## `point` moved out of the trunk if it is inside it: the trunk as an upright elliptic cylinder
## round the line from hips to chest, as broad as the body and a little more (for the clothes and
## the hand itself).
func _clear_of_body(point: Vector3) -> Vector3:
	if _hips == null:
		return point
	var top: Node3D = _chest if _chest else _spine
	var axis := top.global_position - _hips.global_position
	var height := axis.length()
	if height < 0.001:
		return point
	axis /= height
	var left := global_basis.x.normalized()
	left = (left - axis * left.dot(axis)).normalized()
	var front := axis.cross(left)
	if front.dot(global_basis.z) < 0.0:
		front = -front
	var broad: float = BROAD.get(look.get("body", "round"), 1.12)
	var across := (0.168 * broad + 0.05) * global_basis.x.length()
	var deep := 0.185 * global_basis.z.length()
	var centre := _hips.global_position + front * 0.02 * global_basis.z.length()
	var p := point - centre
	var along := p.dot(axis)
	if along < -0.05 * height or along > height * 1.15:
		return point
	var rx := p.dot(left)
	var rz := p.dot(front)
	var inside := (rx / across) * (rx / across) + (rz / deep) * (rz / deep)
	if inside >= 1.0 or inside < 0.000001:
		return point
	var out := 1.0 / sqrt(inside)
	return centre + axis * along + left * rx * out + front * rz * out


# --- Looking at things ---

## Every few seconds something new to look at; the eyes go straight to it, the head and neck
## follow more slowly (and only so far), as anyone's do.
func _gaze(delta: float) -> void:
	_look_next -= delta
	if _look_next <= 0.0 and not look_around.is_empty():
		_look_next = _rng.randf_range(1.2, 4.5)
		var lead: Variant = look_lead.call() if look_lead.is_valid() else null
		if lead is Node3D and lead != get_parent() and _rng.randf() < 0.55:
			_look_target = lead
		else:
			_look_target = look_around[_rng.randi() % look_around.size()]
			if _look_target == get_parent():
				_look_target = null
	var want := Vector2.ZERO
	if is_instance_valid(_look_target):
		var at := _look_target.global_position
		if _look_target is Frog:
			at += Vector3.UP * (_look_target as Frog).size * 1.05
		var local := global_basis.orthonormalized().inverse() * (at - _head.global_position)
		var flat := Vector2(local.x, local.z).length()
		want = Vector2(atan2(local.x, local.z), atan2(local.y, flat))
	# (it cannot look behind itself: past this, it only rolls its eyes that way)
	want.x = clampf(want.x, -1.6, 1.6)
	want.y = clampf(want.y, -0.6, 0.6)
	_gaze_eyes = _gaze_eyes.lerp(want, 1.0 - exp(-22.0 * delta))
	# (a frog has hardly any neck: the head turns less, the eyes do more of the looking, and the
	# turn is shared down through the chest, so no one joint wrings the skin)
	_gaze_head = _gaze_head.lerp(Vector2(clampf(want.x, -0.75, 0.75), clampf(want.y, -0.3, 0.3)), 1.0 - exp(-3.5 * delta))
	var turn := _gaze_head * (1.0 - _emote_amount * 0.6)
	if _chest:
		_chest.rotate_object_local(Vector3.UP, turn.x * 0.3)
		_chest.rotate_object_local(Vector3.RIGHT, -turn.y * 0.2)
	if _neck:
		_neck.rotate_object_local(Vector3.UP, turn.x * 0.35)
		_neck.rotate_object_local(Vector3.RIGHT, -turn.y * 0.35)
	_head.rotate_object_local(Vector3.UP, turn.x * 0.35)
	_head.rotate_object_local(Vector3.RIGHT, -turn.y * 0.45)


# --- The face ---

func _face_pose(delta: float) -> void:
	var want: Dictionary = EXPRESSIONS.get(expression, {}).duplicate()
	# Singing: the jaw and the mouth's shapes follow the voice in the song
	var singing := sings * (1.0 if Groove.playing else 0.0) * (1.0 - _emote_amount)
	if singing > 0.0:
		var voice := Groove.voice
		var vowel := Groove.vowel
		want["jaw"] = lerpf(want.get("jaw", 0.0), voice * (0.35 + 0.35 * (1.0 - absf(vowel))) + 0.05, singing)
		want["round"] = lerpf(want.get("round", 0.0), clampf(-vowel, 0.0, 1.0) * voice * 1.4, singing)
		want["wide"] = lerpf(want.get("wide", 0.0), clampf(vowel, 0.0, 1.0) * voice * 1.2 + 0.2, singing)
		want["lid_l"] = want.get("lid_l", 0.0) + 0.3 * voice * singing
		want["lid_r"] = want.get("lid_r", 0.0) + 0.3 * voice * singing
	# A blower's mouth stays shut on the mouthpiece; its throat puffs instead
	var blowing := part in ["tuba", "trumpet", "clarinet"]
	if blowing:
		want["jaw"] = 0.0
		want["round"] = 0.6
		want["wide"] = 0.0
	if expression == "laugh":
		want["jaw"] = want.get("jaw", 0.0) * (0.6 + 0.4 * absf(sin(_time * 13.0)))
	for key: String in ["jaw", "wide", "round", "frown", "lid_l", "lid_r", "brow_l", "brow_r", "tongue", "tilt", "back"]:
		var rate := 18.0 if key == "jaw" or key == "round" or key == "wide" else 9.0
		_face[key] = _approach(_face.get(key, 0.0), want.get(key, 0.0), rate, delta)
	# Blinks: down fast and up a little slower, now and then
	_blink_in -= delta
	if _blink_in <= 0.0:
		blink()
		_blink_in = _rng.randf_range(blink_every.x, blink_every.y)
	for k in 2:
		_blinks[k] += delta
	# The eyes, drawn: each lid down as far as its droop and the face say (or shut in a blink), tipped
	# for anger or worry, the lower lid up in a smile, the pupils where the rig has the eyes looking
	for k in 2:
		var eye := _eye_materials[k]
		if eye == null:
			continue
		var side := 1.0 if k == 0 else -1.0
		var lid: float = _face["lid_l" if k == 0 else "lid_r"]
		var down := clampf(0.04 + droop * 0.4 + lid * (0.55 if lid > 0.0 else 0.25), 0.0, 1.0)
		var into := _blinks[k] / maxf(blink_time, 0.02)
		var shut := sin(into * PI) if into > 0.0 and into < 1.0 else 0.0
		eye.set_shader_parameter(&"lid", lerpf(down, 1.0, shut))
		# (the inner end of the lid goes down in anger, up in worry: the inner end is towards the middle)
		eye.set_shader_parameter(&"lid_tilt", _face["brow_l" if k == 0 else "brow_r"] * side * 0.6)
		eye.set_shader_parameter(&"lower", clampf(_face.wide * 0.25 + maxf(lid, 0.0) * 0.2, 0.0, 0.6))
		# (the pupils show what the head has not yet turned to: the eyes lead)
		var ahead := _gaze_eyes - _gaze_head * (1.0 - _emote_amount * 0.6)
		eye.set_shader_parameter(&"pupil", Vector2(clampf(ahead.x * 1.6 - side * 0.12, -1.0, 1.0), clampf(ahead.y * 1.8 - 0.05, -1.0, 1.0)))
	for skin in _skin_materials:
		skin.set_shader_parameter(&"open", _face.jaw)
		# (and the drawn line hooks up at its corners in a smile, down in a frown)
		skin.set_shader_parameter(&"smile", _face.wide - _face.frown)
	if _jaw:
		_jaw.rotation.x = _face.jaw * JAW_WIDE
		_jaw.position = _jaw_rest + JAW_SLIDE * sin(_jaw.rotation.x)
		var throat := 0.0
		if blowing:
			throat = Groove.level_of(part) * 0.7 + _hit * 0.5
		_throat = _approach(_throat, throat, 10.0 if throat > _throat else 4.0, delta)
		var swell := 1.0 + 0.16 * _throat + 0.012 * sin(_breath)
		_jaw.scale = Vector3(swell, 1.0 + 0.08 * _throat, swell)
	for shape: Array in _shapes:
		var mesh: MeshInstance3D = shape[0]
		mesh.set_blend_shape_value(shape[1], _face.wide)
		mesh.set_blend_shape_value(shape[2], _face.round)
		mesh.set_blend_shape_value(shape[3], _face.frown)
		# (the upper lip arching as the jaw drops)
		if shape[4] >= 0:
			mesh.set_blend_shape_value(shape[4], _face.jaw)
	_head.rotate_object_local(Vector3.RIGHT, -_face.back)
	_head.rotate_object_local(Vector3.FORWARD, _face.tilt)
	_tongue_pose()


## The tongue: folded away inside the mouth, or thrown out and flailing like a streamer.
func _tongue_pose() -> void:
	if _tongue.is_empty():
		return
	var out: float = _face.tongue
	# (in the mouth it lies along the floor of it, drawn up short; or it is hidden away)
	var resting := Vector3(1.25, 0.9, 0.45) if tongue_in_mouth else Vector3.ONE * 0.04
	_tongue[0].scale = resting.lerp(Vector3.ONE, out)
	# (out and down from the mouth, then waves running down it to the tip, up and down and side to
	# side, bigger towards the tip, as a ribbon flaps)
	_tongue[0].rotation = Vector3(-0.22 * (1.0 - out) - 0.45 * out + sin(_time * 6.0) * 0.12 * out, sin(_time * 3.7) * 0.25 * out, 0.0)
	var joints := _tongue.size()
	for k in range(1, joints):
		var share := float(k) / joints
		var phase := _time * 10.0 - k * 1.1
		_tongue[k].rotation = Vector3(-0.12 * out + sin(phase) * (0.18 + 0.32 * share) * out,
				sin(phase * 0.6 + 1.3) * (0.1 + 0.25 * share) * out, sin(phase * 0.6) * 0.15 * share * out)


# --- Footing: where the feet are, and the legs solved to keep them there ---

## Each foot where the rig put it, in the rig's space, before the hips are moved.
func _footing() -> Array[Transform3D]:
	var feet: Array[Transform3D] = []
	for i in 2:
		feet.append(_hips.transform * _feet[i].transform)
	return feet


## Feet planted square under it, a little apart and turned out: where dances start from.
func _stance(apart := 1.3) -> Array[Transform3D]:
	var feet: Array[Transform3D] = []
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		feet.append(Transform3D(Basis(Vector3.UP, side * 0.22), Vector3(side * _hip_width * apart, ANKLE, 0.0)))
	return feet


## The legs solved again so the feet are where `feet` says, the hips wherever they are now.
func _replant(feet: Array[Transform3D], splay: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_solve_leg(i, side, to_hips * feet[i].origin, (to_hips.basis * feet[i].basis).orthonormalized(), side * splay)


## A foot moved from where it was: up, forward, out, and its toes turned up (+) or pointed (-).
static func _moved(foot: Transform3D, side: float, up: float, forward: float, out: float, toes := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -toes) * foot.basis, foot.origin + Vector3(side * out, up, forward))


# --- Playing ---

## A musician's body in the music: down on the beat in an easy bounce, swaying over two beats,
## leaning back when it is loud and forward into a solo.
func _play_body(amount: float) -> void:
	var b := Groove.beat
	var g := 0.35 + _groove
	var bounce := (0.5 - 0.5 * cos(TAU * b)) * _dancing
	var sway := sin(PI * b) * _dancing
	_hips.position += Vector3(sway * 0.025 * g, -bounce * (0.018 + 0.03 * _feature) * g, 0.03 * _feature) * amount
	_hips.rotate_object_local(Vector3.FORWARD, sway * 0.06 * g * amount)
	_spine.rotate_object_local(Vector3.RIGHT, (0.12 * _feature - 0.08 * smoothstep(0.6, 1.0, _groove) * (1.0 - _feature)) * amount)
	if _chest:
		_chest.rotate_object_local(Vector3.FORWARD, -sway * 0.08 * g * amount)
		_chest.rotate_object_local(Vector3.UP, sin(PI * b * 0.5) * 0.06 * g * amount)
	_head.rotate_object_local(Vector3.RIGHT, (bounce - 0.5) * 0.1 * g * amount)


## Tapping a foot: the toes come up between the beats and slap down on them (the right foot, or
## both in turn for a lively one).
func _tapping(feet: Array[Transform3D]) -> Array[Transform3D]:
	var b := Groove.beat
	var into := fposmod(b, 1.0)
	var lift := sin(clampf((into - 0.35) / 0.65, 0.0, 1.0) * PI) * _dancing * (0.5 + 0.5 * _groove)
	var which := 1 if _groove < 0.6 else posmod(int(floorf(b)), 2)
	var tapped: Array[Transform3D] = feet.duplicate()
	tapped[which] = _moved(feet[which], 1.0 if which == 0 else -1.0, 0.012 * lift, 0.0, 0.0, 0.5 * lift)
	return tapped


func _play(delta: float) -> void:
	var grip_l: Vector3 = instrument.grips.l.global_position
	var grip_r: Vector3 = instrument.grips.r.global_position
	var to_world := global_basis.orthonormalized()
	var pole_l: Vector3 = (to_world * (instrument.poles.l as Vector3)).normalized()
	var pole_r: Vector3 = (to_world * (instrument.poles.r as Vector3)).normalized()
	var size := global_basis.get_scale().y
	var jab := _hit
	match part:
		"tuba", "trumpet", "clarinet":
			# Fingers press on the notes; the bell lifts as it plays out
			var lift := 0.16 * _feature + 0.08 * Groove.level_of(part) + 0.06 * jab
			if instrument.anchor == &"head":
				_head.rotate_object_local(Vector3.RIGHT, -lift)
			else:
				_spine.rotate_object_local(Vector3.RIGHT, -lift * 0.5)
			_curl[0] = 1.1
			_curl[1] = lerpf(0.5, 1.2, jab)
			grip_r += global_basis.y.normalized() * (-0.012 * jab * size)
		"accordion":
			# The bellows breathe: drawn out across a bar and pushed in across the next, squeezed on each note
			var breath := 0.5 - 0.5 * cos(Groove.bar_phase() * TAU) if Groove.playing else 0.3
			var spread := 0.03 + 0.09 * breath * (0.4 + _groove) - 0.02 * jab
			var bellows: Node3D = instrument.parts.bellows
			bellows.scale.x = 1.0 + spread / 0.1
			instrument.parts.end_l.position.x = 0.125 + spread * 0.5
			instrument.parts.end_r.position.x = -0.125 - spread * 0.5
			grip_l += global_basis.x.normalized() * spread * 0.5 * size
			grip_r -= global_basis.x.normalized() * spread * 0.5 * size
			_curl[0] = 0.9
			_curl[1] = lerpf(0.4, 1.0, jab)
			if _chest:
				_chest.rotate_object_local(Vector3.FORWARD, (breath - 0.5) * 0.12)
		"banjo":
			# The right hand strums down across the strings with each note, and comes back up
			var strum := 0.06 * (1.0 - exp(-_hit_time * 18.0)) - 0.03
			grip_r += global_basis.y.normalized() * (-strum * 2.0 * size) * (1.0 if _hit > 0.05 else 0.3)
			_curl[0] = 1.2
			_curl[1] = 0.8
		"fiddle":
			# The bow is drawn one way for one note and back for the next, across the strings
			var across: Vector3 = instrument.parts.across
			var contact: Vector3 = instrument.parts.contact
			var target := 0.82 if _bow_way > 0.0 else 0.18
			_bow_at = _approach(_bow_at, target, 3.0 + 6.0 * _hit, delta)
			var bow: Node3D = instrument.parts.bow
			var hand_local := contact - across * lerpf(0.06, 0.34, _bow_at) + Vector3(0.0, 0.035, 0.0)
			grip_r = instrument.to_global(hand_local)
			bow.position = hand_local + Vector3(0.0, -0.01, 0.0)
			bow.basis = Basis.looking_at(across, Vector3.UP, true)
			_curl[0] = lerpf(0.9, 1.3, jab)
			_curl[1] = 1.0
			if _chest:
				_chest.rotate_object_local(Vector3.UP, (_bow_at - 0.5) * 0.25)
			_head.rotate_object_local(Vector3.FORWARD, 0.2)
		"drums":
			_drum_hands()
			return
		"helm":
			# Steering: the wheel worked a little one way and back as the river bends
			var wheel: Node3D = instrument.parts.wheel
			wheel.rotation.z = sin(_time * 0.35) * 0.35 + sin(_time * 0.11 + 1.0) * 0.25
			_curl[0] = 1.2
			_curl[1] = 1.2
	_solve_arm(0, 1.0, grip_l, _forearm + 0.05, 1.0, pole_l)
	_solve_arm(1, -1.0, grip_r, _forearm + 0.05, 1.0, pole_r)
	_pose_fingers(0, 1.0)
	_pose_fingers(1, -1.0)


func _drum_hands() -> void:
	var size := global_basis.get_scale().y
	var targets: Array[Vector3] = [instrument.to_global(instrument.parts.cymbal_top), instrument.to_global(instrument.parts.snare)]
	var to_world := global_basis.orthonormalized()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var t: float = _stick_down[i]
		# Down onto the drum in a flash, then back up slower (and higher the louder)
		var up := smoothstep(0.0, 0.25, t - 0.05) if t > 0.05 else 1.0 - t / 0.05
		up *= 0.6 + 0.6 * _groove
		var aim := (to_world * Vector3(0.0, -0.35 - 0.5 * (1.0 - minf(up, 1.0)), 1.0)).normalized()
		var tip := targets[i] + to_world * Vector3(0.0, 0.12 * up + 0.01, -0.02 * up) * size
		var hand := tip - aim * 0.27 * size
		_solve_arm(i, side, hand, _forearm + 0.05, 1.0, (to_world * Vector3(side, -0.7, -0.5)).normalized())
		_curl[i] = 1.3
		_pose_fingers(i, side)
		var stick: Node3D = instrument.parts["stick_" + ("l" if i == 0 else "r")]
		var palm := _hands[i].global_transform * Vector3(0.0, -0.045, 0.0)
		stick.global_transform = Transform3D(Basis.looking_at(aim, Vector3.UP, true).scaled(Vector3.ONE * size), palm - aim * 0.04 * size)
	var bass: Node3D = instrument.parts.bass
	bass.scale = Vector3(1.0, 1.0, 1.0 + 0.06 * Groove.level_of("kick"))
	var cymbal: Node3D = instrument.parts.cymbal
	var ring := exp(-_stick_down[0] * 4.0)
	cymbal.rotation = Vector3(sin(_time * 30.0) * 0.12 * ring, 0.0, 0.15 * ring)


# --- Conducting and singing ---

## Where the baton's tip is in each beat of the bar (in his own space, about his hips: left +X), for 4 and 3.
const PATTERN_4 := [Vector3(0.0, 0.15, 0.30), Vector3(0.12, 0.23, 0.28), Vector3(-0.24, 0.23, 0.26), Vector3(-0.06, 0.43, 0.26)]
const PATTERN_3 := [Vector3(0.0, 0.15, 0.30), Vector3(-0.24, 0.23, 0.26), Vector3(-0.06, 0.43, 0.26)]


func _conduct(delta: float) -> void:
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
	var tip: Vector3 = from.lerp(to, eased) + Vector3(0.0, 0.06 * sin(into * PI) * (0.5 + _groove), 0.0)
	var amp := 0.8 + 0.6 * _groove
	tip = Vector3(tip.x * amp, _hip_height + 0.29 + (tip.y - 0.29) * amp, tip.z)
	_solve_arm(1, -1.0, to_global(tip), _forearm + 0.05, 1.0, (global_basis.orthonormalized() * Vector3(-1.0, -0.4, -0.3)).normalized())
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
	var rest := to_global(Vector3(0.12, _hip_height + 0.2, 0.2))
	var left := rest.lerp(global_position.lerp(_cue_at, 0.32), smoothstep(0.0, 0.3, _cue)) if _cue > 0.0 else rest
	_solve_arm(0, 1.0, left + Vector3.UP * 0.06 * _groove * size, _forearm + 0.05, 0.85, Vector3.ZERO)
	_curl[0] = 0.3
	_splay[0] = 0.6
	_pose_fingers(0, 1.0)
	_spine.rotate_object_local(Vector3.RIGHT, 0.1 * _groove)


## The singer: swaying with the song, a hand to its chest, the other out on the long notes, and
## both out wide when it lets go.
func _sing_body() -> void:
	var b := Groove.beat
	var g := 0.4 + _groove
	var sway := sin(PI * b * 0.5) * _dancing
	_hips.position += Vector3(sway * 0.04 * g, -(0.5 - 0.5 * cos(TAU * b)) * 0.02 * g * _dancing, 0.0)
	_hips.rotate_object_local(Vector3.FORWARD, sway * 0.07 * g)
	if _chest:
		_chest.rotate_object_local(Vector3.FORWARD, -sway * 0.1 * g)
	var voice := Groove.voice if Groove.playing else 0.0
	_spine.rotate_object_local(Vector3.RIGHT, -0.12 * voice)
	_replant(_stance(1.5), 0.15)
	var size := global_basis.get_scale().y
	var reach := smoothstep(0.3, 0.8, voice) * _dancing
	# (the left hand on his heart, on its own side; the right low at his side, opening out wide
	# as he sings out)
	var chest := to_global(Vector3(0.07, _hip_height + 0.27, 0.2))
	var low := to_global(Vector3(-0.24, _hip_height + 0.12, 0.16))
	var out := to_global(Vector3(-0.42, _hip_height + 0.33 + 0.12 * voice, 0.28))
	_solve_arm(0, 1.0, chest, _forearm + 0.03, 1.0, Vector3.ZERO)
	_curl[0] = 0.4
	_pose_fingers(0, 1.0)
	_solve_arm(1, -1.0, low.lerp(out, reach), _forearm + 0.03, 0.9, Vector3.ZERO)
	_curl[1] = lerpf(0.6, 0.15, reach)
	_splay[1] = lerpf(0.3, 0.8, reach)
	_pose_fingers(1, -1.0)
	if _emote == "":
		expression = "bliss" if voice > 0.75 else "smile"


# --- Dancing ---

## A dance is a figure of steps going round with the beat: smooth curves of it (sin, cos and
## eased steps), so it never jumps. `g` is how big it is (with the music's loudness).
func _dance() -> void:
	var on := _dancing * _still
	var size := global_basis.get_scale().y
	var b := (Groove.beat if Groove.playing else _time * 0.5) + lag
	var g := (0.55 + 0.6 * _groove) * on
	var left := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	var forward := global_basis.z.normalized()
	var feet := _stance()
	var hips := Vector3.ZERO
	var turn := Vector3.ZERO          # the hips: pitch, yaw, roll
	var bend := Vector3.ZERO          # the spine and chest together: pitch, yaw, roll
	var nod := Vector3.ZERO           # the head
	var hands: Array = [null, null]   # rig-space targets for the hands, or null to let them hang
	var bounce := 0.5 - 0.5 * cos(TAU * b)  # 0 on the beat, 1 between: down on the beat
	var half := sin(PI * b)                  # one way over a beat, back over the next
	match dance:
		"watch":
			hips = Vector3(half * 0.02, -0.01 * bounce, 0.0) * g
			nod = Vector3(0.06 * (bounce - 0.5), 0.0, half * 0.05) * g
		"bounce":
			# Down at the knees on every beat, hips swinging round, elbows pumping
			hips = Vector3(half * 0.03, -0.07 * (1.0 - bounce), 0.0) * g
			turn = Vector3(0.0, half * 0.35, half * 0.08) * g
			bend = Vector3(0.12 * (1.0 - bounce), -half * 0.25, 0.0) * g
			nod = Vector3(0.18 * (1.0 - bounce) - 0.05, 0.0, -half * 0.1) * g
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var pump := sin(PI * b + (0.0 if i == 0 else PI))
				hands[i] = Vector3(side * 0.2, _hip_height + 0.12 + 0.06 * pump, 0.12 + 0.1 * pump)
		"two_step":
			# A step out to the side and the other foot brought to it, then back the other way
			var bar := fposmod(b, 4.0)
			var out := (smoothstep(0.0, 0.5, bar) - smoothstep(2.0, 2.5, bar)) * 2.0 - 1.0
			var lift_l := maxf(0.0, sin(clampf(bar / 0.5, 0.0, 1.0) * PI)) + maxf(0.0, sin(clampf((bar - 3.0) / 0.5, 0.0, 1.0) * PI))
			var lift_r := maxf(0.0, sin(clampf((bar - 1.0) / 0.5, 0.0, 1.0) * PI)) + maxf(0.0, sin(clampf((bar - 2.0) / 0.5, 0.0, 1.0) * PI))
			var shift := out * 0.13 * g
			feet[0] = _moved(feet[0], 1.0, 0.07 * lift_l * g, 0.0, shift)
			feet[1] = _moved(feet[1], -1.0, 0.07 * lift_r * g, 0.0, -shift)
			hips = Vector3(shift, -0.05 * (1.0 - bounce) * g, 0.0)
			turn = Vector3(0.0, 0.0, -out * 0.1 * g)
			bend = Vector3(0.05, 0.0, out * 0.12 * g)
			nod = Vector3(0.1 * (1.0 - bounce) * g, out * 0.2 * g, 0.0)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = Vector3(side * 0.24 + out * 0.08, _hip_height + 0.18, 0.18)
		"charleston":
			# Toes in, heels out, and back; a kick forward then back, arms swinging opposite
			var swivel := sin(PI * b * 2.0)
			var kick := sin(PI * fposmod(b, 4.0) / 2.0)
			var which := 0 if fposmod(b, 4.0) < 2.0 else 1
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var foot := Transform3D(Basis(Vector3.UP, side * (0.22 + 0.5 * swivel * g)), feet[i].origin)
				if i == which:
					foot = _moved(foot, side, 0.1 * maxf(kick, 0.0) * g, (0.16 if which == 0 else -0.14) * absf(kick) * g, 0.0, (0.4 if which == 0 else -0.6) * absf(kick) * g)
				feet[i] = foot
			hips = Vector3(0.0, -0.06 * absf(swivel) * g, -0.03 * absf(kick) * g)
			bend = Vector3(0.18 * g, 0.0, 0.0)
			nod = Vector3(-0.1 * g, swivel * 0.2 * g, 0.0)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var swing := sin(PI * b * 2.0 + (0.0 if i == 0 else PI))
				hands[i] = Vector3(side * (0.18 + 0.12 * absf(swing)), _hip_height + 0.1 + 0.1 * swing, 0.15 + 0.12 * swing)
		"sway":
			# Side to side over the bar, arms loose and swinging
			var lean := sin(PI * b * 2.0 / maxf(Groove.meter, 2))
			hips = Vector3(lean * 0.06, -0.02 * bounce, 0.0) * g
			turn = Vector3(0.0, 0.0, lean * 0.12 * g)
			bend = Vector3(0.0, 0.0, -lean * 0.2 * g)
			nod = Vector3(0.0, 0.0, -lean * 0.15 * g)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var swing := sin(PI * b + (0.0 if i == 0 else PI)) * (0.4 + g)
				hands[i] = Vector3(side * 0.22 - lean * 0.06, _hip_height - 0.06 + 0.06 * absf(swing), 0.12 * swing)
		"wave":
			# Arms up over its head, swept from side to side together, the body going with them
			var sweep := sin(PI * b * 0.5)
			hips = Vector3(sweep * 0.05, -0.04 * (1.0 - bounce), 0.0) * g
			turn = Vector3(0.0, 0.0, sweep * 0.1 * g)
			bend = Vector3(-0.1 * g, 0.0, -sweep * 0.18 * g)
			nod = Vector3(-0.18 * g, 0.0, -sweep * 0.12 * g)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = Vector3(side * 0.16 + sweep * 0.22, _hip_height + 0.62 + 0.04 * bounce, 0.08)
		"jig":
			# Hands on hips, elbows out; hopping, kicking up a heel (one, then the other)
			var which := posmod(int(floorf(b)), 2)
			var into := fposmod(b, 1.0)
			var kick := sin(clampf(into * 1.3, 0.0, 1.0) * PI)
			var hop := sin(into * PI)
			feet[which] = _moved(feet[which], 1.0 if which == 0 else -1.0, 0.12 * kick * g, 0.06 * kick * g, 0.02, 0.6 * kick * g)
			hips = Vector3((0.03 if which == 0 else -0.03) * g, -0.06 + 0.04 * hop * g, 0.0)
			turn = Vector3(0.0, (0.15 if which == 0 else -0.15) * g, 0.0)
			bend = Vector3(-0.05, 0.0, (0.1 if which == 0 else -0.1) * g)
			nod = Vector3(0.1 * hop * g, 0.0, (-0.12 if which == 0 else 0.12) * g)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = Vector3(side * 0.2, _hip_height + 0.05, 0.02)
		"shimmy":
			# Shoulders shaking twice to the beat, knees bent, hands up and out
			var shake := sin(TAU * b * 2.0)
			hips = Vector3(0.0, -0.08 * g, 0.0)
			bend = Vector3(0.1 * g, shake * 0.22 * g, 0.0)
			nod = Vector3(0.0, -shake * 0.15 * g, half * 0.12 * g)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = Vector3(side * 0.34, _hip_height + 0.38, 0.12 + shake * side * 0.04)
		"strut":
			# Marching on the spot: knees up high in turn, arms swinging, chin up
			var step := sin(PI * b)
			var lift_l := maxf(0.0, step)
			var lift_r := maxf(0.0, -step)
			feet[0] = _moved(feet[0], 1.0, 0.16 * lift_l * g, 0.08 * lift_l * g, 0.0, -0.3 * lift_l * g)
			feet[1] = _moved(feet[1], -1.0, 0.16 * lift_r * g, 0.08 * lift_r * g, 0.0, -0.3 * lift_r * g)
			hips = Vector3(step * 0.025, -0.02 * absf(step), 0.0) * g
			turn = Vector3(0.0, step * 0.15 * g, 0.0)
			bend = Vector3(-0.1 * g, -step * 0.2 * g, 0.0)
			nod = Vector3(-0.12, 0.0, 0.0)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var swing := step * (-1.0 if i == 0 else 1.0)
				hands[i] = Vector3(side * 0.2, _hip_height + 0.02 + 0.12 * maxf(swing, 0.0), 0.22 * swing)
		"clap":
			# Bouncing, clapping on the off-beats (every beat when it is going well)
			hips = Vector3(half * 0.02, -0.05 * (1.0 - bounce), 0.0) * g
			nod = Vector3(0.12 * (1.0 - bounce) * g, 0.0, half * 0.08 * g)
			var every := 1.0 if _groove > 0.6 else 2.0
			var into := fposmod(b - (1.0 if every > 1.5 else 0.0), every) / every
			var gap := 0.015 + 0.14 * sin(clampf(into * 1.15, 0.0, 1.0) * PI)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = Vector3(side * gap, _hip_height + 0.24 + 0.1 * _groove, 0.26)
		"partner":
			hips = Vector3(half * 0.03, -0.03 * (1.0 - bounce), 0.0) * g
			turn = Vector3(0.0, 0.0, half * 0.06 * g)
			nod = Vector3(0.0, 0.0, half * 0.1 * g)
	_hips.position = _hips.position.lerp(Vector3(0.0, _hip_height, 0.0) + hips, on)
	_hips.basis = _hips.basis.slerp(Basis.from_euler(turn), on)
	for joint: Node3D in ([_spine, _chest] if _chest else [_spine]):
		joint.rotate_object_local(Vector3.RIGHT, bend.x * 0.5)
		joint.rotate_object_local(Vector3.UP, bend.y * 0.5)
		joint.rotate_object_local(Vector3.FORWARD, bend.z * 0.5)
	_head.rotate_object_local(Vector3.RIGHT, nod.x)
	_head.rotate_object_local(Vector3.UP, nod.y)
	_head.rotate_object_local(Vector3.FORWARD, nod.z)
	var planted := _footing()
	for i in 2:
		feet[i] = planted[i].interpolate_with(feet[i], on)
	_replant(feet, 0.25)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		if hands[i] != null:
			var target: Vector3 = hands[i]
			_solve_arm(i, side, to_global(target), _forearm + 0.03, on, (left * side + Vector3.DOWN * 0.6 - forward * 0.3).normalized())
			_curl[i] = 0.6
			_pose_fingers(i, side)
	if dance == "partner" and is_instance_valid(partner) and partner._shoulders.size() > 1:
		# A closed hold, as in a waltz: the lead's left hand and the other's right joined out to
		# the lead's left at shoulder height; the lead's right hand on the other's shoulder blade,
		# the other's left on the lead's shoulder. (Which leads: the first made.)
		var leads := get_instance_id() < partner.get_instance_id()
		var mine := global_position
		var theirs := partner.global_position
		var shoulder_height := (_shoulders[0].global_position.y + _shoulders[1].global_position.y) * 0.5
		var toward := theirs - mine
		toward.y = 0.0
		toward = toward.normalized()
		var lead_left := toward.cross(up).normalized() * -1.0
		if not leads:
			lead_left = -lead_left
		var joined := (mine + theirs) * 0.5 + lead_left * 0.34 * size
		joined.y = shoulder_height + 0.02 * size
		var far_side: Vector3 = partner.global_basis.z.normalized()
		if leads:
			_solve_arm(0, 1.0, joined, _forearm, 1.0, (left * 0.5 + Vector3.DOWN).normalized())
			var blade: Vector3 = partner._shoulders[0].global_position - far_side * 0.08 * size + Vector3.DOWN * 0.05 * size
			_solve_arm(1, -1.0, blade, _forearm, 1.0, (-left + Vector3.DOWN).normalized())
			_curl[1] = 0.3
		else:
			_solve_arm(1, -1.0, joined, _forearm, 1.0, (-left * 0.5 + Vector3.DOWN).normalized())
			var top: Vector3 = partner._shoulders[1].global_position + Vector3.UP * 0.03 * size - toward * 0.03 * size
			_solve_arm(0, 1.0, top, _forearm, 1.0, (left + Vector3.DOWN).normalized())
			_curl[0] = 0.5
		_curl[0 if leads else 1] = 0.9
		_pose_fingers(0, 1.0)
		_pose_fingers(1, -1.0)


# --- Emotes, over everything else ---

func _emote_pose() -> void:
	var w := smoothstep(0.0, 1.0, _emote_amount)
	var t := _emote_time
	var size := global_basis.get_scale().y
	var left := global_basis.x.normalized()
	var forward := global_basis.z.normalized()
	var hands: Array = [null, null]
	match _emote:
		"bow":
			# Down from the waist, the right hand lifting the hat high, the left sweeping out
			var down := smoothstep(0.0, 0.6, t) * (1.0 - smoothstep(_emote_length - 0.8, _emote_length, t))
			_spine.rotate_object_local(Vector3.RIGHT, 0.5 * down * w)
			if _chest:
				_chest.rotate_object_local(Vector3.RIGHT, 0.3 * down * w)
			_head.rotate_object_local(Vector3.RIGHT, -0.2 * down * w)
			var hat := _head.global_transform * Vector3(0.0, 0.2, 0.0)
			hands[1] = hat.lerp(_head.global_transform * Vector3(-0.15, 0.45, 0.15), down)
			hands[0] = to_global(Vector3(0.38, _hip_height + 0.05, 0.25 * down))
		"coy":
			# Hands clasped under the chin, head tipped, a little twist side to side
			_hips.rotate_object_local(Vector3.UP, sin(t * 2.5) * 0.12 * w)
			_head.rotate_object_local(Vector3.FORWARD, 0.2 * w)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = to_global(Vector3(side * 0.03, _hip_height + 0.3, 0.2))
		"laugh":
			# Doubled up and back again, a hand on its belly, shoulders shaking
			var shake := sin(t * 14.0)
			_spine.rotate_object_local(Vector3.RIGHT, (0.15 + 0.06 * shake) * w)
			if _chest:
				_chest.rotate_object_local(Vector3.RIGHT, -0.25 * w)
			hands[0] = to_global(Vector3(0.05, _hip_height + 0.1, 0.2))
			hands[1] = to_global(Vector3(-0.3, _hip_height + 0.05 + 0.03 * shake, 0.12))
		"shock":
			# Back on its heels, both hands flung up beside its face
			_spine.rotate_object_local(Vector3.RIGHT, -0.15 * w)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = _head.global_transform * Vector3(side * 0.2, 0.0, 0.12)
		"panic":
			# Arms thrown up and waving wildly, head back, tongue out, hopping from foot to foot
			_spine.rotate_object_local(Vector3.RIGHT, -0.1 * w)
			_hips.position.y += 0.03 * absf(sin(t * 9.0)) * w
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var flail := sin(t * (10.0 + side * 1.5) + side)
				hands[i] = to_global(Vector3(side * (0.25 + 0.12 * flail), _hip_height + 0.62 + 0.1 * cos(t * 9.0 + side), 0.1 + 0.08 * flail))
		"cheer":
			# Both arms up, fists pumping
			var pump := absf(sin(t * 6.0))
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				hands[i] = to_global(Vector3(side * 0.22, _hip_height + 0.5 + 0.12 * pump, 0.1))
		"point":
			# Pointing to the bandstand, the other hand on its hip
			hands[1] = global_position + (forward * 0.42 + Vector3.UP * (_hip_height + 0.35)) * size - left * 0.12 * size
			hands[0] = to_global(Vector3(0.2, _hip_height + 0.05, 0.02))
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		if hands[i] != null:
			var target: Vector3 = hands[i]
			_solve_arm(i, side, target, _forearm + 0.03, w, Vector3.ZERO)
			_curl[i] = 1.3 if _emote == "cheer" else (0.2 if _emote == "point" and i == 1 else 0.5)
			_pose_fingers(i, side)
