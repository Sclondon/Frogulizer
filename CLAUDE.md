# Frogulizer: notes for Claude

Read `README.md` first. A music visualiser: a frog band on a riverboat, a dancing crowd. Started 2026-10-27.

## What the user asked for

- A music visualiser: anthropomorphic frogs play on a riverboat and the crowd reacts. Inspiration art in `inpsirationArt/`
  (Over the Garden Wall's riverboat episode). Make original frogs and tunes in that spirit, never copies of its characters.
- **The songs are real songs the user brings aboard in the game** (Song tab, + Add songs: a file browser), kept in
  `user://songs`. **Never put songs in the repo or the web build** (the user, 2026-10-27). Do not compose or synthesise
  music for it. The band is driven by analysing the recording (`SongImport`, `SongAnalysis`), not by note data.
- New anthro frog models whose animation is as good as the Character Studio / Outside boy's, and compatible with it.
  They are built on his skeleton and moved by his `CharacterRig`. Keep them on that contract
  (`tools/build_figure_template.py`): no skeleton of their own. (An earlier note here said "no clip animations": that
  was Claude's reading, not the user's. Captured dances are wanted, as long as they work for every figure on the boy's
  skeleton: GameCommon's `MoveClip`, `moves/`, played by the rig; see `FrogRig.MOVES`.)
- Reuse GameCommon and the other games before making anything new.
- **Don't play sound on the user's machine while checking.** Windowed test runs pop a window up; always pass
  `--audio-driver Dummy`.

## Rules

- GameCommon's files here are installed with `kit.sh` and are shared: `player.tscn`, `scripts/` files from the
  character controller (`character_rig.gd`, `player.gd`, `figure.gd`, `toon.gd`, `settings.gd`, `water.gd`...),
  `models/boy*.glb`, `models/worn/`, `tools/build_character.py`, `build_boy.py`, `build_figure_template.py`, the
  `tools/*_sheets.gd`, and `woodland/`. Change frog things in the frog files (`frog_rig.gd` overrides `_pose_extra`).
  An improvement to the shared rig belongs in Character Studio and goes back to GameCommon from there.
- `scripts/train_smoke.gd` is Outside's, copied unchanged.
- Beat maps (`user://songs/<song>.beats.json`) are generated: bring the song aboard again rather than hand-edit one.
  To test with songs, `tools/add_songs.gd` adds files from the command line (Close Encounters' One Man Band tunes will do).
- The web listening (`SongImport._WEB`, Web Audio) must cut the same bands as the ffmpeg graph (`SongImport._graph`).
- Godot's front faces are clockwise. Shader variables must not be called `dot`, `length` and so on: a shader that
  fails to compile can draw nothing without printing an error.

## Where things are tuned

- The bands and who plays which: `TrackPlayer.PARTS`, `LEADS`, `PHRASE`; the analysis: `SongAnalysis`
  (`SongImport.CUTS`/`VOICE` are the bands' edges; `LIKELY` tempo prior; peak thresholds in `_peaks`).
  Octave errors in tempo (half or double) happen; the instruments follow the hits, not the beat.
- Band positions: `main.gd` `PLACES`; the instruments' layout is in the frog's model space (`Instrument`, with
  `MOUTH`); hands go to the instrument's `grips`.
- Dances: `FrogRig._dance` (made in code) and `FrogRig.MOVES` (captured from life: GameCommon's `moves/`, CMU motion
  capture, brought in and made over with Character Studio's `tools/import_bvh.gd`); crowd mix: `Crowd._pick_dance`
  (about two in three dance a captured one), `count`, `low_from`.
- The open mouth's shape: `build_frogs.py` `lip_drop` (`LIP_CORNER`, `LIP_DEPTH`: corners pinched, a rounded U) and
  `LIP_RISE` (the `gape` shape); `FrogRig.JAW_SLIDE` (the jaw slides forward as it opens, or the chin folds the
  throat up over the mouth). The inside of the skin is drawn as the inside of the mouth in the head (`mouth.gdshader`).
- Shots: `Director.SHOTS`, `ROTATION`.
- Look: `River._air` (fog, exposure, sun), `River._water`, `Riverboat` colours.

## Who it is for

- The desktop app is the user's tool for making music-video edits (films rendered by the camera desk). Quality first there.
- The web build (2026-10-27) is so the user can set shots up **from their phone**: the same camera desk laid out for a
  phone, takes copied as text to the computer to render. It is a secret cabinet on the arcade, code **FROG**. In a
  browser `main.gd` runs `lite` (fewer frogs, 3D at about 1.5 browser pixels); `?full` turns that off. Scripts run
  about 4x slower in the browser than natively: about 25-34 fps on a desktop browser with `lite`.
- Every control must have an on-screen button; touch must work (`tests/touch.gd`).

## State (2026-10-27)

Repo github.com/Sclondon/Frogulizer, Pages serves `build/`. `inpsirationArt/` (Over the Garden Wall stills) and
`modelDebugimages/` are kept out of git: the repo is public. No songs in it or in the build.

Not done yet / ideas: a far crowd as one MultiMesh (ScenicRoute's Velvet Moth crowd shader); dusk and night across a
set of songs, with lanterns; frogs singing along to
vocals; clothes (on hold until the body is right).
