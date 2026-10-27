class_name CameraDesk
extends CanvasLayer
## The camera desk: all the controls of the show, for making films of it (Instagram Reels above all).
## A bar along the bottom plays the songs (back, play and pause, on, a bar to scrub through the song,
## the volume) and shows which camera is on; the panel at the right (Tab, or its button, hides it)
## has the rest in tabs:
##
## - Song: the songs, to play any of them; whether a song's title is shown as it starts.
## - Camera: how the camera is worked. Auto (the Director cuts by itself: how quickly, on new phrases
##   or not, to the soloist or not, and which shots come up), any shot held, Fly (the buttons, or
##   WASD, Q/E, the arrows, Shift; drag to look, the wheel for speed), Orbit (round a frog or
##   the boat: drag to turn round, the wheel in and out, middle-drag to slide; it can turn round by
##   itself), Follow (an orbit that keeps behind a frog), or Path (the keys of a move, played).
## - Lens: focal length (mm, on a full-frame camera) or zoom for the Director's shots, roll (a Dutch
##   angle), handheld shake, a push in with the bass, a bump on every beat, how much the camera lags.
## - Look: exposure, brightness, contrast, saturation, haze and sun; pixels and colours; the frame (9:16
##   Reel with Instagram's safe areas shaded, 4:5, 1:1, 16:9: what is outside it is darkened, and is
##   what renders), thirds, and letterbox bars (which are in the film).
## - Moves: keys of a camera move (on the boat, so it stays on the boat as it goes), in seconds or in
##   beats, played as a smooth path, straight, eased or cut; saved as takes (user://takes/<name>.json),
##   with the lens and the look. A take can be copied as text and pasted in elsewhere: made on the phone
##   (the web build), filmed on the computer.
## - Render: the song, from and to, frames a second and quality; a second Godot renders it frame by frame
##   with Movie Maker (sound and all) and ffmpeg makes an .mp4 of it in renders/. (Not in the browser.)
## On a phone the desk is laid out at the phone's size; one finger drags, two pinch and slide.
## H hides everything but a button to bring it back.

signal changed

const LENSES := [14, 18, 24, 28, 35, 50, 85, 135]
const FRAMES := {"free": Vector2.ZERO, "reel": Vector2(9, 16), "portrait": Vector2(4, 5), "square": Vector2(1, 1), "wide": Vector2(16, 9)}
const FRAME_NAMES := [["free", "Free"], ["reel", "9:16 Reel"], ["portrait", "4:5 Post"], ["square", "1:1"], ["wide", "16:9"]]
const RENDER_SIZES := {"reel": Vector2i(1080, 1920), "portrait": Vector2i(1080, 1350), "square": Vector2i(1080, 1080), "wide": Vector2i(1920, 1080), "free": Vector2i(1920, 1080)}
const FFMPEG := "C:/Projects/scareathon/trailer/node_modules/ffmpeg-static/ffmpeg.exe"
const MODES := [["auto", "Auto"], ["shot", "Hold"], ["free", "Fly"], ["orbit", "Orbit"], ["follow", "Follow"], ["path", "Path"]]
const MODE_NAMES := {"auto": "Auto", "shot": "Holding", "free": "Flying", "orbit": "Orbit", "follow": "Follow", "path": "Path"}
const SHOT_NAMES := {"audience": "Crowd to band", "stage": "Band to crowd", "floor": "Dance floor", "crane": "Crane", "bank": "From the bank",
		"wheel": "Paddle wheel", "broadside": "Broadside", "astern": "The wake", "bow": "The captain", "conductor": "Conductor", "lead": "Soloist",
		"singer": "Singer"}
const EASES := ["Smooth path", "Straight lines", "Ease each move", "Cut between keys"]
const QUALITIES := [["Draft", 26, "veryfast"], ["Good", 18, "slow"], ["Best", 14, "slow"]]
const PANEL_WIDTH := 392.0
const BAR_HEIGHT := 78.0

# The desk's colours: an autumn evening on the river
const BACK := Color(0.11, 0.06, 0.045, 0.94)
const CARD := Color(0.19, 0.1, 0.07, 0.95)
const RAISED := Color(0.3, 0.15, 0.09)
const HOVER := Color(0.42, 0.2, 0.11)
const EDGE := Color(0.46, 0.25, 0.13)
const CREAM := Color(0.98, 0.91, 0.77)
const MUTED := Color(0.78, 0.65, 0.5)
const AMBER := Color(0.96, 0.67, 0.24)
const RUST := Color(0.74, 0.27, 0.14)
const INK := Color(0.16, 0.08, 0.04)

var director: Director
var boat: Riverboat
var player: TrackPlayer
var hud: Hud
var river: River
var frogs: Array = []          # [label, Frog]
var frame_kind := "free"
var camera_mode := "auto"       # auto, shot, free, orbit, follow, path
var focal := 28.0
var zoom := 1.0
var roll := 0.0
var shake := 0.15
var beat_push := 0.3
var beat_bump := 0.0
var lag := 0.0
var orbit_speed := 0.0          # degrees a second
var safe_areas := true
var thirds := false
var letterbox := false
var keys: Array = []            # [{at (boat space), basis, focal, roll, time}]
var keys_in_beats := false
var key_gap := 3.0
var ease := 0
var loop := false
## The picture: Environment and sun settings, and the pixelate pass.
var look := {}

var _ui: Control
var _panel: PanelContainer
var _bar: PanelContainer
var _shade: Control
var _bars: Control
var _show_ui: Button
var _toggle: Button
var _tabs: TabContainer
var _held := {}
var _list: ItemList
var _songs: ItemList
var _song_import: SongImport
var _status: Label
var _target_index := 0
var _target_buttons := {}
var _dancers: OptionButton
var _mode_buttons := {}
var _shot_buttons := {}
var _frame_buttons := []
var _song_pick: OptionButton
var _from: SpinBox
var _to: SpinBox
var _fps := 30
var _quality := 1
var _take_name: LineEdit
var _take_pick: OptionButton
var _render_label: Label
var _play: Button
var _seek: HSlider
var _seeking := false
var _time_label: Label
var _length_label: Label
var _now_title: Label
var _now_artist: Label
var _camera_label: Label
var _sliders := {}
var _orbit_yaw := 0.6
var _orbit_pitch := 0.25
var _orbit_distance := 9.0
var _orbit_height := 1.3
var _orbit_slide := Vector3.ZERO
var _fly_at := Vector3.ZERO
var _fly_yaw := 0.0
var _fly_pitch := 0.0
var _fly_speed := 4.0
var _path_time := 0.0
var _smooth := Transform3D.IDENTITY
var _smooth_ready := false
var _last_shot := ""
var _last_mode := ""
var _render_pid := -1
var _render_out := ""
var _dragging := 0
var _tick := 0.0
var _grabber: ImageTexture
var _grabber_lit: ImageTexture
var _phone := false             # a small screen: the desk laid out for a phone
var _bar_top: HBoxContainer     # (on a phone the song's name and the scrub bar have a row of their own)
var _now_box: VBoxContainer
var _bar_row: HBoxContainer
var _wide_only: Array = []      # what a phone has no room for in the bar
var _short_names := {}          # Button: [its name, its name on a phone, its width]
var _touches := {}              # finger: where it is
var _pinch := 0.0


func _ready() -> void:
	layer = 8
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = _theme()
	add_child(_ui)
	_shade = Control.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.draw.connect(_draw_frame)
	_ui.add_child(_shade)
	_build_bar()
	_build_panel()
	_show_ui = Button.new()
	_show_ui.text = "Show controls  (H)"
	_show_ui.theme = _ui.theme
	_show_ui.focus_mode = Control.FOCUS_NONE
	_show_ui.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_show_ui.position = Vector2(-190, 12)
	_show_ui.modulate.a = 0.75
	_show_ui.pressed.connect(func() -> void: show_ui(true))
	_show_ui.visible = false
	add_child(_show_ui)
	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()


