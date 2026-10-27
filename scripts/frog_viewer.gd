extends Node3D
## The frog viewer (viewer.tscn): the three bodies side by side on a plain floor, bare, in the real
## toon shading, to look the models over. Drag to turn round them, the wheel to come closer,
## right-drag to slide.
##   C  the next outfit (bare, then the crowd's and the band's)
##   E  the next expression (FrogRig.EXPRESSIONS)
##   Space  the next emote (FrogRig.EMOTES)
##   W  warts on and off      L  ink outlines on and off
##   B  blink    [ ]  the second eye later or sooner    - =  blinks slower or quicker
## (From the command line it can also save a picture: `godot --path . res://viewer.tscn -- <file.png>`.)

const OUTFITS := [
	{}, {"coat": "tails", "neck": "bow", "legs": "trousers", "hat": "top"}, {"coat": "dress", "hat": "bonnet"},
	{"coat": "band", "legs": "trousers", "hat": "shako"}, {"coat": "frock", "neck": "cravat", "legs": "trousers", "hat": "bowler"},
	{"coat": "waistcoat", "neck": "scarf", "legs": "breeches", "hat": "cap"},
]

var frogs: Array[Frog] = []
var _outfit := 0
var _expression := 0
var _emote := 0
var _warts := false
var _lines := true
var _camera: Camera3D
var _yaw := 0.3
var _pitch := 0.15
var _distance := 4.2
var _centre := Vector3(0.0, 0.95, 0.0)
var _drag := 0
var _label: Label


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
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(shape)
	add_child(floor_body)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	add_child(_camera)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)
	_make()
	# (from the command line: `-- <file.png> [expression] [close]` saves a picture and quits)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].ends_with(".png"):
		if args.size() > 1:
			_expression = maxi(FrogRig.EXPRESSIONS.keys().find(args[1]), 0)
			for frog in frogs:
				frog.frog_rig().expression = args[1]
		if args.size() > 2:
			_distance = 1.5
			_centre = Vector3(0.0, 0.95, 0.0)
			_yaw = 0.25
			_pitch = 0.05
		_shoot(args[0])


func _make() -> void:
	for frog in frogs:
		frog.queue_free()
	frogs.clear()
	var bodies := ["slim", "round", "squat"]
	for k in bodies.size():
		var look := FrogLook.random(7 + k)
		var chosen: Dictionary = OUTFITS[_outfit].duplicate()
		if _warts:
			chosen["warts"] = "on"
		look["parts"] = FrogLook.parts_for(chosen)
		look["body"] = bodies[k]
		look["size"] = 1.0
		look["build"] = 1.0
		look["head"] = 1.0
		var frog := Frog.new()
		frog.look = look
		frog.dance = "watch"
		frog.position = Vector3((k - 1) * 1.1, 0.0, 0.0)
		add_child(frog)
		if not _lines:
			FrogToon.apply(frog.rig._figure, look.get("colours", {}), false)
			frog.rig.bind_face()
		frog.frog_rig().expression = FrogRig.EXPRESSIONS.keys()[_expression]
		frogs.append(frog)
	# (they look about: at each other, and at whoever is looking at them)
	for frog in frogs:
		frog.frog_rig().look_around = [_camera, _camera] + frogs.filter(func(other: Frog) -> bool: return other != frog)
	_label.text = "outfit %d   expression: %s   warts %s   lines %s\nC outfit   E expression   Space emote   W warts   L lines   B blink   [ ] blink gap   - = blink speed   drag to turn, wheel to zoom" % [
			_outfit, FrogRig.EXPRESSIONS.keys()[_expression], "on" if _warts else "off", "on" if _lines else "off"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_outfit = (_outfit + 1) % OUTFITS.size()
				_make()
			KEY_W:
				_warts = not _warts
				_make()
			KEY_L:
				_lines = not _lines
				_make()
			KEY_E:
				_expression = (_expression + 1) % FrogRig.EXPRESSIONS.size()
				for frog in frogs:
					frog.frog_rig().expression = FrogRig.EXPRESSIONS.keys()[_expression]
				_label.text = _label.text.get_slice("expression:", 0) + "expression: " + FrogRig.EXPRESSIONS.keys()[_expression]
			KEY_B:
				for frog in frogs:
					frog.frog_rig().blink()
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				for frog in frogs:
					var rig := frog.frog_rig()
					rig.blink_gap = clampf(rig.blink_gap + (0.02 if event.keycode == KEY_BRACKETRIGHT else -0.02), 0.0, 0.4)
					rig.blink()
				_note("blink gap %.2f s" % frogs[0].frog_rig().blink_gap)
			KEY_MINUS, KEY_EQUAL:
				for frog in frogs:
					var rig := frog.frog_rig()
					rig.blink_time = clampf(rig.blink_time * (1.25 if event.keycode == KEY_MINUS else 0.8), 0.05, 1.0)
					rig.blink()
				_note("blink time %.2f s" % frogs[0].frog_rig().blink_time)
			KEY_SPACE:
				_emote = (_emote + 1) % FrogRig.EMOTES.size()
				for frog in frogs:
					frog.frog_rig().emote(FrogRig.EMOTES[_emote], 3.0)
	elif event is InputEventMouseButton:
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


func _note(text: String) -> void:
	var lines := _label.text.split("
")
	_label.text = lines[0].get_slice("   |", 0) + "   | " + text + "
" + lines[1]


func _process(_delta: float) -> void:
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.look_at_from_position(_centre + offset, _centre)


func _shoot(path: String) -> void:
	for frame in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
