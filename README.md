# Frogulizer

A music visualiser. A band of frogs in scarlet and gold plays on the bandstand of a paddle steamer going down an
autumn river at sundown, and a crowd of frogs in their Sunday best dances on the deck. Everything moves to the song
that is playing: the band plays each instrument's part of it, the whole crowd dances harder as it gets louder, the
smokestacks puff on the beat, the bandstand's bulbs brighten, and the camera cuts on the phrases.

After the riverboat frogs in *Over the Garden Wall* (the reference art is in `inpsirationArt/`). Godot 4.7, GL
Compatibility. The desktop app makes the films; the web build is for setting shots up on a phone.

## Watching it, and making films of it

The camera desk has every control on screen: the bar along the bottom plays the songs (back, play and pause, on, a
bar to scrub through the song, the volume) and shows which camera is on; the panel (☰ Desk) has the songs, the
camera (Auto, held shots, Fly, Orbit, Follow, Path), the lens, the look, moves (keys of a camera move, saved as
takes) and the render (a film of it, made frame by frame on the computer with Movie Maker and ffmpeg). Keys: Space
pause, P/N songs, C next shot, K add a key, Tab the panel, H everything.

**On a phone** (the web build, on the arcade behind the code FROG): the same desk, laid out at the phone's size
(held upright, the panel is under the picture). One finger turns the orbit or looks round in Fly; two pinch in and
out and slide. It is the lighter version (8 dancers and 2 passengers, the 3D drawn at about 1.5 pixels to the
browser's; add `?full` to the address for everything). A browser cannot render films: make the move on the phone,
**Copy take** (Moves), send the text to the computer, and **Paste take** into the desk there to render it. A take
carries the keys, the frame, the lens and the look.

## Songs

Songs are not part of the project: **any song file can be brought aboard in the game**. On the desk's Song tab,
**+ Add songs...** opens a file browser (the computer's own; on a phone, its file picker), and each song picked is
listened to once for its **beat map** and kept, with the map, in `user://songs` (in the browser, the page's own
storage). **Remove** takes the chosen one off again. `.mp3`, `.ogg` and `.wav` are kept as they are; anything else the
computer's ffmpeg or the browser can read (`.m4a`, `.flac`...) is kept as a `.wav` made from it. With no songs aboard
the desk opens at the Song tab.

The listening (`scripts/music/song_import.gd`) cuts the song into six bands of pitch as loudness over time: on the
computer with the ffmpeg in `scareathon/trailer`, in the browser with Web Audio's filters (the same ones; a 4-minute
song takes about 4 s in a desktop browser). `scripts/music/song_analysis.gd` then finds the beats, the tempo, the bar
lines (3 or 4 to the bar), where each band is struck, and roughly where the voice is. The title and who it is by come
from the song's tags (on the computer) or its file name (`Artist - Title.mp3`).

The analysis is done ahead of time because a browser plays the song outside Godot's mixer, where nothing can listen
to it as it plays. To bring songs aboard from the command line (a whole folder at once):

```
godot --headless --path . --script tools/add_songs.gd -- <song or folder>...
```

How the band is read off the sound (`scripts/music/track_player.gd`, `PARTS`):

| Band (Hz) | Who plays it |
| --- | --- |
| 30-120 | the drummer's bass drum and snare |
| 120-400 | the tuba |
| 400-1200 | the banjo (plucks) and the accordion (bellows) |
| 1200-3000 | the trumpet and the clarinet |
| 3000-6000 | the fiddle (a bow stroke each time), the banjo's attack |
| 6000-14000 | the drummer's cymbal |

Every 8 bars the tune passes to whichever of the front line (trumpet, clarinet, fiddle, accordion, banjo) is loudest
in its own band over the coming phrase. That frog steps forward and plays out, the conductor brings them in, and the
camera often cuts to them.

## The frogs

`models/frog.glb` (and `frog_lo.glb` for the far crowd) is built by `tools/build_frogs.py` in Blender 4.3:

```
"/c/Program Files/Blender Foundation/Blender 4.3/blender.exe" --background --python tools/build_frogs.py [-- <preview folder>]
godot --headless --path . --import
```

It is built **on the boy's skeleton** from GameCommon's character controller (the contract in
`tools/build_figure_template.py`), so `CharacterRig`, the code that animates the Outside / Character Studio boy, moves
it exactly as it moves him: standing, breathing, shifting its weight, looking about, walking and running.
`tools/figure_sheets.gd` checks it the way it checks any figure:

```
godot --path . --fixed-fps 60 --resolution 960x960 --script tools/figure_sheets.gd -- <folder> res://models/frog.glb 1.35
```

A frog is a broad flat head, mostly mouth, sitting straight on a pear of a body; big eyes on top under heavy lids; thin
arms, three long fingers and a thumb with round pads; thin legs; long flat webbed feet. Its own extra bones are `jaw`
(the mouth opens, and the throat puffs as it blows), `lid_l`/`lid_r` (blinks and droops), and the eyes, which the rig
already turns.

Clothes are options on slots in the same model (`frog_<slot>__<option>`, which `CharacterRig.restyle` shows by the
look's "parts"): hats (top, bowler, shako, boater, bonnet with feathers, helmet, cap, fez), coats (tails, band jacket,
frock, jacket, dress, waistcoat), neckwear (bow and collar, cravat, scarf) and legs (trousers, breeches). Every
material can be recoloured. `scripts/frog_look.gd` (FrogLook) makes up crowd members from a seed (ladies, gentlemen,
working frogs) and dresses the band.

`scripts/frog_rig.gd` (FrogRig, extends CharacterRig) lays the frog's own business over the boy's rig. It puts the
hands on an instrument and plays it with each strike. The conductor beats time in the bar's pattern. The crowd dances
bounce, sway, clap, wave, jig, a partner waltz, or just watches. `scripts/frog.gd` (Frog) is a GameCommon `Figure` on
the frog model. `scripts/instrument.gd` builds the tuba, trumpet, clarinet, accordion, fiddle and bow, banjo, drum kit
and baton in code.

## Layout

| File | What |
| --- | --- |
| `main.tscn`, `scripts/main.gd` | Puts it together: river, boat, band, crowd, camera, HUD, the song player |
| `scripts/music/song_import.gd` | + Add songs: the file browser, listening to a song (ffmpeg, or Web Audio in the browser), keeping it in `user://songs` |
| `scripts/music/song_analysis.gd` | A song's beat map from its bands: beats, tempo, bars, where each band is struck, the voice |
| `scripts/music/track_player.gd` | Plays the songs, reads their beat maps, keeps `Groove` up to date, tells the band when it is struck |
| `scripts/music/groove.gd` | What the music is doing now (beat, tempo, loudness, each part's level, who has the tune), for everything that moves to it |
| `scripts/boat.gd` | The riverboat, built in code: hull, deck (`shaders/deck.gdshader`), railings, bandstand with bulbs (`shaders/bulb.gdshader`), paddlewheels, cabin, pilot house, stacks with smoke (`scripts/train_smoke.gd`, from Outside), bunting (`shaders/bunting.gdshader`) |
| `scripts/river.gd` | The river going by: water (GameCommon `water`), banks (`shaders/ground.gdshader`), autumn woods, reeds, sky and falling leaves (GameCommon `painted-woodland`, in `woodland/`), hills |
| `scripts/crowd.gd` | The dancers, couples, and watchers at the rails |
| `scripts/director.gd` | The camera: shots, cuts on phrases, the same width on a phone held upright |
| `scripts/hud.gd` | The song's title and artist as it starts |
| `scripts/camera_desk.gd` | The camera desk: all the controls, on a computer or a phone, takes and renders |
| `scripts/frog*.gd`, `scripts/instrument.gd` | The frogs (above) |
| GameCommon's | `scripts/character_rig.gd`, `player.gd`, `figure.gd`, `toon.gd`, `settings.gd`, ... and `tools/build_character.py`, `figure_sheets.gd` ... (`godot/character-controller`); `scripts/water.gd` (`godot/water`); `woodland/` (`godot/painted-woodland`) |

## Checking it

```
godot --headless --path . --import
godot --audio-driver Dummy --path . --resolution 1280x720 --script tests/shots.gd -- <folder> [shot ...]
godot --audio-driver Dummy --path . --resolution 540x1100 --script tests/shots.gd -- <folder>
godot --audio-driver Dummy --path . --resolution 1280x720 --script tests/bench.gd -- <folder>
```

```
godot --audio-driver Dummy --path . --resolution 390x844 --script tests/touch.gd
godot --audio-driver Dummy --path . --resolution 390x844 --script tests/songs.gd
```

`tests/shots.gd` plays the show and saves a picture of every camera shot with the frame rate. `tests/bench.gd` puts
the band and one dancer of each kind on a plain floor. `tests/touch.gd` checks the desk on a phone (its layout, a
one-finger drag, a pinch, a take copied and pasted) and `tests/songs.gd` brings a song aboard, plays it and takes it
off (it needs a song aboard already to copy); both end PASSED or FAILED. The shots and the bench play the songs aboard. `--audio-driver Dummy` keeps them quiet.

Web build: `godot --headless --path . --export-release "Web" build/index.html`, committed in `build/` (GitHub
Pages serves it: sclondon.github.io/Frogulizer/build/). Fonts are bundled in `fonts/` (a browser has no others).
No songs are in the repo or the web build (`music/`, `*.mp3`... are ignored and kept out of the export).
