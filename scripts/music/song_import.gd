class_name SongImport
extends Node
## Brings a song aboard: any song file picked in a file browser (the computer's own, or the phone's in
## the browser), listened to once for its beat map (SongAnalysis) and kept, with the map, in
## user://songs (the browser keeps it in the page's own storage). Nothing of it is in the project.
##
## The song is cut into the bands' loudness envelopes first: on the computer by ffmpeg, on the web by
## the browser's Web Audio (the same filters). A song Godot cannot play as it is (.m4a, .flac...) is
## kept as a .wav made from it.
##     var songs := SongImport.new()
##     add_child(songs)
##     songs.added.connect(func(name: String) -> void: ...)
##     songs.pick()

## How it is going, for the desk to show.
signal said(text: String)
## A song has been added (its file name in DIR).
signal added(name: String)
signal failed(text: String)

const DIR := "user://songs"
## What Godot plays as it is.
const PLAYS := ["mp3", "ogg", "wav"]
const OPENS := ["mp3", "ogg", "wav", "m4a", "aac", "flac", "opus", "oga", "aif", "aiff", "webm", "mp4"]
## The bands' edges must match SongAnalysis.BANDS. Each is rectified and smoothed to an envelope and taken
## down to 100 a second; the seventh is the whole sound. The song is made stereo (a mono one is the same
## both sides), then: the whole of it in mono, cut into the bands; and the voice, roughly: the middle of
## the stereo picture (where a singer is) and its sides (where the band is spread), each in a low and a
## high band of the voice. (The web does the same in _WEB.)
const ENV := "aeval=exprs=abs(val(0)),lowpass=f=25,lowpass=f=25,aresample=100"
const CUTS := [[30, 120], [120, 400], [400, 1200], [1200, 3000], [3000, 6000], [6000, 10000], [0, 0]]
const VOICE := [[250, 900], [900, 3200]]

## Whether a song is being brought aboard now.
var busy := false

var _dialog: FileDialog
var _thread: Thread
# (the browser's callbacks, kept so they are not let go while it works)
var _js_said: JavaScriptObject
var _js_done: JavaScriptObject


## Every song aboard: [[file name in DIR, its beat map's file name], ...], in no order.
static func aboard() -> Array:
	var found := []
	if not DirAccess.dir_exists_absolute(DIR):
		return found
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".beats.json"):
			continue
		var map := file.get_basename() + ".beats.json"
		if FileAccess.file_exists(DIR.path_join(map)):
			found.append([file, map])
	return found


## The song `name` (in DIR) as Godot plays it.
static func stream(name: String) -> AudioStream:
	var path := DIR.path_join(name)
	match name.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


static func remove(name: String) -> void:
	DirAccess.remove_absolute(DIR.path_join(name))
	DirAccess.remove_absolute(DIR.path_join(name.get_basename() + ".beats.json"))


## Opens the file browser; whatever is picked is brought aboard.
func pick() -> void:
	if busy:
		said.emit("Still listening to the last one...")
		return
	if OS.has_feature("web"):
		_pick_web()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.use_native_dialog = true
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_dialog.title = "Bring songs aboard"
		_dialog.filters = PackedStringArray([", ".join(OPENS.map(func(e: String) -> String: return "*." + e)) + " ; Songs"])
		_dialog.files_selected.connect(func(paths: PackedStringArray) -> void: add_files(Array(paths)))
		add_child(_dialog)
	_dialog.popup_centered_ratio(0.6)


## Brings these files aboard one after another (on the computer: ffmpeg does the listening).
func add_files(paths: Array) -> void:
	busy = true
	for path: String in paths:
		said.emit("Listening to %s..." % path.get_file())
		_thread = Thread.new()
		_thread.start(_add_file.bind(path))
		while _thread.is_alive():
			await get_tree().process_frame
		var result: String = _thread.wait_to_finish()
		if result.begins_with("!"):
			failed.emit(result.substr(1))
		else:
			added.emit(result)
	busy = false


