extends Node3D
## The frog viewer (viewer.tscn): the three bodies side by side on a plain floor, in the real toon
## shading, to look the models over. Everything is on the panel at the right: the outfit, the
## expression, an emote, warts, ink outlines, blinking (how quick, and how far one eye is behind the
## other), and where to look from. Drag on the picture to turn round them, the wheel to come closer,
## right-drag to slide.
## (From the command line it can also save a picture: `godot --path . res://viewer.tscn -- <file.png> [expression] [close|front|side|back|three-quarter|feet] [outfit number]`.)

const OUTFITS := [
	["Bare", {}], ["Tails and top hat", {"coat": "tails", "neck": "bow", "legs": "trousers", "hat": "top"}],
	["Gown and bonnet", {"coat": "dress", "hat": "bonnet"}], ["Band uniform", {"coat": "band", "legs": "trousers", "hat": "shako"}],
	["Frock coat", {"coat": "frock", "neck": "cravat", "legs": "trousers", "hat": "bowler"}],
	["Waistcoat and cap", {"coat": "waistcoat", "neck": "scarf", "legs": "breeches", "hat": "cap"}],
]
const VIEWS := [["Front", 0.0, 0.1, 4.2], ["Three-quarter", 0.6, 0.15, 4.2], ["Side", 1.57, 0.05, 4.2], ["Back", 3.14, 0.15, 4.2],
		["Faces", 0.3, 0.05, 1.6], ["Feet", 0.5, -0.1, 1.6], ["Eye backs", 3.5, 0.55, 1.3]]

var frogs: Array[Frog] = []
var _outfit := 0
var _warts := false
var _lines := true
var _blink_time := 0.16
var _blink_gap := 0.0
var _camera: Camera3D
var _yaw := 0.3
var _pitch := 0.15
var _distance := 4.2
var _centre := Vector3(0.0, 0.8, 0.0)
var _drag := 0
var _expression: OptionButton
var _emote: OptionButton


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.4, 0.44)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.52, 0.55)
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.5, -0.6, -0.7), Vector3.UP)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	floor_mesh.material_override = FrogToon.material(Color(0.62, 0.5, 0.36))
	add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	add_child(_camera)
	_panel()
	_make()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].ends_with(".png"):
		if args.size() > 1:
			_set_expression(args[1])
		if args.size() > 2:
			# (a view by name: close is the faces)
			var names := VIEWS.map(func(v: Array) -> String: return String(v[0]).to_lower())
			_view(4 if args[2] == "close" else maxi(names.find(args[2]), 0))
		if args.size() > 3:
			_outfit = int(args[3])
			_lines = not (args.size() > 4 and args[4] == "nolines")
			_make()
		_shoot(args[0])


# --- The panel ---

func _panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -270
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.08, 0.85)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_heading(box, "Frog viewer")
	_heading(box, "Outfit")
	var outfit := OptionButton.new()
	for entry: Array in OUTFITS:
		outfit.add_item(entry[0])
	outfit.item_selected.connect(func(i: int) -> void:
		_outfit = i
		_make())
	box.add_child(outfit)
	_heading(box, "Face")
	_expression = OptionButton.new()
	for name: String in FrogRig.EXPRESSIONS:
		_expression.add_item(name.capitalize())
	_expression.item_selected.connect(func(i: int) -> void: _set_expression(FrogRig.EXPRESSIONS.keys()[i]))
	box.add_child(_expression)
	var emote_row := HBoxContainer.new()
	box.add_child(emote_row)
	_emote = OptionButton.new()
	for name: String in FrogRig.EMOTES:
		_emote.add_item(name.capitalize())
	_emote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emote_row.add_child(_emote)
	_button(emote_row, "Play", func() -> void:
		for frog in frogs:
			frog.frog_rig().emote(FrogRig.EMOTES[_emote.selected], 3.0))
	_heading(box, "Skin")
	_toggle(box, "Warts", false, func(on: bool) -> void:
		_warts = on
		_make())
	_toggle(box, "Tongue in the open mouth", FrogRig.tongue_in_mouth, func(on: bool) -> void: FrogRig.tongue_in_mouth = on)
	_toggle(box, "Ink outlines", true, func(on: bool) -> void:
		_lines = on
		_make())
	_heading(box, "Blinking")
	_button(box, "Blink now", func() -> void:
		for frog in frogs:
			frog.frog_rig().blink())
	_slider(box, "How long a blink takes (s)", 0.05, 0.8, _blink_time, func(v: float) -> void:
		_blink_time = v
		for frog in frogs:
			frog.frog_rig().blink_time = v
			frog.frog_rig().blink())
	_slider(box, "Second eye behind the first (s)", 0.0, 0.4, _blink_gap, func(v: float) -> void:
		_blink_gap = v
		for frog in frogs:
			frog.frog_rig().blink_gap = v
			frog.frog_rig().blink())
	_heading(box, "Look from")
	var views := GridContainer.new()
	views.columns = 2
	box.add_child(views)
	for k in VIEWS.size():
		_button(views, VIEWS[k][0], func() -> void: _view(k))
	var hint := Label.new()
	hint.text = "Drag the picture to turn round,\nthe wheel to come closer,\nright-drag to slide."
	hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	box.add_child(hint)