# --- The look of the desk ---

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = 14
	_grabber = _dot(16, AMBER)
	_grabber_lit = _dot(18, CREAM)
	theme.set_color("font_color", "Label", CREAM)
	for type: String in ["Button", "OptionButton", "CheckBox", "CheckButton", "MenuButton"]:
		theme.set_color("font_color", type, CREAM)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, CREAM)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_disabled_color", type, MUTED * Color(1, 1, 1, 0.5))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, _box(RAISED, 8, EDGE))
		theme.set_stylebox("hover", type, _box(HOVER, 8, AMBER * Color(1, 1, 1, 0.6)))
		theme.set_stylebox("pressed", type, _box(AMBER, 8, AMBER))
		theme.set_stylebox("hover_pressed", type, _box(AMBER.lightened(0.15), 8, CREAM))
		theme.set_stylebox("disabled", type, _box(RAISED * Color(1, 1, 1, 0.5), 8))
	for type: String in ["CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, _box(Color(0, 0, 0, 0), 6))
		theme.set_stylebox("hover", type, _box(Color(1, 1, 1, 0.05), 6))
		theme.set_stylebox("pressed", type, _box(Color(0, 0, 0, 0), 6))
		theme.set_stylebox("hover_pressed", type, _box(Color(1, 1, 1, 0.05), 6))
		theme.set_color("font_pressed_color", type, CREAM)
		theme.set_color("font_hover_pressed_color", type, Color.WHITE)
	theme.set_stylebox("panel", "PanelContainer", _box(BACK, 14, EDGE, 10, true))
	var track := _box(Color(0, 0, 0, 0.35), 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(AMBER, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(AMBER.lightened(0.2), 3))
	theme.set_icon("grabber", "HSlider", _grabber)
	theme.set_icon("grabber_highlight", "HSlider", _grabber_lit)
	theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	theme.set_stylebox("tab_selected", "TabContainer", _box(AMBER, 8, AMBER, 7))
	theme.set_stylebox("tab_unselected", "TabContainer", _box(RAISED, 8, EDGE, 7))
	theme.set_stylebox("tab_hovered", "TabContainer", _box(HOVER, 8, AMBER * Color(1, 1, 1, 0.6), 7))
	theme.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	theme.set_color("font_selected_color", "TabContainer", INK)
	theme.set_color("font_unselected_color", "TabContainer", MUTED)
	theme.set_color("font_hovered_color", "TabContainer", CREAM)
	theme.set_constant("side_margin", "TabContainer", 0)
	theme.set_font_size("font_size", "TabContainer", 13)
	for type: String in ["LineEdit"]:
		theme.set_stylebox("normal", type, _box(Color(0, 0, 0, 0.35), 7, EDGE))
		theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0.45), 7, AMBER))
		theme.set_color("font_color", type, CREAM)
		theme.set_color("caret_color", type, AMBER)
		theme.set_color("selection_color", type, RUST)
	theme.set_stylebox("panel", "ItemList", _box(Color(0, 0, 0, 0.3), 8, EDGE, 6))
	theme.set_stylebox("selected", "ItemList", _box(AMBER, 5))
	theme.set_stylebox("selected_focus", "ItemList", _box(AMBER, 5))
	theme.set_stylebox("hovered", "ItemList", _box(HOVER, 5))
	theme.set_stylebox("hovered_selected", "ItemList", _box(AMBER.lightened(0.15), 5))
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	theme.set_color("font_color", "ItemList", CREAM)
	theme.set_color("font_selected_color", "ItemList", INK)
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_color("font_hovered_selected_color", "ItemList", INK)
	theme.set_stylebox("panel", "PopupMenu", _box(CARD, 8, EDGE, 6))
	theme.set_stylebox("hover", "PopupMenu", _box(AMBER, 5))
	theme.set_color("font_color", "PopupMenu", CREAM)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("panel", "TooltipPanel", _box(CARD, 6, EDGE, 6))
	theme.set_color("font_color", "TooltipLabel", CREAM)
	for type: String in ["VScrollBar"]:
		theme.set_stylebox("scroll", type, _box(Color(0, 0, 0, 0.2), 4))
		theme.set_stylebox("grabber", type, _box(EDGE, 4))
		theme.set_stylebox("grabber_highlight", type, _box(AMBER * Color(1, 1, 1, 0.7), 4))
		theme.set_stylebox("grabber_pressed", type, _box(AMBER, 4))
	theme.set_stylebox("separator", "VSeparator", _line(true))
	theme.set_stylebox("separator", "HSeparator", _line(false))
	theme.set_constant("separation", "VSeparator", 18)
	return theme


