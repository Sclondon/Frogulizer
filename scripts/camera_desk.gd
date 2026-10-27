class_name CameraDesk
extends CanvasLayer
## The camera desk, for making films of the show (Instagram Reels above all): a panel (Tab shows
## and hides it) that drives the Director's camera and renders the result.
##
## - Frame: Free, 9:16 Reel (with Instagram's safe areas shaded: where its own buttons and text go),
##   1:1 or 16:9. The picture outside the frame is darkened, so what is framed is what renders.
## - Camera: Auto (the Director cuts by itself), any of its shots held, Free (fly: WASD, Q/E down and
##   up, right-drag or arrow keys to look, Shift faster, wheel the speed), Orbit (round what it
##   follows: left-drag to turn, wheel in and out, middle-drag to slide) or Follow (orbit that keeps
##   behind a frog's shoulder). Orbit and Follow ride with the boat, round the stage, the crowd, the
##   boat or any frog.
## - Lens: focal length (mm, on a full-frame camera), a roll (Dutch angle), handheld shake, and a
##   push in on the beat.
## - Moves: Add key keeps where the camera is (on the boat: so a move stays on the boat as it goes);
##   Play goes through them along a smooth path, in seconds or in beats of the song; they are saved
##   as takes (user://takes/<name>.json).
## - Render: the song, from and to (seconds), the frame and frames a second; a second Godot renders
##   it frame by frame with Movie Maker (sound and all) and ffmpeg makes an .mp4 of it in renders/.

signal changed

const LENSES := [14, 18, 24, 28, 35, 50, 85, 135]
const FRAMES := {"free": Vector2.ZERO, "reel": Vector2(9, 16), "square": Vector2(1, 1), "wide": Vector2(16, 9)}
const RENDER_SIZES := {"reel": Vector2i(1080, 1920), "square": Vector2i(1080, 1080), "wide": Vector2i(1920, 1080), "free": Vector2i(1920, 1080)}
const FFMPEG := "C:/Projects/scareathon/trailer/node_modules/ffmpeg-static/ffmpeg.exe"

var director: Director
var boat: Riverboat
var player: TrackPlayer
var frogs: Array = []          # [label, Frog]
var frame_kind := "free"
var camera_mode := "auto"       # auto, shot, free, orbit, follow, path
var focal := 28.0
var roll := 0.0
var shake := 0.15
var beat_push := 0.3
var keys: Array = []            # [{at (boat space), basis, focal, roll, time}]
var keys_in_beats := false

var _panel: PanelContainer
var _shade: Control
var _list: ItemList
var _status: Label
var _target_pick: OptionButton
var _shot_pick: OptionButton
var _song_pick: OptionButton
var _from: SpinBox
var _to: SpinBox
var _fps: OptionButton
var _take_name: LineEdit
var _orbit_yaw := 0.6
var _orbit_pitch := 0.25
var _orbit_distance := 9.0
var _orbit_slide := Vector3.ZERO
var _fly_yaw := 0.0
var _fly_pitch := 0.0
var _fly_speed := 4.0
var _path_time := 0.0
var _render_pid := -1
var _render_out := ""
var _dragging := 0


func _ready() -> void:
	layer = 8
	_shade = Control.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.draw.connect(_draw_frame)
	add_child(_shade)
	_build_panel()
	_panel.visible = false
	get_viewport().size_changed.connect(_shade.queue_redraw)


