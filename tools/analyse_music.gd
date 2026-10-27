extends SceneTree
## Works out what the band does to a song, ahead of time, from its sound: the
## beats (and which are the first of a bar), how loud it is in each of six bands
## of pitch over time, and where each band is struck. Writes it beside the song
## as music/<name>.beats.json, which TrackPlayer reads as the song plays.
## (Done ahead because a browser plays the song outside Godot's mixer, where
## nothing can listen to it.)
##
## Run by tools/analyse_music.sh, which first has ffmpeg cut the song into the
## bands' loudness envelopes (BANDS, at RATE a second, as raw 32-bit floats):
##   godot --headless --path . --script tools/analyse_music.gd -- <envelope folder> <out.json> <song file> <title> <artist>
##   godot --headless --path . --script tools/analyse_music.gd -- --manifest     (lists every analysed song in music/tracks.json)

## The bands, as ffmpeg cuts them (Hz): sub and kick; tuba and bass; the middle
## (banjo, accordion, voices); the upper middle (trumpet, clarinet); bite (the
## fiddle, the attack of a pluck); air (cymbals and hats). The seventh envelope
## is the whole sound.
const BANDS := [[30, 120], [120, 400], [400, 1200], [1200, 3000], [3000, 6000], [6000, 14000]]
## Envelopes come in at this many a second, and are written out at OUT_RATE.
const RATE := 100
const OUT_RATE := 50
## Tempos looked for, and the one most songs are near (the DP tracker leans to it).
const SLOWEST := 60.0
const FASTEST := 190.0
const LIKELY := 105.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--manifest":
		_manifest()
	elif args.size() >= 3:
		_analyse(args[0], args[1], args[2], args[3] if args.size() > 3 else "", args[4] if args.size() > 4 else "")
	else:
		printerr("usage: -- <envelope folder> <out.json> <song> [title] [artist]  |  -- --manifest")
	quit()


func _analyse(folder: String, out_path: String, song: String, title: String, artist: String) -> void:
	var env: Array[PackedFloat32Array] = []
	for k in BANDS.size() + 1:
		var bytes := FileAccess.get_file_as_bytes(folder.path_join("b%d.raw" % k))
		env.append(bytes.to_float32_array())
	var frames := env[BANDS.size()].size()
	for k in env.size():
		env[k].resize(frames)
	if frames < RATE * 2:
		printerr("too short: ", song)
		return
	var seconds := float(frames) / RATE

	# Loudness per band, on a log scale, as a share of how loud that band gets in this song
	var levels: Array[PackedFloat32Array] = []
	for k in env.size():
		var l := PackedFloat32Array()
		l.resize(frames)
		for i in frames:
			l[i] = log(1.0 + 400.0 * maxf(env[k][i], 0.0))
		var top := _percentile(l, 0.98)
		var floor_ := _percentile(l, 0.10)
		for i in frames:
			l[i] = clampf((l[i] - floor_) / maxf(top - floor_, 0.0001), 0.0, 1.0)
		levels.append(l)

	# How hard each band is struck: the rise in its loudness (onset strength)
	var flux: Array[PackedFloat32Array] = []
	for k in BANDS.size():
		var f := PackedFloat32Array()
		f.resize(frames)
		var l := levels[k]
		for i in range(2, frames):
			f[i] = maxf(0.0, l[i] - maxf(l[i - 1], l[i - 2] * 0.98))
		flux.append(f)
	# ...and of the song as a whole, leaning on the low end, which carries the beat
	var weights := [1.4, 1.1, 0.9, 0.7, 0.8, 0.9]
	var onset := PackedFloat32Array()
	onset.resize(frames)
	for i in frames:
		var s := 0.0
		for k in BANDS.size():
			s += flux[k][i] * weights[k]
		onset[i] = s
	_smooth(onset, 1)
	_normalise(onset)

	var period := _tempo(onset)
	var beats := _track(onset, period)
	var bpm := 60.0 * RATE / period
	var bar := _bars(beats, flux[0], flux[1])

	var data := {
		"version": 1,
		"song": song.get_file(),
		"title": title if title != "" else song.get_file().get_basename().replace("_", " "),
		"artist": artist,
		"seconds": snappedf(seconds, 0.01),
		"bpm": snappedf(bpm, 0.1),
		"meter": bar.x,
		"first_downbeat": bar.y,
		"beats": beats.map(func(b: int) -> float: return snappedf(float(b) / RATE, 0.001)),
		"rate": OUT_RATE,
		"bands": [],
		"onsets": [],
	}
	var step := RATE / OUT_RATE
	for k in levels.size():
		var packed := PackedByteArray()
		packed.resize(frames / step)
		for i in packed.size():
			var v := 0.0
			for j in step:
				v = maxf(v, levels[k][i * step + j])
			packed[i] = clampi(roundi(v * 255.0), 0, 255)
		data.bands.append(Marshalls.raw_to_base64(packed))
	for k in BANDS.size():
		data.onsets.append(_peaks(flux[k]))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("ANALYSED %s: %.1f s, %.1f bpm, %d/4 time from beat %d, %d beats, onsets %s" % [song.get_file(), seconds, bpm, bar.x, bar.y, beats.size(),
			str(data.onsets.map(func(o: Array) -> int: return o.size()))])


