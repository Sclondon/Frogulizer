class_name MoveClip
extends Resource
## A move captured from life (a dance), made over for the boy's skeleton by tools/import_bvh.gd, for
## CharacterRig to play on any figure on that skeleton (`rig.clip`, `rig.clip_time`, `rig.clip_weight`).
##
## It is not a pose of each bone, which would only fit a figure of the dancer's own build. It is what
## the rig needs to do the move its own way: where the hips are and how they are turned, how the back,
## neck, head and arms are turned (each bone in its own axes, as the skeleton has them, the bones'
## rest being unturned), and where each ankle and knee is and how each foot is turned. Distances are
## in "stands": the height of the dancer's hips above their ankles, standing. The rig scales them by
## its own figure's, and puts the legs where the feet go with its own leg solver, so a long-legged
## frog and the boy do the same steps each in their own way.
##
## Facing +Z, its left +X, as the boy does; the ground is at 0 (the ankles' height when planted is
## taken off: the rig adds its own, ANKLE). Kept at `fps` frames a second. The move goes round
## from `loop_from` to `loop_to` (seconds), a whole number of its beats (`beat` seconds each, the first
## at `first_beat`), so a song's beat can be laid on it.

## The bones whose turns are kept, each in its parent's axes (the hips' in the figure's).
const BONES := ["hips", "spine", "chest", "neck", "head", "upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r", "foot_l", "foot_r"]
## How long a loop's seam is blended over, seconds.
const SEAM := 0.3

@export var title := ""
## Where it came from, and what its maker asks to be said of it.
@export var credit := ""
@export var fps := 30.0
@export var frames := 0
@export var beat := 0.5
@export var first_beat := 0.0
@export var loop_from := 0.0
@export var loop_to := 0.0
## Where the hips are, in stands.
@export var hips := PackedVector3Array()
## Each bone of BONES: its turn each frame (x, y, z, w). The feet's are in the figure's axes.
@export var turns := {}
## Each ankle and knee, left then right, in stands.
@export var ankles: Array[PackedVector3Array] = []
@export var knees: Array[PackedVector3Array] = []


## The move `seconds` into it, going round its loop once past `loop_from`: {"hips": Vector3,
## "turns": {bone: Quaternion}, "ankles": [Vector3, Vector3], "knees": [Vector3, Vector3]}.
func sample(seconds: float) -> Dictionary:
	var length := loop_to - loop_from
	if length <= SEAM or seconds < loop_from:
		return _at(clampf(seconds, 0.0, _end()))
	var into := fposmod(seconds - loop_from, length)
	var pose := _at(loop_from + into)
	# (the end of the loop is blended into what comes before its start, so it comes round smoothly)
	var seam := minf(SEAM, loop_from)
	if seam > 0.0 and into > length - seam:
		var before := _at(loop_from + into - length)
		pose = _blend(pose, before, smoothstep(length - seam, length, into))
	return pose


func _end() -> float:
	return maxf(frames - 1, 0) / fps


func _at(seconds: float) -> Dictionary:
	var f := clampf(seconds * fps, 0.0, maxf(frames - 1, 0))
	var i := int(f)
	var j := mini(i + 1, frames - 1)
	var t := f - i
	var out := {"hips": hips[i].lerp(hips[j], t), "turns": {}, "ankles": [], "knees": []}
	for bone: String in turns:
		var track: PackedVector4Array = turns[bone]
		out.turns[bone] = _quat(track[i]).slerp(_quat(track[j]), t)
	for side in 2:
		out.ankles.append(ankles[side][i].lerp(ankles[side][j], t))
		out.knees.append(knees[side][i].lerp(knees[side][j], t))
	return out


static func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {"hips": (a.hips as Vector3).lerp(b.hips, t), "turns": {}, "ankles": [], "knees": []}
	for bone: String in a.turns:
		out.turns[bone] = (a.turns[bone] as Quaternion).slerp(b.turns[bone], t)
	for side in 2:
		out.ankles.append((a.ankles[side] as Vector3).lerp(b.ankles[side], t))
		out.knees.append((a.knees[side] as Vector3).lerp(b.knees[side], t))
	return out


static func _quat(v: Vector4) -> Quaternion:
	return Quaternion(v.x, v.y, v.z, v.w)