func _box(colour: Color, radius: int, border := Color(0, 0, 0, 0), margin := 8, shadow := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
	box.content_margin_left = margin + 2
	box.content_margin_right = margin + 2
	box.content_margin_top = margin * 0.6
	box.content_margin_bottom = margin * 0.6
	box.anti_aliasing = true
	if shadow:
		box.shadow_color = Color(0, 0, 0, 0.35)
		box.shadow_size = 10
		box.shadow_offset = Vector2(0, 3)
	return box


func _line(vertical: bool) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = EDGE
	line.vertical = vertical
	line.thickness = 1
	return line


## A round dot, for the sliders' handles.
func _dot(size: int, colour: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - middle, y - middle).length()
			var a := clampf(middle - d + 0.5, 0.0, 1.0)
			var rim := clampf(d - (middle - 2.0), 0.0, 1.0)
			image.set_pixel(x, y, Color(colour.lerp(INK, rim * 0.6), a))
	return ImageTexture.create_from_image(image)


func _heading_font() -> Font:
	return font(true)


## The writing (Jost) or a heading (Libre Baskerville, in bold), with the symbols on the buttons from
## Noto's: all from fonts/, since in a browser there are none of the computer's own to fall back on.
static func font(heading := false) -> Font:
	var made := FontVariation.new()
	made.base_font = load("res://fonts/LibreBaskerville.ttf" if heading else "res://fonts/Jost.ttf")
	made.fallbacks = [load("res://fonts/NotoSansSymbols2-Regular.woff2"), load("res://fonts/NotoSansMath-Regular.woff2")]
	if heading:
		made.variation_embolden = 0.7
	return made


# --- The bar along the bottom ---

func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.anchor_left = 0.0
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = 12
	_bar.offset_right = -12
	_bar.offset_top = -BAR_HEIGHT - 12
	_bar.offset_bottom = -12
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(_bar)
	_bar.resized.connect(_place_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_bar.add_child(rows)
	_bar_top = HBoxContainer.new()
	_bar_top.visible = false
	rows.add_child(_bar_top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	rows.add_child(row)
	_bar_row = row
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 6)
	transport.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(transport)
	_icon_button(transport, "◀◀", "Back a song  (P)", func() -> void: player.previous())
	_play = _icon_button(transport, "▶", "Play / pause  (Space)", _play_pause)
	_play.custom_minimum_size = Vector2(54, 50)
	_play.add_theme_stylebox_override("normal", _box(AMBER, 25, AMBER))
	_play.add_theme_stylebox_override("hover", _box(AMBER.lightened(0.15), 25, CREAM))
	_play.add_theme_color_override("font_color", INK)
	_play.add_theme_color_override("font_hover_color", INK)
	_icon_button(transport, "▶▶", "On a song  (N)", func() -> void: player.next())
	# What is playing, and where in it
	var now := VBoxContainer.new()
	now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now.alignment = BoxContainer.ALIGNMENT_CENTER
	now.add_theme_constant_override("separation", 2)
	row.add_child(now)
	_now_box = now
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 10)
	now.add_child(names)
	_now_title = Label.new()
	_now_title.text = "Frogulizer"
	_now_title.add_theme_font_override("font", _heading_font())
	_now_title.add_theme_font_size_override("font_size", 16)
	_now_title.clip_text = true
	_now_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_now_title.size_flags_stretch_ratio = 2.0
	names.add_child(_now_title)
	_now_artist = Label.new()
	_now_artist.add_theme_color_override("font_color", MUTED)
	_now_artist.clip_text = true
	_now_artist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(_now_artist)
	var scrub := HBoxContainer.new()
	scrub.add_theme_constant_override("separation", 8)
	now.add_child(scrub)
	_time_label = _small(scrub, "0:00")
	_seek = HSlider.new()
	_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seek.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_seek.max_value = 1.0
	_seek.step = 0.0001
	_seek.focus_mode = Control.FOCUS_NONE
	_seek.tooltip_text = "Drag or click to go anywhere in the song"
	_seek.drag_started.connect(func() -> void: _seeking = true)
	_seek.drag_ended.connect(func(_changed: bool) -> void:
		_seeking = false
		_seek_to(_seek.value))
	_seek.value_changed.connect(func(v: float) -> void:
		if not _seeking:
			_seek_to(v))
	scrub.add_child(_seek)
	_length_label = _small(scrub, "0:00")
	_wide_only.append(VSeparator.new())
	row.add_child(_wide_only[-1])
	# The volume (a phone has its own)
	var sound := HBoxContainer.new()
	sound.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(sound)
	_wide_only.append(sound)
	var speaker := Label.new()
	speaker.text = "🔊"
	sound.add_child(speaker)
	var volume := HSlider.new()
	volume.custom_minimum_size.x = 96
	volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = 1.0
	volume.focus_mode = Control.FOCUS_NONE
	volume.tooltip_text = "Volume"
	volume.value_changed.connect(func(v: float) -> void:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
		speaker.text = "🔇" if v <= 0.001 else "🔊")
	sound.add_child(volume)
	_wide_only.append(VSeparator.new())
	row.add_child(_wide_only[-1])
	# Which camera
	var camera := VBoxContainer.new()
	_wide_only.append(camera)
	camera.alignment = BoxContainer.ALIGNMENT_CENTER
	camera.custom_minimum_size.x = 170
	camera.add_theme_constant_override("separation", 0)
	row.add_child(camera)
	var caption := _small(camera, "CAMERA")
	caption.add_theme_font_size_override("font_size", 11)
	_camera_label = Label.new()
	_camera_label.add_theme_font_override("font", _heading_font())
	_camera_label.clip_text = true
	camera.add_child(_camera_label)
	var cut := _icon_button(row, "⟳  Next shot", "Cut to the next shot  (C)", _next_shot)
	cut.custom_minimum_size.x = 112
	_short_names[cut] = [cut.text, "⟳", 112.0]
	_wide_only.append(VSeparator.new())
	row.add_child(_wide_only[-1])
	_toggle = _icon_button(row, "☰  Desk", "Show or hide the desk  (Tab)", func() -> void: show_panel(not _panel.visible))
	_toggle.toggle_mode = true
	_toggle.button_pressed = true
	_short_names[_toggle] = [_toggle.text, "☰", 44.0]
	var hide := _icon_button(row, "◱  Hide all", "Hide all the controls, to see the picture  (H)", func() -> void: show_ui(false))
	_short_names[hide] = [hide.text, "◱", 44.0]


func _icon_button(box: Container, text: String, tip: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(pressed)
	box.add_child(button)
	return button


func _small(box: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	return label


# --- The panel ---

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_WIDTH - 12
	_panel.offset_right = -12
	_panel.offset_top = 12
	_panel.offset_bottom = -BAR_HEIGHT - 24
	_ui.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = "Camera desk"
	title.add_theme_font_override("font", _heading_font())
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := _icon_button(top, "✕", "Hide the desk  (Tab)", func() -> void: show_panel(false))
	close.custom_minimum_size = Vector2(34, 34)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_focus_mode = Control.FOCUS_NONE
	column.add_child(_tabs)
	_song_tab(_tab("Song"))
	_camera_tab(_tab("Camera"))
	_lens_tab(_tab("Lens"))
	_look_tab(_tab("Look"))
	_moves_tab(_tab("Moves"))
	_render_tab(_tab("Render"))
	_tabs.current_tab = 1
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", AMBER)
	_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_status)


func _tab(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box


## A card in a tab, with a heading (and a line under it saying what it is for): what goes in it goes in what it returns.
func _section(box: Container, heading: String, note := "") -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(CARD, 10, EDGE * Color(1, 1, 1, 0.6), 10))
	box.add_child(card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 7)
	card.add_child(inside)
	var label := Label.new()
	label.text = heading
	label.add_theme_font_override("font", _heading_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", AMBER)
	inside.add_child(label)
	if note != "":
		_note(inside, note)
	return inside


func _note(box: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	return label


## A slider with its name and value over it. `shown` turns the value into what is written.
func _slider(box: Container, key: String, text: String, low: float, high: float, value: float, moved: Callable, shown := Callable(), step := 0.01) -> HSlider:
	var top := HBoxContainer.new()
	box.add_child(top)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var number := Label.new()
	number.add_theme_color_override("font_color", AMBER)
	top.add_child(number)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	var show := func(v: float) -> void: number.text = shown.call(v) if shown.is_valid() else ("%.2f" % v)
	slider.value_changed.connect(func(v: float) -> void:
		show.call(v)
		moved.call(v))
	slider.set_value_no_signal(value)
	show.call(value)
	box.add_child(slider)
	_sliders[key] = [slider, show]
	return slider


## Sets a slider from outside (without it calling back).
func _set_slider(key: String, value: float) -> void:
	if not _sliders.has(key):
		return
	var slider: HSlider = _sliders[key][0]
	slider.set_value_no_signal(value)
	(_sliders[key][1] as Callable).call(value)


func _toggle_box(box: Container, text: String, on: bool, toggled: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(toggled)
	box.add_child(check)
	return check


func _button(box: Container, text: String, pressed: Callable, tip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(pressed)
	box.add_child(button)
	return button


## A row (or grid) of buttons of which one is chosen. Returns them in order.
func _choices(box: Container, names: Array, chosen: int, picked: Callable, columns := 0) -> Array:
	var holder: Container
	if columns > 0:
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 5)
		holder = grid
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		holder = row
	box.add_child(holder)
	var group := ButtonGroup.new()
	var made := []
	for k in names.size():
		var button := Button.new()
		button.text = str(names[k])
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = k == chosen
		button.pressed.connect(func() -> void: picked.call(k))
		holder.add_child(button)
		made.append(button)
	return made


func _option(box: Container, items: Array, picked: Callable) -> OptionButton:
	var choice := OptionButton.new()
	for item in items:
		choice.add_item(str(item))
	choice.focus_mode = Control.FOCUS_NONE
	choice.item_selected.connect(picked)
	box.add_child(choice)
	return choice


# --- The tabs ---

func _song_tab(box: VBoxContainer) -> void:
	var songs := _section(box, "Songs", "Any song file from this phone, brought aboard and kept in this browser: tap one to play it." if OS.has_feature("web")
			else "Any song files, brought aboard and kept in user://songs: click one to play it.")
	var row := HBoxContainer.new()
	songs.add_child(row)
	_button(row, "+ Add songs...", func() -> void: _song_import.pick(), "Pick song files in a file browser: the band learns each one's beat")
	_button(row, "Remove", _remove_song, "Takes the chosen song off the boat")
	_songs = ItemList.new()
	_songs.custom_minimum_size.y = 220
	_songs.focus_mode = Control.FOCUS_NONE
	_songs.item_clicked.connect(func(index: int, _at: Vector2, _button_index: int) -> void: player.play(index))
	songs.add_child(_songs)
	_song_import = SongImport.new()
	_song_import.said.connect(func(text: String) -> void: _status.text = text)
	_song_import.failed.connect(func(text: String) -> void: _status.text = text)
	_song_import.added.connect(func(name: String) -> void:
		player.scan()
		_refresh_songs()
		var track: Dictionary = player.tracks[player.find(name)]
		_status.text = "Aboard: %s (%.0f bpm, %d/4)." % [track.title, float(track.bpm), int(JSON.parse_string(FileAccess.get_file_as_string(SongImport.DIR.path_join(track.map))).get("meter", 4))]
		if not player.playing:
			player.play(player.find(name)))
	add_child(_song_import)
	var shown := _section(box, "On screen")
	_toggle_box(shown, "Show each song's title as it starts", true, func(on: bool) -> void:
		if hud:
			hud.titles = on)


## The desk open at the Song tab (when there are no songs yet).
func show_songs() -> void:
	show_panel(true)
	_tabs.current_tab = 0
	_status.text = "No songs aboard yet: + Add songs to pick some."


## Takes the song chosen in the list off the boat (its file and its map).
func _remove_song() -> void:
	var picked := _songs.get_selected_items()
	if picked.is_empty():
		_status.text = "Choose a song in the list first."
		return
	var track: Dictionary = player.tracks[picked[0]]
	if picked[0] == player.index:
		player.stop()
		player.index = -1
		player.track = {}
	SongImport.remove(track.song)
	player.scan()
	_refresh_songs()
	_status.text = "Took %s off the boat." % track.title


func _camera_tab(box: VBoxContainer) -> void:
	var how := _section(box, "Camera")
	var names := []
	for entry: Array in MODES:
		names.append(entry[1])
	var made := _choices(how, names, 0, func(k: int) -> void: _set_mode(MODES[k][0]), 3)
	for k in MODES.size():
		_mode_buttons[MODES[k][0]] = made[k]
	_button(how, "↺  Reset the camera", _reset_camera, "Lens, roll, shake, lag and orbit back as they were")

	var shots := _section(box, "Shots", "Click one to hold it. In Auto the one it is on lights up.")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	shots.add_child(grid)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for shot: String in Director.SHOTS:
		var button := Button.new()
		button.text = SHOT_NAMES.get(shot, shot.capitalize())
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func() -> void: _hold(shot))
		grid.add_child(button)
		_shot_buttons[shot] = button

	var auto := _section(box, "Auto cutting")
	_slider(auto, "pace", "How long each shot is held", 0.3, 2.5, 1.0, func(v: float) -> void: director.pace = v,
			func(v: float) -> String: return "×%.1f" % v)
	_toggle_box(auto, "Cut on a new phrase of the music", true, func(on: bool) -> void: director.cut_on_phrase = on)
	_toggle_box(auto, "Cut to whoever has the tune", true, func(on: bool) -> void: director.cut_to_soloist = on)
	_note(auto, "Shots it cuts between:")
	var turns := GridContainer.new()
	turns.columns = 2
	auto.add_child(turns)
	var picked := {}
	for shot: String in Director.SHOTS:
		picked[shot] = Director.ROTATION.has(shot) or shot == "lead"
		var check := CheckBox.new()
		check.text = SHOT_NAMES.get(shot, shot.capitalize())
		check.button_pressed = picked[shot]
		check.focus_mode = Control.FOCUS_NONE
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.toggled.connect(func(on: bool) -> void:
			picked[shot] = on
			var list := Director.ROTATION.filter(func(s: String) -> bool: return picked.get(s, false))
			for other: String in Director.SHOTS:
				if picked[other] and not list.has(other) and other != "lead":
					list.append(other)
			director.shot_list = list if not list.is_empty() else ["audience"])
		turns.add_child(check)

	var round_about := _section(box, "Orbit and follow", "Round whom (drag the picture to turn round, the wheel to come closer, middle-drag to slide):")
	var who := FlowContainer.new()
	who.add_theme_constant_override("h_separation", 5)
	who.add_theme_constant_override("v_separation", 5)
	round_about.add_child(who)
	var people := ButtonGroup.new()
	people.allow_unpress = true
	_target_buttons = {"group": people, "box": who}
	_dancers = _option(round_about, ["A dancer..."], func(i: int) -> void:
		if i <= 0:
			return
		var index: int = _dancer_indexes()[i - 1]
		_pick_target(index))
	_slider(round_about, "distance", "Distance", 0.8, 60.0, _orbit_distance, func(v: float) -> void: _orbit_distance = v,
			func(v: float) -> String: return "%.1f m" % v)
	_slider(round_about, "pitch", "Height (angle)", -15.0, 80.0, rad_to_deg(_orbit_pitch), func(v: float) -> void: _orbit_pitch = deg_to_rad(v),
			func(v: float) -> String: return "%d°" % v, 1.0)
	_slider(round_about, "aim", "Aim at (height)", 0.0, 6.0, _orbit_height, func(v: float) -> void: _orbit_height = v,
			func(v: float) -> String: return "%.1f m" % v)
	_slider(round_about, "orbit_speed", "Turn round by itself", -40.0, 40.0, orbit_speed, func(v: float) -> void: orbit_speed = v,
			func(v: float) -> String: return "%d°/s" % v, 1.0)
	_button(round_about, "Re-centre", func() -> void: _orbit_slide = Vector3.ZERO)

	var fly := _section(box, "Fly", "Hold to move and turn (or WASD, Q/E, the arrows, Shift; drag to look):")
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 5)
	pad.add_theme_constant_override("v_separation", 5)
	fly.add_child(pad)
	for entry: Array in [["↶ Turn", "turn_left"], ["▲ Forward", "forward"], ["Turn ↷", "turn_right"],
			["◀ Left", "left"], ["▼ Back", "back"], ["Right ▶", "right"],
			["⤒ Up", "up"], ["Look ⇅", "look_up"], ["⤓ Down", "down"], ["", ""], ["Look ⇵", "look_down"], ["⚡ Fast", "fast"]]:
		if entry[1] == "":
			pad.add_child(Control.new())
			continue
		var hold := Button.new()
		hold.text = entry[0]
		hold.focus_mode = Control.FOCUS_NONE
		hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = entry[1]
		hold.button_down.connect(func() -> void:
			if camera_mode != "free":
				_set_mode("free")
			_held[key] = true)
		hold.button_up.connect(func() -> void: _held.erase(key))
		pad.add_child(hold)
	_slider(fly, "fly_speed", "Speed", 0.3, 40.0, _fly_speed, func(v: float) -> void: _fly_speed = v,
			func(v: float) -> String: return "%.1f m/s" % v)


func _lens_tab(box: VBoxContainer) -> void:
	var lens := _section(box, "Lens", "Focal length is for Fly, Orbit, Follow and Path; the Director's own shots take the zoom.")
	_slider(lens, "focal", "Focal length", 12.0, 135.0, focal, func(v: float) -> void: focal = v,
			func(v: float) -> String: return "%d mm" % v, 1.0)
	var presets := GridContainer.new()
	presets.columns = 4
	presets.add_theme_constant_override("h_separation", 5)
	presets.add_theme_constant_override("v_separation", 5)
	lens.add_child(presets)
	for mm: int in LENSES:
		var button := _button(presets, "%d" % mm, func() -> void:
			focal = mm
			_set_slider("focal", mm))
		button.tooltip_text = "%d mm" % mm
	_slider(lens, "zoom", "Zoom (Auto and held shots)", 0.5, 2.5, zoom, func(v: float) -> void: zoom = v,
			func(v: float) -> String: return "×%.2f" % v)
	_slider(lens, "roll", "Roll (Dutch angle)", -30.0, 30.0, 0.0, func(v: float) -> void: roll = deg_to_rad(v),
			func(v: float) -> String: return "%d°" % v, 1.0)
	_note(lens, "Depth of field is not to be had: the project draws with the Compatibility renderer, which has no blur.")
	var motion := _section(box, "Motion")
	_slider(motion, "shake", "Handheld shake", 0.0, 1.0, shake, func(v: float) -> void: shake = v)
	_slider(motion, "push", "Push in with the bass", 0.0, 1.0, beat_push, func(v: float) -> void: beat_push = v)
	_slider(motion, "bump", "Bump on every beat", 0.0, 1.0, beat_bump, func(v: float) -> void: beat_bump = v)
	_slider(motion, "lag", "Camera lag (smooths every move)", 0.0, 1.0, lag, func(v: float) -> void: lag = v)


func _look_tab(box: VBoxContainer) -> void:
	var frogs_box := _section(box, "Frogs", "Clothes are off while the bodies are being worked on.")
	_toggle_box(frogs_box, "Clothes", Frog.clothed, func(on: bool) -> void: Frog.dress_all(get_tree(), on))
	_toggle_box(frogs_box, "Tongue in the open mouth", FrogRig.tongue_in_mouth, func(on: bool) -> void: FrogRig.tongue_in_mouth = on)
	var frame := _section(box, "Frame", "What is outside the frame is darkened; the frame is what renders.")
	var names := []
	for entry: Array in FRAME_NAMES:
		names.append(entry[1])
	_frame_buttons = _choices(frame, names, 0, func(k: int) -> void: _set_frame(FRAME_NAMES[k][0]), 3)
	_toggle_box(frame, "Instagram's safe areas (on a Reel)", safe_areas, func(on: bool) -> void:
		safe_areas = on
		_redraw())
	_toggle_box(frame, "Rule of thirds", thirds, func(on: bool) -> void:
		thirds = on
		_redraw())
	_toggle_box(frame, "Letterbox bars (in the film)", letterbox, func(on: bool) -> void:
		letterbox = on
		_redraw())
	var picture := _section(box, "Picture")
	_look_slider(picture, "exposure", "Exposure", 0.2, 2.0)
	_look_slider(picture, "brightness", "Brightness", 0.5, 1.6)
	_look_slider(picture, "contrast", "Contrast", 0.5, 1.8)
	_look_slider(picture, "saturation", "Saturation", 0.0, 2.0)
	_look_slider(picture, "haze", "Haze", 0.0, 0.02, 0.0005)
	_look_slider(picture, "sun", "Sun", 0.0, 2.0)
	var retro := _section(box, "Retro")
	_look_slider(retro, "pixels", "Pixels (1 is off)", 1.0, 12.0, 1.0)
	_look_slider(retro, "levels", "Colours (0 is all)", 0.0, 16.0, 1.0)
	_button(box, "↺  Reset the picture", func() -> void:
		look = _default_look()
		for key: String in look:
			_set_slider("look_" + key, look[key])
		_apply_look())


func _look_slider(box: Container, key: String, text: String, low: float, high: float, step := 0.01) -> void:
	_slider(box, "look_" + key, text, low, high, float(look.get(key, low)), func(v: float) -> void:
		look[key] = v
		_apply_look(), Callable(), step)


func _moves_tab(box: VBoxContainer) -> void:
	var moves := _section(box, "Keys", "A move: put the camera where you want it (Fly, Orbit...), add a key, move it, add another. Path plays them.")
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	moves.add_child(row)
	_button(row, "+ Add key (K)", _add_key, "Keep where the camera is now")
	_button(row, "↻ Update", _update_key, "The chosen key to where the camera is now")
	_button(row, "◎ Go to", _go_to_key, "Put the camera at the chosen key (to fly on from it)")
	_button(row, "▲ Earlier", func() -> void: _shift_key(-1), "Swap the chosen key with the one before")
	_button(row, "▼ Later", func() -> void: _shift_key(1), "Swap the chosen key with the one after")
	_button(row, "✕ Remove", _remove_key)
	_list = ItemList.new()
	_list.custom_minimum_size.y = 130
	_list.focus_mode = Control.FOCUS_NONE
	moves.add_child(_list)
	_button(moves, "Clear all keys", func() -> void:
		keys.clear()
		_refresh_keys())
	var timing := _section(box, "Timing")
	_choices(timing, ["In seconds", "In beats"], 0, func(k: int) -> void:
		keys_in_beats = k == 1
		_refresh_keys())
	_slider(timing, "gap", "Between new keys", 1.0, 16.0, key_gap, func(v: float) -> void: key_gap = v,
			func(v: float) -> String: return "%.1f %s" % [v, "beats" if keys_in_beats else "s"], 0.5)
	_note(timing, "While a song plays, a key is put at the time it is added.")
	_option(timing, EASES, func(i: int) -> void: ease = i)
	_toggle_box(timing, "Loop", loop, func(on: bool) -> void: loop = on)
	var play := HBoxContainer.new()
	timing.add_child(play)
	_button(play, "▶  Play the path", func() -> void: _set_mode("path"))
	_button(play, "■  Stop", func() -> void: _set_mode("free"))
	var takes := _section(box, "Takes", "The keys, the lens and the look. Saved in this browser." if OS.has_feature("web") else "The keys, the lens and the look. Saved in user://takes.")
	var name_row := HBoxContainer.new()
	takes.add_child(name_row)
	_take_name = LineEdit.new()
	_take_name.text = "take1"
	_take_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_take_name)
	if OS.has_feature("web"):
		# (the browser asks for the name: Godot's own typing on a phone can swallow touches)
		_take_name.editable = false
	var save := _button(name_row, "Save", func() -> void:
		var name := _ask("Name this take", _take_name.text) if OS.has_feature("web") else _take_name.text
		if name.strip_edges() == "":
			return
		_take_name.text = name.strip_edges().validate_filename()
		save_take(_take_name.text)
		_refresh_takes())
	save.size_flags_horizontal = Control.SIZE_FILL
	var share := HBoxContainer.new()
	takes.add_child(share)
	_button(share, "Copy take", func() -> void:
		DisplayServer.clipboard_set(JSON.stringify(_take()))
		_status.text = "Copied %s (%d keys): paste it into the desk on the computer (or send it there)." % [_take_name.text, keys.size()],
			"The take as text, to paste into the desk somewhere else")
	_button(share, "Paste take", _paste_take, "A take copied from the desk somewhere else")
	_take_pick = _option(takes, [], func(i: int) -> void:
		var name := _take_pick.get_item_text(i)
		_take_name.text = name
		load_take(name))
	_refresh_takes()


func _render_tab(box: VBoxContainer) -> void:
	var what := _section(box, "What to film")
	_song_pick = _option(what, [], func(_i: int) -> void: pass)
	var times := GridContainer.new()
	times.columns = 3
	times.add_theme_constant_override("h_separation", 6)
	what.add_child(times)
	_from = _spin(times, "From", 0.0)
	_button(times, "◀ Now", func() -> void: _from.value = player.time if player else 0.0, "From where the song is now")
	_to = _spin(times, "To", 30.0)
	_button(times, "◀ Now", func() -> void: _to.value = player.time if player else 30.0, "To where the song is now")
	_button(what, "The whole song", func() -> void:
		_from.value = 0.0
		if player and not player.tracks.is_empty():
			_to.value = float(player.tracks[maxi(_song_pick.selected, 0)].get("seconds", 30.0)))
	var how := _section(box, "How")
	_render_label = _note(how, "")
	_choices(how, ["30 fps", "60 fps"], 0, func(k: int) -> void: _fps = 30 if k == 0 else 60)
	var names := []
	for entry: Array in QUALITIES:
		names.append(entry[0])
	_choices(how, names, _quality, func(k: int) -> void: _quality = k)
	_note(how, "The camera, lens, look and letterbox go into the film as they are set now (Fly is filmed from where it is).")
	if OS.has_feature("web"):
		var away := _section(box, "Films are made on the computer")
		_note(away, "The browser cannot film. Make the move here and save it, then Copy take (on Moves), paste it into the desk on the computer (Paste take) and render it there.")
		return
	var go := _button(box, "●  Render the film", _render)
	go.custom_minimum_size.y = 46
	go.add_theme_stylebox_override("normal", _box(RUST, 10, AMBER))
	go.add_theme_stylebox_override("hover", _box(RUST.lightened(0.15), 10, CREAM))
	go.add_theme_font_size_override("font_size", 17)
	_button(box, "Open the renders folder", func() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders"))
		OS.shell_open(ProjectSettings.globalize_path("res://renders")))


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
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spin)
	return spin


## Fills the lists that depend on the scene (call once everything is aboard).
func setup() -> void:
	look = _default_look()
	for key: String in look:
		_set_slider("look_" + key, look[key])
	var who: FlowContainer = _target_buttons.box
	for k in frogs.size():
		var label: String = frogs[k][0]
		if label.begins_with("Dancer"):
			_dancers.add_item(label)
			continue
		var button := Button.new()
		button.text = label.trim_prefix("The ").capitalize()
		button.toggle_mode = true
		button.button_group = _target_buttons.group
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.button_pressed = k == _target_index
		var index := k
		button.pressed.connect(func() -> void: _pick_target(index))
		who.add_child(button)
		_target_buttons[k] = button
	_refresh_songs()


## The song lists (the Song tab's and the Render tab's) as the player has them.
func _refresh_songs() -> void:
	_songs.clear()
	_song_pick.clear()
	for track: Dictionary in player.tracks:
		var title := str(track.get("title", track.get("song", "?")))
		var artist := str(track.get("artist", ""))
		var seconds := float(track.get("seconds", 0.0))
		_songs.add_item("%s%s   %s" % [title, ("  —  " + artist) if artist != "" else "", _clock(seconds)])
		_song_pick.add_item(title)
	if not player.tracks.is_empty():
		_to.value = float(player.tracks[0].get("seconds", 30.0))
	_refresh_render_label()


func _dancer_indexes() -> Array:
	var out := []
	for k in frogs.size():
		if String(frogs[k][0]).begins_with("Dancer"):
			out.append(k)
	return out


func _pick_target(index: int) -> void:
	_target_index = index
	_orbit_slide = Vector3.ZERO
	for k: Variant in _target_buttons:
		if k is int:
			(_target_buttons[k] as Button).set_pressed_no_signal(k == index)
	if not String(frogs[index][0]).begins_with("Dancer"):
		_dancers.select(0)
	# (a frog from in front of it, close; the boat from well off)
	var target: Node3D = frogs[index][1]
	if target is Frog:
		var front := boat.global_basis.orthonormalized() * Vector3(sin((target as Frog).facing_yaw), 0.0, cos((target as Frog).facing_yaw))
		_orbit_yaw = atan2(front.x, front.z) + 0.35
		_orbit_distance = 3.5
		_orbit_height = 1.3
		_orbit_pitch = deg_to_rad(10.0)
	else:
		_orbit_distance = 30.0
		_orbit_height = 3.0
		_orbit_pitch = deg_to_rad(20.0)
	_set_slider("aim", _orbit_height)
	_set_slider("distance", _orbit_distance)
	_set_slider("pitch", rad_to_deg(_orbit_pitch))
	if camera_mode not in ["orbit", "follow"]:
		_set_mode("orbit")


static func _clock(seconds: float) -> String:
	var whole := int(maxf(seconds, 0.0))
	return "%d:%02d" % [whole / 60, whole % 60]


## Shows or hides the panel (the bar, and the button that does it, stay).
func show_panel(on: bool) -> void:
	_panel.visible = on
	_toggle.set_pressed_no_signal(on)


## Shows or hides everything (but a button to bring it back).
func show_ui(on: bool) -> void:
	_ui.visible = on
	_show_ui.visible = not on


## Nothing of the desk on screen (rendering a film, or photographing the show). Letterbox bars stay.
func hide_all() -> void:
	_ui.visible = false
	_show_ui.visible = false


func _pixels() -> Pixelate:
	return get_tree().current_scene.get(&"pixels") if get_tree().current_scene else null


func _redraw() -> void:
	_shade.queue_redraw()
	_bars.queue_redraw()


## Sizes the desk for the screen. On a computer it is laid out for 1280 × 720 and scaled with the
## window; on a phone (under 600 of the browser's pixels across its short side) at the phone's own
## size, so its writing is as big as the phone's. Held upright, the desk goes under the picture.
func _fit() -> void:
	var window := get_window()
	var screen := Vector2(window.size) / maxf(DisplayServer.screen_get_scale(), 1.0)
	_phone = minf(screen.x, screen.y) < 600.0
	var want := Vector2i(screen.round()) if _phone else Vector2i(1280, 720)
	if window.content_scale_size != want:
		window.content_scale_size = want
	var size := get_viewport().get_visible_rect().size
	var upright := _phone and size.x < size.y
	for thing: Control in _wide_only:
		thing.visible = not _phone
	for button: Button in _short_names:
		button.text = _short_names[button][1 if _phone else 0]
		button.custom_minimum_size.x = 44.0 if _phone else _short_names[button][2]
	# (upright, the song and where it is have a row of their own over the buttons)
	if upright != (_now_box.get_parent() == _bar_top):
		_now_box.reparent(_bar_top if upright else _bar_row, false)
		if not upright:
			_bar_row.move_child(_now_box, 1)
	_bar_top.visible = upright
	var edge := 6.0 if _phone else 12.0
	_bar.offset_left = edge
	_bar.offset_right = -edge
	_bar.offset_bottom = -edge
	_bar.offset_top = -edge - (0.0 if _phone else BAR_HEIGHT)
	_place_panel()
	_redraw()


## The panel beside the picture, over the bar; on an upright phone under it, across the bottom half.
func _place_panel() -> void:
	if _panel == null:
		return
	var size := get_viewport().get_visible_rect().size
	var edge := 6.0 if _phone else 12.0
	var above := _bar.size.y + edge * 2.0
	if _phone and size.x < size.y:
		_panel.anchor_left = 0.0
		_panel.anchor_top = 0.5
		_panel.offset_left = edge
		_panel.offset_top = 0.0
	else:
		_panel.anchor_left = 1.0
		_panel.anchor_top = 0.0
		_panel.offset_left = -minf(PANEL_WIDTH, size.x * 0.5) - edge
		_panel.offset_top = edge
	_panel.offset_right = -edge
	_panel.offset_bottom = -above


# --- Playing ---

func _play_pause() -> void:
	if player.playing:
		player.toggle_pause()
	elif not player.tracks.is_empty():
		player.play(maxi(player.index, 0))


func _seek_to(share: float) -> void:
	if player == null or player.tracks.is_empty() or player.index < 0:
		return
	player.play(player.index, share * float(player.track.get("seconds", 0.0)))


func _show_playing() -> void:
	if player == null:
		return
	_play.text = "▶" if not player.playing or player.paused() else "❚❚"
	var length := float(player.track.get("seconds", 0.0))
	var title := str(player.track.get("title", "")) if player.index >= 0 else ""
	if title == "" and player.index >= 0:
		title = str(player.track.get("song", "")).get_basename().capitalize()
	_now_title.text = title if title != "" else "Frogulizer"
	_now_artist.text = str(player.track.get("artist", "")) if player.index >= 0 else ("%d songs aboard" % player.tracks.size())
	_time_label.text = _clock(player.time)
	_length_label.text = _clock(length)
	if not _seeking:
		_seek.set_value_no_signal(player.progress() if player.index >= 0 else 0.0)
	var shot := director.shot() if director else ""
	var shot_name: String = SHOT_NAMES.get(shot, shot.capitalize())
	match camera_mode:
		"auto", "shot":
			_camera_label.text = "%s · %s" % [MODE_NAMES[camera_mode], shot_name]
		"orbit", "follow":
			_camera_label.text = "%s · %s" % [MODE_NAMES[camera_mode], String(frogs[_target_index][0]).trim_prefix("The ") if not frogs.is_empty() else "the boat"]
		_:
			_camera_label.text = MODE_NAMES.get(camera_mode, camera_mode)
	for name: String in _shot_buttons:
		(_shot_buttons[name] as Button).set_pressed_no_signal(camera_mode in ["auto", "shot"] and name == shot)
	if _songs and player.index >= 0 and player.index < _songs.item_count and not _songs.is_selected(player.index):
		_songs.select(player.index)


func _next_shot() -> void:
	if camera_mode != "auto":
		_set_mode("auto")
	director.cut_to()


# --- The frame ---

func _set_frame(kind: String) -> void:
	frame_kind = kind
	for k in FRAME_NAMES.size():
		(_frame_buttons[k] as Button).set_pressed_no_signal(FRAME_NAMES[k][0] == kind)
	_refresh_render_label()
	_redraw()


func _refresh_render_label() -> void:
	if _render_label == null:
		return
	var size: Vector2i = RENDER_SIZES[frame_kind]
	var name := "Free"
	for entry: Array in FRAME_NAMES:
		if entry[0] == frame_kind:
			name = entry[1]
	_render_label.text = "Frame: %s, %d × %d (set it on the Look tab)." % [name, size.x, size.y]


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
	if frame_kind != "free":
		var dark := Color(0.05, 0.02, 0.02, 0.78)
		_shade.draw_rect(Rect2(0, 0, rect.position.x, size.y), dark)
		_shade.draw_rect(Rect2(rect.end.x, 0, size.x - rect.end.x, size.y), dark)
		_shade.draw_rect(Rect2(rect.position.x, 0, rect.size.x, rect.position.y), dark)
		_shade.draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, size.y - rect.end.y), dark)
		_shade.draw_rect(rect, Color(AMBER, 0.7), false, 2.0)
		if frame_kind == "reel" and safe_areas:
			# Instagram's own things: the top bar, and the caption, buttons and audio line at the bottom and right
			var tint := Color(1.0, 0.3, 0.3, 0.13)
			_shade.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.13)), tint)
			_shade.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.75), Vector2(rect.size.x, rect.size.y * 0.25)), tint)
			_shade.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.45), Vector2(rect.size.x * 0.16, rect.size.y * 0.3)), tint)
	if thirds:
		for k: int in [1, 2]:
			var x := rect.position.x + rect.size.x * k / 3.0
			var y := rect.position.y + rect.size.y * k / 3.0
			_shade.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(1, 1, 1, 0.14))
			_shade.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(1, 1, 1, 0.14))