func _heading(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.98, 0.78, 0.35))
	box.add_child(label)


func _button(box: Container, text: String, pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	box.add_child(button)


func _toggle(box: Container, text: String, on: bool, toggled: Callable) -> void:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = on
	check.toggled.connect(toggled)
	box.add_child(check)


func _slider(box: Container, text: String, low: float, high: float, value: float, moved: Callable) -> void:
	var label := Label.new()
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	label.text = "%s: %.2f" % [text, value]
	slider.value_changed.connect(func(v: float) -> void:
		label.text = "%s: %.2f" % [text, v]
		moved.call(v))
	box.add_child(slider)


func _set_expression(name: String) -> void:
	_expression.selected = maxi(FrogRig.EXPRESSIONS.keys().find(name), 0)
	for frog in frogs:
		frog.frog_rig().expression = name


func _view(k: int) -> void:
	_yaw = VIEWS[k][1]
	_pitch = VIEWS[k][2]
	_distance = VIEWS[k][3]
	_centre = Vector3(0.0, 0.95 if k == 4 or k == 6 else (0.15 if k == 5 else 0.8), 0.0)


# --- The frogs ---

func _make() -> void:
	for frog in frogs:
		frog.queue_free()
	frogs.clear()
	# (the viewer shows the outfit picked, whatever the scene's switch says)
	Frog.clothed = true
	var bodies := ["slim", "round", "squat"]
	for k in bodies.size():
		var look := FrogLook.random(7 + k)
		var chosen: Dictionary = OUTFITS[_outfit][1].duplicate()
		if _warts:
			chosen["warts"] = "on"
		look["parts"] = FrogLook.parts_for(chosen)
		look["body"] = bodies[k]
		look["size"] = 1.0
		look["build"] = 1.0
		look["head"] = 1.0
		look["blink_time"] = _blink_time
		look["blink_gap"] = _blink_gap
		var frog := Frog.new()
		frog.look = look
		frog.dance = "watch"
		frog.position = Vector3((k - 1) * 1.1, 0.0, 0.0)
		add_child(frog)
		if not _lines:
			FrogToon.apply(frog.rig._figure, look.get("colours", {}), false)
			frog.rig.bind_face()
		if _expression:
			frog.frog_rig().expression = FrogRig.EXPRESSIONS.keys()[_expression.selected]
		frogs.append(frog)
	# (they look about: at each other, and at whoever is looking at them)
	for frog in frogs:
		frog.frog_rig().look_around = [_camera, _camera] + frogs.filter(func(other: Frog) -> bool: return other != frog)


# --- Looking round them ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 0.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 15.0)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_drag = event.button_index if event.pressed else 0
	elif event is InputEventMouseMotion and _drag != 0:
		if _drag == MOUSE_BUTTON_LEFT:
			_yaw -= event.relative.x * 0.006
			_pitch = clampf(_pitch + event.relative.y * 0.006, -1.2, 1.4)
		else:
			_centre += (-_camera.global_basis.x * event.relative.x + _camera.global_basis.y * event.relative.y) * 0.002 * _distance


func _process(_delta: float) -> void:
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at_from_position(_centre + offset, _centre)


func _shoot(path: String) -> void:
	for frame in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
