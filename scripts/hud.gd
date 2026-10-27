class_name Hud
extends CanvasLayer
## What is on the screen over the show, kept out of the way: the song's title
## and who it is by, shown as it starts and then faded; and, when the screen is
## touched, a bar along the bottom to go back a song, pause, go on a song, and
## choose a camera (Auto, or one shot to hold), with how far through the song it
## is. The bar hides itself after a few seconds untouched. Before anything has
## been touched there is a card to come aboard (browsers will not play sound
## until the page is touched).

signal boarded
signal previous
signal pause
signal next
signal camera(mode: String)

const CAMERAS := [["auto", "Auto"], ["audience", "Crowd"], ["stage", "Stage"], ["lead", "Soloist"], ["bank", "River"], ["crane", "High"]]
const INK := Color(0.98, 0.92, 0.78)
const SHADOW := Color(0.18, 0.07, 0.05, 0.85)

var player: TrackPlayer
var _card: Control
var _title: Label
var _artist: Label
var _bar: Control
var _progress: ProgressBar
var _play_button: Button
var _camera_button: Button
var _camera_index := 0
var _shown_for := 0.0
var _title_for := 0.0
var _boarded := false


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	root.gui_input.connect(_on_touch)
	# The title, top left
	var titles := VBoxContainer.new()
	titles.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titles.offset_left = 22
	titles.offset_top = 18
	titles.offset_right = -22
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(titles)
	_title = _label(34)
	_artist = _label(20)
	titles.add_child(_title)
	titles.add_child(_artist)
	titles.modulate.a = 0.0
	# The bar
	_bar = PanelContainer.new()
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -118
	_bar.offset_left = 12
	_bar.offset_right = -12
	_bar.offset_bottom = -14
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.2, 0.08, 0.06, 0.78)
	panel.border_color = Color(0.92, 0.7, 0.26)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(14)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	_bar.add_theme_stylebox_override("panel", panel)
	root.add_child(_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_bar.add_child(column)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.7, 0.26)
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.15)
	back.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("fill", fill)
	_progress.add_theme_stylebox_override("background", back)
	column.add_child(_progress)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	row.add_child(_button("|<", func() -> void: previous.emit()))
	_play_button = _button("||", func() -> void: pause.emit())
	row.add_child(_play_button)
	row.add_child(_button(">|", func() -> void: next.emit()))
	_camera_button = _button("Camera: Auto", _next_camera)
	_camera_button.custom_minimum_size.x = 170
	row.add_child(_camera_button)
	_bar.modulate.a = 0.0
	_bar.visible = false
	# The card to come aboard
	_card = ColorRect.new()
	(_card as ColorRect).color = Color(0.08, 0.04, 0.03, 0.55)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_card)
	var words := VBoxContainer.new()
	words.set_anchors_preset(Control.PRESET_CENTER)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.grow_horizontal = Control.GROW_DIRECTION_BOTH
	words.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.add_child(words)
	var name_label := _label(52)
	name_label.text = "Frogulizer"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(name_label)
	var hint := _label(24)
	hint.text = "Tap to come aboard"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(hint)
	_card.gui_input.connect(_on_touch)


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", INK)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0.55, 0.12, 0.10)
	plain.set_corner_radius_all(10)
	var down := plain.duplicate()
	down.bg_color = Color(0.85, 0.6, 0.2)
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", plain)
	button.add_theme_stylebox_override("pressed", down)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void:
		pressed.call()
		_shown_for = 0.0)
	return button


func _on_touch(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	if not _boarded:
		_boarded = true
		var fade := create_tween()
		fade.tween_property(_card, "modulate:a", 0.0, 0.6)
		fade.tween_callback(_card.hide)
		boarded.emit()
		return
	_bar.visible = true
	_shown_for = 0.0


## Gone straight aboard (a render has no one to tap).
func skip_card() -> void:
	_boarded = true
	_card.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if not _boarded:
					_on_touch(_fake_tap())
				else:
					pause.emit()
			KEY_RIGHT, KEY_N:
				next.emit()
			KEY_LEFT, KEY_P:
				previous.emit()
			KEY_C:
				_next_camera()


func _fake_tap() -> InputEventMouseButton:
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	return tap


func _next_camera() -> void:
	_camera_index = (_camera_index + 1) % CAMERAS.size()
	_camera_button.text = "Camera: " + CAMERAS[_camera_index][1]
	camera.emit(CAMERAS[_camera_index][0])


## A song has started: its title and who it is by, shown for a while.
func show_title(track: Dictionary) -> void:
	_title.text = track.get("title", "")
	_artist.text = track.get("artist", "")
	_title_for = 0.0


func _process(delta: float) -> void:
	_shown_for += delta
	_title_for += delta
	var titles := _title.get_parent() as Control
	titles.modulate.a = clampf(minf(_title_for * 1.5, (6.0 - _title_for) * 0.8), 0.0, 1.0) if _boarded else 0.0
	var want := 1.0 if _shown_for < 4.0 and _bar.visible else 0.0
	_bar.modulate.a = move_toward(_bar.modulate.a, want, delta * 4.0)
	if _bar.modulate.a <= 0.0 and want == 0.0:
		_bar.visible = false
	if player:
		_progress.value = player.progress() * 100.0
		_play_button.text = ">" if player.paused() else "||"