# --- The panel ---

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_panel.custom_minimum_size.x = 330
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.05, 0.92)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	_heading(box, "Camera desk  (Tab hides it)")
	_heading(box, "Frame")
	var frames := _choice(box, ["Free", "9:16 Reel", "1:1 Square", "16:9 Wide"], func(i: int) -> void:
		frame_kind = ["free", "reel", "square", "wide"][i]
		_shade.queue_redraw())
	frames.selected = 0

	_heading(box, "Camera")
	_choice(box, ["Auto (cuts by itself)", "Hold a shot", "Free fly", "Orbit", "Follow", "Play the path"], func(i: int) -> void:
		_set_mode(["auto", "shot", "free", "orbit", "follow", "path"][i]))
	_shot_pick = _choice(box, Director.SHOTS.keys(), func(i: int) -> void:
		if camera_mode == "shot":
			director.mode = Director.SHOTS.keys()[i])
	_label(box, "Orbit and follow round:")
	_target_pick = _choice(box, [], func(_i: int) -> void: _orbit_slide = Vector3.ZERO)

	_heading(box, "Lens")
	_slider(box, "Focal length (mm)", 12.0, 135.0, focal, func(v: float) -> void: focal = v)
	_slider(box, "Roll (degrees)", -30.0, 30.0, 0.0, func(v: float) -> void: roll = deg_to_rad(v))
	_slider(box, "Handheld shake", 0.0, 1.0, shake, func(v: float) -> void: shake = v)
	_slider(box, "Push on the beat", 0.0, 1.0, beat_push, func(v: float) -> void: beat_push = v)

	_heading(box, "Look")
	_slider(box, "Pixels (1 = off)", 1.0, 12.0, 1.0, func(v: float) -> void: _pixels().size = roundf(v))
	_slider(box, "Colours (0 = all)", 0.0, 16.0, 0.0, func(v: float) -> void: _pixels().levels = roundf(v))

	_heading(box, "Moves")
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row, "Add key", _add_key)
	_button(row, "Remove", _remove_key)
	_button(row, "Clear", func() -> void:
		keys.clear()
		_refresh_keys())
	_list = ItemList.new()
	_list.custom_minimum_size.y = 110
	box.add_child(_list)
	var beats := CheckBox.new()
	beats.text = "Time the keys in beats (the move keeps to the song)"
	beats.toggled.connect(func(on: bool) -> void: keys_in_beats = on)
	box.add_child(beats)
	var takes := HBoxContainer.new()
	box.add_child(takes)
	_take_name = LineEdit.new()
	_take_name.text = "take1"
	_take_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	takes.add_child(_take_name)
	_button(takes, "Save", func() -> void: save_take(_take_name.text))
	_button(takes, "Load", func() -> void: load_take(_take_name.text))

	_heading(box, "Render")
	_song_pick = _choice(box, [], func(_i: int) -> void: pass)
	var times := HBoxContainer.new()
	box.add_child(times)
	_from = _spin(times, "from", 0.0)
	_to = _spin(times, "to", 30.0)
	_fps = _choice(box, ["30 frames a second", "60 frames a second"], func(_i: int) -> void: pass)
	_button(box, "Render the film", _render)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	box.add_child(_status)


## Fills the lists that depend on the scene (call once everything is aboard).
func setup() -> void:
	_target_pick.clear()
	for entry: Array in frogs:
		_target_pick.add_item(entry[0])
	_song_pick.clear()
	for track: Dictionary in player.tracks:
		_song_pick.add_item(str(track.get("title", track.get("song", "?"))))
	if not player.tracks.is_empty():
		_to.value = float(player.tracks[0].get("seconds", 30.0))


func _heading(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.98, 0.78, 0.35))
	box.add_child(label)


