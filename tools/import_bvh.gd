extends SceneTree
## Makes a move captured from life (a .bvh file on the CMU motion capture database's skeleton) into a
## MoveClip for the boy's rig (see scripts/move_clip.gd for what it keeps and why):
##   godot --headless --path . --script tools/import_bvh.gd -- <in.bvh> <out.res> "<title>" [from to] [fps]
## `from` and `to` (seconds) cut out the part to keep; `fps` is the rate it was captured at, when the
## file's own Frame Time is wrong (many CMU files say 120 and were taken at 30, or the other way).
##
## Each of the boy's bones is given the turn of the dancer's bone it stands for, as a turn away from
## where it rests (both skeletons rest unturned, arms out), less the difference between the way his
## bone lies and theirs. The dancer is turned to face +Z on the whole, kept on the spot (where they
## wander is taken off, slowly, so steps still go somewhere and come back), and measured in stands.
## The beat is found from the steps: the ankles and the hips going up and down repeat with it.

const FPS := 30.0
const CREDIT := "Carnegie Mellon University motion capture database, mocap.cs.cmu.edu (created with funding from NSF EIA-0196217)"
## The boy's bones (MoveClip.BONES), the dancer's joint each takes its turn from, and the joint that
## bone points to in each skeleton when they rest (to find how differently they lie).
const MAP := {
	"hips": ["Hips", "", Vector3.ZERO],
	"spine": ["LowerBack", "Spine", Vector3.UP],
	"chest": ["Spine1", "Neck1", Vector3.UP],
	"neck": ["Neck1", "Head", Vector3.UP],
	"head": ["Head", "", Vector3.ZERO],
	"upper_arm_l": ["LeftArm", "LeftForeArm", Vector3.RIGHT],
	"forearm_l": ["LeftForeArm", "LeftHand", Vector3.RIGHT],
	"hand_l": ["LeftHand", "", Vector3.ZERO],
	"upper_arm_r": ["RightArm", "RightForeArm", Vector3.LEFT],
	"forearm_r": ["RightForeArm", "RightHand", Vector3.LEFT],
	"hand_r": ["RightHand", "", Vector3.ZERO],
	"foot_l": ["LeftFoot", "LeftToeBase", Vector3(0.0, -0.035, 0.075)],
	"foot_r": ["RightFoot", "RightToeBase", Vector3(0.0, -0.035, 0.075)],
}
## Each bone's parent among those, for its turn in its parent's axes (the hips' and the feet's are the figure's).
const PARENT := {
	"spine": "hips", "chest": "spine", "neck": "chest", "head": "neck",
	"upper_arm_l": "chest", "forearm_l": "upper_arm_l", "hand_l": "forearm_l",
	"upper_arm_r": "chest", "forearm_r": "upper_arm_r", "hand_r": "forearm_r",
}
## How slowly the dancer's wandering is taken off (seconds either side).
const WANDER := 1.5

var names: Array[String] = []
var parents: PackedInt32Array = []
var offsets: Array[Vector3] = []
var channels: Array = []        # per joint: channel names
var first: PackedInt32Array = []  # per joint: its first channel's index in a frame
var data: Array[PackedFloat32Array] = []
var frame_time := 1.0 / 120.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: -- <in.bvh> <out.res> <title> [from to] [fps]")
		quit(1)
		return
	_read(args[0])
	if args.size() >= 6:
		frame_time = 1.0 / float(args[5])
	var from := float(args[3]) if args.size() >= 5 else 0.0
	var to := float(args[4]) if args.size() >= 5 else 1e9
	var clip := _make(from, to)
	clip.title = args[2]
	clip.credit = CREDIT + " (%s)" % args[0].get_file()
	var error := ResourceSaver.save(clip, args[1], ResourceSaver.FLAG_COMPRESS)
	print("%s %s: %d frames (%.1f s), beat %.3f s (%.0f bpm), loop %.2f to %.2f s (%d beats)%s" % [
		"WROTE" if error == OK else "COULD NOT WRITE", args[1], clip.frames, clip.frames / FPS, clip.beat, 60.0 / clip.beat,
		clip.loop_from, clip.loop_to, roundi((clip.loop_to - clip.loop_from) / clip.beat), _speed_note(clip)])
	quit()