## (on its own thread) The song copied into DIR and its map made: its name there, or "!" and why not.
func _add_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "!There is no file at " + path
	DirAccess.make_dir_recursive_absolute(DIR)
	var ext := path.get_extension().to_lower()
	var base := path.get_file().get_basename().validate_filename()
	var name := base + "." + (ext if ext in PLAYS else "wav")
	var out := []
	if ext in PLAYS:
		DirAccess.copy_absolute(path, ProjectSettings.globalize_path(DIR.path_join(name)))
	elif OS.execute(CameraDesk.FFMPEG, ["-v", "error", "-y", "-i", path, "-vn", "-c:a", "pcm_s16le", ProjectSettings.globalize_path(DIR.path_join(name))], out, true) != 0:
		return "!ffmpeg could not read %s: %s" % [path.get_file(), "".join(out).strip_edges()]
	if stream(name) == null:
		remove(name)
		return "!Godot cannot play %s." % path.get_file()
	# The envelopes, written by ffmpeg as raw floats
	var work := ProjectSettings.globalize_path("user://songs_work")
	DirAccess.make_dir_recursive_absolute(work)
	var args := ["-v", "error", "-y", "-i", path, "-filter_complex", _graph()]
	for k in CUTS.size() + 4:
		args.append_array(["-map", "[o%d]" % k, "-f", "f32le", work.path_join("b%d.raw" % k)])
	out.clear()
	if OS.execute(CameraDesk.FFMPEG, args, out, true) != 0:
		remove(name)
		return "!ffmpeg could not listen to %s: %s" % [path.get_file(), "".join(out).strip_edges()]
	var env: Array[PackedFloat32Array] = []
	for k in CUTS.size() + 4:
		env.append(FileAccess.get_file_as_bytes(work.path_join("b%d.raw" % k)).to_float32_array())
	# Its title and who it is by, from its tags, else its file name
	out.clear()
	OS.execute(CameraDesk.FFMPEG, ["-i", path], out, true)
	var tags := {}
	for line: String in "".join(out).split("\n"):
		var parts := line.split(":", true, 1)
		var key := parts[0].strip_edges().to_lower()
		if parts.size() == 2 and key in ["title", "artist"] and not tags.has(key):
			tags[key] = parts[1].strip_edges()
	var named := _from_name(path.get_file())
	var data := SongAnalysis.analyse(env, name, tags.get("title", named[0]), tags.get("artist", named[1]))
	if data.is_empty():
		remove(name)
		return "!%s is too short." % path.get_file()
	_write_map(name, data)
	return name


## The ffmpeg graph cutting a song into the envelopes (see ENV).
static func _graph() -> String:
	var graph := "[0:a]aformat=channel_layouts=stereo,aresample=22050,asplit=2[st][vo];[st]pan=mono|c0=0.5*c0+0.5*c1,asplit=%d" % CUTS.size()
	for k in CUTS.size():
		graph += "[s%d]" % k
	graph += ";"
	for k in CUTS.size():
		var cut: Array = CUTS[k]
		graph += "[s%d]%s%s[o%d];" % [k, ("highpass=f=%d,lowpass=f=%d," % cut) if cut[0] > 0 else "", ENV, k]
	graph += "[vo]asplit=2[mid][side];[mid]pan=mono|c0=0.5*c0+0.5*c1,asplit=2[m0][m1];[side]pan=mono|c0=0.5*c0-0.5*c1,asplit=2[x0][x1]"
	var k := CUTS.size()
	for side in ["m", "x"]:
		for v in VOICE.size():
			graph += ";[%s%d]highpass=f=%d,lowpass=f=%d,%s[o%d]" % [side, v, VOICE[v][0], VOICE[v][1], ENV, k]
			k += 1
	return graph