## The letterbox: the frame cut down to 2.39:1 by black bars (if it is wider than that, at its sides).
func _draw_bars() -> void:
	if not letterbox:
		return
	var rect := frame_rect()
	var wide := 2.39
	if rect.size.x / rect.size.y < wide:
		var bar := (rect.size.y - rect.size.x / wide) * 0.5
		_bars.draw_rect(Rect2(rect.position, Vector2(rect.size.x, bar)), Color.BLACK)
		_bars.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - bar), Vector2(rect.size.x, bar)), Color.BLACK)


# --- The picture ---

func _default_look() -> Dictionary:
	var environment: Environment = river.environment if river else null
	return {"exposure": environment.tonemap_exposure if environment else 1.0, "brightness": 1.0, "contrast": 1.0, "saturation": 1.0,
			"haze": environment.fog_density if environment else 0.0, "sun": river.sun.light_energy if river and river.sun else 1.0,
			"pixels": 1.0, "levels": 0.0}


func _apply_look() -> void:
	if river and river.environment:
		var environment := river.environment
		environment.tonemap_exposure = float(look.get("exposure", 1.0))
		environment.adjustment_enabled = true
		environment.adjustment_brightness = float(look.get("brightness", 1.0))
		environment.adjustment_contrast = float(look.get("contrast", 1.0))
		environment.adjustment_saturation = float(look.get("saturation", 1.0))
		environment.fog_density = float(look.get("haze", environment.fog_density))
	if river and river.sun:
		river.sun.light_energy = float(look.get("sun", river.sun.light_energy))
	var pixels := _pixels()
	if pixels:
		pixels.size = roundf(float(look.get("pixels", 1.0)))
		pixels.levels = roundf(float(look.get("levels", 0.0)))


