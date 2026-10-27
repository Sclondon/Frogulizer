extends Node3D
## Frogulizer: a music visualiser. A band of frogs plays in the bandstand at the back of a paddle
## steamer's cabin as it goes down an autumn river at sundown, and the crowd on the stern deck
## dances. The songs are in music/ (with their beat maps: see tools/analyse_music.sh); everything
## moves to them.
##
## This puts it all together: the River and the Riverboat, the band (a Frog for each part
## TrackPlayer reads off the music, a singer and a conductor), the Crowd, the Director's camera
## and the Hud. Everyone aboard is a child of the boat, and goes down the river with it.

## Where each of the band stands in the bandstand (x, z on the boat), back row then front. They face aft.
const PLACES := {
	"tuba": Vector2(-1.8, 0.35), "drums": Vector2(0.0, 0.45), "accordion": Vector2(1.8, 0.35),
	"banjo": Vector2(-2.0, -1.1), "clarinet": Vector2(-0.75, -0.9), "trumpet": Vector2(0.75, -0.9), "fiddle": Vector2(2.0, -1.1),
}
## How far forward (aft, to the crowd) whoever has the tune steps.
const STEP_FORWARD := 0.55

var river: River
var boat: Riverboat
var crowd: Crowd
var director: Director
var hud: Hud
var player: TrackPlayer
var band := {}
var conductor: Frog
var singer: Frog
var captain: Frog
var passengers: Passengers
var pixels: Pixelate
var desk: CameraDesk
## Rendering a film (a second Godot started by the camera desk, with Movie Maker): its settings.
var render := {}
## The lighter version, for phones (in a browser, unless the address has ?full): fewer frogs.
var lite := false
var _rendered := 0.0


func _ready() -> void:
	# (the world is shaded in the same hard bands as the frogs)
	Settings.world_banded = true
	var query := str(JavaScriptBridge.eval("location.search", true)) if OS.has_feature("web") else ""
	lite = OS.has_feature("web") and not query.contains("full")
	boat = Riverboat.new()
	add_child(boat)
	river = River.new()
	river.boat = boat
	add_child(river)
	if lite:
		# (a phone's screen has two or three pixels to each of the browser's: the 3D is drawn at about one and a half)
		get_viewport().scaling_3d_scale = clampf(1.5 / DisplayServer.screen_get_scale(), 0.5, 1.0)
	var k := 0
	for part: String in PLACES:
		var at: Vector2 = PLACES[part]
		band[part] = _aboard(FrogLook.bandsman(k), part, Vector3(at.x, Riverboat.STAGE_Y, at.y), PI + at.x * 0.06)
		band[part].add_to_group(&"band")
		k += 1
	singer = _aboard(FrogLook.singer(4), "singer", Vector3(0.0, Riverboat.STAGE_Y, Riverboat.STAGE_FRONT + 0.45), PI)
	singer.frog_rig().sings = 1.0
	conductor = _aboard(FrogLook.bandsman(11, true), "conductor", Vector3(-1.7, Riverboat.DECK_Y, Riverboat.STAGE_FRONT - 1.2), 0.35)
	crowd = Crowd.new()
	crowd.boat = boat
	if lite:
		crowd.count = 8
	add_child(crowd)
	passengers = Passengers.new()
	passengers.boat = boat
	passengers.few = lite
	add_child(passengers)
	# The captain at the wheel in the pilot house, on top of it all
	captain = _aboard(FrogLook.captain(21), "helm", Vector3(0.0, Riverboat.UPPER_Y, Riverboat.CABIN_FRONT - 2.05), 0.0)
	_set_gazes()

	player = TrackPlayer.new()
	add_child(player)
	player.struck.connect(_on_struck)
	player.phrase.connect(_on_phrase)
	player.started.connect(_on_started)
	player.finished.connect(_on_finished)

	director = Director.new()
	director.boat = boat
	director.river = river
	director.band = band
	director.conductor = conductor
	director.singer = singer
	add_child(director)
	director.make_current()

	pixels = Pixelate.new()
	add_child(pixels)

	hud = Hud.new()
	hud.player = player
	add_child(hud)
	# (nothing plays until Play on the desk)
	if player.tracks.is_empty():
		_no_songs()

	# (the desk has all the controls: playing, the camera, the picture, moves and renders)
	desk = CameraDesk.new()
	desk.director = director
	desk.boat = boat
	desk.player = player
	desk.hud = hud
	desk.river = river
	desk.frogs = [["The boat", boat], ["The singer", singer], ["The conductor", conductor], ["The captain", captain]]
	for part: String in band:
		desk.frogs.append([part.capitalize(), band[part]])
	for n in crowd.frogs.size():
		desk.frogs.append(["Dancer %d" % (n + 1), crowd.frogs[n]])
	add_child(desk)
	desk.setup()
	_start_render()