## "Artist - Title.mp3" read as [title, artist]; else the name as the title.
static func _from_name(file: String) -> Array:
	var bare := file.get_basename().replace("_", " ").strip_edges()
	var parts := bare.split(" - ", true, 1)
	return [parts[1].strip_edges(), parts[0].strip_edges()] if parts.size() == 2 else [bare, ""]


static func _write_map(name: String, data: Dictionary) -> void:
	var file := FileAccess.open(DIR.path_join(name.get_basename() + ".beats.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


# --- On the web ---

func _pick_web() -> void:
	if JavaScriptBridge.eval("typeof window.frogulizerPick", true) != "function":
		JavaScriptBridge.eval(_WEB, true)
	_js_said = JavaScriptBridge.create_callback(func(args: Array) -> void:
		busy = true
		said.emit(str(args[0])))
	_js_done = JavaScriptBridge.create_callback(_web_done)
	var window := JavaScriptBridge.get_interface("window")
	window.frogulizerPick(_js_said, _js_done, ",".join(OPENS.map(func(e: String) -> String: return "." + e)))


## The browser has listened to it: [file name, kind it is kept as, the song's bytes, the envelopes, frames
## in each], or ["", why not].
func _web_done(args: Array) -> void:
	if str(args[0]) == "":
		busy = false
		failed.emit("The browser could not read that song (%s)." % str(args[1]))
		return
	var file := str(args[0])
	var name := file.get_basename().validate_filename() + "." + str(args[1])
	var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(args[2])
	var floats := JavaScriptBridge.js_buffer_to_packed_byte_array(args[3]).to_float32_array()
	var frames := int(args[4])
	# (the analysis takes a few seconds in the browser: the word is shown first)
	said.emit("Finding the beat of %s..." % file)
	for wait in 3:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	var song := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
	song.store_buffer(bytes)
	song.close()
	if stream(name) == null:
		remove(name)
		busy = false
		failed.emit("Godot cannot play %s." % file)
		return
	var env: Array[PackedFloat32Array] = []
	for k in CUTS.size() + 4:
		env.append(floats.slice(k * frames, (k + 1) * frames))
	var named := _from_name(file)
	var data := SongAnalysis.analyse(env, name, named[0], named[1])
	busy = false
	if data.is_empty():
		remove(name)
		failed.emit("%s is too short." % file)
		return
	_write_map(name, data)
	added.emit(name)


## The browser's half: a file input (the phone's own file browser), Web Audio's filters for the
## envelopes (as _graph, a band at a time so a phone has the memory), and a .wav for a song Godot
## cannot play as it is. (BiquadFilter's Q is in dB here: -3.01 is ffmpeg's Butterworth.)
const _WEB := """
window.frogulizerPick = function (said, done, accept) {
	var Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = 'audio/*,' + accept;
	input.style.display = 'none';
	document.body.appendChild(input);
	function decode(bytes, rate) {
		return new Promise(function (ok, no) { new Offline(2, 1, rate).decodeAudioData(bytes.slice(0), ok, no); });
	}
	function render(ctx) {
		return new Promise(function (ok) { ctx.oncomplete = function (e) { ok(e.renderedBuffer); }; ctx.startRendering(); });
	}
	async function band(from, low, high) {
		var rate = from.sampleRate, n = from.length;
		var ctx = new Offline(1, n, rate);
		var node = ctx.createBufferSource();
		node.buffer = from;
		var start = node;
		function filter(type, f) {
			var b = ctx.createBiquadFilter();
			b.type = type; b.frequency.value = f; b.Q.value = -3.0103;
			node.connect(b); node = b;
		}
		if (low > 0) { filter('highpass', low); filter('lowpass', high); }
		var down = ctx.createGain(); down.gain.value = 0.5; node.connect(down);
		var abs = ctx.createWaveShaper(); abs.curve = new Float32Array([1, 0, 1]); down.connect(abs);
		var up = ctx.createGain(); up.gain.value = 2; abs.connect(up); node = up;
		filter('lowpass', 25); filter('lowpass', 25);
		node.connect(ctx.destination);
		start.start();
		var out = (await render(ctx)).getChannelData(0);
		var frames = Math.floor(n / rate * 100), env = new Float32Array(frames);
		// (two frames on: these filters come out 20 ms later than ffmpeg's, which the maps were tuned on)
		for (var i = 0; i < frames; i++) env[i] = out[Math.min(n - 1, Math.round((i + 2) * rate / 100))];
		return env;
	}
	function wav(song) {
		var n = song.length, ch = Math.min(2, song.numberOfChannels), rate = song.sampleRate;
		var view = new DataView(new ArrayBuffer(44 + n * ch * 2));
		function text(at, s) { for (var i = 0; i < s.length; i++) view.setUint8(at + i, s.charCodeAt(i)); }
		text(0, 'RIFF'); view.setUint32(4, 36 + n * ch * 2, true); text(8, 'WAVE'); text(12, 'fmt ');
		view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, ch, true);
		view.setUint32(24, rate, true); view.setUint32(28, rate * ch * 2, true); view.setUint16(32, ch * 2, true);
		view.setUint16(34, 16, true); text(36, 'data'); view.setUint32(40, n * ch * 2, true);
		var data = [];
		for (var c = 0; c < ch; c++) data.push(song.getChannelData(c));
		var at = 44;
		for (var i = 0; i < n; i++) for (var c = 0; c < ch; c++, at += 2) {
			var v = Math.max(-1, Math.min(1, data[c][i]));
			view.setInt16(at, v < 0 ? v * 32768 : v * 32767, true);
		}
		return view.buffer;
	}
	input.addEventListener('change', async function () {
		var file = input.files && input.files[0];
		input.remove();
		if (!file) return;
		try {
			said('Listening to ' + file.name + '...');
			var bytes = await file.arrayBuffer();
			var song = await decode(bytes, 22050);
			var n = song.length, rate = song.sampleRate;
			var L = song.getChannelData(0), R = song.numberOfChannels > 1 ? song.getChannelData(1) : L;
			var mid = new Offline(1, 1, rate).createBuffer(1, n, rate), side = new Offline(1, 1, rate).createBuffer(1, n, rate);
			var m = mid.getChannelData(0), s = side.getChannelData(0);
			// (a mono song made stereo at -3 dB, as ffmpeg does)
			var gain = song.numberOfChannels > 1 ? 0.5 : Math.SQRT1_2;
			for (var i = 0; i < n; i++) { m[i] = gain * (L[i] + R[i]); s[i] = gain * (L[i] - R[i]); }
			song = null;
			var cuts = [[mid, 30, 120], [mid, 120, 400], [mid, 400, 1200], [mid, 1200, 3000], [mid, 3000, 6000], [mid, 6000, 10000], [mid, 0, 0],
				[mid, 250, 900], [mid, 900, 3200], [side, 250, 900], [side, 900, 3200]];
			var frames = Math.floor(n / rate * 100), env = new Float32Array(cuts.length * frames);
			for (var k = 0; k < cuts.length; k++) {
				said('Listening to ' + file.name + '... ' + Math.round(100 * k / cuts.length) + '%');
				env.set((await band(cuts[k][0], cuts[k][1], cuts[k][2])).subarray(0, frames), k * frames);
			}
			var kind = (file.name.split('.').pop() || '').toLowerCase();
			var play = bytes;
			if (kind !== 'mp3' && kind !== 'ogg') {
				said('Making ' + file.name + ' playable...');
				play = wav(await decode(bytes, 44100));
				kind = 'wav';
			}
			// (the songs are kept in the page's storage: asked not to be cleared to make room)
			if (navigator.storage && navigator.storage.persist) navigator.storage.persist();
			done(file.name, kind, play, env.buffer, frames);
		} catch (e) {
			done('', String((e && e.message) || e || 'unknown'));
		}
	});
	input.click();
};
"""
