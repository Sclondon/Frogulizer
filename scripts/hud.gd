class_name Hud
extends CanvasLayer
## What is on the screen over the show besides the camera desk (which has all the controls): the
## song's title and who it is by, shown as it starts and then faded (it is in the film).

const INK := Color(0.98, 0.92, 0.78)
const SHADOW := Color(0.18, 0.07, 0.05, 0.85)

var player: TrackPlayer
## Whether a song's title is shown as it starts (the desk's Song tab sets it).
var titles := true
var _title: Label
var _artist: Label
var _title_for := 99.0


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# The title, top left
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_left = 26
	box.offset_top = 20
	box.offset_right = -26
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_title = _label(36, true)
	_artist = _label(20, false)
	box.add_child(_title)
	box.add_child(_artist)
	box.modulate.a = 0.0


func _label(size: int, serif: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", CameraDesk.font())
	if serif:
		label.add_theme_font_override("font", CameraDesk.font(true))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A song has started: its title and who it is by, shown for a while.
func show_title(track: Dictionary) -> void:
	_title.text = track.get("title", "")
	_artist.text = track.get("artist", "")
	_title_for = 0.0 if titles else 99.0


func _process(delta: float) -> void:
	_title_for += delta
	var box := _title.get_parent() as Control
	box.modulate.a = clampf(minf(_title_for * 1.5, (6.0 - _title_for) * 0.8), 0.0, 1.0)