func _process(delta: float) -> void:
	director.crop = desk.frame_rect() if desk and desk.frame_kind != "free" else Rect2()
	if not render.is_empty():
		# (counted in frames rendered, which Movie Maker keeps exactly: the music's own clock wanders
		# when the pictures are slow to make)
		_rendered += delta
		if _rendered >= float(render.to) - float(render.get("from", 0.0)) or not player.playing and _rendered > 0.5:
			get_tree().quit()


## With `-- --render <settings.json>` (the camera desk does this): play the song from where it says,
## with the camera it says, and stop at the end, for Movie Maker to have written it all.
func _start_render() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--render")
	if at < 0 or at + 1 >= args.size():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[at + 1]))
	if not data is Dictionary:
		return
	render = data
	hud.visible = false
	desk.apply_render(render)
	player.play(int(render.get("song", 0)), float(render.get("from", 0.0)))


## Who looks at whom: the crowd at the bandstand (whoever has the tune most of all, or the singer)
## and at each other; the band at the conductor, each other and the crowd.
func _set_gazes() -> void:
	var stage: Array = band.values() + [singer]
	var lead := func() -> Node3D: return band.get(Groove.lead, singer) if Groove.voice < 0.4 else singer
	for frog in crowd.frogs:
		var near: Array = crowd.frogs.filter(func(other: Frog) -> bool: return other != frog and other.position.distance_to(frog.position) < 2.5)
		frog.frog_rig().look_around = stage + stage + near
		frog.frog_rig().look_lead = lead
	for frog: Frog in stage + [conductor]:
		frog.frog_rig().look_around = [conductor, conductor] + crowd.frogs.slice(0, 8) + stage
		frog.frog_rig().look_lead = lead
	# The passengers at whoever is near them, the dancers, the singer, the river ahead
	var ahead := Node3D.new()
	ahead.position = Vector3(0.0, 3.0, 60.0)
	boat.add_child(ahead)
	for frog in passengers.frogs:
		var near: Array = passengers.frogs.filter(func(other: Frog) -> bool: return other != frog and other.position.distance_to(frog.position) < 4.0)
		frog.frog_rig().look_around = [ahead] + near + crowd.frogs.slice(0, 4) + [singer]
	captain.frog_rig().look_around = [ahead, ahead, ahead] + boat.stacks


func _aboard(look: Dictionary, part: String, at: Vector3, yaw: float) -> Frog:
	var frog := Frog.new()
	frog.look = look
	frog.part = part
	frog.droop = look.get("droop", 0.25)
	frog.position = at
	frog.home_yaw = yaw
	boat.add_child(frog)
	return frog


func _on_struck(part: String, loud: float) -> void:
	if part == "kick" or part == "cymbal":
		band.drums.frog_rig().strike(loud, part)
	elif band.has(part):
		band[part].frog_rig().strike(loud)


## A new phrase: whoever has the tune steps forward to play it out, the one who had it steps back.
func _on_phrase(_index: int) -> void:
	for part: String in band:
		var frog: Frog = band[part]
		var leading := part == Groove.lead and part != "drums" and part != "tuba"
		frog.go_to(frog.home + (Vector3(0.0, 0.0, -STEP_FORWARD) if leading else Vector3.ZERO))
	crowd.on_phrase()
	director.on_phrase()


func _on_started(track: Dictionary) -> void:
	hud.show_title(track)
	director.cut_to("audience")


func _on_finished() -> void:
	crowd.cheer(3.5)
	passengers.cheer(3.5)
	for frog: Frog in band.values():
		frog.go_to(frog.home)
	get_tree().create_timer(4.5).timeout.connect(player.next)


func _no_songs() -> void:
	hud.show_title({"title": "No songs aboard yet", "artist": "Put songs in music/ and run tools/analyse_music.sh"})
