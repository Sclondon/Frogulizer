# Frogulizer: notes for Claude

Read `README.md` first. A music visualiser: a frog band on a riverboat, a dancing crowd. Started 2026-10-27.

## What the user asked for

- A music visualiser: anthropomorphic frogs play on a riverboat and the crowd reacts. Inspiration art in `inpsirationArt/`
  (Over the Garden Wall's riverboat episode). Make original frogs and tunes in that spirit, never copies of its characters.
- **The songs are real songs the user downloads** into `music/`. Do not compose or synthesise music for it. The band is
  driven by analysing the recording (`tools/analyse_music.sh`), not by note data.
- New anthro frog models whose animation is as good as the Character Studio / Outside boy's, and compatible with it.
  They are built on his skeleton and moved by his `CharacterRig`. Keep them on that contract
  (`tools/build_figure_template.py`): don't give them clip animations or a skeleton of their own.
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
- `music/*.beats.json` and `music/tracks.json` are generated: re-run `tools/analyse_music.sh`, don't hand-edit maps.
  `tracks.json` titles may be edited.
- The web export includes `music/*.json` through `include_filter`. A new kind of data file needs adding there.
- Godot's front faces are clockwise. Shader variables must not be called `dot`, `length` and so on: a shader that
  fails to compile can draw nothing without printing an error.

## Where things are tuned

- The bands and who plays which: `TrackPlayer.PARTS`, `LEADS`, `PHRASE`; the analysis: `tools/analyse_music.gd`
  (`BANDS` must match the ffmpeg graph in `analyse_music.sh`; `LIKELY` tempo prior; peak thresholds in `_peaks`).
  Octave errors in tempo (half or double) happen; the instruments follow the hits, not the beat.
- Band positions: `main.gd` `PLACES`; the instruments' layout is in the frog's model space (`Instrument`, with
  `MOUTH`); hands go to the instrument's `grips`.
- Dances: `FrogRig._dance`; crowd mix: `Crowd._pick_dance`, `count`, `low_from`.
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
`modelDebugimages/` are kept out of git: the repo is public. So is everything in `music/` once exported.

Not done yet / ideas: a far crowd as one MultiMesh (ScenicRoute's Velvet Moth crowd shader); dusk and night across a
set of songs, with lanterns; a live analyser for songs dropped in without a map (desktop only); frogs singing along to
vocals; clothes (on hold until the body is right).
