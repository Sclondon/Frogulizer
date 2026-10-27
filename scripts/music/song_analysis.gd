class_name SongAnalysis
extends RefCounted
## Works out what the band does to a song from its sound: the beats (and which are the first of a
## bar), how loud it is in each of six bands of pitch over time, and where each band is struck. Made
## once, when the song is brought aboard (SongImport), and kept beside it as its beat map, which
## TrackPlayer reads as the song plays. (Done ahead because a browser plays the song outside Godot's
## mixer, where nothing can listen to it.)
##
## It is given the bands' loudness envelopes (BANDS, at RATE a second), which ffmpeg (on the computer)
## or the browser's Web Audio (on the web) cut from the song: see SongImport.


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


## The beat map of a song from its envelopes: the six bands, the whole, then the voice's middle low
## and high, and the sides' low and high. Empty if the song is too short.
static func analyse(env: Array[PackedFloat32Array], song: String, title: String, artist: String) -> Dictionary:
	var frames := env[BANDS.size()].size()
	for k in env.size():
		env[k].resize(frames)
	if frames < RATE * 2:
		return {}
	var seconds := float(frames) / RATE

	# Loudness per band, on a log scale, as a share of how loud that band gets in this song
	var levels: Array[PackedFloat32Array] = []
	for k in BANDS.size() + 1:
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
		"song": song,
		"title": title if title != "" else song.get_basename().replace("_", " "),
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
	var voice := _voice(env, frames)
	data["voice"] = Marshalls.raw_to_base64(_packed(voice[0], step))
	data["vowel"] = Marshalls.raw_to_base64(_packed(voice[1], step))
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
	return data


## The voice, as well as it can be told from the mix: how much louder the middle of the stereo
## picture is than its sides, in the voice's low and high bands, eased so a mouth can follow it
## (0..1); and its vowel, from where that sound sits, 0 (low: round, O and U) to 1 (high: E and I).
static func _voice(env: Array[PackedFloat32Array], frames: int) -> Array[PackedFloat32Array]:
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	low.resize(frames)
	high.resize(frames)
	for i in frames:
		low[i] = maxf(0.0, sqrt(maxf(env[7][i], 0.0)) - 1.1 * sqrt(maxf(env[9][i], 0.0)))
		high[i] = maxf(0.0, sqrt(maxf(env[8][i], 0.0)) - 1.1 * sqrt(maxf(env[10][i], 0.0)))
	var loud := PackedFloat32Array()
	loud.resize(frames)
	for i in frames:
		loud[i] = low[i] + high[i]
	var top := _percentile(loud, 0.97)
	var floor_ := _percentile(loud, 0.35)
	var voice := PackedFloat32Array()
	var vowel := PackedFloat32Array()
	voice.resize(frames)
	vowel.resize(frames)
	var v := 0.0
	var w := 0.5
	for i in frames:
		var target := clampf((loud[i] - floor_) / maxf(top - floor_, 1e-6), 0.0, 1.0)
		# (opening quickly, closing a little slower: syllables, not a flutter)
		v += (target - v) * (0.55 if target > v else 0.3)
		voice[i] = v
		var share := high[i] / maxf(low[i] + high[i], 1e-6)
		w += (share - w) * 0.15
		vowel[i] = clampf((w - 0.25) / 0.5, 0.0, 1.0)
	return [voice, vowel]


static func _packed(values: PackedFloat32Array, step: int) -> PackedByteArray:
	var packed := PackedByteArray()
	packed.resize(values.size() / step)
	for i in packed.size():
		var v := 0.0
		for j in step:
			v = maxf(v, values[i * step + j])
		packed[i] = clampi(roundi(v * 255.0), 0, 255)
	return packed


## The beat's length in frames: the lag at which the onsets repeat most strongly,
## weighted towards likely tempos (after Ellis, "Beat tracking by dynamic programming").
static func _tempo(onset: PackedFloat32Array) -> float:
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
static func _track(onset: PackedFloat32Array, period: float) -> Array[int]:
	var n := onset.size()
	var score := PackedFloat32Array()
	score.resize(n)
	var back := PackedInt32Array()
	back.resize(n)
	var tightness := 100.0
	var near := int(roundf(period * 0.5))
	var far := int(roundf(period * 2.0))
	# (the cost of a gap of so many frames, worked out once)
	var cost := PackedFloat32Array()
	cost.resize(far + 1)
	for gap in range(1, far + 1):
		cost[gap] = tightness * pow(log(gap / period), 2.0)
	for t in n:
		var best := 0.0
		var from := -1
		for p in range(maxi(t - far, 0), maxi(t - near, 0)):
			var s := score[p] - cost[t - p]
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
static func _bars(beats: Array[int], low: PackedFloat32Array, bass: PackedFloat32Array) -> Vector2i:
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
static func _peaks(flux: PackedFloat32Array) -> Array:
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


static func _percentile(values: PackedFloat32Array, share: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(share * (sorted.size() - 1)), 0, sorted.size() - 1)]


static func _smooth(values: PackedFloat32Array, radius: int) -> void:
	var copy := values.duplicate()
	for i in values.size():
		var s := 0.0
		var c := 0
		for j in range(maxi(i - radius, 0), mini(i + radius + 1, values.size())):
			s += copy[j]
			c += 1
		values[i] = s / c


static func _normalise(values: PackedFloat32Array) -> void:
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