# --- Driving the camera ---

func _set_mode(mode: String) -> void:
	camera_mode = mode
	for name: String in _mode_buttons:
		(_mode_buttons[name] as Button).set_pressed_no_signal(name == mode)
	match mode:
		"auto":
			director.mode = "auto"
		"shot":
			director.mode = director.shot() if director.mode in ["auto", "manual"] else director.mode
		"free":
			director.mode = "manual"
			var forward := -director.global_basis.z
			_fly_yaw = atan2(-forward.x, -forward.z)
			_fly_pitch = asin(clampf(forward.y, -1.0, 1.0))
			_fly_at = director.global_position
		"path":
			director.mode = "manual"
			_path_time = 0.0
		_:
			director.mode = "manual"


func _hold(shot: String) -> void:
	_set_mode("shot")
	director.mode = shot
	director.cut_to(shot)


func _reset_camera() -> void:
	focal = 28.0
	zoom = 1.0
	roll = 0.0
	shake = 0.15
	beat_push = 0.3
	beat_bump = 0.0
	lag = 0.0
	orbit_speed = 0.0
	_orbit_yaw = 0.6
	_orbit_pitch = 0.25
	_orbit_distance = 9.0
	_orbit_slide = Vector3.ZERO
	for entry: Array in [["focal", focal], ["zoom", zoom], ["roll", 0.0], ["shake", shake], ["push", beat_push], ["bump", beat_bump],
			["lag", lag], ["orbit_speed", orbit_speed], ["pitch", rad_to_deg(_orbit_pitch)], ["distance", _orbit_distance]]:
		_set_slider(entry[0], entry[1])