func _read(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var tokens := Array(text.replace("\r", " ").replace("\n", " ").replace("\t", " ").split(" ", false))
	var at := 0
	var stack: Array[int] = []
	var count := 0
	var last := -1
	while at < tokens.size():
		var word: String = tokens[at]
		match word:
			"ROOT", "JOINT":
				names.append(tokens[at + 1])
				parents.append(stack[-1] if not stack.is_empty() else -1)
				offsets.append(Vector3.ZERO)
				channels.append([])
				first.append(count)
				last = names.size() - 1
				at += 2
			"End":
				# (an end site: a joint of no use here, its braces skipped)
				last = -2
				at += 2
			"{":
				stack.append(last)
				at += 1
			"}":
				stack.pop_back()
				at += 1
			"OFFSET":
				if last >= 0 and stack[-1] == last:
					offsets[last] = Vector3(float(tokens[at + 1]), float(tokens[at + 2]), float(tokens[at + 3]))
				at += 4
			"CHANNELS":
				var n := int(tokens[at + 1])
				for k in n:
					channels[last].append(tokens[at + 2 + k])
				count += n
				at += 2 + n
			"MOTION":
				var frames := int(tokens[at + 2])
				frame_time = float(tokens[at + 5])
				at += 6
				for f in frames:
					var row := PackedFloat32Array()
					row.resize(count)
					for k in count:
						row[k] = float(tokens[at + k])
					data.append(row)
					at += count
				break
			_:
				at += 1


## Every joint's place and turn in the world at source frame `f`: [positions, turns].
func _pose(f: int) -> Array:
	var row := data[clampi(f, 0, data.size() - 1)]
	var places: Array[Vector3] = []
	var turns: Array[Quaternion] = []
	for j in names.size():
		var local := Quaternion.IDENTITY
		var moved := offsets[j]
		var k := first[j]
		for channel: String in channels[j]:
			var v := row[k]
			k += 1
			match channel:
				"Xposition": moved.x += v
				"Yposition": moved.y += v
				"Zposition": moved.z += v
				"Xrotation": local *= Quaternion(Vector3.RIGHT, deg_to_rad(v))
				"Yrotation": local *= Quaternion(Vector3.UP, deg_to_rad(v))
				"Zrotation": local *= Quaternion(Vector3.BACK, deg_to_rad(v))
		var p := parents[j]
		if p < 0:
			places.append(moved)
			turns.append(local)
		else:
			places.append(places[p] + turns[p] * moved)
			turns.append(turns[p] * local)
	return [places, turns]


## Where a joint rests in the dancer's skeleton (from the hips).
func _rest(j: int) -> Vector3:
	var at := Vector3.ZERO
	while j >= 0:
		at += offsets[j]
		j = parents[j]
	return at


func _make(from: float, to: float) -> MoveClip:
	var source_fps := 1.0 / frame_time
	var start := clampf(from, 0.0, (data.size() - 1) / source_fps)
	var end := clampf(to, start, (data.size() - 1) / source_fps)
	var count := int((end - start) * FPS) + 1
	var j := {}
	for k in names.size():
		j[names[k]] = k
	# A stand: the height of the hips above the ankles, resting
	var stand := absf(_rest(j.LeftFoot).y - _rest(j.Hips).y)
	# How differently each of his bones lies from the dancer's, resting
	var align := {}
	for bone: String in MAP:
		var to_joint: String = MAP[bone][1]
		align[bone] = Quaternion.IDENTITY
		if to_joint != "":
			var theirs := (_rest(j[to_joint]) - _rest(j[MAP[bone][0]])).normalized()
			align[bone] = Quaternion((MAP[bone][2] as Vector3).normalized(), theirs)
	# Every frame, in the world
	var hips := PackedVector3Array()
	var globals := {}
	for bone: String in MAP:
		globals[bone] = []
	var ankles: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var knees: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	var lefts := PackedVector3Array()
	for f in count:
		var pose := _pose(roundi((start + f / FPS) * source_fps))
		var places: Array[Vector3] = pose[0]
		var turns: Array[Quaternion] = pose[1]
		hips.append(places[j.Hips])
		for bone: String in MAP:
			globals[bone].append(turns[j[MAP[bone][0]]] * align[bone])
		ankles[0].append(places[j.LeftFoot])
		ankles[1].append(places[j.RightFoot])
		knees[0].append(places[j.LeftLeg])
		knees[1].append(places[j.RightLeg])
		lefts.append(places[j.LeftUpLeg] - places[j.RightUpLeg])
	# Turned to face +Z on the whole
	var left := Vector3.ZERO
	for v in lefts:
		left += Vector3(v.x, 0.0, v.z).normalized()
	var facing := Quaternion(left.normalized(), Vector3.RIGHT) if left.normalized().dot(Vector3.RIGHT) > -0.999 else Quaternion(Vector3.UP, PI)
	# The ground: where the lower ankle is most of the time
	var low := PackedFloat32Array()
	for f in count:
		low.append(minf(ankles[0][f].y, ankles[1][f].y))
	var sorted := low.duplicate()
	sorted.sort()
	var ground := sorted[int(0.1 * (count - 1))]
	# Where the dancer wanders, slowly, to be taken off
	var drift := PackedVector3Array()
	var reach := int(WANDER * FPS)
	for f in count:
		var sum := Vector3.ZERO
		var n := 0
		for g in range(maxi(f - reach, 0), mini(f + reach + 1, count)):
			sum += Vector3(hips[g].x, 0.0, hips[g].z)
			n += 1
		drift.append(sum / n + Vector3(0.0, ground, 0.0))
	var clip := MoveClip.new()
	clip.fps = FPS
	clip.frames = count
	for f in count:
		clip.hips.append(facing * (hips[f] - drift[f]) / stand)
	for side in 2:
		var a := PackedVector3Array()
		var k := PackedVector3Array()
		for f in count:
			a.append(facing * (ankles[side][f] - drift[f]) / stand)
			k.append(facing * (knees[side][f] - drift[f]) / stand)
		clip.ankles.append(a)
		clip.knees.append(k)
	for bone: String in MAP:
		var track := PackedVector4Array()
		for f in count:
			var turn: Quaternion = facing * globals[bone][f]
			if PARENT.has(bone):
				turn = (facing * globals[PARENT[bone]][f]).inverse() * turn
			turn = turn.normalized()
			track.append(Vector4(turn.x, turn.y, turn.z, turn.w))
		clip.turns[bone] = track
	_find_beat(clip)
	return clip


## The beat, from the steps: the ankles' speed and the hips' rise and fall repeat with it. Its length
## leans to about 120 a minute; the first beat is where the hips are lowest (down on the beat). Then
## the loop: the most whole bars (four beats) that fit, leaving room before it for the seam.
func _find_beat(clip: MoveClip) -> void:
	var n := clip.frames
	var signal_ := PackedFloat32Array()
	signal_.resize(n)
	for f in range(1, n):
		var s := absf(clip.hips[f].y - clip.hips[f - 1].y) * 2.0
		for side in 2:
			s += clip.ankles[side][f].distance_to(clip.ankles[side][f - 1])
		signal_[f] = s
	var mean := 0.0
	for v in signal_:
		mean += v
	mean /= n
	var best := 0.5
	var best_score := -INF
	for lag in range(int(0.3 * FPS), int(1.2 * FPS) + 1):
		var s := 0.0
		for f in range(lag, n):
			s += (signal_[f] - mean) * (signal_[f - lag] - mean)
		s /= (n - lag)
		var seconds := lag / FPS
		s *= exp(-0.5 * pow(log(seconds / 0.5) / log(2.0) / 0.7, 2.0))
		if s > best_score:
			best_score = s
			best = seconds
	clip.beat = best
	# Down on the beat: the phase at which the hips are lowest on average
	var phases := 16
	var depth := PackedFloat32Array()
	depth.resize(phases)
	var counts := PackedInt32Array()
	counts.resize(phases)
	for f in n:
		var k := int(fposmod(f / FPS, best) / best * phases) % phases
		depth[k] += clip.hips[f].y
		counts[k] += 1
	var lowest := 0
	for k in phases:
		if counts[k] > 0 and depth[k] / counts[k] < depth[lowest] / maxi(counts[lowest], 1):
			lowest = k
	clip.first_beat = (lowest + 0.5) / phases * best
	var seam := MoveClip.SEAM
	var from := clip.first_beat
	while from < seam:
		from += best
	var bars := floori((clip.frames / FPS - from) / (4.0 * best))
	clip.loop_from = from
	clip.loop_to = from + maxi(bars, 1) * 4.0 * best


func _speed_note(clip: MoveClip) -> String:
	var fastest := 0.0
	for f in range(1, clip.frames):
		fastest = maxf(fastest, clip.hips[f].distance_to(clip.hips[f - 1]) * FPS)
	return ", hips at most %.1f stands a second" % fastest