## The beat's length in frames: the lag at which the onsets repeat most strongly,
## weighted towards likely tempos (after Ellis, "Beat tracking by dynamic programming").
func _tempo(onset: PackedFloat32Array) -> float:
	var n := onset.size()
	var mean := 0.0
	for v in onset:
		mean += v
	mean /= n
	var shortest := int(60.0 * RATE / FASTEST)
	var longest := int(60.0 * RATE / SLOWEST)
	var scores := PackedFloat32Array()
	scores.resize(longest + 2)
	for lag in range(shortest, longest + 2):
		var s := 0.0
		for i in range(lag, n):
			s += (onset[i] - mean) * (onset[i - lag] - mean)
		scores[lag] = s / (n - lag)
	var best := shortest
	var best_score := -INF
	for lag in range(shortest + 1, longest + 1):
		var bpm := 60.0 * RATE / lag
		var lean := exp(-0.5 * pow(log(bpm / LIKELY) / log(2.0) / 0.6, 2.0))
		# (a beat is usually divided in two: a lag also strong at half itself is a beat, not a half-beat)
		var s := (scores[lag] + 0.5 * maxf(scores[lag / 2], scores[(lag + 1) / 2])) * lean
		if s > best_score:
			best_score = s
			best = lag
	# Between whole frames: fit a parabola through the peak
	var a := scores[best - 1]
	var b := scores[best]
	var c := scores[best + 1]
	var shift := 0.5 * (a - c) / (a - 2.0 * b + c) if absf(a - 2.0 * b + c) > 1e-9 else 0.0
	return best + clampf(shift, -0.5, 0.5)


## Beats by dynamic programming: each frame's best score is its onset plus the
## best earlier beat about one period back, less a cost for straying from the period.
func _track(onset: PackedFloat32Array, period: float) -> Array[int]:
	var n := onset.size()
	var score := PackedFloat32Array()
	score.resize(n)
	var back := PackedInt32Array()
	back.resize(n)
	var tightness := 100.0
	var near := int(roundf(period * 0.5))
	var far := int(roundf(period * 2.0))
	for t in n:
		var best := 0.0
		var from := -1
		for p in range(maxi(t - far, 0), maxi(t - near, 0)):
			var gap := float(t - p) / period
			var s := score[p] - tightness * pow(log(gap), 2.0)
			if from < 0 or s > best:
				best = s
				from = p
		score[t] = onset[t] + (best if from >= 0 else 0.0)
		back[t] = from
	# Back from the best frame in the last period
	var last := n - 1
	for t in range(maxi(n - int(period), 0), n):
		if score[t] > score[last]:
			last = t
	var beats: Array[int] = []
	var t := last
	while t >= 0:
		beats.push_front(t)
		t = back[t]
	return beats