func _target() -> Node3D:
	if frogs.is_empty() or _target_index < 0 or _target_index >= frogs.size():
		return boat
	return frogs[_target_index][1]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				show_panel(not _panel.visible)
			KEY_H:
				show_ui(not _ui.visible)
			KEY_K:
				_add_key()
			KEY_SPACE:
				_play_pause()
			KEY_N:
				player.next()
			KEY_P:
				player.previous()
			KEY_C:
				_next_shot()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	# Fingers: one drags as the left mouse button does (the phone sends that too); two pinch in and
	# out and slide the orbit (or fly forward and back)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch = _spread()
		if _touches.size() >= 2:
			_dragging = 0
	elif event is InputEventScreenDrag:
		var middle := _middle()
		_touches[event.index] = event.position
		if _touches.size() == 1 and camera_mode in ["free", "orbit", "follow"]:
			# (one finger turns as the left button does; read here, not as the mouse Godot makes of it,
			# since a phone can lose the finger going down and send only the drag)
			_turn(event.relative * 0.005, MOUSE_BUTTON_LEFT)
		elif _touches.size() >= 2 and camera_mode in ["free", "orbit", "follow"]:
			var spread := _spread()
			if _pinch > 0.0 and spread > 0.0:
				_orbit_distance = clampf(_orbit_distance * _pinch / spread, 0.8, 60.0)
				_fly_at += -director.global_basis.z * (spread - _pinch) * 0.01 * _fly_speed
				_set_slider("distance", _orbit_distance)
			var move := (_middle() - middle) * 0.005
			if camera_mode != "free":
				var basis := director.global_basis
				_orbit_slide += (-basis.x * move.x + basis.y * move.y) * _orbit_distance * 0.4
			_pinch = spread
	if camera_mode in ["free", "orbit", "follow"]:
		if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event is InputEventMouseButton:
			if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				_dragging = event.button_index
			elif not event.pressed:
				_dragging = 0
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_orbit_distance = maxf(_orbit_distance * 0.9, 0.8)
				_fly_speed = minf(_fly_speed * 1.15, 40.0)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_orbit_distance = minf(_orbit_distance * 1.1, 60.0)
				_fly_speed = maxf(_fly_speed / 1.15, 0.3)
			_set_slider("distance", _orbit_distance)
			_set_slider("fly_speed", _fly_speed)
		elif event is InputEventMouseMotion and _dragging != 0:
			_turn(event.relative * 0.005, _dragging)


