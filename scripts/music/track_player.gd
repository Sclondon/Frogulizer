class_name TrackPlayer
extends Node
## Plays the songs in music/ and reads their beat maps (tools/analyse_music.gd)
## as they play, keeping Groove up to date and telling the band when its part
## of the sound is struck.
##
## Who plays what is read off the bands of pitch: the tuba is the low end, the
## drums the kick and the cymbals, the banjo plucks in the middle, the
## accordion breathes with the middle, the trumpet and clarinet are the upper
## middle and the fiddle the bite above it (the drummer answers to "kick" and "cymbal"). The tune is passed round the front
## line every PHRASE bars, to whichever is loudest in its own band then.

## A part of the band has been struck: who (a part in PARTS), and how hard, 0..1.
signal struck(part: String, loud: float)
signal started(track: Dictionary)
## A new phrase (every PHRASE bars): the camera cuts, the lead changes hands.
signal phrase(index: int)
signal finished

## Which bands (see BANDS in tools/analyse_music.gd) each part plays from: its
## loudness is the loudest of them, and it is struck when any of them is.
const PARTS := {
	"tuba": [1], "kick": [0], "cymbal": [5], "banjo": [2, 4], "accordion": [2],
	"trumpet": [3], "clarinet": [3, 2], "fiddle": [4],
}
## Who may have the tune, and the band each is judged by for it.
const LEADS := {"trumpet": 3, "clarinet": 3, "fiddle": 4, "accordion": 2, "banjo": 2}
const PHRASE := 8

var tracks: Array = []
var index := -1
var track: Dictionary = {}
var playing := false
## Seconds into the song, kept smooth (see _clock).
var time := 0.0

var _player: AudioStreamPlayer
var _beats := PackedFloat32Array()
var _bands: Array[PackedByteArray] = []
var _voice := PackedByteArray()
var _vowel := PackedByteArray()
var _rate := 50
var _onsets: Array = []      # per band: [[seconds, strength], ...]
var _next_onset: Array[int] = []
var _meter := 4
var _first_downbeat := 0
var _last_phrase := -1
var _leads_used := {}
var _last_raw := 0.0
var _stuck := 0.0
var _clock_started := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	# (stream, not the browser's sample playback, so its position can be read as it goes)
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_player.finished.connect(_on_finished)
	add_child(_player)
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://music/tracks.json")) if FileAccess.file_exists("res://music/tracks.json") else null
	if listed is Dictionary:
		tracks = listed.get("tracks", [])


func play(which: int, from := 0.0) -> void:
	if tracks.is_empty():
		return
	index = posmod(which, tracks.size())
	track = tracks[index]
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://music/" + String(track.map)))
	if not data is Dictionary:
		push_warning("no beat map for " + str(track.song))
		return
	_beats = PackedFloat32Array(data.beats)
	_rate = int(data.rate)
	_meter = int(data.get("meter", 4))
	_first_downbeat = int(data.get("first_downbeat", 0))
	_bands.clear()
	for coded: String in data.bands:
		_bands.append(Marshalls.base64_to_raw(coded))
	_voice = Marshalls.base64_to_raw(data.get("voice", ""))
	_vowel = Marshalls.base64_to_raw(data.get("vowel", ""))
	_onsets = data.onsets
	_next_onset.clear()
	for k in _onsets.size():
		_next_onset.append(0)
	_last_phrase = -1
	_leads_used.clear()
	time = 0.0
	_last_raw = 0.0
	_stuck = 0.0
	_clock_started = false
	_player.stream = load("res://music/" + String(track.song))
	_player.play(from)
	time = from
	_last_raw = from
	playing = true
	Groove.playing = true
	Groove.meter = _meter
	Groove.title = track.get("title", "")
	Groove.lead = "trumpet"
	Groove.second = ""
	started.emit(track)


func next() -> void:
	play(index + 1)


func previous() -> void:
	play(index - 1)


func toggle_pause() -> void:
	if not playing:
		return
	_player.stream_paused = not _player.stream_paused
	Groove.playing = not _player.stream_paused


func paused() -> bool:
	return _player.stream_paused


func stop() -> void:
	_player.stop()
	playing = false
	Groove.playing = false


## How far through the song, 0..1.
func progress() -> float:
	var length := float(track.get("seconds", 1.0))
	return clampf(time / maxf(length, 0.1), 0.0, 1.0)


## A band's loudness now, 0..1.
func band(k: int) -> float:
	return _sample(_bands[k]) if k < _bands.size() else 0.0


## A track of the map (bytes at `_rate` a second) where the song is now, 0..1, between its samples.
func _sample(track: PackedByteArray) -> float:
	if track.is_empty():
		return 0.0
	var f := time * _rate
	var i := clampi(int(f), 0, track.size() - 1)
	var j := mini(i + 1, track.size() - 1)
	return lerpf(track[i], track[j], f - floorf(f)) / 255.0