func _label(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	box.add_child(label)


func _choice(box: Container, items: Array, picked: Callable) -> OptionButton:
	var choice := OptionButton.new()
	for item in items:
		choice.add_item(str(item))
	choice.item_selected.connect(picked)
	box.add_child(choice)
	return choice


func _slider(box: Container, text: String, low: float, high: float, value: float, moved: Callable) -> void:
	var label := Label.new()
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	var show := func(v: float) -> void: label.text = "%s: %.2f" % [text, v]
	show.call(value)
	slider.value_changed.connect(func(v: float) -> void:
		show.call(v)
		moved.call(v))
	box.add_child(slider)


func _spin(box: Container, text: String, value: float) -> SpinBox:
	var label := Label.new()
	label.text = text
	box.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = 0.0
	spin.max_value = 3600.0
	spin.step = 0.1
	spin.value = value
	spin.suffix = "s"
	box.add_child(spin)
	return spin


func _button(box: Container, text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	box.add_child(button)
	return button


func _pixels() -> Pixelate:
	return get_tree().current_scene.get(&"pixels") if get_tree().current_scene else null


# --- The frame ---

## The part of the window that is the film, for a frame kind.
func frame_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var shape: Vector2 = FRAMES[frame_kind]
	if shape == Vector2.ZERO:
		return Rect2(Vector2.ZERO, size)
	var scale := minf(size.x / shape.x, size.y / shape.y)
	var framed := shape * scale
	return Rect2((size - framed) * 0.5, framed)


func _draw_frame() -> void:
	var size := get_viewport().get_visible_rect().size
	var rect := frame_rect()
	if frame_kind == "free":
		return
	var dark := Color(0, 0, 0, 0.72)
	_shade.draw_rect(Rect2(0, 0, rect.position.x, size.y), dark)
	_shade.draw_rect(Rect2(rect.end.x, 0, size.x - rect.end.x, size.y), dark)
	_shade.draw_rect(Rect2(rect.position.x, 0, rect.size.x, rect.position.y), dark)
	_shade.draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, size.y - rect.end.y), dark)
	_shade.draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.0)
	if frame_kind == "reel":
		# Instagram's own things: the top bar, and the caption, buttons and audio line at the bottom and right
		var tint := Color(1.0, 0.3, 0.3, 0.13)
		_shade.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.13)), tint)
		_shade.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.75), Vector2(rect.size.x, rect.size.y * 0.25)), tint)
		_shade.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.45), Vector2(rect.size.x * 0.16, rect.size.y * 0.3)), tint)
	# (thirds)
	for k: int in [1, 2]:
		var x := rect.position.x + rect.size.x * k / 3.0
		var y := rect.position.y + rect.size.y * k / 3.0
		_shade.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(1, 1, 1, 0.12))
		_shade.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(1, 1, 1, 0.12))


# --- Driving the camera ---

func _set_mode(mode: String) -> void:
	camera_mode = mode
	match mode:
		"auto":
			director.mode = "auto"
		"shot":
			director.mode = Director.SHOTS.keys()[maxi(_shot_pick.selected, 0)]
		"free":
			director.mode = "manual"
			var forward := -director.global_basis.z
			_fly_yaw = atan2(-forward.x, -forward.z)
			_fly_pitch = asin(clampf(forward.y, -1.0, 1.0))
		"path":
			director.mode = "manual"
			_path_time = 0.0
		_:
			director.mode = "manual"


func _target() -> Node3D:
	if frogs.is_empty() or _target_pick.selected < 0:
		return boat
	return frogs[_target_pick.selected][1]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K and camera_mode != "auto":
		_add_key()
	if camera_mode in ["free", "orbit", "follow"]:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				_dragging = event.button_index
			elif not event.pressed:
				_dragging = 0
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(_orbit_distance * 0.9, 0.8)
				_fly_speed = minf(_fly_speed * 1.15, 40.0)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(_orbit_distance * 1.1, 120.0)
				_fly_speed = maxf(_fly_speed / 1.15, 0.3)
		elif event is InputEventMouseMotion and _dragging != 0:
			var move: Vector2 = event.relative * 0.005
			if camera_mode == "free" and _dragging == MOUSE_BUTTON_RIGHT:
				_fly_yaw -= move.x
				_fly_pitch = clampf(_fly_pitch - move.y, -1.5, 1.5)
			elif _dragging == MOUSE_BUTTON_MIDDLE:
				var basis := director.global_basis
				_orbit_slide += (-basis.x * move.x + basis.y * move.y) * _orbit_distance * 0.4
			elif _dragging == MOUSE_BUTTON_LEFT and camera_mode != "free":
				_orbit_yaw -= move.x
				_orbit_pitch = clampf(_orbit_pitch + move.y, -0.3, 1.4)


func _process(delta: float) -> void:
	_poll_render()
	if director == null or boat == null:
		return
	match camera_mode:
		"free":
			_fly(delta)
		"orbit", "follow":
			_orbit(delta)
		"path":
			_play_path(delta)
	if camera_mode != "auto" and camera_mode != "shot":
		director.fov = _vertical_fov()
		director.rotate_object_local(Vector3.BACK, roll)
		var now := Time.get_ticks_msec() * 0.001
		director.position += Vector3(sin(now * 0.7) + 0.5 * sin(now * 2.3), sin(now * 1.1) + 0.4 * sin(now * 2.9), 0.0) * 0.03 * shake
		director.fov *= 1.0 - (Groove.bass * 0.03 * beat_push if Groove.playing else 0.0)