## A drag with a mouse button (or a finger): looks round in Fly, slides (the middle button) or turns round the orbit.
func _turn(move: Vector2, button: int) -> void:
	if camera_mode == "free" and button in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_LEFT]:
		_fly_yaw -= move.x
		_fly_pitch = clampf(_fly_pitch - move.y, -1.5, 1.5)
	elif button == MOUSE_BUTTON_MIDDLE:
		var basis := director.global_basis
		_orbit_slide += (-basis.x * move.x + basis.y * move.y) * _orbit_distance * 0.4
	elif button == MOUSE_BUTTON_LEFT and camera_mode != "free":
		_orbit_yaw -= move.x
		_orbit_pitch = clampf(_orbit_pitch + move.y, deg_to_rad(-15.0), deg_to_rad(80.0))
		_set_slider("pitch", rad_to_deg(_orbit_pitch))


func _spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var at: Array = _touches.values()
	return (at[0] as Vector2).distance_to(at[1])


func _middle() -> Vector2:
	if _touches.size() < 2:
		return Vector2.ZERO
	var at: Array = _touches.values()
	return ((at[0] as Vector2) + (at[1] as Vector2)) * 0.5


func _process(delta: float) -> void:
	_poll_render()
	_tick -= delta
	if _tick <= 0.0 and _ui.visible:
		_tick = 0.1
		_show_playing()
	if director == null or boat == null:
		return
	# Where the camera is, by its way of working (the Director has aimed its own shots already)
	match camera_mode:
		"free":
			_fly(delta)
		"orbit", "follow":
			_orbit(delta)
		"path":
			_play_path(delta)
	var manual := camera_mode not in ["auto", "shot"]
	# Lag: the camera eased after where it should be (on the boat, so the boat's going is not lag);
	# a cut, or a new way of working, is not eased
	var shot := director.shot()
	var here := boat.global_transform.affine_inverse() * director.global_transform
	if not _smooth_ready or shot != _last_shot or camera_mode != _last_mode or lag <= 0.001 or here.origin.distance_to(_smooth.origin) > 6.0:
		_smooth = here
		_smooth_ready = true
	else:
		var keep := 1.0 - exp(-lerpf(30.0, 0.8, pow(lag, 0.5)) * delta)
		_smooth = Transform3D(Basis(_smooth.basis.get_rotation_quaternion().slerp(here.basis.get_rotation_quaternion(), keep)),
				_smooth.origin.lerp(here.origin, keep))
	_last_shot = shot
	_last_mode = camera_mode
	director.global_transform = boat.global_transform * _smooth
	# The lens, roll, shake and the beat
	if manual:
		director.fov = _vertical_fov()
	else:
		director.fov = clampf(director.fov / zoom, 4.0, 120.0)
	director.rotate_object_local(Vector3.BACK, roll)
	var now := Time.get_ticks_msec() * 0.001
	director.position += director.global_basis * Vector3(sin(now * 0.7) + 0.5 * sin(now * 2.3), sin(now * 1.1) + 0.4 * sin(now * 2.9), 0.0) * 0.03 * shake
	if Groove.playing:
		var punch := Groove.bass * 0.03 * beat_push * (1.0 if manual else 0.6) + Groove.pulse(9.0) * 0.06 * beat_bump
		director.fov *= 1.0 - punch


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
	# (the buttons on the panel, or the keys: WASD, Q and E, the arrows, shift)
	var held := func(name: String, key: Key) -> float: return 1.0 if _held.has(name) or Input.is_key_pressed(key) else 0.0
	var go := Vector3(held.call("right", KEY_D) - held.call("left", KEY_A), held.call("up", KEY_E) - held.call("down", KEY_Q),
			held.call("back", KEY_S) - held.call("forward", KEY_W))
	_fly_yaw += (held.call("turn_left", KEY_LEFT) - held.call("turn_right", KEY_RIGHT)) * delta * 1.2
	_fly_pitch = clampf(_fly_pitch + (held.call("look_up", KEY_UP) - held.call("look_down", KEY_DOWN)) * delta * 0.9, -1.5, 1.5)
	var basis := Basis.from_euler(Vector3(_fly_pitch, _fly_yaw, 0.0))
	var fast := 3.0 if held.call("fast", KEY_SHIFT) > 0.0 else 1.0
	# (it goes along with the boat, so a shot held still stays on the boat)
	_fly_at += basis * go * _fly_speed * fast * delta + boat.global_basis.z * boat.speed * delta
	director.global_transform = Transform3D(basis, _fly_at)


func _orbit(delta: float) -> void:
	_orbit_yaw += deg_to_rad(orbit_speed) * delta
	var target := _target()
	var centre := target.global_position + Vector3.UP * _orbit_height + _orbit_slide
	var yaw := _orbit_yaw
	if camera_mode == "follow" and target is Frog:
		yaw += (target as Frog).facing_yaw + PI
	var offset := Vector3(sin(yaw) * cos(_orbit_pitch), sin(_orbit_pitch), cos(yaw) * cos(_orbit_pitch)) * _orbit_distance
	director.look_at_from_position(centre + offset, centre)


# --- Moves ---

func _camera_key() -> Dictionary:
	var local := boat.global_transform.affine_inverse() * director.global_transform
	return {"at": local.origin, "basis": local.basis.orthonormalized().get_rotation_quaternion(), "focal": focal, "roll": roll}


func _add_key() -> void:
	var key := _camera_key()
	var time := (Groove.beat if keys_in_beats else (player.time if player else 0.0))
	if keys.is_empty():
		time = 0.0 if not Groove.playing else time
	elif not Groove.playing or time <= float(keys[-1].time):
		time = float(keys[-1].time) + key_gap
	key["time"] = time
	keys.append(key)
	_refresh_keys()
	_list.select(keys.size() - 1)
	_status.text = "Key %d added." % keys.size()


func _chosen_key() -> int:
	var picked := _list.get_selected_items()
	return picked[0] if not picked.is_empty() else -1


func _update_key() -> void:
	var k := _chosen_key()
	if k < 0:
		_status.text = "Choose a key in the list first."
		return
	var key := _camera_key()
	key["time"] = keys[k].time
	keys[k] = key
	_refresh_keys()
	_list.select(k)


func _go_to_key() -> void:
	var k := _chosen_key()
	if k < 0:
		return
	var key: Dictionary = keys[k]
	_set_mode("free")
	var place := boat.global_transform * Transform3D(Basis(key.basis as Quaternion), key.at)
	_fly_at = place.origin
	var forward := -place.basis.z
	_fly_yaw = atan2(-forward.x, -forward.z)
	_fly_pitch = asin(clampf(forward.y, -1.0, 1.0))
	focal = key.focal
	roll = key.roll
	_set_slider("focal", focal)
	_set_slider("roll", rad_to_deg(roll))


func _shift_key(way: int) -> void:
	var k := _chosen_key()
	var other := k + way
	if k < 0 or other < 0 or other >= keys.size():
		return
	# (the places swap; the times stay in order)
	var time_k: float = keys[k].time
	var time_other: float = keys[other].time
	var moved: Dictionary = keys[k]
	keys[k] = keys[other]
	keys[other] = moved
	keys[k].time = time_k
	keys[other].time = time_other
	_refresh_keys()
	_list.select(other)


func _remove_key() -> void:
	var k := _chosen_key()
	if k < 0:
		if not keys.is_empty():
			keys.pop_back()
	else:
		keys.remove_at(k)
	_refresh_keys()


func _refresh_keys() -> void:
	if _list == null:
		return
	_list.clear()
	for k in keys.size():
		_list.add_item("%d    at %.1f %s    %d mm%s" % [k + 1, float(keys[k].time) - float(keys[0].time), "beats" if keys_in_beats else "s",
				int(keys[k].focal), ("    roll %d°" % rad_to_deg(float(keys[k].roll))) if absf(float(keys[k].roll)) > 0.01 else ""])
	changed.emit()


## Where the path is at time `t` (from its first key): between the keys' places as `ease` says
## (Catmull-Rom, straight, eased, or cut), slerp between their turns.
func path_at(t: float) -> Dictionary:
	if keys.is_empty():
		return {}
	var start := float(keys[0].time)
	var length := float(keys[-1].time) - start
	if loop and length > 0.001:
		t = fposmod(t, length)
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
	var at: Vector3
	match ease:
		1:
			at = (a.at as Vector3).lerp(b.at, u)
		2:
			u = u * u * (3.0 - 2.0 * u)
			at = (a.at as Vector3).lerp(b.at, u)
		3:
			u = 0.0
			at = a.at
		_:
			u = u * u * (3.0 - 2.0 * u) if keys.size() == 2 else u
			var p0: Vector3 = keys[maxi(i - 1, 0)].at
			var p3: Vector3 = keys[mini(i + 2, keys.size() - 1)].at
			at = (a.at as Vector3).cubic_interpolate(b.at, p0, p3, u)
	return {"at": at, "basis": (a.basis as Quaternion).slerp(b.basis, u), "focal": lerpf(a.focal, b.focal, u), "roll": lerpf(a.roll, b.roll, u)}