func _process(delta: float) -> void:
	if not playing or _player.stream_paused:
		_settle(delta)
		return
	_clock(delta)
	_beat_now()
	var whole := band(6)
	Groove.energy = lerpf(Groove.energy, whole, 1.0 - exp(-10.0 * delta))
	Groove.bass = maxf(band(0), band(1))
	Groove.treble = band(5)
	Groove.voice = _sample(_voice)
	Groove.vowel = _sample(_vowel) * 2.0 - 1.0
	for part: String in PARTS:
		var loud := 0.0
		for k: int in PARTS[part]:
			loud = maxf(loud, band(k))
		Groove.level[part] = lerpf(Groove.level_of(part), loud, 1.0 - exp(-14.0 * delta))
	# What has been struck since last frame
	var hit := {}
	for k in _onsets.size():
		var list: Array = _onsets[k]
		while _next_onset[k] < list.size() and float(list[_next_onset[k]][0]) <= time:
			var strength := float(list[_next_onset[k]][1])
			for part: String in PARTS:
				if k in PARTS[part]:
					hit[part] = maxf(hit.get(part, 0.0), strength)
			_next_onset[k] += 1
	for part: String in hit:
		struck.emit(part, hit[part])


func _settle(delta: float) -> void:
	Groove.energy = maxf(0.0, Groove.energy - delta * 0.5)
	for part: String in Groove.level.keys():
		Groove.level[part] = maxf(0.0, Groove.level[part] - delta * 2.0)


## The beat as a number: which beat of the map it is past, and how far to the next.
func _beat_now() -> void:
	if _beats.size() < 2:
		return
	var i := _beats.bsearch(time, true) - 1
	var b := 0.0
	if i < 0:
		var gap := _beats[1] - _beats[0]
		b = (time - _beats[0]) / gap
	elif i >= _beats.size() - 1:
		var gap := _beats[-1] - _beats[-2]
		b = _beats.size() - 1 + (time - _beats[-1]) / gap
	else:
		b = i + (time - _beats[i]) / maxf(_beats[i + 1] - _beats[i], 0.01)
	var k := clampi(i, 0, _beats.size() - 2)
	Groove.bpm = 60.0 / maxf(_beats[k + 1] - _beats[k], 0.1)
	# (counted from the first downbeat, so that beat 0 of every bar is its first)
	Groove.beat = b - _first_downbeat
	var bar := int(floorf(Groove.beat / _meter))
	var at := bar / PHRASE if bar >= 0 else -1
	if at != _last_phrase and at >= 0:
		_last_phrase = at
		_pass_the_tune()
		Groove.section += 1
		phrase.emit(at)


## The tune goes to whichever of the front line is loudest in its own band over
## the coming phrase (looked ahead in the map), the one who had it last left out.
func _pass_the_tune() -> void:
	var seconds := PHRASE * _meter * 60.0 / maxf(Groove.bpm, 30.0)
	var best := ""
	var best_score := -1.0
	for part: String in LEADS:
		if part == Groove.lead:
			continue
		var k: int = LEADS[part]
		var s := 0.0
		for step in 8:
			s += _band_at(k, time + seconds * step / 8.0)
		# (each takes a turn: those who have had it often are less likely to again)
		s *= 1.0 / (1.0 + 0.4 * _leads_used.get(part, 0)) * randf_range(0.85, 1.15)
		if s > best_score:
			best_score = s
			best = part
	Groove.lead = best
	_leads_used[best] = _leads_used.get(best, 0) + 1


func _band_at(k: int, seconds: float) -> float:
	if k >= _bands.size() or _bands[k].is_empty():
		return 0.0
	return _bands[k][clampi(int(seconds * _rate), 0, _bands[k].size() - 1)] / 255.0


## Seconds into the song, as SalmonRun2's music clock keeps it: run on frame
## time, gently pulled towards where the audio says it is. A browser keeps audio
## suspended until the page is touched; while the song is stuck it holds still.
func _clock(delta: float) -> void:
	var raw := _player.get_playback_position()
	_stuck = _stuck + delta if is_equal_approx(raw, _last_raw) else 0.0
	_last_raw = raw
	if _stuck > 0.25:
		_clock_started = false
		return
	var measured := raw + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	if not _clock_started:
		time = measured
		_clock_started = true
	else:
		time += delta
		var err := measured - time
		if absf(err) > 0.12:
			time = measured
		else:
			time += err * 0.08


func _on_finished() -> void:
	playing = false
	Groove.playing = false
	finished.emit()