## The field of view for the focal length (on a 36 x 24 mm frame, by its width), on this window's shape.
func _vertical_fov() -> float:
	var rect := frame_rect()
	var horizontal := 2.0 * atan(36.0 / (2.0 * focal))
	var aspect := rect.size.x / maxf(rect.size.y, 1.0)
	# (the camera sees the whole window; the frame is its middle: widen to keep the frame's width)
	var window := get_viewport().get_visible_rect().size
	var share := rect.size.y / maxf(window.y, 1.0)
	return clampf(rad_to_deg(2.0 * atan(tan(horizontal * 0.5) / aspect) / share), 5.0, 120.0)


func _fly(delta: float) -> void:
	var go := Vector3(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	_fly_yaw += (float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))) * delta * 1.2
	_fly_pitch = clampf(_fly_pitch + (float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))) * delta * 0.9, -1.5, 1.5)
	var basis := Basis.from_euler(Vector3(_fly_pitch, _fly_yaw, 0.0))
	var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	# (it goes along with the boat, so a shot held still stays on the boat)
	director.global_transform = Transform3D(basis, director.global_position + basis * go * _fly_speed * fast * delta + boat.global_basis.z * boat.speed * delta)


func _orbit(_delta: float) -> void:
	var target := _target()
	var centre := target.global_position + Vector3.UP * (1.3 if target is Frog else 3.0) + _orbit_slide
	var yaw := _orbit_yaw
	if camera_mode == "follow" and target is Frog:
		yaw += (target as Frog).facing_yaw + PI
	var offset := Vector3(sin(yaw) * cos(_orbit_pitch), sin(_orbit_pitch), cos(yaw) * cos(_orbit_pitch)) * _orbit_distance
	director.look_at_from_position(centre + offset, centre)


# --- Moves ---

func _add_key() -> void:
	var local := boat.global_transform.affine_inverse() * director.global_transform
	var time := (Groove.beat if keys_in_beats else (player.time if player else 0.0))
	if keys.is_empty():
		time = 0.0
	elif not Groove.playing or keys_in_beats == false and time <= float(keys[-1].time):
		time = float(keys[-1].time) + (4.0 if keys_in_beats else 3.0)
	keys.append({"at": local.origin, "basis": local.basis.get_rotation_quaternion(), "focal": focal, "roll": roll, "time": time})
	_refresh_keys()


func _remove_key() -> void:
	var picked := _list.get_selected_items()
	if picked.is_empty():
		if not keys.is_empty():
			keys.pop_back()
	else:
		keys.remove_at(picked[0])
	_refresh_keys()


func _refresh_keys() -> void:
	_list.clear()
	for k in keys.size():
		_list.add_item("%d   at %.1f %s   %d mm" % [k + 1, float(keys[k].time) - float(keys[0].time), "beats" if keys_in_beats else "s", int(keys[k].focal)])
	changed.emit()


## Where the path is at time `t` (from its first key): Catmull-Rom between the keys' places, slerp between their turns.
func path_at(t: float) -> Dictionary:
	if keys.is_empty():
		return {}
	var start := float(keys[0].time)
	t += start
	if keys.size() == 1 or t <= start:
		return keys[0]
	if t >= float(keys[-1].time):
		return keys[-1]
	var i := 0
	while i < keys.size() - 2 and float(keys[i + 1].time) < t:
		i += 1
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[i + 1]
	var u := (t - float(a.time)) / maxf(float(b.time) - float(a.time), 0.001)
	u = u * u * (3.0 - 2.0 * u) if keys.size() == 2 else u
	var p0: Vector3 = keys[maxi(i - 1, 0)].at
	var p3: Vector3 = keys[mini(i + 2, keys.size() - 1)].at
	var at: Vector3 = (a.at as Vector3).cubic_interpolate(b.at, p0, p3, u)
	return {"at": at, "basis": (a.basis as Quaternion).slerp(b.basis, u), "focal": lerpf(a.focal, b.focal, u), "roll": lerpf(a.roll, b.roll, u)}