func _play_path(delta: float) -> void:
	if keys.is_empty():
		return
	_path_time = (Groove.beat - float(keys[0].time) if keys_in_beats and Groove.playing else _path_time + delta)
	var at := path_at(_path_time)
	director.global_transform = boat.global_transform * Transform3D(Basis(at.basis), at.at)
	focal = at.focal
	roll = at.roll


## The take as it is now: the keys, how they are played, and the desk's lens and look.
func _take() -> Dictionary:
	var out := []
	for key: Dictionary in keys:
		var q: Quaternion = key.basis
		out.append({"at": [key.at.x, key.at.y, key.at.z], "basis": [q.x, q.y, q.z, q.w], "focal": key.focal, "roll": key.roll, "time": key.time})
	return {"name": _take_name.text if _take_name else "", "keys": out, "beats": keys_in_beats, "frame": frame_kind, "ease": ease, "loop": loop, "desk": state()}


func save_take(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://takes")
	var file := FileAccess.open("user://takes/%s.json" % name, FileAccess.WRITE)
	file.store_string(JSON.stringify(_take(), "\t"))
	if _status:
		_status.text = "Saved %s (%d keys)%s" % [name, keys.size(), "." if OS.has_feature("web") else " in " + ProjectSettings.globalize_path("user://takes")]


func load_take(name: String) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://takes/%s.json" % name))
	if not data is Dictionary:
		if _status:
			_status.text = "No take called %s" % name
		return false
	_use_take(data)
	if _status:
		_status.text = "Loaded %s (%d keys)." % [name, keys.size()]
	return true


## A take copied from the desk somewhere else (the phone's, say): used, and saved here under its name.
func _paste_take() -> void:
	var text := _ask("Paste the take here", "") if OS.has_feature("web") else DisplayServer.clipboard_get()
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not data.has("keys"):
		_status.text = "That is not a take: copy one with Copy take, then paste it."
		return
	_use_take(data)
	var name := str(data.get("name", "")).validate_filename()
	_take_name.text = name if name != "" else "pasted"
	save_take(_take_name.text)
	_refresh_takes()
	_status.text = "Pasted %s (%d keys) and saved it." % [_take_name.text, keys.size()]


## The browser's own box for typing in (on the web only).
func _ask(question: String, answer: String) -> String:
	var said: Variant = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(question), JSON.stringify(answer)], true)
	return str(said) if said != null else ""


func _use_take(data: Dictionary) -> void:
	keys.clear()
	for key: Dictionary in data.keys:
		keys.append({"at": Vector3(key.at[0], key.at[1], key.at[2]), "basis": Quaternion(key.basis[0], key.basis[1], key.basis[2], key.basis[3]),
				"focal": key.focal, "roll": key.roll, "time": key.time})
	keys_in_beats = data.get("beats", false)
	ease = int(data.get("ease", 0))
	loop = bool(data.get("loop", false))
	if data.get("desk") is Dictionary:
		_use_state(data.desk)
	if FRAMES.has(str(data.get("frame", ""))) and not _frame_buttons.is_empty():
		_set_frame(str(data.frame))
	_refresh_keys()


func _refresh_takes() -> void:
	if _take_pick == null:
		return
	_take_pick.clear()
	_take_pick.add_item("Load a take...")
	_take_pick.set_item_disabled(0, true)
	var dir := DirAccess.open("user://takes")
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".json") and not file.begins_with("_"):
			_take_pick.add_item(file.get_basename())


# --- Rendering ---

## Everything about the camera and the picture, for a render to set up as it is here.
func state() -> Dictionary:
	return {"camera": camera_mode, "shot": director.mode if camera_mode == "shot" else "", "focal": focal, "zoom": zoom, "roll": roll,
			"shake": shake, "push": beat_push, "bump": beat_bump, "lag": lag, "look": look, "letterbox": letterbox, "target": _target_index,
			"orbit": [_orbit_yaw, _orbit_pitch, _orbit_distance, _orbit_height, orbit_speed, _orbit_slide.x, _orbit_slide.y, _orbit_slide.z],
			"pace": director.pace, "cut_on_phrase": director.cut_on_phrase, "cut_to_soloist": director.cut_to_soloist,
			"shot_list": director.shot_list}


## Sets up a render (main.gd, with `--render`): the camera and the picture as the desk had them, none of the desk on screen.
func apply_render(settings: Dictionary) -> void:
	hide_all()
	var desk: Dictionary = settings.get("desk", {}).duplicate()
	if not desk.has("focal"):
		desk["focal"] = float(settings.get("focal", 28.0))
	if not desk.has("look"):
		desk["look"] = {"pixels": float(settings.get("pixels", 1.0)), "levels": float(settings.get("levels", 0.0))}
	_use_state(desk)
	match String(settings.get("camera", desk.get("camera", "auto"))):
		"path":
			load_take(String(settings.get("take", "_render")))
			_set_mode("path")
		"shot":
			_set_mode("shot")
			director.mode = String(settings.get("shot", "audience"))
		"orbit", "follow":
			_set_mode(String(settings.camera))
		_:
			_set_mode("auto")
	# (the film is the frame: the window is made its size)
	frame_kind = "free"
	_redraw()


## The lens, the look and the camera's settings from `state()`, and the desk's controls set to match.
func _use_state(desk: Dictionary) -> void:
	focal = float(desk.get("focal", 28.0))
	zoom = float(desk.get("zoom", 1.0))
	roll = float(desk.get("roll", 0.0))
	shake = float(desk.get("shake", 0.15))
	beat_push = float(desk.get("push", 0.3))
	beat_bump = float(desk.get("bump", 0.0))
	lag = float(desk.get("lag", 0.0))
	letterbox = bool(desk.get("letterbox", false))
	look = _default_look()
	look.merge(desk.get("look", {}), true)
	_apply_look()
	director.pace = float(desk.get("pace", 1.0))
	director.cut_on_phrase = bool(desk.get("cut_on_phrase", true))
	director.cut_to_soloist = bool(desk.get("cut_to_soloist", true))
	if desk.has("shot_list"):
		director.shot_list = desk.shot_list
	_target_index = int(desk.get("target", 0))
	var orbit: Array = desk.get("orbit", [])
	if orbit.size() >= 8:
		_orbit_yaw = orbit[0]
		_orbit_pitch = orbit[1]
		_orbit_distance = orbit[2]
		_orbit_height = orbit[3]
		orbit_speed = orbit[4]
		_orbit_slide = Vector3(orbit[5], orbit[6], orbit[7])
	for entry: Array in [["focal", focal], ["zoom", zoom], ["roll", rad_to_deg(roll)], ["shake", shake], ["push", beat_push],
			["bump", beat_bump], ["lag", lag], ["pace", director.pace], ["distance", _orbit_distance], ["pitch", rad_to_deg(_orbit_pitch)],
			["aim", _orbit_height], ["orbit_speed", orbit_speed]]:
		_set_slider(entry[0], entry[1])
	for key: String in look:
		_set_slider("look_" + key, look[key])
	_redraw()


func _render() -> void:
	if _render_pid > 0 and OS.is_process_running(_render_pid):
		_status.text = "Already rendering..."
		return
	if FileAccess.file_exists("res://override.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://override.cfg"))
	var song := maxi(_song_pick.selected, 0)
	var size: Vector2i = RENDER_SIZES[frame_kind]
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://renders"))
	_render_out = ProjectSettings.globalize_path("res://renders/frogulizer_%s" % stamp)
	# The camera goes to the render as a take: the path; Fly as a path of one key, where it is
	var camera := camera_mode
	var saved_keys := keys.duplicate()
	if camera == "free":
		keys = [_camera_key()]
		keys[0]["time"] = 0.0
		camera = "path"
	var take := "_render"
	save_take(take)
	keys = saved_keys
	var settings := {"song": song, "song_file": player.tracks[song].song if song < player.tracks.size() else "", "from": _from.value, "to": _to.value, "camera": camera, "shot": director.mode, "take": take, "desk": state()}
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
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--write-movie", _render_out + ".avi", "--fixed-fps", str(_fps),
			"--", "--render", ProjectSettings.globalize_path("user://render.json")]
	_render_pid = OS.create_process(OS.get_executable_path(), args)
	_status.text = "Rendering %s (%.0f to %.0f s) at %d × %d, %d fps..." % [_song_pick.get_item_text(song), _from.value, _to.value, size.x, size.y, _fps]


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
	var quality: Array = QUALITIES[_quality]
	var out := []
	var code := OS.execute(FFMPEG, ["-y", "-v", "error", "-i", avi, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", str(quality[1]), "-preset", quality[2],
			"-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", _render_out + ".mp4"], out, true)
	_status.text = ("Made %s.mp4" % _render_out) if code == 0 else ("ffmpeg could not make the .mp4 (the .avi is there): %s" % str(out))
