#!/bin/sh
# Analyses every song in music/ that has no up-to-date beat map yet (or all of them with --force),
# then lists them all in music/tracks.json. Run from the project root:
#     sh tools/analyse_music.sh [--force]
# Songs can be .mp3, .ogg or .wav. A song's title and artist are taken from its tags if it has them,
# else from its file name; music/tracks.json can be edited by hand after (it is only rewritten here).
set -e
FFMPEG=${FFMPEG:-/c/Projects/scareathon/trailer/node_modules/ffmpeg-static/ffmpeg.exe}
GODOT=${GODOT:-"/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"}
WORK=${TMPDIR:-/tmp}/frogulizer_envelopes
mkdir -p "$WORK"
# The bands' edges must match BANDS in tools/analyse_music.gd. Each is rectified and smoothed to an
# envelope and taken down to 100 a second; the seventh is the whole sound.
ENV="aeval=exprs=abs(val(0)),lowpass=f=25,lowpass=f=25,aresample=100"
GRAPH="[0:a]aresample=22050,asplit=7[s0][s1][s2][s3][s4][s5][s6];\
[s0]highpass=f=30,lowpass=f=120,$ENV[o0];\
[s1]highpass=f=120,lowpass=f=400,$ENV[o1];\
[s2]highpass=f=400,lowpass=f=1200,$ENV[o2];\
[s3]highpass=f=1200,lowpass=f=3000,$ENV[o3];\
[s4]highpass=f=3000,lowpass=f=6000,$ENV[o4];\
[s5]highpass=f=6000,lowpass=f=10000,$ENV[o5];\
[s6]$ENV[o6]"
for song in music/*.mp3 music/*.ogg music/*.wav; do
	[ -f "$song" ] || continue
	map="${song%.*}.beats.json"
	if [ -f "$map" ] && [ "$map" -nt "$song" ] && [ "$1" != "--force" ]; then
		continue
	fi
	echo "analysing $song"
	"$FFMPEG" -v error -y -i "$song" -ac 1 -filter_complex "$GRAPH" \
		-map "[o0]" -f f32le "$WORK/b0.raw" -map "[o1]" -f f32le "$WORK/b1.raw" -map "[o2]" -f f32le "$WORK/b2.raw" \
		-map "[o3]" -f f32le "$WORK/b3.raw" -map "[o4]" -f f32le "$WORK/b4.raw" -map "[o5]" -f f32le "$WORK/b5.raw" \
		-map "[o6]" -f f32le "$WORK/b6.raw"
	tags=$("$FFMPEG" -i "$song" 2>&1 || true)
	title=$(printf '%s\n' "$tags" | sed -n 's/^ *title *: //p' | head -1)
	artist=$(printf '%s\n' "$tags" | sed -n 's/^ *artist *: //p' | head -1)
	"$GODOT" --headless --path . --script tools/analyse_music.gd -- "$WORK" "$map" "$song" "$title" "$artist" 2>&1 | grep -v "^Godot Engine\|^$" || true
done
"$GODOT" --headless --path . --script tools/analyse_music.gd -- --manifest 2>&1 | grep -v "^Godot Engine\|^$" || true
