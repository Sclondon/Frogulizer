# Frogulizer

A music visualiser. A band of frogs in scarlet and gold plays on the bandstand of a paddle steamer going down an
autumn river at sundown, and a crowd of frogs in their Sunday best dances on the deck. Everything moves to the song
that is playing: the band plays each instrument's part of it, the whole crowd dances harder as it gets louder, the
smokestacks puff on the beat, the bandstand's bulbs brighten, and the camera cuts on the phrases.

After the riverboat frogs in *Over the Garden Wall* (the reference art is in `inpsirationArt/`). Godot 4.7, GL
Compatibility, for the browser and phones first.

## Watching it

Tap (or press Space) to come aboard. That starts the first song, since browsers will not play sound until the page is
touched. Tap again for the bar along the bottom: back a song, pause, on a song, and the camera (Auto cuts by itself;
Crowd, Stage, Soloist, River and High hold one shot). Keys: Space pause, Left/Right or P/N songs, C camera.

## Songs

The songs are real recordings, kept in `music/` (`.mp3`, `.ogg` or `.wav`). Each needs a **beat map** made from it
ahead of time:

```
sh tools/analyse_music.sh            # every song without an up-to-date map
sh tools/analyse_music.sh --force    # all of them again
```

That uses the ffmpeg in `scareathon/trailer` to cut the song into six bands of pitch (as loudness over time), and
`tools/analyse_music.gd` (headless Godot) to find the beats, the tempo, the bar lines (3 or 4 to the bar), and where
each band is struck. It writes `music/<song>.beats.json` beside the song and lists every song in
`music/tracks.json`, with the title and artist from the song's tags (or its file name). Edit `tracks.json` to fix a
title or change the order. Only songs listed there are played.

The analysis is done ahead of time because a browser plays the song outside Godot's mixer, where nothing can listen
to it as it plays.

`music/test_*.wav` are three short placeholder tunes from Close Encounters (made in One Man Band, our own). Replace
them with real songs, then re-run the script.

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
| `scripts/music/track_player.gd` | Plays the songs, reads their beat maps, keeps `Groove` up to date, tells the band when it is struck |
| `scripts/music/groove.gd` | What the music is doing now (beat, tempo, loudness, each part's level, who has the tune), for everything that moves to it |
| `scripts/boat.gd` | The riverboat, built in code: hull, deck (`shaders/deck.gdshader`), railings, bandstand with bulbs (`shaders/bulb.gdshader`), paddlewheels, cabin, pilot house, stacks with smoke (`scripts/train_smoke.gd`, from Outside), bunting (`shaders/bunting.gdshader`) |
| `scripts/river.gd` | The river going by: water (GameCommon `water`), banks (`shaders/ground.gdshader`), autumn woods, reeds, sky and falling leaves (GameCommon `painted-woodland`, in `woodland/`), hills |
| `scripts/crowd.gd` | The dancers, couples, and watchers at the rails |
| `scripts/director.gd` | The camera: shots, cuts on phrases, the same width on a phone held upright |
| `scripts/hud.gd` | The title, the bar, the card to come aboard |
| `scripts/frog*.gd`, `scripts/instrument.gd` | The frogs (above) |
| GameCommon's | `scripts/character_rig.gd`, `player.gd`, `figure.gd`, `toon.gd`, `settings.gd`, ... and `tools/build_character.py`, `figure_sheets.gd` ... (`godot/character-controller`); `scripts/water.gd` (`godot/water`); `woodland/` (`godot/painted-woodland`) |

## Checking it

```
godot --headless --path . --import
godot --audio-driver Dummy --path . --resolution 1280x720 --script tests/shots.gd -- <folder> [shot ...]
godot --audio-driver Dummy --path . --resolution 540x1100 --script tests/shots.gd -- <folder>
godot --audio-driver Dummy --path . --resolution 1280x720 --script tests/bench.gd -- <folder>
```

`tests/shots.gd` plays the show and saves a picture of every camera shot with the frame rate. `tests/bench.gd` puts
the band and one dancer of each kind on a plain floor. `--audio-driver Dummy` keeps them quiet.

Web build: `godot --headless --path . --export-release "Web" build/index.html`.
