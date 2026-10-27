class_name Groove
## What the music is doing right now, for everything that moves to it (the band,
## the crowd, the lamps, the camera). The Bandleader writes it every frame.

## Beats since the song began (with the swing in it), and the song's tempo and metre.
static var beat := 0.0
static var bpm := 112.0
static var meter := 4
## Whether a song is playing at all.
static var playing := false
## How loud the band is, 0..1, rising at once with each note and falling slowly.
static var energy := 0.0
## How much each part is sounding, 0..1 (a note sets it to its loudness; it dies away).
static var level := {}
## Who has the tune now, and who plays it with them ("" for nobody: the vamp, the end).
static var lead := ""
static var second := ""
## The low end and the top: the tuba and the drums' kick, and the cymbals, hats and high notes.
static var bass := 0.0
static var treble := 0.0
## Counts up by one with each new section (to cut the camera, change the dance).
static var section := 0
static var section_name := ""
## The song, by title.
static var title := ""


## Where in the beat it is, 0 on the beat rising to 1 just before the next.
static func phase() -> float:
	return fposmod(beat, 1.0)


## A pulse on every beat: 1 on it, falling quickly away.
static func pulse(sharpness := 6.0) -> float:
	return exp(-sharpness * phase()) if playing else 0.0


## Where in the bar it is, 0..1.
static func bar_phase() -> float:
	return fposmod(beat / meter, 1.0)


static func level_of(part: String) -> float:
	return level.get(part, 0.0)


static func seconds_per_beat() -> float:
	return 60.0 / bpm


## The singing voice in the song (from the beat map: the middle of the stereo picture, where a
## singer is, less the sides): how loud, 0..1, and which way its vowel leans, from -1 (round: O, U)
## to 1 (bright: E, I), by where its sound sits.
static var voice := 0.0
static var vowel := 0.0