## The metre (3 or 4) and which beat is the first downbeat: the one whose beats
## the low end strikes hardest against the rest.
func _bars(beats: Array[int], low: PackedFloat32Array, bass: PackedFloat32Array) -> Vector2i:
	var hits := PackedFloat32Array()
	for b in beats:
		var s := 0.0
		for j in range(maxi(b - 3, 0), mini(b + 4, low.size())):
			s = maxf(s, low[j] + 0.6 * bass[j])
		hits.append(s)
	var best := Vector2i(4, 0)
	var best_score := -INF
	for meter in [4, 3]:
		for phase in meter:
			var on := 0.0
			var on_count := 0
			var off := 0.0
			var off_count := 0
			for i in hits.size():
				if (i - phase) % meter == 0:
					on += hits[i]
					on_count += 1
				else:
					off += hits[i]
					off_count += 1
			var contrast := on / maxi(on_count, 1) - off / maxi(off_count, 1)
			# (four is the usual, so three has to win clearly)
			if meter == 3:
				contrast -= 0.04
			if contrast > best_score:
				best_score = contrast
				best = Vector2i(meter, phase)
	return best


## Where a band is struck: peaks of its onset strength over a threshold that
## follows the music, at least 70 ms apart. [[seconds, strength 0..1], ...]
func _peaks(flux: PackedFloat32Array) -> Array:
	var n := flux.size()
	var top := _percentile(flux, 0.995)
	var found := []
	var last := -1000
	var window := RATE  # a second either side for the local threshold
	var running := 0.0
	var sums := PackedFloat32Array()
	sums.resize(n + 1)
	for i in n:
		running += flux[i]
		sums[i + 1] = running
	for i in range(1, n - 1):
		var v := flux[i]
		if v <= flux[i - 1] or v < flux[i + 1]:
			continue
		var a := maxi(i - window, 0)
		var b := mini(i + window, n)
		var local := (sums[b] - sums[a]) / (b - a)
		if v < local * 2.2 + top * 0.12 or i - last < RATE * 7 / 100:
			continue
		last = i
		found.append([snappedf(float(i) / RATE, 0.001), snappedf(clampf(v / maxf(top, 0.0001), 0.0, 1.0), 0.01)])
	return found


func _percentile(values: PackedFloat32Array, share: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(share * (sorted.size() - 1)), 0, sorted.size() - 1)]


func _smooth(values: PackedFloat32Array, radius: int) -> void:
	var copy := values.duplicate()
	for i in values.size():
		var s := 0.0
		var c := 0
		for j in range(maxi(i - radius, 0), mini(i + radius + 1, values.size())):
			s += copy[j]
			c += 1
		values[i] = s / c


func _normalise(values: PackedFloat32Array) -> void:
	var mean := 0.0
	for v in values:
		mean += v
	mean /= values.size()
	var spread := 0.0
	for v in values:
		spread += (v - mean) * (v - mean)
	spread = sqrt(spread / values.size())
	for i in values.size():
		values[i] = (values[i] - mean) / maxf(spread, 1e-6)


## music/tracks.json: every song that has been analysed, in name order.
func _manifest() -> void:
	var tracks := []
	var dir := DirAccess.open("res://music")
	if dir == null:
		printerr("no music folder")
		return
	var names := Array(dir.get_files()).filter(func(f: String) -> bool: return f.ends_with(".beats.json"))
	names.sort()
	for name: String in names:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://music/" + name))
		tracks.append({"song": data.song, "map": name, "title": data.title, "artist": data.artist, "seconds": data.seconds, "bpm": data.bpm})
	var file := FileAccess.open("res://music/tracks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"tracks": tracks}, "\t"))
	file.close()
	print("LISTED %d songs" % tracks.size())
