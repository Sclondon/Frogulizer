extends Node3D
## Frogulizer: a music visualiser. A band of frogs plays on the bandstand of a
## paddle steamer going down an autumn river at sundown, and the crowd on the
## deck dances. The songs are in music/ (with their beat maps: see
## tools/analyse_music.sh); everything moves to them.
##
## This puts it all together: the River and the Riverboat, the band on the
## bandstand (a Frog for each part TrackPlayer reads off the music, and a
## conductor), the Crowd, the Director's camera and the Hud.

## Where each of the band stands on the bandstand (x, z), back row then front.
const PLACES := {
	"tuba": Vector2(-2.6, -13.3), "drums": Vector2(0.0, -13.6), "accordion": Vector2(2.6, -13.3),
	"banjo": Vector2(-3.0, -11.7), "clarinet": Vector2(-1.2, -11.4), "trumpet": Vector2(1.2, -11.4), "fiddle": Vector2(3.0, -11.7),
}
## How far forward whoever has the tune steps.
const STEP_FORWARD := 0.7

var river: River
var boat: Riverboat
var crowd: Crowd
var director: Director
var hud: Hud
var player: TrackPlayer
var band := {}
var conductor: Frog


func _ready() -> void:
	# (the world is shaded in the same hard bands as the frogs)
	Settings.world_banded = true
	river = River.new()
	add_child(river)
	boat = Riverboat.new()
	add_child(boat)
	var k := 0
	for part: String in PLACES:
		var frog := Frog.new()
		frog.look = FrogLook.bandsman(k)
		frog.part = part
		frog.droop = 0.15 + 0.07 * (k % 4)
		var at: Vector2 = PLACES[part]
		frog.position = Vector3(at.x, Riverboat.STAGE_Y, at.y)
		frog.add_to_group(&"band")
		add_child(frog)
		frog.turn_to(-at.x * 0.07)
		band[part] = frog
		k += 1
	conductor = Frog.new()
	conductor.look = FrogLook.bandsman(11, true)
	conductor.part = "conductor"
	conductor.droop = 0.3
	conductor.position = Vector3(0.0, Riverboat.STAGE_Y, Riverboat.STAGE_FRONT - 0.7)
	add_child(conductor)
	conductor.turn_to(PI)
	crowd = Crowd.new()
	add_child(crowd)

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
	add_child(director)
	director.make_current()

	hud = Hud.new()
	hud.player = player
	add_child(hud)
	hud.boarded.connect(func() -> void: player.play(0) if not player.tracks.is_empty() else _no_songs())
	hud.previous.connect(player.previous)
	hud.next.connect(player.next)
	hud.pause.connect(player.toggle_pause)
	hud.camera.connect(func(mode: String) -> void: director.mode = mode)


func _on_struck(part: String, loud: float) -> void:
	if part == "kick" or part == "cymbal":
		band.drums.frog_rig().strike(loud, part)
	elif band.has(part):
		band[part].frog_rig().strike(loud)


## A new phrase: whoever has the tune steps forward to play it out, the one who had it steps back.
func _on_phrase(_index: int) -> void:
	for part: String in band:
		var frog: Frog = band[part]
		var leading := part == Groove.lead
		frog.go_to(frog.home + (Vector3(0.0, 0.0, STEP_FORWARD) if leading and part != "drums" and part != "tuba" else Vector3.ZERO))
	director.on_phrase()


func _on_started(track: Dictionary) -> void:
	hud.show_title(track)
	director.cut_to("audience")


func _on_finished() -> void:
	crowd.cheer(3.5)
	for frog: Frog in band.values():
		frog.go_to(frog.home)
	get_tree().create_timer(4.5).timeout.connect(player.next)


func _no_songs() -> void:
	hud.show_title({"title": "No songs aboard yet", "artist": "Put songs in music/ and run tools/analyse_music.sh"})