func _play_path(delta: float) -> void:
	if keys.is_empty():
		return
	_path_time = (Groove.beat - float(keys[0].time) if keys_in_beats and Groove.playing else _path_time + delta)
	var at := path_at(_path_time)
	director.global_transform = boat.global_transform * Transform3D(Basis(at.basis), at.at)
	focal = at.focal
	roll = at.roll


func save_take(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://takes")
	var out := []
	for key: Dictionary in keys:
		var q: Quaternion = key.basis
		out.append({"at": [key.at.x, key.at.y, key.at.z], "basis": [q.x, q.y, q.z, q.w], "focal": key.focal, "roll": key.roll, "time": key.time})
	var file := FileAccess.open("user://takes/%s.json" % name, FileAccess.WRITE)
	file.store_string(JSON.stringify({"keys": out, "beats": keys_in_beats, "frame": frame_kind}, "\t"))
	_status.text = "Saved %s (%d keys) in %s" % [name, keys.size(), ProjectSettings.globalize_path("user://takes")]


func load_take(name: String) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://takes/%s.json" % name))
	if not data is Dictionary:
		if _status:
			_status.text = "No take called %s" % name
		return false
	keys.clear()
	for key: Dictionary in data.keys:
		keys.append({"at": Vector3(key.at[0], key.at[1], key.at[2]), "basis": Quaternion(key.basis[0], key.basis[1], key.basis[2], key.basis[3]),
				"focal": key.focal, "roll": key.roll, "time": key.time})
	keys_in_beats = data.get("beats", false)
	frame_kind = data.get("frame", frame_kind)
	if _list:
		_refresh_keys()
	return true


# --- Rendering ---

func _render() -> void:
	if _render_pid > 0 and OS.is_process_running(_render_pid):
		_status.text = "Already rendering..."
		return
	var song := maxi(_song_pick.selected, 0)
	var fps := 30 if _fps.selected <= 0 else 60
	var size: Vector2i = RENDER_SIZES[frame_kind]
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders"))
	_render_out = ProjectSettings.globalize_path("res://renders/frogulizer_%s" % stamp)
	# The camera goes to the render as a take: the path, or (with no keys) the Director's own cutting
	var take := "_render"
	save_take(take)
	var settings := {"song": song, "from": _from.value, "to": _to.value, "camera": camera_mode if camera_mode in ["path", "auto", "shot"] else "auto",
			"shot": director.mode, "take": take, "focal": focal, "pixels": _pixels().size if _pixels() else 1.0, "levels": _pixels().levels if _pixels() else 0.0}
	var file := FileAccess.open("user://render.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(settings))
	file.close()
	# (Movie Maker films the window at the project's size, whatever --resolution says: so for this one
	# run the project is told the film's size, in an override.cfg taken away again when it is done)
	var override := FileAccess.open("res://override.cfg", FileAccess.WRITE)
	override.store_string("[display]

window/size/viewport_width=%d
window/size/viewport_height=%d
" % [size.x, size.y])
	override.close()
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--write-movie", _render_out + ".avi", "--fixed-fps", str(fps),
			"--", "--render", ProjectSettings.globalize_path("user://render.json")]
	_render_pid = OS.create_process(OS.get_executable_path(), args)
	_status.text = "Rendering %s (%.0f to %.0f s) at %dx%d, %d fps..." % [_song_pick.get_item_text(song), _from.value, _to.value, size.x, size.y, fps]


func _poll_render() -> void:
	if _render_pid <= 0 or OS.is_process_running(_render_pid):
		return
	_render_pid = -1
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://override.cfg"))
	# Movie Maker writes an .avi of pictures and sound: made into an .mp4 Instagram takes
	var avi := _render_out + ".avi"
	if not FileAccess.file_exists(avi):
		_status.text = "The render did not write a film."
		return
	var out := []
	var code := OS.execute(FFMPEG, ["-y", "-v", "error", "-i", avi, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow",
			"-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", _render_out + ".mp4"], out, true)
	_status.text = ("Made %s.mp4" % _render_out) if code == 0 else ("ffmpeg could not make the .mp4 (the .avi is there): %s" % str(out))
